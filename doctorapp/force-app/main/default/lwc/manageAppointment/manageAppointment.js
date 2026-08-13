import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getSchedules from '@salesforce/apex/ScheduleController.getSchedules';
import createSchedule from '@salesforce/apex/ScheduleController.createSchedule';
import deleteSchedule from '@salesforce/apex/ScheduleController.deleteSchedule';

import { validateBookingForm } from './manageAppointmentValidator';

/** Shown wherever a stored value is missing (flow 2). */
const NOT_AVAILABLE = 'N/A';

/** The delete confirmation closes itself after this long (flow 12). */
const DELETE_COUNTDOWN_MS = 10000;

/** The Server Error panel auto-dismisses after this long (flow 10). */
const ERROR_DISMISS_MS = 5000;

/** The "Not Supported!!" notice disappears after this long (flow 11). */
const EDIT_NOTICE_MS = 3000;

const EMPTY_FORM = {
    startDate: '',
    startTime: '',
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

/**
 * manageAppointment — the Appointments tab (`ManageAppointmentList`).
 *
 * A pather-only component: the appointment list, the appointment row, the page
 * header, the empty state, the booking form, the available-slots panel, the error
 * panel and the delete confirmation are all template sections of this one
 * component, not child components. It listens, calls Apex, and updates its
 * principal state from the responses — it never mutates state ahead of a result.
 *
 * The tab holds two views and shows exactly one at a time; the list is the default.
 */
export default class ManageAppointment extends LightningElement {
    // ── Principal data (Case 3) ──────────────────────────────────────────────

    /** Every appointment the clinic holds. The one principal state here. */
    @track schedules = [];

    /** The wire result object itself — refreshApex needs it, not `result.data`. */
    _wiredSchedulesResult;

    // ── Control state — one boolean per surface, flipped from handlers only ──

    showBookingForm = false;
    showDeleteConfirm = false;

    // ── Communication state ──────────────────────────────────────────────────

    /**
     * Starts true: the wire is parameterless and fires on component creation, so
     * the fetch is already in flight on the first render. Cleared once, on both
     * branches of the wire callback.
     */
    isLoading = true;

    /** Flow 1 — rendered above the list area; empty when the load succeeded. */
    listErrorMessage = '';

    /**
     * The "Server Error" panel inside the booking form. One of:
     *   { kind: 'VALIDATION', fieldErrors: [...] }
     *   { kind: 'SLOTS',      message, slots: [...] }
     *   { kind: 'MESSAGE',    message }
     * Null when no panel is showing.
     */
    @track serverError = null;

    // ── Form draft — kept separate from the visibility flag ──────────────────

    @track bookingForm = { ...EMPTY_FORM };

    // ── Interaction state — transient, private, cleared in every exit path ───

    _pendingDeleteId = null;
    _deleteTimerId = null;
    _errorTimerId = null;
    _editNoticeTimerId = null;

    showEditNotice = false;

    // ── Wire — flow 1, load on tab load ──────────────────────────────────────

    /**
     * getSchedules is cacheable and takes no parameter, so there is no gating field
     * and no cache-miss gate: the wire fires once on creation, and refreshApex is
     * what re-runs it after a create, a delete, or a cancel out of the form.
     */
    @wire(getSchedules)
    wiredSchedules(result) {
        this._wiredSchedulesResult = result;
        const { data, error } = result;

        if (data === undefined && error === undefined) {
            return;
        }

        if (data) {
            if (data.success) {
                this.schedules = data.data || [];
                this.listErrorMessage = '';
            } else {
                this.schedules = [];
                this.listErrorMessage = data.message;
                this._toast('Error', data.message, 'error');
            }
        } else if (error) {
            this.schedules = [];
            this.listErrorMessage = `Failed to retrieve schedules: ${this._errorMessage(error)}`;
            this._toast('Error', this.listErrorMessage, 'error');
        }

        this.isLoading = false;
    }

    disconnectedCallback() {
        this._clearDeleteTimer();
        this._clearErrorTimer();
        this._clearEditNoticeTimer();
    }

    // ── Derived state — getters, never parallel tracked fields ───────────────

    get isListView() {
        return !this.showBookingForm;
    }

    get hasListError() {
        return this.listErrorMessage !== '';
    }

    get hasSchedules() {
        return this.schedules.length > 0;
    }

    /**
     * The empty state replaces the table only when the load actually succeeded and
     * has finished. Without the isLoading guard, "No appointments scheduled yet."
     * flashes under the spinner on every first render, before any row has arrived.
     */
    get isEmptyState() {
        return !this.isLoading && !this.hasListError && !this.hasSchedules;
    }

    get showTable() {
        return !this.hasListError && this.hasSchedules;
    }

    /**
     * The row view-model. Missing values become "N/A" here, at the presentation
     * edge — the DTO stays honest about what is actually stored.
     */
    get scheduleRows() {
        return this.schedules.map((row) => ({
            id: row.id,
            dateLabel: this._orNotAvailable(row.startDateLabel),
            timeLabel: this._orNotAvailable(row.startTimeLabel),
            patientName: this._patientName(row),
            phone: this._orNotAvailable(row.phoneNumber),
            appointmentType: this._orNotAvailable(row.appointmentType),
            location: this._orNotAvailable(row.location),
            duration: this._orNotAvailable(row.durationMinutes),
            fees: this._feesLabel(row.fees)
        }));
    }

    get hasServerError() {
        return this.serverError !== null;
    }

    get serverErrorIsValidation() {
        return this.hasServerError && this.serverError.kind === 'VALIDATION';
    }

    get serverErrorIsSlots() {
        return this.hasServerError && this.serverError.kind === 'SLOTS';
    }

    get serverErrorIsMessage() {
        return this.hasServerError && this.serverError.kind === 'MESSAGE';
    }

    /** One entry per invalid field, keyed for the template's for:each. */
    get panelFieldErrors() {
        const fieldErrors = (this.serverError && this.serverError.fieldErrors) || [];
        return fieldErrors.map((fieldError, index) => ({
            key: `${fieldError.field}-${index}`,
            field: fieldError.field,
            message: fieldError.message
        }));
    }

    /**
     * The offered free times, as start-end pairs. Presentational only — flow 7:
     * "The free slots are not clickable."
     *
     * The offer arrives as a mathematical set with no guaranteed order, so it is
     * sorted here by start time before it is shown.
     */
    get panelSlots() {
        const slots = (this.serverError && this.serverError.slots) || [];
        return [...slots]
            .sort((left, right) => left.startLabel.localeCompare(right.startLabel))
            .map((slot) => ({
                key: `${slot.startLabel}-${slot.endLabel}`,
                label: `${slot.startLabel} – ${slot.endLabel}`
            }));
    }

    get panelMessage() {
        return this.serverError ? this.serverError.message : '';
    }

    // ── Handlers — page header and empty state ───────────────────────────────

    /**
     * Flow 3 and flow 4 share this handler: "Create one now." opens the same empty
     * form as "New Appointment". Opening the form creates nothing.
     */
    handleNewAppointment() {
        this.bookingForm = { ...EMPTY_FORM };
        this._clearServerError();
        this.showBookingForm = true;
    }

    // ── Handlers — booking form ──────────────────────────────────────────────

    /**
     * One delegating handler for all ten fields, keyed by `data-field`.
     *
     * `c-ao-input` reports through `event.detail.value`; the hand-rolled textareas
     * are native controls whose value is on the target. The draft is replaced, not
     * mutated, so the change is unambiguously reactive.
     */
    handleFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        const detail = event.detail;
        const value =
            detail && typeof detail === 'object' && 'value' in detail
                ? detail.value
                : event.target.value;

        this.bookingForm = { ...this.bookingForm, [field]: value };
    }

    /**
     * Flow 6 — validate, then book.
     *
     * Client-side validation runs first so an invalid form costs no round-trip; it
     * renders into the same panel the server would have produced, and the server
     * re-validates regardless. On any non-BOOKED outcome the draft is left exactly
     * as typed — values are kept, nothing is saved.
     */
    handleBookAppointment() {
        const fieldErrors = validateBookingForm(this.bookingForm);
        if (fieldErrors.length > 0) {
            this._showPanel({ kind: 'VALIDATION', fieldErrors });
            return;
        }

        this.isLoading = true;
        createSchedule({
            startDate: this.bookingForm.startDate,
            startTime: this.bookingForm.startTime,
            firstName: this.bookingForm.firstName,
            lastName: this.bookingForm.lastName,
            phoneNumber: this.bookingForm.phoneNumber,
            phoneNumber2: this.bookingForm.phoneNumber2,
            appointmentType: this.bookingForm.appointmentType,
            durationMinutes: this.bookingForm.durationMinutes,
            fees: this.bookingForm.fees,
            location: this.bookingForm.location,
            notes: this.bookingForm.notes
        })
            .then((response) => {
                if (response.success) {
                    this._clearServerError();
                    this.bookingForm = { ...EMPTY_FORM };
                    this.showBookingForm = false;
                    return this._reloadList();
                }
                this._showPanelFromResponse(response);
                return null;
            })
            .catch((error) => {
                const message = `Failed to create schedule: ${this._errorMessage(error)}`;
                this._showPanel({ kind: 'MESSAGE', message });
                this._toast('Error', message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /** Flow 9 — nothing is saved, the list reloads, no message is shown. */
    handleCancelForm() {
        this.showBookingForm = false;
        this.bookingForm = { ...EMPTY_FORM };
        this._clearServerError();

        this.isLoading = true;
        this._reloadList().catch(() => {
            // The wire callback clears the flag on its error branch; this is only a
            // fallback for a rejection that never reaches the wire.
            this.isLoading = false;
        });
    }

    /** Flow 10 — hiding the panel does not affect the booking; it was already rejected. */
    handleDismissError() {
        this._clearServerError();
    }

    // ── Handlers — appointment row actions ───────────────────────────────────

    /** Flow 11 — editing is not supported; delete and rebook instead. */
    handleEdit() {
        this._clearEditNoticeTimer();
        this.showEditNotice = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation -- flow 11 specifies
        // a notice that "disappears after ~3 seconds"; the delay is the requirement.
        this._editNoticeTimerId = window.setTimeout(() => {
            this.showEditNotice = false;
            this._editNoticeTimerId = null;
        }, EDIT_NOTICE_MS);
    }

    /** Flow 12 — opens the confirmation and starts the 10-second countdown. */
    handleDeleteRequest(event) {
        this._pendingDeleteId = event.currentTarget.dataset.id;
        this.showDeleteConfirm = true;

        this._clearDeleteTimer();
        // eslint-disable-next-line @lwc/lwc/no-async-operation -- flow 12 specifies a
        // 10-second countdown after which "the panel closes and nothing is deleted".
        this._deleteTimerId = window.setTimeout(() => {
            // The countdown expired — the panel closes and nothing is deleted.
            this._deleteTimerId = null;
            this.handleCancelDelete();
        }, DELETE_COUNTDOWN_MS);
    }

    /**
     * Flow 12 — permanent deletion, then a reload.
     *
     * The list reloads on EVERY path: on success (the appointment is gone), on a
     * server-reported failure ("the appointment remains"), and when the record had
     * already been deleted elsewhere ("the list reloads unchanged"). One reload,
     * no branch.
     */
    handleConfirmDelete() {
        const targetId = this._pendingDeleteId;
        this._closeDeleteConfirm();

        if (!targetId) {
            return;
        }

        this.isLoading = true;
        deleteSchedule({ scheduleId: targetId })
            .then((response) => {
                if (!response.success) {
                    this._toast('Error', response.message, 'error');
                }
            })
            .catch((error) => {
                this._toast(
                    'Error',
                    `Failed to delete schedule: ${this._errorMessage(error)}`,
                    'error'
                );
            })
            .then(() => this._reloadList())
            .catch(() => {
                // Swallowed on purpose: the wire callback already surfaced the load
                // failure through listErrorMessage and a toast.
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /** Flow 13 — the X, or the countdown running out. Nothing changes either way. */
    handleCancelDelete() {
        this._closeDeleteConfirm();
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    /**
     * refreshApex needs a provisioned wire result; calling it with `undefined`
     * throws. The guard matters on the very first interaction, before the wire has
     * delivered anything.
     */
    _reloadList() {
        if (!this._wiredSchedulesResult) {
            return Promise.resolve();
        }
        return refreshApex(this._wiredSchedulesResult);
    }

    _closeDeleteConfirm() {
        this._clearDeleteTimer();
        this.showDeleteConfirm = false;
        this._pendingDeleteId = null;
    }

    /** Maps a non-BOOKED create response onto the panel it should render. */
    _showPanelFromResponse(response) {
        const result = response.data;

        if (result && result.status === 'INVALID') {
            this._showPanel({ kind: 'VALIDATION', fieldErrors: result.fieldErrors });
            return;
        }
        if (result && result.status === 'BUSY') {
            this._showPanel({ kind: 'SLOTS', message: response.message, slots: result.slots });
            return;
        }
        this._showPanel({ kind: 'MESSAGE', message: response.message });
    }

    _showPanel(payload) {
        this._clearErrorTimer();
        this.serverError = payload;
        // eslint-disable-next-line @lwc/lwc/no-async-operation -- flow 10 specifies
        // that the panel "auto-dismisses after ~5 seconds".
        this._errorTimerId = window.setTimeout(() => {
            this.serverError = null;
            this._errorTimerId = null;
        }, ERROR_DISMISS_MS);
    }

    _clearServerError() {
        this._clearErrorTimer();
        this.serverError = null;
    }

    _clearDeleteTimer() {
        if (this._deleteTimerId) {
            window.clearTimeout(this._deleteTimerId);
            this._deleteTimerId = null;
        }
    }

    _clearErrorTimer() {
        if (this._errorTimerId) {
            window.clearTimeout(this._errorTimerId);
            this._errorTimerId = null;
        }
    }

    _clearEditNoticeTimer() {
        if (this._editNoticeTimerId) {
            window.clearTimeout(this._editNoticeTimerId);
            this._editNoticeTimerId = null;
        }
    }

    _orNotAvailable(value) {
        if (value === null || value === undefined || String(value).trim() === '') {
            return NOT_AVAILABLE;
        }
        return String(value);
    }

    /** Patient identification uses both names together (flow 2). */
    _patientName(row) {
        const parts = [row.firstName, row.lastName].filter(
            (part) => part !== null && part !== undefined && String(part).trim() !== ''
        );
        return parts.length > 0 ? parts.join(' ') : NOT_AVAILABLE;
    }

    /** Fees of 0 is a real value, not a missing one — free appointments are allowed. */
    _feesLabel(fees) {
        if (fees === null || fees === undefined) {
            return NOT_AVAILABLE;
        }
        return Number(fees).toFixed(2);
    }

    _errorMessage(error) {
        if (!error) {
            return 'Unknown error';
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        return error.message || 'Unknown error';
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
