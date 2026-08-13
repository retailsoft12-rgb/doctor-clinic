/**
 * The ONLY class in this codebase that touches the `aiplatform` namespace.
 *
 * Why the isolation: the `aiplatform` namespace exists only in an org with
 * Einstein Generative AI provisioned. If it is absent, this file fails to
 * compile — and because it is the single point of contact, it is the only file
 * that has to be swapped to move the assistant onto a different provider.
 * ScheduleAssistantService talks to it through a plain String-in/String-out
 * signature and knows nothing about Einstein.
 *
 * VERIFY BEFORE DEPLOY: the exact member names of the Models API for Apex
 * (`createChatGenerations_Request`, `ModelsAPI_ChatMessageRequest`, the
 * `Code200` response wrapper) track the org's Models API version. They are
 * written here to the documented shape but have not been compiled against the
 * target org.
 */
public with sharing class EinsteinModelsGateway {
    /**
     * The Einstein-provided model alias. Changing model is a one-line change.
     */
    public static final String MODEL_NAME = 'sfdc_ai__DefaultGPT4Omni';

    /** Set by tests so the assistant can be exercised without a live model. */
    @TestVisible
    private static String mockReply;

    public class GatewayException extends Exception {
    }

    /**
     * Sends a system prompt plus an alternating conversation and returns the
     * model's reply text.
     *
     * @param systemPrompt the instruction block (never shown to the user)
     * @param roles        'user' or 'assistant', parallel to `contents`
     * @param contents     message text, parallel to `roles`
     */
    public static String complete(String systemPrompt, List<String> roles, List<String> contents) {
        if (mockReply != null) {
            return mockReply;
        }
        if (roles == null || contents == null || roles.size() != contents.size()) {
            throw new GatewayException('Conversation roles and contents must be parallel lists');
        }

        try {
            aiplatform.ModelsAPI.createChatGenerations_Request request = new aiplatform.ModelsAPI.createChatGenerations_Request();
            request.modelName = MODEL_NAME;

            aiplatform.ModelsAPI_ChatGenerationsRequest body = new aiplatform.ModelsAPI_ChatGenerationsRequest();
            body.messages = new List<aiplatform.ModelsAPI_ChatMessageRequest>();

            if (String.isNotBlank(systemPrompt)) {
                body.messages.add(buildMessage('system', systemPrompt));
            }
            for (Integer i = 0; i < roles.size(); i++) {
                body.messages.add(buildMessage(roles[i], contents[i]));
            }
            request.body = body;

            aiplatform.ModelsAPI modelsApi = new aiplatform.ModelsAPI();
            aiplatform.ModelsAPI.createChatGenerations_Response response = modelsApi.createChatGenerations(
                request
            );

            if (
                response == null ||
                response.Code200 == null ||
                response.Code200.generationDetails == null ||
                response.Code200.generationDetails.generations == null ||
                response.Code200.generationDetails.generations.isEmpty()
            ) {
                return null;
            }
            return response.Code200.generationDetails.generations[0].content;
        } catch (Exception ex) {
            throw new GatewayException('Einstein model call failed: ' + ex.getMessage());
        }
    }

    private static aiplatform.ModelsAPI_ChatMessageRequest buildMessage(String role, String content) {
        aiplatform.ModelsAPI_ChatMessageRequest message = new aiplatform.ModelsAPI_ChatMessageRequest();
        message.role = role;
        message.content = content;
        return message;
    }
}
