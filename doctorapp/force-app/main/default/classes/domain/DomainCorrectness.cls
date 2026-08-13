/**
 * DomainCorrectness — input guards.
 *
 * sequence-be phase 1: this class validates THE CONTROLLER'S INPUT ONLY — the
 * values that arrived in this request's parameter list. It decides MEANING
 * (missing / malformed -> ServiceException); it holds no SOQL of its own and
 * resolves ids through the Dao of the object it guards.
 *
 * Business rules do not live here — they are DomainCompleteValidator's, one
 * phase later. "The appointment must exist" is an input guard; "two appointments
 * must never overlap" is a business rule.
 */
public with sharing class DomainCorrectness {

    // ── Existence guards ──────────────────────────────────────────────────────

    /**
     * Resolves the appointment the request names, so the Service receives the
     * record rather than the id (phase 2 hop 2.1 — the guard already paid for
     * the query).
     */
    public static Schedule__c requireScheduleExists(String scheduleId) {
        Schedule__c record = ScheduleDao.findScheduleById(scheduleId);
        if (record == null) {
            throw new ServiceException('Schedule not found: ' + scheduleId);
        }
        return record;
    }

    // ── Input-format guards ───────────────────────────────────────────────────
    // The Tab 5a input rules recorded in scratchpad-memory.md section 8a. They
    // are re-checked here because the LWC's client-side validator can be
    // bypassed; the two sets are deliberately identical in meaning.

    /** Required free text with a maximum length (first name, last name, type, location). */
    public static void requireText(String value, String label, Integer maxLength) {
        if (String.isBlank(value)) {
            throw new ServiceException(label + ' is required');
        }
        if (value.length() > maxLength) {
            throw new ServiceException(label + ' must be at most ' + maxLength + ' characters');
        }
    }

    /**
     * 6-15 digits, optionally preceded by the Lebanese country code (+961 or
     * 961) with an optional single space after it.
     */
    public static void requirePhone(String value, String label) {
        if (String.isBlank(value)) {
            throw new ServiceException(label + ' is required');
        }
        if (!isPhoneShaped(value)) {
            throw new ServiceException(
                label + ' must be 6-15 digits, optionally preceded by +961 or 961');
        }
    }

    /** The alternative contact: absent is fine, present must match the same shape. */
    public static void requireOptionalPhone(String value, String label) {
        if (String.isBlank(value)) {
            return;
        }
        if (!isPhoneShaped(value)) {
            throw new ServiceException(
                label + ' must be 6-15 digits, optionally preceded by +961 or 961');
        }
    }

    /** The requested moment must exist and must not be in the past. */
    public static void requireFutureDateTime(Datetime value, String label) {
        if (value == null) {
            throw new ServiceException(label + ' is required');
        }
        if (value <= Datetime.now()) {
            throw new ServiceException(label + ' must be in the future');
        }
    }

    /** Whole minutes of 1 or more. */
    public static void requirePositiveDuration(Integer value, String label) {
        if (value == null) {
            throw new ServiceException(label + ' is required');
        }
        if (value <= 0) {
            throw new ServiceException(label + ' must be greater than 0 minutes');
        }
    }

    /** 0 or more — a free-of-charge appointment is allowed. */
    public static void requireNonNegativeFees(Decimal value, String label) {
        if (value == null) {
            throw new ServiceException(label + ' is required');
        }
        if (value < 0) {
            throw new ServiceException(label + ' must be 0 or more');
        }
    }

    // ── Internals ─────────────────────────────────────────────────────────────

    private static Boolean isPhoneShaped(String value) {
        return Pattern.matches('^(?:\\+?961[ ]?)?[0-9]{6,15}$', value.trim());
    }
}
