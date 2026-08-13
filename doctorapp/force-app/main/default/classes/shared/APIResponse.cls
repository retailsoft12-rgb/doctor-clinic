/**
 * APIResponse — the single envelope every @AuraEnabled method returns.
 *
 * The controller never returns an SObject and never returns void: success,
 * failure and caught exceptions all leave through this shape, so the LWC has
 * exactly one response contract to branch on.
 */
public class APIResponse {

    /** True when the operation completed; false for input failures and caught exceptions. */
    @AuraEnabled
    public Boolean success { get; set; }

    /** Human-readable outcome. On failure this is what the LWC surfaces. */
    @AuraEnabled
    public String message { get; set; }

    /** The payload: one record, one list, or a Map<String, Object> of named pieces. */
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
