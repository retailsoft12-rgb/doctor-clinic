/**
 * manageAppointmentValidator — the input rules of the booking form.
 *
 * Flow A (pather-only) keeps the input rules in <patherName>Validator.js beside
 * the pather, not in a child component (ao-reusable-components-guide, and
 * create-new-functionality Step 4a).
 *
 * These are the client half of the Tab 5a rules. DomainCorrectness re-checks
 * every one of them server-side, because a client can be bypassed; the two sets
 * are deliberately identical in meaning and wording.
 *
 * The validator returns EVERY failure, not the first one, so the form can name
 * each invalid field and its reason in one message.
 */

const MAX_NAME_LENGTH = 50;
const MAX_TYPE_LENGTH = 255;
const MAX_LOCATION_LENGTH = 500;

/** 6-15 digits, optionally preceded by +961 or 961 with an optional single space. */
const PHONE_PATTERN = /^(?:\+?961 ?)?\d{6,15}$/;

/** 0 or more, with up to 2 decimals. */
const FEES_PATTERN = /^\d+(\.\d{1,2})?$/;

/** Whole minutes. */
const WHOLE_NUMBER_PATTERN = /^\d+$/;

const blank = (value) => value === null || value === undefined || String(value).trim() === '';

/**
 * Combines the date field ('YYYY-MM-DD') and the time field ('HH:mm') into the
 * 'yyyy-MM-dd HH:mm:ss' local wall-clock string the Apex boundary parses.
 * Returns null when either half is missing.
 */
export function toApexMoment(appointmentDate, appointmentTime) {
    if (blank(appointmentDate) || blank(appointmentTime)) {
        return null;
    }
    const time = appointmentTime.length === 5 ? `${appointmentTime}:00` : appointmentTime;
    return `${appointmentDate} ${time}`;
}

/** The same two halves as a JS Date, for the "must be in the future" check. */
function toLocalDate(appointmentDate, appointmentTime) {
    const moment = toApexMoment(appointmentDate, appointmentTime);
    if (!moment) {
        return null;
    }
    const parsed = new Date(moment.replace(' ', 'T'));
    return isNaN(parsed.getTime()) ? null : parsed;
}

function validateRequiredText(value, label, maxLength, errors) {
    if (blank(value)) {
        errors.push(`${label} is required.`);
        return;
    }
    if (String(value).trim().length > maxLength) {
        errors.push(`${label} must be at most ${maxLength} characters.`);
    }
}

function validatePhone(value, label, errors, required) {
    if (blank(value)) {
        if (required) {
            errors.push(`${label} is required.`);
        }
        return;
    }
    if (!PHONE_PATTERN.test(String(value).trim())) {
        errors.push(`${label} must be 6-15 digits, optionally preceded by +961 or 961.`);
    }
}

function validateMoment(form, errors, isEdit) {
    if (blank(form.appointmentDate) || blank(form.appointmentTime)) {
        errors.push('Date & Time is required.');
        return;
    }
    const moment = toLocalDate(form.appointmentDate, form.appointmentTime);
    if (!moment) {
        errors.push('Date & Time is not a valid date and time.');
        return;
    }
    // An appointment's moment is fixed once booked, so an edit never re-checks
    // it — the record it is editing may legitimately already be in the past.
    if (!isEdit && moment.getTime() <= Date.now()) {
        errors.push('Date & Time must be in the future.');
    }
}

function validateDuration(value, errors) {
    if (blank(value)) {
        errors.push('Duration is required.');
        return;
    }
    const raw = String(value).trim();
    if (!WHOLE_NUMBER_PATTERN.test(raw)) {
        errors.push('Duration must be a whole number of minutes.');
        return;
    }
    if (parseInt(raw, 10) <= 0) {
        errors.push('Duration must be greater than 0 minutes.');
    }
}

function validateFees(value, errors) {
    if (blank(value)) {
        errors.push('Fees is required.');
        return;
    }
    if (!FEES_PATTERN.test(String(value).trim())) {
        errors.push('Fees must be 0 or more, with up to 2 decimals.');
    }
}

/**
 * @param {object} form   the draft the booking form holds
 * @param {object} options `{ isEdit }` — an edit skips the future check, because
 *                         the date and time of a booked appointment cannot move
 * @returns {string[]}    every failure, each naming its field and its reason
 */
export function validateAppointmentForm(form, options) {
    const isEdit = !!(options && options.isEdit);
    const errors = [];

    validateMoment(form, errors, isEdit);
    validateRequiredText(form.firstName, 'First Name', MAX_NAME_LENGTH, errors);
    validateRequiredText(form.lastName, 'Last Name', MAX_NAME_LENGTH, errors);
    validatePhone(form.phoneNumber, 'Phone Number', errors, true);
    validatePhone(form.phoneNumber2, 'Phone Number 2', errors, false);
    validateRequiredText(form.appointmentType, 'Type', MAX_TYPE_LENGTH, errors);
    validateDuration(form.durationMinutes, errors);
    validateFees(form.fees, errors);
    validateRequiredText(form.location, 'Location', MAX_LOCATION_LENGTH, errors);

    return errors;
}

/** The empty booking form. */
export function emptyAppointmentForm() {
    return {
        appointmentDate: '',
        appointmentTime: '',
        firstName: '',
        lastName: '',
        phoneNumber: '',
        phoneNumber2: '',
        appointmentType: '',
        durationMinutes: '',
        fees: '',
        location: '',
        notes: ''
    };
}
