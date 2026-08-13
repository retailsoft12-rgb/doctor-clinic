/**
 * DomainCorrectness — input guards for the values that arrived in this request's
 * parameter list. No SOQL of its own: it resolves ids through the Dao of the
 * object it guards, and decides only what an empty result MEANS.
 *
 * Business rules do not live here — overlap, effective duration and slot
 * generation belong to DomainCompleteValidator / ScheduleService, one phase later.
 */
public class DomainCorrectness {

    // ── Regex constants ──────────────────────────────────────────────────────

    /** ISO calendar date as an <input type="date"> produces it. */
    private static final String DATE_PATTERN = '^\\d{4}-\\d{2}-\\d{2}$';

    /** 24-hour clock as an <input type="time"> produces it — seconds optional. */
    private static final String TIME_PATTERN = '^\\d{2}:\\d{2}(:\\d{2})?$';

    /**
     * 6–15 digits, optionally preceded by +961 or 961 (Lebanese country code)
     * with an optional single space after it (flow 5).
     */
    private static final String PHONE_PATTERN = '^(\\+961|961)?[ ]?[0-9]{6,15}$';

    /** Whole minutes only — no decimal point, no sign. */
    private static final String WHOLE_NUMBER_PATTERN = '^[0-9]+$';

    /** An amount with at most two decimals. */
    private static final String MONEY_PATTERN = '^[0-9]+(\\.[0-9]{1,2})?$';

    // ── Field labels — these are what the Server Error panel lists ───────────

    private static final String F_DATETIME = 'Date & Time';
    private static final String F_FIRST_NAME = 'First Name';
    private static final String F_LAST_NAME = 'Last Name';
    private static final String F_PHONE = 'Phone Number';
    private static final String F_PHONE_2 = 'Phone Number 2';
    private static final String F_TYPE = 'Type';
    private static final String F_DURATION = 'Duration (min)';
    private static final String F_FEES = 'Fees';
    private static final String F_LOCATION = 'Location';
    private static final String F_NOTES = 'Notes';

    /**
     * The outcome of parsing and checking one booking request.
     *
     * `candidate` is populated only when `errors` is empty — a request that failed
     * validation never produces a record, not even an unsaved one.
     */
    public class ScheduleInputResult {
        public List<ScheduleDto.FieldError> errors = new List<ScheduleDto.FieldError>();
        public Schedule__c candidate;

        public Boolean isValid() {
            return this.errors.isEmpty();
        }
    }

    /**
     * Existence guard. Throws when the row is gone.
     *
     * NOTE: the delete path deliberately does not use this. Flow 12 states that an
     * appointment which "no longer exists at confirmation" is a non-error — the list
     * simply reloads unchanged — so the controller resolves that row through the Dao
     * and returns a successful envelope instead of raising here.
     */
    public static Schedule__c requireScheduleExists(Id scheduleId) {
        Schedule__c record = ScheduleDao.findScheduleById(scheduleId);
        if (record == null) {
            throw new ServiceException('Schedule not found: ' + scheduleId);
        }
        return record;
    }

    /**
     * Every input rule from the spec, checked in one pass so the Server Error panel
     * can list ALL invalid fields at once rather than the first failure.
     *
     * Values arrive as strings because that is what the form holds: parsing IS part
     * of the validation (a duration of "1.5" is a failed rule, not a cast error).
     */
    public static ScheduleInputResult validateScheduleInput(
        String startDate,
        String startTime,
        String firstName,
        String lastName,
        String phoneNumber,
        String phoneNumber2,
        String appointmentType,
        String durationMinutes,
        String fees,
        String location,
        String notes
    ) {
        ScheduleInputResult result = new ScheduleInputResult();

        Datetime startDateTime = parseStartDateTime(startDate, startTime, result.errors);
        String cleanFirstName = requireText(firstName, F_FIRST_NAME, 50, result.errors);
        String cleanLastName = requireText(lastName, F_LAST_NAME, 50, result.errors);
        String cleanPhone = requirePhone(phoneNumber, F_PHONE, result.errors);
        String cleanPhone2 = optionalPhone(phoneNumber2, F_PHONE_2, result.errors);
        String cleanType = requireText(appointmentType, F_TYPE, 255, result.errors);
        Integer cleanDuration = requireDuration(durationMinutes, result.errors);
        Decimal cleanFees = requireFees(fees, result.errors);
        String cleanLocation = requireText(location, F_LOCATION, 500, result.errors);
        String cleanNotes = optionalText(notes, F_NOTES, 500, result.errors);

        if (!result.isValid()) {
            return result;
        }

        result.candidate = new Schedule__c(
            StartDateTime__c = startDateTime,
            FirstName__c = cleanFirstName,
            LastName__c = cleanLastName,
            PhoneNumber__c = cleanPhone,
            PhoneNumber2__c = cleanPhone2,
            Type__c = cleanType,
            DurationMinutes__c = cleanDuration,
            Fees__c = cleanFees,
            Location__c = cleanLocation,
            Notes__c = cleanNotes
        );
        return result;
    }

    // ── Per-field rules ──────────────────────────────────────────────────────

