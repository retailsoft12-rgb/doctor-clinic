/**
 * ServiceException — the only exception type the domain layer throws.
 *
 * sequence-be: DomainCorrectness throws it when an input is missing or malformed,
 * DomainCompleteValidator throws it when a business rule is violated, and the
 * Service throws it when a DML fails. It is never caught inside the domain — it
 * propagates to the controller's catch, which turns it into
 * APIResponse(false, message).
 */
public class ServiceException extends Exception {}
