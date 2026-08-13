import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getSchedules from '@salesforce/apex/ScheduleController.getSchedules';
import createSchedule from '@salesforce/apex/ScheduleController.createSchedule';
import updateSchedule from '@salesforce/apex/ScheduleController.updateSchedule';
import deleteSchedule from '@salesforce/apex/ScheduleController.deleteSchedule';

import {
    validateAppointmentForm,
    emptyAppointmentForm,
    toApexMoment
} from './manageAppointmentValidator';

/**
 * manageAppointment — the pather (parent) of the Appointments tab.
 *
 * The tab holds two views — the appointment list and the booking form — and
 * shows exactly one of them at a time, the list being the default.
 *
 * Call style (sequence-fe-desicion):
 *   getSchedules   cacheable = true  -> FLOW B, @wire in wired-FUNCTION form,
 *                                      re-read with refreshApex after every
 *                                      mutation and after leaving the form
 *   create/update/delete             -> FLOW A, imperative: validate -> spinner
 *                                      up -> Apex -> branch -> toast -> spinner
 *                                      down in .finally
 *
 * State categories (handle-state):
 *   Data (principal)  _schedules            server-backed, full CRUD
 *   Data (derived)    appointmentRows, ...  getters, never parallel tracked copies
 *   Control           _showForm, _showDeleteConfirm
 *   Selection         _editingScheduleId, _deleteTargetId
 *   Form buffer       _form
 *   Communication     isLoading + ShowToastEvent
 */

const NOT_AVAILABLE = 'N/A';

const MONTHS = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
];

const DELETE_COUNTDOWN_SECONDS = 10;

export default class ManageAppointment extends LightningElement {
    // ── Principal data state ──────────────────────────────────────────────────
    // Every appointment the clinic holds, in the order they are stored.
    @track _schedules = [];

    // The raw wire result, kept so refreshApex has something to re-read.
    _wiredSchedulesResult;

    // ── Control state ─────────────────────────────────────────────────────────
    _showForm = false;
    _showDeleteConfirm = false;

    // ── Selection state ───────────────────────────────────────────────────────
    _editingScheduleId = null;
    _deleteTargetId = null;

    // ── Form buffer ───────────────────────────────────────────────────────────
    @track _form = emptyAppointmentForm();

    // ── The offer returned when a booking is refused ──────────────────────────
    // Server-returned data, not an error field: the slots must stay on screen
    // beside the form the admin is correcting, which a toast cannot do.
    _availabilityMessage = null;
    @track _availableSlots = [];

    // ── Communication state ───────────────────────────────────────────────────
    // Starts true: the wire fires on page load, so the spinner is already up
    // while the first read is in flight.
    isLoading = true;

    // ── Delete confirmation countdown ─────────────────────────────────────────
    _deleteCountdown = DELETE_COUNTDOWN_SECONDS;
    _countdownIntervalId = null;

    // ══ Data load ════════════════════════════════════════════════════════════

    /**
     * Wired FUNCTION form, not property form: principal state is updated from
     * the Apex response inside the callback (state checklist rows 1-2).
     *
     * The read takes no parameter and loads when the tab first loads, so there
     * is no gating field and no cache-miss gate to apply — the wire fires once
     * on its own and again on every refreshApex.
     */
    @wire(getSchedules)
    wiredSchedules(result) {
        this._wiredSchedulesResult = result;

        // Guard the framework's initial invocation, before data or error exist.
        if (!result || (!result.data && !result.error)) {
            return;
        }

        if (result.data) {
            if (result.data.success) {
                this._schedules = result.data.data || [];
            } else {
                this._toast('Error', result.data.message || 'Failed to retrieve schedules', 'error');
            }
        } else {
            this._toast('Error', this._reasonFrom(result.error, 'Failed to retrieve schedules'), 'error');
        }

        // One assignment, reached on both branches — the wire owns the lifecycle,
        // so this never lives in a .finally.
        this.isLoading = false;
    }

