/**
 * The AI schedule assistant.
 *
 * Knows nothing about which model answers it — EinsteinModelsGateway is the
 * only file that touches the `aiplatform` namespace. Speech is a separate
 * concern reached through the `Speech_API` named credential.
 *
 * The assistant can only CREATE appointments. It can neither change nor cancel
 * one that already exists, so it holds no update or delete path at all.
 *
 * Conversation memory lives on the client and travels with each request: the
 * spec closes and forgets a conversation the moment its appointment is booked,
 * so there is nothing server-side worth persisting.
 */
public with sharing class ScheduleAssistantService {
    /**
     * Chosen by the user: JSON in, JSON out — no multipart from Apex, which is
     * unreliable to build. Speech-to-text and text-to-speech sit on different
     * hosts, so they take one named credential each; swapping provider is a
     * change to the credential URL plus these two paths.
     */
    private static final String STT_CREDENTIAL = 'callout:Speech_STT_API';
    private static final String TTS_CREDENTIAL = 'callout:Speech_TTS_API';
    private static final String STT_PATH = '/v1/speech:recognize';
    private static final String TTS_PATH = '/v1/text:synthesize';
    private static final String SPEECH_LANGUAGE = 'en-US';
    private static final String TTS_VOICE = 'en-US-Standard-C';
    private static final Integer CALLOUT_TIMEOUT_MS = 120000;

    public static final String ACTION_ASK = 'ASK';
    public static final String ACTION_BOOK = 'BOOK';
    public static final String ACTION_CANCEL = 'CANCEL';

    /** One turn of the conversation as the client remembers it. */
    public class Turn {
        @AuraEnabled
        public String role { get; set; }
        @AuraEnabled
        public String content { get; set; }
    }

    /** What the assistant hands back for one exchange. */
    public class Reply {
        @AuraEnabled
        public String reply { get; set; }
        @AuraEnabled
        public String transcript { get; set; }
        @AuraEnabled
        public String audioBase64 { get; set; }
        /** True once the appointment is booked — the client then forgets the conversation. */
        @AuraEnabled
        public Boolean conversationClosed { get; set; }
        @AuraEnabled
        public Schedule__c created { get; set; }
        @AuraEnabled
        public List<ScheduleSlotFinder.TimeSlot> availableSlots { get; set; }

        public Reply(String reply) {
            this.reply = reply;
            this.conversationClosed = false;
            this.availableSlots = new List<ScheduleSlotFinder.TimeSlot>();
        }
    }

    /**
     * Answers a message in writing. The same path serves a spoken message once
     * it has been turned into words, so a spoken message is treated exactly as
     * the same words typed would be.
     */
    public static Reply respond(String message, List<Turn> history) {
        if (String.isBlank(message)) {
            throw new ServiceException('Message is required');
        }

        String raw = EinsteinModelsGateway.complete(
            buildSystemPrompt(),
            rolesOf(history, message),
            contentsOf(history, message)
        );

        if (String.isBlank(raw)) {
            // The spec reports an empty model answer verbatim.
            return new Reply('No response received. Please try again.');
        }

        Map<String, Object> parsed = parseModelJson(raw);
        if (parsed == null) {
            // The model answered in prose rather than the shape asked for.
            // Prose is still a usable answer to the user, so it is passed through.
            return new Reply(raw.trim());
        }

        String action = stringOf(parsed.get('action'));
        String replyText = stringOf(parsed.get('reply'));

        if (ACTION_CANCEL.equalsIgnoreCase(action)) {
            Reply cancelled = new Reply(
                String.isBlank(replyText) ? 'No problem — I have cleared that. Just say the word when you want to start again.' : replyText
            );
            // A closed conversation is forgotten in full.
            cancelled.conversationClosed = true;
            return cancelled;
        }

        if (!ACTION_BOOK.equalsIgnoreCase(action)) {
            return new Reply(
                String.isBlank(replyText) ? 'Could you tell me a little more?' : replyText
            );
        }

        return book(parsed, replyText);
    }

    /**
     * Books through exactly the same Service the booking form uses, so an
     * appointment created here obeys identical rules and lands in the same list.
     */
    private static Reply book(Map<String, Object> parsed, String replyText) {
        Object fieldsRaw = parsed.get('fields');
        if (!(fieldsRaw instanceof Map<String, Object>)) {
            return new Reply('I still need a few details before I can book that.');
        }
        Map<String, Object> fields = (Map<String, Object>) fieldsRaw;

        ScheduleDto.Input input = new ScheduleDto.Input();
        input.startDateTimeRaw = stringOf(fields.get('startDateTime'));
        input.firstName = stringOf(fields.get('firstName'));
        input.lastName = stringOf(fields.get('lastName'));
        input.phoneNumber = normalisePhone(stringOf(fields.get('phoneNumber')));
        input.phoneNumber2 = normalisePhone(stringOf(fields.get('phoneNumber2')));
        input.appointmentType = stringOf(fields.get('appointmentType'));
        input.durationRaw = stringOf(fields.get('durationMinutes'));
        input.feesRaw = stringOf(fields.get('fees'));
        input.location = stringOf(fields.get('location'));
        input.notes = stringOf(fields.get('notes'));

        ScheduleDto.Result result;
        try {
            result = ScheduleService.createSchedule(input);
        } catch (ServiceException se) {
            // Each answer is judged on its own — the conversation stays open and
            // the assistant simply asks again for what did not pass.
            String detail = se.fieldErrors.isEmpty()
                ? se.getMessage()
                : String.join(se.fieldErrors, '; ');
            return new Reply('I could not book that yet — ' + detail + '. Could you give me that again?');
        }

        if (result.outcome == ScheduleService.OUTCOME_SLOTS) {
            Reply clash = new Reply(
                'Requested time is not available. Here are available slots' +
                formatSlots(result.availableSlots)
            );
            clash.availableSlots = result.availableSlots;
            return clash;
        }
        if (result.outcome == ScheduleService.OUTCOME_NO_SLOTS) {
            return new Reply(
                'No available slots for the requested date. Would another day work?'
            );
        }

        Reply booked = new Reply(
            String.isBlank(replyText) ? confirmationFor(result.created) : replyText
        );
        booked.created = result.created;
        // A conversation ends the moment its appointment is booked.
        booked.conversationClosed = true;
        return booked;
    }

    private static String confirmationFor(Schedule__c record) {
        return 'Booked: ' +
            record.FirstName__c + ' ' + record.LastName__c +
            ' on ' + record.StartDateTime__c.format('dd/MM/yyyy HH:mm') +
            ', ' + record.Type__c +
            ', ' + String.valueOf(record.DurationMinutes__c.intValue()) + ' minutes' +
            ', fees ' + String.valueOf(record.Fees__c) +
            ', phone ' + record.PhoneNumber__c + '.';
    }

    private static String formatSlots(List<ScheduleSlotFinder.TimeSlot> slots) {
        List<String> parts = new List<String>();
        for (ScheduleSlotFinder.TimeSlot slot : slots) {
            parts.add(slot.startLabel + ' - ' + slot.endLabel);
        }
        return parts.isEmpty() ? '' : ': ' + String.join(parts, ', ');
    }

    /** A phone number given without a country code is completed with 961. */
    @TestVisible
    private static String normalisePhone(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String trimmed = raw.trim();
        if (trimmed.startsWith('+961') || trimmed.startsWith('961')) {
            return trimmed;
        }
        return '961' + trimmed;
    }

    // ─── Speech ───────────────────────────────────────────────────────────────

    /**
     * Turns a recording into words. JSON in, JSON out — deliberately not a
     * multipart upload, which is unreliable to build from Apex.
     */
    public static String transcribe(String audioBase64, String mimeType) {
        if (String.isBlank(audioBase64)) {
            throw new ServiceException('No audio was recorded');
        }

        Map<String, Object> config = new Map<String, Object>{
            'encoding' => encodingFor(mimeType),
            'languageCode' => SPEECH_LANGUAGE,
            'enableAutomaticPunctuation' => true
        };
        Map<String, Object> body = new Map<String, Object>{
            'config' => config,
            'audio' => new Map<String, Object>{ 'content' => audioBase64 }
        };

        HttpResponse response = post(STT_CREDENTIAL, STT_PATH, JSON.serialize(body));
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(
            response.getBody()
        );
        Object resultsRaw = parsed.get('results');
        if (!(resultsRaw instanceof List<Object>) || ((List<Object>) resultsRaw).isEmpty()) {
            throw new ServiceException('The recording could not be understood');
        }

        List<String> pieces = new List<String>();
        for (Object resultRaw : (List<Object>) resultsRaw) {
            Map<String, Object> result = (Map<String, Object>) resultRaw;
            Object alternativesRaw = result.get('alternatives');
            if (!(alternativesRaw instanceof List<Object>) || ((List<Object>) alternativesRaw).isEmpty()) {
                continue;
            }
            Map<String, Object> best = (Map<String, Object>) ((List<Object>) alternativesRaw)[0];
            String transcript = stringOf(best.get('transcript'));
            if (String.isNotBlank(transcript)) {
                pieces.add(transcript.trim());
            }
        }
        if (pieces.isEmpty()) {
            throw new ServiceException('The recording could not be understood');
        }
        return String.join(pieces, ' ');
    }

    /** Reads the reply out loud. Returns base64 audio for the player. */
    public static String synthesize(String text) {
        if (String.isBlank(text)) {
            return null;
        }
        Map<String, Object> body = new Map<String, Object>{
            'input' => new Map<String, Object>{ 'text' => text },
            'voice' => new Map<String, Object>{
                'languageCode' => SPEECH_LANGUAGE,
                'name' => TTS_VOICE
            },
            'audioConfig' => new Map<String, Object>{ 'audioEncoding' => 'MP3' }
        };

        HttpResponse response = post(TTS_CREDENTIAL, TTS_PATH, JSON.serialize(body));
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(
            response.getBody()
        );
        return stringOf(parsed.get('audioContent'));
    }

    private static String encodingFor(String mimeType) {
        String lower = String.isBlank(mimeType) ? '' : mimeType.toLowerCase();
        if (lower.contains('ogg')) {
            return 'OGG_OPUS';
        }
        if (lower.contains('wav')) {
            return 'LINEAR16';
        }
        // MediaRecorder's default in Chrome and Edge.
        return 'WEBM_OPUS';
    }

    private static HttpResponse post(String credential, String path, String body) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(credential + path);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setTimeout(CALLOUT_TIMEOUT_MS);
        request.setBody(body);

        HttpResponse response = new Http().send(request);
        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            throw new ServiceException(
                'Speech service returned ' + response.getStatusCode() + ': ' + response.getStatus()
            );
        }
        return response;
    }

    // ─── Prompt and parsing ───────────────────────────────────────────────────

    /**
     * The instruction block. It encodes the spec's conversation rules: ask only
     * for what is missing, never ask for an optional detail, never repeat a
     * detail already given, and never spell out formats or patterns.
     */
    @TestVisible
    private static String buildSystemPrompt() {
        Datetime now = Datetime.now();
        return String.join(
            new List<String>{
                'You are a clinic scheduling assistant. You can ONLY create appointments.',
                'You can neither change nor cancel an appointment that already exists.',
                'The current date and time is ' + now.format('yyyy-MM-dd HH:mm') + ' (' + now.format('EEEE') + ').',
                'Resolve any relative day such as "tomorrow" or "next week" against that moment.',
                '',
                'Required before booking: startDateTime, appointmentType, durationMinutes, fees,',
                'firstName, lastName, location, phoneNumber.',
                'Optional and NEVER to be asked for: notes, phoneNumber2. Keep them if offered.',
                '',
                'Rules for your reply text:',
                '- Ask only for details that are still missing, by name, in one short warm sentence.',
                '- Never spell out formats, patterns, examples or country codes.',
                '- Never list back the details you already have.',
                '- Never ask for the same detail twice once it has been given acceptably.',
                '- Judge each answer on its own; an earlier rejected answer never counts against it.',
                '',
                'Answer with a single JSON object and nothing else:',
                '{"action":"ASK|BOOK|CANCEL","reply":"<what to say>","fields":{',
                '"startDateTime":"yyyy-MM-ddTHH:mm","firstName":"","lastName":"","phoneNumber":"",',
                '"phoneNumber2":"","appointmentType":"","durationMinutes":"","fees":"","location":"","notes":""}}',
                '',
                'Use action BOOK only when every required field is known; carry every field you have',
                'collected across the whole conversation into "fields" each time.',
                'Use action CANCEL when the user says they want to start over or to stop.',
                'Otherwise use action ASK. Omit a field you do not know rather than inventing it.'
            },
            '\n'
        );
    }

    /** Tolerates a model that wraps its JSON in prose or a fenced code block. */
    @TestVisible
    private static Map<String, Object> parseModelJson(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        Integer start = raw.indexOf('{');
        Integer finish = raw.lastIndexOf('}');
        if (start < 0 || finish <= start) {
            return null;
        }
        String candidate = raw.substring(start, finish + 1);
        try {
            Object parsed = JSON.deserializeUntyped(candidate);
            return (parsed instanceof Map<String, Object>) ? (Map<String, Object>) parsed : null;
        } catch (Exception ex) {
            return null;
        }
    }

    private static String stringOf(Object value) {
        if (value == null) {
            return null;
        }
        String text = String.valueOf(value);
        return String.isBlank(text) ? null : text;
    }

    private static List<String> rolesOf(List<Turn> history, String message) {
        List<String> roles = new List<String>();
        if (history != null) {
            for (Turn turn : history) {
                roles.add('assistant'.equalsIgnoreCase(turn.role) ? 'assistant' : 'user');
            }
        }
        roles.add('user');
        return roles;
    }

    private static List<String> contentsOf(List<Turn> history, String message) {
        List<String> contents = new List<String>();
        if (history != null) {
            for (Turn turn : history) {
                contents.add(turn.content == null ? '' : turn.content);
            }
        }
        contents.add(message);
        return contents;
    }
}
