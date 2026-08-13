/**
 * manageAppointmentValidator — the booking form's input rules.
 *
 * Flow A (pather-only) keeps input rules in `<patherName>Validator.js`, next to
 * the pather that owns the form.
 *
 * These rules are a MIRROR of `DomainCorrectness.validateScheduleInput`, not a
 * replacement for it: running them here means an invalid form costs no round-trip,
 * but the server re-checks every one of them. The client is never the trust
 * boundary.
 *
 * The field labels below are the ones the Server Error panel lists, and they match
 * the Apex labels character for character so a client-side failure and a
 * server-side failure render identically.
 */

const FIELD_DATETIME = 'Date & Time';
const FIELD_FIRST_NAME = 'First Name';
const FIELD_LAST_NAME = 'Last Name';
const FIELD_PHONE = 'Phone Number';
const FIELD_PHONE_2 = 'Phone Number 2';
const FIELD_TYPE = 'Type';
const FIELD_DURATION = 'Duration (min)';
const FIELD_FEES = 'Fees';
const FIELD_LOCATION = 'Location';
const FIELD_NOTES = 'Notes';

/** 6-15 digits, optionally preceded by +961 or 961, with an optional single space. */
const PHONE_PATTERN = /^(\+961|961)?[ ]?[0-9]{6,15}$/;

/** Whole minutes only — no decimal point, no sign. */
const WHOLE_NUMBER_PATTERN = /^[0-9]+$/;

/** An amount with at most two decimals. */
const MONEY_PATTERN = /^[0-9]+(\.[0-9]{1,2})?$/;

const isBlank = (value) => value === null || value === undefined || String(value).trim() === '';

/**
 * Validates the whole draft in one pass and returns EVERY failure, so the panel
 * can list each invalid field with its reason rather than stopping at the first.
 *
 * @param {object} form the booking form draft
 * @returns {Array<{field: string, message: string}>} empty when the draft is valid
 */
export function validateBookingForm(form) {
    const errors = [];

    checkStartDateTime(form, errors);
    checkRequiredText(form.firstName, FIELD_FIRST_NAME, 50, errors);
    checkRequiredText(form.lastName, FIELD_LAST_NAME, 50, errors);
    checkRequiredPhone(form.phoneNumber, FIELD_PHONE, errors);
    checkOptionalPhone(form.phoneNumber2, FIELD_PHONE_2, errors);
    checkRequiredText(form.appointmentType, FIELD_TYPE, 255, errors);
    checkDuration(form.durationMinutes, errors);
    checkFees(form.fees, errors);
    checkRequiredText(form.location, FIELD_LOCATION, 500, errors);
    checkOptionalText(form.notes, FIELD_NOTES, 500, errors);

    return errors;
}

/**
 * The calendar picker and the time picker are one logical field, so every failure
 * is reported once, under the single label "Date & Time".
 *
 * `new Date('YYYY-MM-DDTHH:mm')` parses as LOCAL time — which is the clinic's zone,
 * the same basis Apex uses via Datetime.newInstance(Date, Time).
 */
function checkStartDateTime(form, errors) {
    if (isBlank(form.startDate) || isBlank(form.startTime)) {
        errors.push({ field: FIELD_DATETIME, message: 'Date & Time is required' });
        return;
    }

    const parsed = new Date(`${form.startDate}T${form.startTime}`);
    if (Number.isNaN(parsed.getTime())) {
        errors.push({ field: FIELD_DATETIME, message: 'Date & Time is not a valid date and time' });
        return;
    }

    if (parsed.getTime() <= Date.now()) {
        errors.push({ field: FIELD_DATETIME, message: 'Date & Time must be in the future' });
    }
}

function checkRequiredText(value, label, maxLength, errors) {
    if (isBlank(value)) {
        errors.push({ field: label, message: `${label} is required` });
        return;
    }
    if (String(value).trim().length > maxLength) {
        errors.push({ field: label, message: `${label} must be ${maxLength} characters or fewer` });
    }
}

function checkOptionalText(value, label, maxLength, errors) {
    if (isBlank(value)) {
        return;
    }
    if (String(value).trim().length > maxLength) {
        errors.push({ field: label, message: `${label} must be ${maxLength} characters or fewer` });
    }
}

function checkRequiredPhone(value, label, errors) {
    if (isBlank(value)) {
        errors.push({ field: label, message: `${label} is required` });
        return;
    }
    checkPhoneFormat(value, label, errors);
}

function checkOptionalPhone(value, label, errors) {
    if (isBlank(value)) {
        return;
    }
    checkPhoneFormat(value, label, errors);
}

function checkPhoneFormat(value, label, errors) {
    if (!PHONE_PATTERN.test(String(value).trim())) {
        errors.push({
            field: label,
            message: `${label} must be 6-15 digits, optionally prefixed with +961`
        });
    }
}

function checkDuration(value, errors) {
    if (isBlank(value)) {
        errors.push({ field: FIELD_DURATION, message: `${FIELD_DURATION} is required` });
        return;
    }
    const trimmed = String(value).trim();
    if (!WHOLE_NUMBER_PATTERN.test(trimmed) || trimmed.length > 5 || Number(trimmed) < 1) {
        errors.push({
            field: FIELD_DURATION,
            message: `${FIELD_DURATION} must be a whole number of at least 1`
        });
    }
}

function checkFees(value, errors) {
    if (isBlank(value)) {
        errors.push({ field: FIELD_FEES, message: `${FIELD_FEES} is required` });
        return;
    }
    if (!MONEY_PATTERN.test(String(value).trim())) {
        errors.push({
            field: FIELD_FEES,
            message: `${FIELD_FEES} must be 0 or greater, with at most 2 decimals`
        });
    }
}
