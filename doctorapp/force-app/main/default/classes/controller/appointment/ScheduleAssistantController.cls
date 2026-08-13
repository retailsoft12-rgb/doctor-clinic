/**
 * Thin @AuraEnabled surface for the AI schedule assistant.
 *
 * Speaking the reply is a SEPARATE method on purpose. Booking an appointment
 * performs DML, and Salesforce forbids a callout once a transaction has
 * uncommitted work — so text-to-speech cannot run in the same transaction that
 * may have just inserted a Schedule__c. The LWC calls sendVoiceMessage first,
 * then speakReply, which keeps each callout in a clean transaction.
 */
public with sharing class ScheduleAssistantController {
    /** Answers a typed message in writing only. */
    @AuraEnabled
    public static APIResponse sendMessage(String message, List<ScheduleAssistantService.Turn> history) {
        try {
            if (String.isBlank(message)) {
                return new APIResponse(false, 'message is required');
            }
            return new APIResponse(
                true,
                'Assistant replied successfully',
                ScheduleAssistantService.respond(message, history)
            );
        } catch (Exception ex) {
            return new APIResponse(false, 'Error: ' + ex.getMessage());
        }
    }

    /**
     * Turns a recording into words and answers it through the same conversation
     * a typed message would follow. Returns the transcript alongside the reply
     * so the client can add both to the conversation.
     */
    @AuraEnabled
    public static APIResponse sendVoiceMessage(
        String audioBase64,
        String mimeType,
        List<ScheduleAssistantService.Turn> history
    ) {
        try {
            if (String.isBlank(audioBase64)) {
                return new APIResponse(false, 'No audio was recorded');
            }
            String transcript = ScheduleAssistantService.transcribe(audioBase64, mimeType);
            ScheduleAssistantService.Reply reply = ScheduleAssistantService.respond(transcript, history);
            reply.transcript = transcript;
            return new APIResponse(true, 'Assistant replied successfully', reply);
        } catch (Exception ex) {
            return new APIResponse(false, 'Error: ' + ex.getMessage());
        }
    }

    /** Reads a reply out loud. Only a spoken message earns a spoken reply. */
    @AuraEnabled
    public static APIResponse speakReply(String text) {
        try {
            if (String.isBlank(text)) {
                return new APIResponse(false, 'text is required');
            }
            return new APIResponse(
                true,
                'Reply spoken successfully',
                ScheduleAssistantService.synthesize(text)
            );
        } catch (Exception ex) {
            return new APIResponse(false, 'Error: ' + ex.getMessage());
        }
    }
}
