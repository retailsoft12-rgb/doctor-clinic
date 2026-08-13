/**
 * ServiceException — the only exception type the domain layer throws.
 *
 * Guards, validators and services raise this; the controller's catch turns it
 * into `new APIResponse(false, ...)`. No layer below the controller builds an
 * envelope of its own.
 */
public class ServiceException extends Exception {}
