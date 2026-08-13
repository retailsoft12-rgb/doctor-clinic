/**
 * The only exception type a Service, a guard or a validator throws.
 *
 * It is never caught to be converted mid-stack — it propagates to the
 * controller's catch, which turns it into APIResponse(false, message).
 */
public class ServiceException extends Exception {
    /**
     * Field-level failures carried alongside the message, so the controller can
     * hand the LWC the per-field "Validation errors" list the spec requires
     * without parsing the message string.
     */
    public List<String> fieldErrors = new List<String>();

    public ServiceException withFieldErrors(List<String> errors) {
        this.fieldErrors = errors == null ? new List<String>() : errors;
        return this;
    }
}
