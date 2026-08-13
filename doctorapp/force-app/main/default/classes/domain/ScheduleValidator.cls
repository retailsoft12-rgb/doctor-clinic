/**
 * Business-rule and field-rule validation for the Schedule domain — the
 * DomainCompleteValidator role of the back-end sequence, carrying the name the
 * deployed permission set already grants (`ScheduleValidator`).
 *
 * Pure in-memory: no SOQL, no DML. It receives data the Service already loaded.
 *
 * Every rule failure is collected rather than thrown on first sight, because the
 * spec requires the panel to name EVERY field at fault in one go:
 * "shows a panel titled 'Server Error' holding a message that begins
 * 'Validation errors' and then names each field that is wrong and what is wrong
 * with it".
 */
public with sharing class ScheduleValidator {
    private static final Integer NAME_MAX = 50;
    private static final Integer LOCATION_MAX = 500;
    private static final Integer NOTES_MAX = 500;

    /**
     * 6 to 15 digits, optionally preceded by the Lebanese country code 961 with
     * or without a leading plus sign and with or without one space after it.
     */
    private static final Pattern PHONE_PATTERN = Pattern.compile('^(\\+?961 ?)?[0-9]{6,15}$');

    public static final String PHONE_ERROR = 'Invalid phone number format';

    /**
     * Validates every field rule, parses the values that pass, and throws a
     * single ServiceException carrying the whole field-error list.
     *
     * Mutates `input` in place with the parsed startDateTime, durationMinutes
     * and fees so the Service never re-parses.
     */
    public static void requireValidInput(ScheduleDto.Input input) {
        List<String> errors = new List<String>();

        validateStartDateTime(input, errors);
        validateNames(input, errors);
        validatePhones(input, errors);
        validateType(input, errors);
        validateDuration(input, errors);
        validateFees(input, errors);
        validateLocationAndNotes(input, errors);

        if (!errors.isEmpty()) {
            throw new ServiceException('Validation errors').withFieldErrors(errors);
        }
    }

    private static void validateStartDateTime(ScheduleDto.Input input, List<String> errors) {
        if (String.isBlank(input.startDateTimeRaw)) {
            errors.add('Date & Time is required');
            return;
        }
        Datetime parsed = parseDateTime(input.startDateTimeRaw);
        if (parsed == null) {
            errors.add('Date & Time is not a valid date and time');
            return;
        }
        if (parsed <= Datetime.now()) {
            errors.add('Date & Time must be in the future');
            return;
        }
        input.startDateTime = parsed;
    }

    private static void validateNames(ScheduleDto.Input input, List<String> errors) {
        if (String.isBlank(input.firstName)) {
            errors.add('First Name is required');
        } else if (input.firstName.trim().length() > NAME_MAX) {
            errors.add('First Name must be between 1 and 50 characters');
        }

        if (String.isBlank(input.lastName)) {
            errors.add('Last Name is required');
        } else if (input.lastName.trim().length() > NAME_MAX) {
            errors.add('Last Name must be between 1 and 50 characters');
        }
    }

    private static void validatePhones(ScheduleDto.Input input, List<String> errors) {
        if (String.isBlank(input.phoneNumber)) {
            errors.add('Phone Number is required');
        } else if (!isValidPhone(input.phoneNumber)) {
            errors.add(PHONE_ERROR + ': Phone Number');
        }

        // Blank means "no second number at all", not an empty one — not an error.
        if (String.isNotBlank(input.phoneNumber2) && !isValidPhone(input.phoneNumber2)) {
            errors.add(PHONE_ERROR + ': Phone Number 2');
        }
    }

    public static Boolean isValidPhone(String raw) {
        if (String.isBlank(raw)) {
            return false;
        }
        return PHONE_PATTERN.matcher(raw.trim()).matches();
    }

    private static void validateType(ScheduleDto.Input input, List<String> errors) {
        // Free text — the clinic decides its own wording, so only blankness fails.
        if (String.isBlank(input.appointmentType)) {
            errors.add('Type is required');
        }
    }

    private static void validateDuration(ScheduleDto.Input input, List<String> errors) {
        if (String.isBlank(input.durationRaw)) {
            errors.add('Duration is required');
            return;
        }
        Decimal parsed;
        try {
            parsed = Decimal.valueOf(input.durationRaw.trim());
        } catch (Exception ex) {
            errors.add('Duration must be a whole number of minutes');
            return;
        }
        // intValue() truncates, so a fractional input never equals itself back.
        if (parsed != Decimal.valueOf(parsed.intValue())) {
            errors.add('Duration must be a whole number of minutes');
            return;
        }
        if (parsed < 1) {
            errors.add('Duration must be greater than zero');
            return;
        }
        input.durationMinutes = parsed.intValue();
    }

    private static void validateFees(ScheduleDto.Input input, List<String> errors) {
        if (String.isBlank(input.feesRaw)) {
            errors.add('Fees are required');
            return;
        }
        Decimal parsed;
        try {
            parsed = Decimal.valueOf(input.feesRaw.trim());
        } catch (Exception ex) {
            errors.add('Fees must be an amount of zero or more');
            return;
        }
        if (parsed < 0) {
            errors.add('Fees must be zero or more');
            return;
        }
        if (parsed.scale() > 2) {
            errors.add('Fees must have at most two decimals');
            return;
        }
        input.fees = parsed;
    }

    private static void validateLocationAndNotes(ScheduleDto.Input input, List<String> errors) {
        if (String.isBlank(input.location)) {
            errors.add('Location is required');
        } else if (input.location.length() > LOCATION_MAX) {
            errors.add('Location must be at most 500 characters');
        }

        if (String.isNotBlank(input.notes) && input.notes.length() > NOTES_MAX) {
            errors.add('Notes must be at most 500 characters');
        }
    }

    /**
     * A duration given as a whole number of hours is recorded one minute
     * shorter, so consecutive appointments never touch.
     */
    public static Integer applyWholeHourShortening(Integer durationMinutes) {
        if (durationMinutes != null && durationMinutes >= 60 && Math.mod(durationMinutes, 60) == 0) {
            return durationMinutes - 1;
        }
        return durationMinutes;
    }

    /**
     * Accepts 'yyyy-MM-ddTHH:mm' and 'yyyy-MM-ddTHH:mm:ss' (what an
     * <input type="datetime-local"> produces), plus the space-separated form.
     * Returns null when the value cannot be read as a moment.
     */
    public static Datetime parseDateTime(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String normalised = raw.trim().replace('T', ' ');
        // Trim any timezone suffix or fractional seconds the browser may append.
        if (normalised.contains('.')) {
            normalised = normalised.substring(0, normalised.indexOf('.'));
        }
        if (normalised.length() == 16) {
            normalised += ':00';
        }
        try {
            return Datetime.valueOf(normalised);
        } catch (Exception ex) {
            return null;
        }
    }
}
