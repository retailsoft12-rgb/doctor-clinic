/**
 * Booking-form input rules.
 *
 * Flow A (pather-only) keeps the input rules here rather than in a child
 * component. These mirror ScheduleValidator on the server one-for-one — the
 * server stays the authority (the spec titles the failure panel "Server Error"),
 * and this file only shortens the round trip.
 */

/**
 * 6 to 15 digits, optionally preceded by the Lebanese country code 961 with or
 * without a leading plus sign and with or without one space after it.
 */
const PHONE_PATTERN = /^(\+?961 ?)?[0-9]{6,15}$/;

const NAME_MAX = 50;
const LOCATION_MAX = 500;
const NOTES_MAX = 500;

export const PHONE_ERROR = 'Invalid phone number format';

export function isValidPhone(raw) {
    if (!raw || !raw.trim()) {
        return false;
    }
    return PHONE_PATTERN.test(raw.trim());
}

/**
 * Returns every field error at once — never the first one only, because the
 * spec's panel "names each field that is wrong and what is wrong with it".
 *
 * @param {object} form the booking-form draft
 * @returns {string[]} empty when the form is bookable
 */
export function validateBooking(form) {
    const errors = [];
    const value = (key) => (form && form[key] ? String(form[key]) : '');

    // Date & Time — required, a real moment, and in the future.
    const startRaw = value('startDateTime');
    if (!startRaw.trim()) {
        errors.push('Date & Time is required');
    } else {
        const parsed = new Date(startRaw);
        if (Number.isNaN(parsed.getTime())) {
            errors.push('Date & Time is not a valid date and time');
        } else if (parsed.getTime() <= Date.now()) {
            errors.push('Date & Time must be in the future');
        }
    }

    // Names — required, 1 to 50 characters, never only spaces.
    const firstName = value('firstName').trim();
    if (!firstName) {
        errors.push('First Name is required');
    } else if (firstName.length > NAME_MAX) {
        errors.push('First Name must be between 1 and 50 characters');
    }

    const lastName = value('lastName').trim();
    if (!lastName) {
        errors.push('Last Name is required');
    } else if (lastName.length > NAME_MAX) {
        errors.push('Last Name must be between 1 and 50 characters');
    }

    // Phone — the first is required, the second is entirely optional.
    const phone = value('phoneNumber').trim();
    if (!phone) {
        errors.push('Phone Number is required');
    } else if (!isValidPhone(phone)) {
        errors.push(`${PHONE_ERROR}: Phone Number`);
    }

    const phone2 = value('phoneNumber2').trim();
    if (phone2 && !isValidPhone(phone2)) {
        errors.push(`${PHONE_ERROR}: Phone Number 2`);
    }

    // Type — free text; the clinic decides its own wording.
    if (!value('appointmentType').trim()) {
        errors.push('Type is required');
    }

    // Duration — a whole number of minutes, at least one.
    const durationRaw = value('durationMinutes').trim();
    if (!durationRaw) {
        errors.push('Duration is required');
    } else {
        const duration = Number(durationRaw);
        if (!Number.isFinite(duration) || !Number.isInteger(duration)) {
            errors.push('Duration must be a whole number of minutes');
        } else if (duration < 1) {
            errors.push('Duration must be greater than zero');
        }
    }

    // Fees — zero or more, at most two decimals. A free visit is bookable.
    const feesRaw = value('fees').trim();
    if (!feesRaw) {
        errors.push('Fees are required');
    } else {
        const fees = Number(feesRaw);
        if (!Number.isFinite(fees)) {
            errors.push('Fees must be an amount of zero or more');
        } else if (fees < 0) {
            errors.push('Fees must be zero or more');
        } else if (decimalPlaces(feesRaw) > 2) {
            errors.push('Fees must have at most two decimals');
        }
    }

    // Location — required, up to 500 characters.
    const location = value('location').trim();
    if (!location) {
        errors.push('Location is required');
    } else if (location.length > LOCATION_MAX) {
        errors.push('Location must be at most 500 characters');
    }

    // Notes — optional, never required for an appointment to exist.
    if (value('notes').length > NOTES_MAX) {
        errors.push('Notes must be at most 500 characters');
    }

    return errors;
}

function decimalPlaces(raw) {
    const dot = raw.indexOf('.');
    return dot === -1 ? 0 : raw.length - dot - 1;
}
