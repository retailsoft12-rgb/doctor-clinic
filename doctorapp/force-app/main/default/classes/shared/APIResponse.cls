/**
 * The single response envelope every @AuraEnabled method returns.
 *
 * Kept free of any domain type so it stays shared across features: the
 * available-slot list travels in `data` rather than in a typed field, and the
 * LWC branches on `code` rather than on the text of `message`.
 */
public with sharing class APIResponse {
    /** Machine-readable outcome. The LWC branches on this, never on message text. */
    public static final String CODE_OK = 'OK';
    public static final String CODE_VALIDATION = 'VALIDATION';
    public static final String CODE_SLOTS = 'SLOTS';
    public static final String CODE_NO_SLOTS = 'NO_SLOTS';
    public static final String CODE_ERROR = 'ERROR';

    @AuraEnabled
    public Boolean success { get; set; }

    @AuraEnabled
    public String message { get; set; }

    @AuraEnabled
    public String code { get; set; }

    @AuraEnabled
    public Object data { get; set; }

    /** One entry per field at fault. Populated only when code = VALIDATION. */
    @AuraEnabled
    public List<String> errors { get; set; }

    public APIResponse(Boolean success, String message) {
        this(success, message, null);
    }

    public APIResponse(Boolean success, String message, Object data) {
        this.success = success;
        this.message = message;
        this.data = data;
        this.code = success ? CODE_OK : CODE_ERROR;
        this.errors = new List<String>();
    }

    public APIResponse withCode(String code) {
        this.code = code;
        return this;
    }

    public APIResponse withErrors(List<String> errors) {
        this.errors = errors == null ? new List<String>() : errors;
        return this;
    }
}