    disconnectedCallback() {
        this._stopCountdown();
    }

    // ══ Derived state — getters, never parallel tracked fields ═══════════════

    get isListView() {
        return !this._showForm;
    }

    /**
     * Template-facing aliases for the private fields above. The template never
     * reads a `_`-prefixed field directly — it goes through a getter, the same
     * way every other derived value does.
     */
    get form() {
        return this._form;
    }

    get showDeleteConfirm() {
        return this._showDeleteConfirm;
    }

    get availabilityMessage() {
        return this._availabilityMessage;
    }

    get hasAppointments() {
        return this._schedules.length > 0;
    }

    get isEditMode() {
        return this._editingScheduleId !== null;
    }

    get formTitle() {
        return this.isEditMode ? 'Edit Appointment' : 'Create Appointment';
    }

    get submitLabel() {
        return this.isEditMode ? 'Save' : 'Book appointment';
    }

    /**
     * One row view-model per appointment: de-normalised principal fields, every
     * unknown value rendered as "N/A". Notes are deliberately absent — they are
     * kept with the appointment but are never part of the list.
     */
    get appointmentRows() {
        return this._schedules.map((row) => ({
            id: row.id,
            whenLabel: this._formatMoment(row.startDateTime),
            patientName: this._formatPatientName(row.firstName, row.lastName),
            phone: this._orNotAvailable(row.phoneNumber),
            appointmentType: this._orNotAvailable(row.appointmentType),
            location: this._orNotAvailable(row.location),
            durationLabel: this._orNotAvailable(row.durationMinutes),
            feesLabel: this._formatFees(row.fees)
        }));
    }

    get hasAvailabilityMessage() {
        return this._availabilityMessage !== null;
    }

    get hasAvailableSlots() {
        return this._availableSlots.length > 0;
    }

    /**
     * The offered slots as start-end pairs. The algorithm returns a mathematical
     * SET with no guaranteed ordering, so the UI sorts them itself.
     */
    get slotRows() {
        return [...this._availableSlots]
            .sort((left, right) => new Date(left.startDateTime) - new Date(right.startDateTime))
            .map((slot) => ({
                key: `${slot.startDateTime}|${slot.endDateTime}`,
                label: `${this._formatTime(slot.startDateTime)} – ${this._formatTime(slot.endDateTime)}`
            }));
    }

    get deleteCountdownLabel() {
        return `This confirmation closes in ${this._deleteCountdown}s`;
    }

    /** Date & Time is read-only on an edit — a different time is a different appointment. */
    get isMomentReadOnly() {
        return this.isEditMode;
    }

    // ══ Page header / empty state — opening the form ═════════════════════════

    handleNewAppointmentClick() {
        this._openBlankForm();
    }

    handleCreateFromEmptyState(event) {
        // Rendered as a link per the spec, so the default navigation is stopped.
        event.preventDefault();
        this._openBlankForm();
    }

    // ══ Booking form ═════════════════════════════════════════════════════════

    handleFormFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        if (!field) {
            return;
        }
        const value = event.detail ? event.detail.value : event.target.value;
        this._form = { ...this._form, [field]: value };
    }

    handleFormTextAreaChange(event) {
        const field = event.target.dataset.field;
        if (!field) {
            return;
        }
        this._form = { ...this._form, [field]: event.target.value };
    }

    /**
     * FLOW A — imperative. Synchronous validation first, so the spinner never
     * flashes for an action that was about to bail out.
     */
    handleBookAppointment() {
        const errors = validateAppointmentForm(this._form, { isEdit: this.isEditMode });
        if (errors.length > 0) {
            // Every entered value is kept; nothing is saved.
            this._toast('Cannot save appointment', errors.join(' '), 'error');
            return;
        }

        this._clearAvailability();
        this.isLoading = true;

        this._submitForm()
            .then((response) => this._handleSaveResponse(response))
            .catch((error) => {
                this._toast('Error', this._reasonFrom(error, this._saveFailurePrefix()), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleFormCancel() {
        // Everything typed is discarded and the list reappears freshly loaded.
        this._closeForm();
        this._reloadList();
    }

    handleAvailabilityDismiss() {
        // The booking was already rejected, so nothing about it changes — the
        // form stays on screen with every typed value in place.
        this._clearAvailability();
    }

    // ══ Row actions ══════════════════════════════════════════════════════════

    handleEditClick(event) {
        const scheduleId = event.currentTarget.dataset.id;
        const record = this._schedules.find((row) => row.id === scheduleId);
        if (!record) {
            return;
        }

        this._editingScheduleId = scheduleId;
        this._form = {
            appointmentDate: this._toDateInputValue(record.startDateTime),
            appointmentTime: this._toTimeInputValue(record.startDateTime),
            firstName: record.firstName || '',
            lastName: record.lastName || '',
            phoneNumber: record.phoneNumber || '',
            phoneNumber2: record.phoneNumber2 || '',
            appointmentType: record.appointmentType || '',
            durationMinutes: record.durationMinutes === null ? '' : String(record.durationMinutes),
            fees: record.fees === null ? '' : String(record.fees),
            location: record.location || '',
            notes: record.notes || ''
        };
        this._clearAvailability();
        this._showForm = true;
    }

    handleDeleteClick(event) {
        this._deleteTargetId = event.currentTarget.dataset.id;
        this._showDeleteConfirm = true;
        this._startCountdown();
    }

    handleDeleteConfirm() {
        const scheduleId = this._deleteTargetId;
        if (!scheduleId) {
            return;
        }

        this._closeDeleteConfirm();
        this.isLoading = true;

        deleteSchedule({ scheduleId })
            .then((response) => {
                if (response && response.success) {
                    this._toast('Success', response.message, 'success');
                } else {
                    // Includes "the appointment no longer exists": either way the
                    // list is re-read, so it comes back showing what is really there.
                    this._toast('Error', (response && response.message) || 'Failed to delete schedule', 'error');
                }
                return refreshApex(this._wiredSchedulesResult);
            })
            .catch((error) => {
                this._toast('Error', this._reasonFrom(error, 'Failed to delete schedule'), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleDeleteCancel() {
        // Nothing is deleted; the admin can start the deletion again on any row.
        this._closeDeleteConfirm();
    }

    // ══ Internals — Apex ═════════════════════════════════════════════════════

    _submitForm() {
        const payload = {
            startDateTime: toApexMoment(this._form.appointmentDate, this._form.appointmentTime),
            firstName: this._form.firstName,
            lastName: this._form.lastName,
            phoneNumber: this._form.phoneNumber,
            phoneNumber2: this._form.phoneNumber2 || null,
            appointmentType: this._form.appointmentType,
            durationMinutes: parseInt(this._form.durationMinutes, 10),
            fees: parseFloat(this._form.fees),
            location: this._form.location,
            notes: this._form.notes || null
        };

        if (this.isEditMode) {
            return updateSchedule({ scheduleId: this._editingScheduleId, ...payload });
        }
        return createSchedule(payload);
    }

    _handleSaveResponse(response) {
        if (response && response.success) {
            this._closeForm();
            this._toast('Success', response.message, 'success');
            return refreshApex(this._wiredSchedulesResult);
        }

        const message = (response && response.message) || this._saveFailurePrefix();

        // A refused booking is not a failure to report and walk away from: the
        // form stays open with every typed value, and the offer is shown beside
        // it so the admin can pick another time.
        if (response && response.data && response.data.availabilityRejected) {
            this._availabilityMessage = message;
            this._availableSlots = response.data.availableSlots || [];
            return null;
        }

        throw new Error(message);
    }

    /**
     * "when the tab first loads, and again after leaving the booking form" —
     * the second half of the recorded load timing. The wire callback clears the
     * spinner on the happy path; the .finally covers the case where refreshApex
     * rejects and the callback therefore never fires.
     */
    _reloadList() {
        this.isLoading = true;
        refreshApex(this._wiredSchedulesResult)
            .catch((error) => {
                this._toast('Error', this._reasonFrom(error, 'Failed to retrieve schedules'), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    _saveFailurePrefix() {
        return this.isEditMode ? 'Failed to update schedule' : 'Failed to create schedule';
    }

    // ══ Internals — view switching ═══════════════════════════════════════════

    _openBlankForm() {
        this._editingScheduleId = null;
        this._form = emptyAppointmentForm();
        this._clearAvailability();
        this._showForm = true;
    }

    _closeForm() {
        this._showForm = false;
        this._editingScheduleId = null;
        this._form = emptyAppointmentForm();
        this._clearAvailability();
    }

    _clearAvailability() {
        this._availabilityMessage = null;
        this._availableSlots = [];
    }

    _closeDeleteConfirm() {
        this._stopCountdown();
        this._showDeleteConfirm = false;
        this._deleteTargetId = null;
    }

    _startCountdown() {
        this._stopCountdown();
        this._deleteCountdown = DELETE_COUNTDOWN_SECONDS;
        this._countdownIntervalId = setInterval(() => {
            this._deleteCountdown -= 1;
            if (this._deleteCountdown <= 0) {
                this.handleDeleteCancel();
            }
        }, 1000);
    }

    _stopCountdown() {
        if (this._countdownIntervalId) {
            clearInterval(this._countdownIntervalId);
            this._countdownIntervalId = null;
        }
    }

    // ══ Internals — formatting ═══════════════════════════════════════════════

    _orNotAvailable(value) {
        if (value === null || value === undefined || String(value).trim() === '') {
            return NOT_AVAILABLE;
        }
        return String(value);
    }

    _formatPatientName(firstName, lastName) {
        const name = `${firstName || ''} ${lastName || ''}`.trim();
        return name === '' ? NOT_AVAILABLE : name;
    }

    /** "15 May 2026 14:30" — day month year, time in 24-hour form. */
    _formatMoment(value) {
        const moment = this._toDate(value);
        if (!moment) {
            return NOT_AVAILABLE;
        }
        const day = moment.getDate();
        const month = MONTHS[moment.getMonth()];
        const year = moment.getFullYear();
        return `${day} ${month} ${year} ${this._formatTime(value)}`;
    }

    _formatTime(value) {
        const moment = this._toDate(value);
        if (!moment) {
            return NOT_AVAILABLE;
        }
        const hours = String(moment.getHours()).padStart(2, '0');
        const minutes = String(moment.getMinutes()).padStart(2, '0');
        return `${hours}:${minutes}`;
    }

    _formatFees(value) {
        if (value === null || value === undefined || value === '') {
            return NOT_AVAILABLE;
        }
        const amount = Number(value);
        return isNaN(amount) ? NOT_AVAILABLE : amount.toFixed(2);
    }

    _toDateInputValue(value) {
        const moment = this._toDate(value);
        if (!moment) {
            return '';
        }
        const month = String(moment.getMonth() + 1).padStart(2, '0');
        const day = String(moment.getDate()).padStart(2, '0');
        return `${moment.getFullYear()}-${month}-${day}`;
    }

    _toTimeInputValue(value) {
        const moment = this._toDate(value);
        return moment ? this._formatTime(value) : '';
    }

    _toDate(value) {
        if (value === null || value === undefined || value === '') {
            return null;
        }
        const moment = new Date(value);
        return isNaN(moment.getTime()) ? null : moment;
    }

    // ══ Internals — the single error channel ═════════════════════════════════

    _reasonFrom(error, fallback) {
        if (!error) {
            return fallback;
        }
        const reason = (error.body && error.body.message) || error.message;
        return reason ? `${fallback}: ${reason}` : fallback;
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
