/**
 * APIResponse — the single envelope every @AuraEnabled method returns.
 *
 * sequence-be phase 3, hop 3.7: an @AuraEnabled method never returns an SObject,
 * never returns void, and never lets an exception escape. Every exit path of
 * every controller method is one of these three shapes:
 *
 *   new APIResponse(true,  'Appointment created successfully', data)
 *   new APIResponse(false, 'scheduleId is required')
 *   new APIResponse(false, 'Failed to create schedule: ' + ex.getMessage())
 */
public with sharing class APIResponse {

    @AuraEnabled
    public Boolean success { get; set; }

    @AuraEnabled
    public String message { get; set; }

    @AuraEnabled
    public Object data { get; set; }

    public APIResponse(Boolean success, String message) {
        this(success, message, null);
    }

    public APIResponse(Boolean success, String message, Object data) {
        this.success = success;
        this.message = message;
        this.data = data;
    }
}
