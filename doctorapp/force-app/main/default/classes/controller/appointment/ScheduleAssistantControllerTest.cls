@isTest
private class ScheduleAssistantControllerTest {
    /** Answers both speech hosts with the JSON shape the service reads. */
    private class SpeechMock implements HttpCalloutMock {
        private Integer statusCode;

        private SpeechMock(Integer statusCode) {
            this.statusCode = statusCode;
        }

        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setStatus(statusCode == 200 ? 'OK' : 'Service Unavailable');
            if (request.getEndpoint().contains('speech:recognize')) {
                response.setBody(
                    '{"results":[{"alternatives":[{"transcript":"book a check-up tomorrow"}]}]}'
                );
            } else {
                response.setBody('{"audioContent":"QUJD"}');
            }
            return response;
        }
    }

    private static String futureAt(Integer hour) {
        Datetime moment = Datetime.newInstance(
            Date.today().addDays(1),
            Time.newInstance(hour, 0, 0, 0)
        );
        return moment.format('yyyy-MM-dd') + 'T' + moment.format('HH:mm');
    }

    private static List<ScheduleAssistantService.Turn> noHistory() {
        return new List<ScheduleAssistantService.Turn>();
    }

    @isTest
    static void anEmptyMessageIsRefused() {
        APIResponse refused = ScheduleAssistantController.sendMessage('', noHistory());

        System.assertEquals(false, refused.success, 'A message cannot be sent empty');
        System.assertEquals('message is required', refused.message, 'The message format is fixed');
    }

    @isTest
    static void theAssistantAsksOnlyForWhatIsMissing() {
        EinsteinModelsGateway.mockReply =
            '{"action":"ASK","reply":"Happy to help — what time works, and how long should it be?"}';

        Test.startTest();
        APIResponse asked = ScheduleAssistantController.sendMessage('Book Rana in', noHistory());
        Test.stopTest();

        System.assertEquals(true, asked.success, 'The assistant should answer');
        ScheduleAssistantService.Reply reply = (ScheduleAssistantService.Reply) asked.data;
        System.assert(reply.reply.contains('what time works'), 'The model reply should come through');
        System.assertEquals(
            false,
            reply.conversationClosed,
            'The conversation stays open until the appointment is booked or the user ends it'
        );
        System.assertEquals(0, [SELECT COUNT() FROM Schedule__c], 'Asking books nothing');
    }

    @isTest
    static void aWholeBookingIsTakenFromOneMessageAndClosesTheConversation() {
        EinsteinModelsGateway.mockReply =
            '{"action":"BOOK","reply":"","fields":{' +
            '"startDateTime":"' + futureAt(10) + '",' +
            '"firstName":"Rana","lastName":"Haddad","phoneNumber":"70123456",' +
            '"appointmentType":"Consultation","durationMinutes":"30","fees":"50",' +
            '"location":"Beirut Clinic"}}';

        Test.startTest();
        APIResponse booked = ScheduleAssistantController.sendMessage(
            'Book Rana Haddad tomorrow at 10 for a 30 minute consultation in Beirut, 50 dollars, 70123456',
            noHistory()
        );
        Test.stopTest();

        System.assertEquals(true, booked.success, 'The booking should be taken');
        ScheduleAssistantService.Reply reply = (ScheduleAssistantService.Reply) booked.data;
        System.assertEquals(
            true,
            reply.conversationClosed,
            'A conversation ends the moment its appointment is booked'
        );
        System.assertNotEquals(null, reply.created, 'The created appointment comes back');

        Schedule__c stored = [SELECT PhoneNumber__c, FirstName__c FROM Schedule__c LIMIT 1];
        System.assertEquals(
            '96170123456',
            stored.PhoneNumber__c,
            'A number given without a country code is completed with the Lebanese one'
        );
    }

    @isTest
    static void theAssistantOffersOtherTimesWhenTheRequestedOneIsTaken() {
        // An appointment already on the day the assistant will ask for.
        insert new Schedule__c(
            StartDateTime__c = Datetime.newInstance(
                Date.today().addDays(1),
                Time.newInstance(10, 0, 0, 0)
            ),
            EndDateTime__c = Datetime.newInstance(
                Date.today().addDays(1),
                Time.newInstance(10, 30, 0, 0)
            ),
            FirstName__c = 'Existing',
            LastName__c = 'Patient',
            PhoneNumber__c = '96170000000',
            Type__c = 'Check-up',
            DurationMinutes__c = 30,
            Fees__c = 40,
            Location__c = 'Beirut Clinic'
        );

        EinsteinModelsGateway.mockReply =
            '{"action":"BOOK","reply":"","fields":{' +
            '"startDateTime":"' + futureAt(10) + '",' +
            '"firstName":"Rana","lastName":"Haddad","phoneNumber":"70123456",' +
            '"appointmentType":"Consultation","durationMinutes":"30","fees":"50",' +
            '"location":"Beirut Clinic"}}';

        Test.startTest();
        APIResponse clashed = ScheduleAssistantController.sendMessage('Book it', noHistory());
        Test.stopTest();

        ScheduleAssistantService.Reply reply = (ScheduleAssistantService.Reply) clashed.data;
        System.assert(
            reply.reply.startsWith('Requested time is not available. Here are available slots'),
            'The spec fixes this wording: ' + reply.reply
        );
        System.assert(!reply.availableSlots.isEmpty(), 'Other times that day should be offered');
        System.assertEquals(
            false,
            reply.conversationClosed,
            'The conversation stays open so a new time can be given'
        );
        System.assertEquals(1, [SELECT COUNT() FROM Schedule__c], 'Nothing extra is booked');
    }

    @isTest
    static void askingToStopClosesAndForgetsTheConversation() {
        EinsteinModelsGateway.mockReply =
            '{"action":"CANCEL","reply":"No problem, I have cleared that."}';

        Test.startTest();
        APIResponse stopped = ScheduleAssistantController.sendMessage('Actually, stop', noHistory());
        Test.stopTest();

        ScheduleAssistantService.Reply reply = (ScheduleAssistantService.Reply) stopped.data;
        System.assertEquals(true, reply.conversationClosed, 'An abandoned conversation is closed');
        System.assertEquals(0, [SELECT COUNT() FROM Schedule__c], 'It holds no time and creates nothing');
    }

    @isTest
    static void anEmptyModelAnswerIsReportedVerbatim() {
        EinsteinModelsGateway.mockReply = '';

        Test.startTest();
        APIResponse answered = ScheduleAssistantController.sendMessage('Hello', noHistory());
        Test.stopTest();

        ScheduleAssistantService.Reply reply = (ScheduleAssistantService.Reply) answered.data;
        System.assertEquals(
            'No response received. Please try again.',
            reply.reply,
            'The spec fixes this message'
        );
    }

    @isTest
    static void aSpokenMessageIsTurnedIntoWordsAndFollowsTheSameConversation() {
        Test.setMock(HttpCalloutMock.class, new SpeechMock(200));
        EinsteinModelsGateway.mockReply = '{"action":"ASK","reply":"What time suits you?"}';

        Test.startTest();
        APIResponse spoken = ScheduleAssistantController.sendVoiceMessage(
            EncodingUtil.base64Encode(Blob.valueOf('fake-audio')),
            'audio/webm',
            noHistory()
        );
        Test.stopTest();

        System.assertEquals(true, spoken.success, 'The spoken message should be answered');
        ScheduleAssistantService.Reply reply = (ScheduleAssistantService.Reply) spoken.data;
        System.assertEquals(
            'book a check-up tomorrow',
            reply.transcript,
            'The transcript comes back so the conversation can show it'
        );
        System.assertEquals('What time suits you?', reply.reply, 'The reply follows the same path');
    }

    @isTest
    static void sendingWithNoRecordingIsRefused() {
        APIResponse refused = ScheduleAssistantController.sendVoiceMessage('', 'audio/webm', noHistory());

        System.assertEquals(false, refused.success, 'A recording must exist before it can be sent');
        System.assertEquals('No audio was recorded', refused.message, 'The user is told exactly that');
    }

    @isTest
    static void aReplyIsReadOutLoudAsBase64Audio() {
        Test.setMock(HttpCalloutMock.class, new SpeechMock(200));

        Test.startTest();
        APIResponse spoken = ScheduleAssistantController.speakReply('Your appointment is booked.');
        Test.stopTest();

        System.assertEquals(true, spoken.success, 'The reply should be spoken');
        System.assertEquals('QUJD', (String) spoken.data, 'The player is fed base64 audio');
    }

    @isTest
    static void anUnreachableSpeechServiceIsReportedAsTheReason() {
        Test.setMock(HttpCalloutMock.class, new SpeechMock(503));

        Test.startTest();
        APIResponse failed = ScheduleAssistantController.speakReply('Anything');
        Test.stopTest();

        System.assertEquals(false, failed.success, 'A failing speech service is a failure');
        System.assert(
            failed.message.startsWith('Error'),
            'The spec begins the report with "Error": ' + failed.message
        );
    }
}