    /**
     * V1 + V2 — Date & Time is required and must be in the future.
     *
     * The two form controls (calendar picker + time picker) are one logical field,
     * so every failure below is reported under the single label "Date & Time".
     * Datetime.newInstance(Date, Time) resolves in the running user's time zone,
     * which is the clinic's local zone.
     */
    private static Datetime parseStartDateTime(
        String startDate,
        String startTime,
        List<ScheduleDto.FieldError> errors
    ) {
        if (String.isBlank(startDate) || String.isBlank(startTime)) {
            errors.add(new ScheduleDto.FieldError(F_DATETIME, 'Date & Time is required'));
            return null;
        }
        if (!Pattern.matches(DATE_PATTERN, startDate.trim())
            || !Pattern.matches(TIME_PATTERN, startTime.trim())) {
            errors.add(new ScheduleDto.FieldError(F_DATETIME, 'Date & Time is not a valid date and time'));
            return null;
        }

        Datetime parsed;
        try {
            Date day = Date.valueOf(startDate.trim());
            List<String> parts = startTime.trim().split(':');
            Integer hours = Integer.valueOf(parts[0]);
            Integer minutes = Integer.valueOf(parts[1]);
            if (hours > 23 || minutes > 59) {
                errors.add(new ScheduleDto.FieldError(F_DATETIME, 'Date & Time is not a valid date and time'));
                return null;
            }
            parsed = Datetime.newInstance(day, Time.newInstance(hours, minutes, 0, 0));
        } catch (Exception ex) {
            errors.add(new ScheduleDto.FieldError(F_DATETIME, 'Date & Time is not a valid date and time'));
            return null;
        }

        if (parsed <= Datetime.now()) {
            errors.add(new ScheduleDto.FieldError(F_DATETIME, 'Date & Time must be in the future'));
            return null;
        }
        return parsed;
    }

    /** V3 / V4 / V7 / V10 — required text with a maximum length. */
    private static String requireText(
        String value,
        String label,
        Integer maxLength,
        List<ScheduleDto.FieldError> errors
    ) {
        if (String.isBlank(value)) {
            errors.add(new ScheduleDto.FieldError(label, label + ' is required'));
            return null;
        }
        String trimmed = value.trim();
        if (trimmed.length() > maxLength) {
            errors.add(new ScheduleDto.FieldError(
                label, label + ' must be ' + maxLength + ' characters or fewer'));
            return null;
        }
        return trimmed;
    }

    /** V11 — optional text with a maximum length; blank is valid and stores null. */
    private static String optionalText(
        String value,
        String label,
        Integer maxLength,
        List<ScheduleDto.FieldError> errors
    ) {
        if (String.isBlank(value)) {
            return null;
        }
        String trimmed = value.trim();
        if (trimmed.length() > maxLength) {
            errors.add(new ScheduleDto.FieldError(
                label, label + ' must be ' + maxLength + ' characters or fewer'));
            return null;
        }
        return trimmed;
    }

    /** V5 — Phone Number is required and must match the Lebanese format. */
    private static String requirePhone(
        String value,
        String label,
        List<ScheduleDto.FieldError> errors
    ) {
        if (String.isBlank(value)) {
            errors.add(new ScheduleDto.FieldError(label, label + ' is required'));
            return null;
        }
        return checkPhoneFormat(value.trim(), label, errors);
    }

    /** V6 — Phone Number 2 is optional, but must match the same format when given. */
    private static String optionalPhone(
        String value,
        String label,
        List<ScheduleDto.FieldError> errors
    ) {
        if (String.isBlank(value)) {
            return null;
        }
        return checkPhoneFormat(value.trim(), label, errors);
    }

    private static String checkPhoneFormat(
        String trimmed,
        String label,
        List<ScheduleDto.FieldError> errors
    ) {
        if (!Pattern.matches(PHONE_PATTERN, trimmed)) {
            errors.add(new ScheduleDto.FieldError(
                label, label + ' must be 6-15 digits, optionally prefixed with +961'));
            return null;
        }
        return trimmed;
    }

    /** V8 — Duration is required, a whole number of minutes, at least 1. */
    private static Integer requireDuration(
        String value,
        List<ScheduleDto.FieldError> errors
    ) {
        if (String.isBlank(value)) {
            errors.add(new ScheduleDto.FieldError(F_DURATION, F_DURATION + ' is required'));
            return null;
        }
        String trimmed = value.trim();
        if (!Pattern.matches(WHOLE_NUMBER_PATTERN, trimmed) || trimmed.length() > 5) {
            errors.add(new ScheduleDto.FieldError(
                F_DURATION, F_DURATION + ' must be a whole number of at least 1'));
            return null;
        }
        Integer parsed = Integer.valueOf(trimmed);
        if (parsed < 1) {
            errors.add(new ScheduleDto.FieldError(
                F_DURATION, F_DURATION + ' must be a whole number of at least 1'));
            return null;
        }
        return parsed;
    }

    /** V9 — Fees is required, 0 or greater, with at most 2 decimals (0 is allowed). */
    private static Decimal requireFees(
        String value,
        List<ScheduleDto.FieldError> errors
    ) {
        if (String.isBlank(value)) {
            errors.add(new ScheduleDto.FieldError(F_FEES, F_FEES + ' is required'));
            return null;
        }
        String trimmed = value.trim();
        if (!Pattern.matches(MONEY_PATTERN, trimmed)) {
            errors.add(new ScheduleDto.FieldError(
                F_FEES, F_FEES + ' must be 0 or greater, with at most 2 decimals'));
            return null;
        }
        return Decimal.valueOf(trimmed);
    }
}
