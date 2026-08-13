import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getSchedules from '@salesforce/apex/ScheduleController.getSchedules';
import createSchedule from '@salesforce/apex/ScheduleController.createSchedule';
import deleteSchedule from '@salesforce/apex/ScheduleController.deleteSchedule';
import sendMessage from '@salesforce/apex/ScheduleAssistantController.sendMessage';
import sendVoiceMessage from '@salesforce/apex/ScheduleAssistantController.sendVoiceMessage';
import speakReply from '@salesforce/apex/ScheduleAssistantController.speakReply';

import { validateBooking } from './manageAppointmentValidator';

/** The tab holds three views; exactly one is on screen at a time. */
const VIEW_LIST = 'list';
const VIEW_FORM = 'form';
const VIEW_ASSISTANT = 'assistant';

const GREETING =
    'Hello! I am your AI Schedule Assistant. How can I help you create or manage your schedule?';

const DELETE_COUNTDOWN_MS = 10000;
const ERROR_PANEL_MS = 5000;
const BUBBLE_MS = 3000;

const EMPTY_FORM = {
    startDateTime: '',
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

export default class ManageAppointment extends LightningElement {
    // ─── Data state — principal (assigned only in the wire handler) ───────────
    @track _schedules = [];
    _wiredSchedules;

    // ─── Control state ────────────────────────────────────────────────────────
    @track _activeView = VIEW_LIST;
    @track _form = { ...EMPTY_FORM };
    @track _pendingDeleteId = null;
    @track _showVoicePanel = false;

    // ─── Communication state ──────────────────────────────────────────────────
    isLoading = true;
    /** Stays on the page until the next successful load — never a passing message. */
    @track _listErrorMessage = '';
    /** The "Server Error" panel; one is ever on screen, replaced by a new attempt. */
    @track _errorPanel = null;

    // ─── Assistant state ──────────────────────────────────────────────────────
    /** Every message of the current conversation, whether or not it is on screen. */
    _history = [];
    @track _exchange = null;
    @track _aiResponse = '';
    @track _draftMessage = '';
    @track _bubble = null;

    // ─── Voice state ──────────────────────────────────────────────────────────
    @track _voiceStatus = 'Click Start to begin recording';
    @track _voiceStatusVariant = 'idle';
    @track _elapsedSeconds = 0;
    @track _isRecording = false;
    @track _isSending = false;
    @track _hasRecording = false;
    @track _voiceReply = '';
    @track _voiceAudioUrl = '';

    _mediaRecorder = null;
    _mediaStream = null;
    _chunks = [];
    _audioBlob = null;
    _audioMimeType = '';

    _deleteTimeoutId = null;
    _errorTimeoutId = null;
    _bubbleTimeoutId = null;
    _tickIntervalId = null;

    // ─── Wire — FLOW B, cacheable read, fires on first render ─────────────────

    /**
     * getSchedules takes no parameters: the spec loads every appointment with no
     * sorting, filtering, searching or paging. There is no gating field to
     * separate, and the wire firing on first render is exactly what "load on
     * page creation" asks for. The result is stored so refreshApex can re-fire it.
     */
    @wire(getSchedules)
    wiredSchedules(result) {
        this._wiredSchedules = result;
        const { data, error } = result;

        if (data) {
            if (data.success) {
                this._schedules = data.data || [];
                this._listErrorMessage = '';
            } else {
                // Nothing is listed at all when the load failed.
                this._schedules = [];
                this._listErrorMessage = data.message;
            }
        } else if (error) {
            this._schedules = [];
            this._listErrorMessage = `Failed to retrieve schedules: ${this._reduceError(error)}`;
        } else {
            // The framework's initial invocation before any response has landed.
            return;
        }
        this.isLoading = false;
    }

    disconnectedCallback() {
        this._clearTimer(this._deleteTimeoutId);
        this._clearTimer(this._errorTimeoutId);
        this._clearTimer(this._bubbleTimeoutId);
        this._stopTicking();
        this._releaseMicrophone();
    }

    // ─── Derived state — getters, never parallel tracked fields ───────────────

    get isListView() {
        return this._activeView === VIEW_LIST;
    }

    get isFormView() {
        return this._activeView === VIEW_FORM;
    }

    get isAssistantView() {
        return this._activeView === VIEW_ASSISTANT;
    }

    get hasAppointments() {
        return this._schedules.length > 0;
    }

    get hasListError() {
        return !!this._listErrorMessage;
    }

    get listErrorMessage() {
        return this._listErrorMessage;
    }

    get errorPanel() {
        return this._errorPanel;
    }

    get hasErrorPanel() {
        return !!this._errorPanel;
    }

    get form() {
        return this._form;
    }

    get greeting() {
        return GREETING;
    }

    get draftMessage() {
        return this._draftMessage;
    }

    get exchange() {
        return this._exchange;
    }

    get aiResponse() {
        return this._aiResponse;
    }

    get hasAiResponse() {
        return !!this._aiResponse;
    }

    get bubble() {
        return this._bubble;
    }

    get showVoicePanel() {
        return this._showVoicePanel;
    }

    get voiceStatus() {
        return this._voiceStatus;
    }

    get voiceStatusClass() {
        return `voice__status voice__status--${this._voiceStatusVariant}`;
    }

    get voiceReply() {
        return this._voiceReply;
    }

    get hasVoiceReply() {
        return !!this._voiceReply;
    }

    get voiceAudioUrl() {
        return this._voiceAudioUrl;
    }

    get hasVoiceAudio() {
        return !!this._voiceAudioUrl;
    }

    /** "00 00" while idle, counting up in minutes and seconds while recording. */
    get timerLabel() {
        const minutes = Math.floor(this._elapsedSeconds / 60);
        const seconds = this._elapsedSeconds % 60;
        return `${this._pad(minutes)} ${this._pad(seconds)}`;
    }

    get startDisabled() {
        return this._isRecording || this._isSending;
    }

    get stopDisabled() {
        return !this._isRecording || this._isSending;
    }

    get sendVoiceDisabled() {
        return !this._hasRecording || this._isRecording || this._isSending;
    }

    get sendDisabled() {
        return !this._draftMessage.trim();
    }

    /**
     * The at-a-glance view-model. Every "N/A" substitution and every format lives
     * here, so the template never computes.
     */
    get scheduleRows() {
        return this._schedules.map((record) => ({
            id: record.Id,
            when: this._formatMoment(record.StartDateTime__c),
            // "N/A" for the patient name unless BOTH names are recorded.
            patient:
                record.FirstName__c && record.LastName__c
                    ? `${record.FirstName__c} ${record.LastName__c}`
                    : 'N/A',
            // Only the first contact number is shown in the list.
            phone: this._orNA(record.PhoneNumber__c),
            type: this._orNA(record.Type__c),
            location: this._orNA(record.Location__c),
            duration: this._orNA(record.DurationMinutes__c),
            fees: this._orNA(record.Fees__c),
            isPendingDelete: this._pendingDeleteId === record.Id
        }));
    }

    // ─── List and header handlers ─────────────────────────────────────────────

    handleNewAppointmentClick() {
        this._openForm();
    }

    handleCreateOneNowClick() {
        this._openForm();
    }

    handleAssistantOpen() {
        // A visit to the assistant begins a conversation that knows nothing
        // about any earlier one.
        this._resetConversation();
        this._activeView = VIEW_ASSISTANT;
    }

    /** Editing is not implemented; the action exists only to say so. */
    handleEditClick() {
        this._showBubble('Not Supported!!', 'sad');
    }

    /** The floating assistant face has no behaviour yet beyond announcing itself. */
    handleAssistantButtonClick() {
        this._showBubble('Unlock Me!', 'wink');
    }

    // ─── Delete ───────────────────────────────────────────────────────────────

    handleDeleteRequest(event) {
        const scheduleId = event.currentTarget.dataset.id;
        this._clearTimer(this._deleteTimeoutId);
        this._pendingDeleteId = scheduleId;
        // Silence never deletes anything — the countdown just closes the panel.
        this._deleteTimeoutId = setTimeout(() => {
            this._pendingDeleteId = null;
        }, DELETE_COUNTDOWN_MS);
    }

    handleDeleteCancel() {
        this._clearTimer(this._deleteTimeoutId);
        this._pendingDeleteId = null;
    }

    handleDeleteConfirm(event) {
        const scheduleId = event.currentTarget.dataset.id;
        if (!scheduleId) {
            return;
        }
        this._clearTimer(this._deleteTimeoutId);
        this._pendingDeleteId = null;

        this.isLoading = true;
        deleteSchedule({ scheduleId })
            .then((response) => {
                if (!response.success) {
                    this._toast('Delete failed', response.message, 'error');
                }
                // An appointment that was already gone is not an error: the
                // freshly loaded list is the answer either way.
                return refreshApex(this._wiredSchedules);
            })
            .catch((error) => {
                this._toast('Delete failed', this._reduceError(error), 'error');
                return refreshApex(this._wiredSchedules);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ─── Booking form ─────────────────────────────────────────────────────────

    handleFormFieldChange(event) {
        const field = event.target.dataset.field;
        if (!field) {
            return;
        }
        this._form = { ...this._form, [field]: event.target.value };
    }

    handleCancelBooking() {
        // An abandoned booking leaves no trace — but leaving the form always
        // shows the list freshly loaded, exactly as leaving the assistant does.
        this._closeForm();
        this.isLoading = true;
        refreshApex(this._wiredSchedules).finally(() => {
            this.isLoading = false;
        });
    }

    handleErrorPanelClose() {
        this._clearTimer(this._errorTimeoutId);
        this._errorPanel = null;
    }

    handleBookAppointment() {
        // Synchronous validation first — the spinner never rises for a form that
        // is about to bail out without calling Apex.
        const errors = validateBooking(this._form);
        if (errors.length > 0) {
            this._showErrorPanel('Validation errors', errors, []);
            return;
        }

        this.isLoading = true;
        createSchedule({
            startDateTime: this._form.startDateTime,
            firstName: this._form.firstName,
            lastName: this._form.lastName,
            phoneNumber: this._form.phoneNumber,
            phoneNumber2: this._form.phoneNumber2,
            appointmentType: this._form.appointmentType,
            durationMinutes: this._form.durationMinutes,
            fees: this._form.fees,
            appointmentLocation: this._form.location,
            notes: this._form.notes
        })
            .then((response) => {
                if (response.success) {
                    // The appointment appearing in the list is the confirmation;
                    // no success message is shown.
                    this._closeForm();
                    return refreshApex(this._wiredSchedules);
                }
                // Every typed value stays in place on every rejection.
                if (response.code === 'VALIDATION') {
                    this._showErrorPanel(response.message, response.errors || [], []);
                } else if (response.code === 'SLOTS') {
                    this._showErrorPanel(response.message, [], response.data || []);
                } else {
                    this._showErrorPanel(response.message, [], []);
                }
                return null;
            })
            .catch((error) => {
                this._showErrorPanel(
                    `Failed to create schedule: ${this._reduceError(error)}`,
                    [],
                    []
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ─── Assistant ────────────────────────────────────────────────────────────

    handleBackToAppointments() {
        this._activeView = VIEW_LIST;
        this.isLoading = true;
        refreshApex(this._wiredSchedules).finally(() => {
            this.isLoading = false;
        });
    }

    handleMessageChange(event) {
        this._draftMessage = event.target.value;
    }

    handleSendMessage() {
        const message = this._draftMessage.trim();
        if (!message) {
            return;
        }

        this.isLoading = true;
        const history = [...this._history];
        sendMessage({ message, history })
            .then((response) => {
                if (!response.success) {
                    // Nothing new is remembered from a failed attempt.
                    this._showExchange(message, response.message, false);
                    return;
                }
                const reply = response.data;
                this._history = [
                    ...this._history,
                    { role: 'user', content: message },
                    { role: 'assistant', content: reply.reply }
                ];
                this._showExchange(message, reply.reply, reply.conversationClosed);
                this._draftMessage = '';
            })
            .catch((error) => {
                this._showExchange(message, `Error: ${this._reduceError(error)}`, false);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ─── Voice ────────────────────────────────────────────────────────────────

    handleVoicePanelOpen() {
        // The panel opens clean every time.
        this._resetVoiceState();
        this._showVoicePanel = true;
    }

    handleVoicePanelClose() {
        // Closing discards the recording but never the conversation.
        this._resetVoiceState();
        this._showVoicePanel = false;
    }

    handleRecordStart() {
        this._audioBlob = null;
        this._hasRecording = false;
        this._chunks = [];
        this._voiceReply = '';
        this._voiceAudioUrl = '';

        navigator.mediaDevices
            .getUserMedia({ audio: true })
            .then((stream) => {
                this._mediaStream = stream;
                this._mediaRecorder = new MediaRecorder(stream);
                this._audioMimeType = this._mediaRecorder.mimeType || 'audio/webm';

                this._mediaRecorder.ondataavailable = (event) => {
                    if (event.data && event.data.size > 0) {
                        this._chunks.push(event.data);
                    }
                };
                this._mediaRecorder.onstop = () => {
                    this._audioBlob = new Blob(this._chunks, { type: this._audioMimeType });
                    this._hasRecording = this._audioBlob.size > 0;
                    this._releaseMicrophone();
                };

                this._mediaRecorder.start();
                this._isRecording = true;
                this._elapsedSeconds = 0;
                this._setVoiceStatus('Recording...', 'recording');
                this._startTicking();
            })
            .catch(() => {
                this._isRecording = false;
                this._hasRecording = false;
                this._setVoiceStatus('Error accessing microphone', 'error');
            });
    }

    handleRecordStop() {
        if (!this._mediaRecorder || !this._isRecording) {
            return;
        }
        this._mediaRecorder.stop();
        this._isRecording = false;
        this._stopTicking();
        this._setVoiceStatus('Ready to send', 'ready');
    }

    handleRecordSend() {
        if (!this._audioBlob || this._audioBlob.size === 0) {
            this._setVoiceStatus('No audio was recorded', 'error');
            return;
        }

        this._isSending = true;
        this._setVoiceStatus('Processing...', 'busy');

        const history = [...this._history];
        let transcript = '';
        let replyText = '';
        let closed = false;

        this._blobToBase64(this._audioBlob)
            .then((audioBase64) =>
                sendVoiceMessage({
                    audioBase64,
                    mimeType: this._audioMimeType,
                    history
                })
            )
            .then((response) => {
                if (!response.success) {
                    throw new Error(response.message);
                }
                const reply = response.data;
                transcript = reply.transcript;
                replyText = reply.reply;
                closed = reply.conversationClosed;

                // A spoken message follows the same conversation a typed one does.
                this._history = [
                    ...this._history,
                    { role: 'user', content: transcript },
                    { role: 'assistant', content: replyText }
                ];
                this._showExchange(transcript, replyText, closed);
                this._voiceReply = replyText;

                // Speaking is a second call on purpose: booking performs DML, and
                // a callout cannot follow uncommitted work in one transaction.
                return speakReply({ text: replyText });
            })
            .then((audioResponse) => {
                if (audioResponse && audioResponse.success && audioResponse.data) {
                    this._voiceAudioUrl = `data:audio/mpeg;base64,${audioResponse.data}`;
                }
                this._setVoiceStatus('Done', 'ready');
            })
            .catch((error) => {
                // The recording is kept so the same one can be retried.
                this._setVoiceStatus(this._reduceError(error), 'error');
            })
            .finally(() => {
                this._isSending = false;
            });
    }

    // ─── Private helpers ──────────────────────────────────────────────────────

    _openForm() {
        this._form = { ...EMPTY_FORM };
        this._errorPanel = null;
        this._activeView = VIEW_FORM;
    }

    _closeForm() {
        this._clearTimer(this._errorTimeoutId);
        this._form = { ...EMPTY_FORM };
        this._errorPanel = null;
        this._activeView = VIEW_LIST;
    }

    _showErrorPanel(message, errors, slots) {
        this._clearTimer(this._errorTimeoutId);
        this._errorPanel = {
            message,
            errors: errors || [],
            hasErrors: (errors || []).length > 0,
            slots: (slots || []).map((slot, index) => ({
                key: `${slot.startIso}-${index}`,
                label: `${slot.startLabel} - ${slot.endLabel}`
            })),
            hasSlots: (slots || []).length > 0
        };
        this._errorTimeoutId = setTimeout(() => {
            this._errorPanel = null;
        }, ERROR_PANEL_MS);
    }

    _showExchange(userText, assistantText, conversationClosed) {
        this._exchange = { userText, assistantText };
        this._aiResponse = assistantText || 'No response received. Please try again.';
        if (conversationClosed) {
            // A closed conversation is forgotten in full.
            this._history = [];
        }
    }

    _resetConversation() {
        this._history = [];
        this._exchange = null;
        this._aiResponse = '';
        this._draftMessage = '';
        this._resetVoiceState();
        this._showVoicePanel = false;
    }

    _resetVoiceState() {
        this._stopTicking();
        if (this._mediaRecorder && this._isRecording) {
            try {
                this._mediaRecorder.stop();
            } catch (error) {
                // Already stopped — nothing to undo.
            }
        }
        this._releaseMicrophone();
        this._mediaRecorder = null;
        this._chunks = [];
        this._audioBlob = null;
        this._audioMimeType = '';
        this._isRecording = false;
        this._isSending = false;
        this._hasRecording = false;
        this._elapsedSeconds = 0;
        this._voiceReply = '';
        this._voiceAudioUrl = '';
        this._setVoiceStatus('Click Start to begin recording', 'idle');
    }

    _releaseMicrophone() {
        if (this._mediaStream) {
            this._mediaStream.getTracks().forEach((track) => track.stop());
            this._mediaStream = null;
        }
    }

    _setVoiceStatus(text, variant) {
        this._voiceStatus = text;
        this._voiceStatusVariant = variant;
    }

    _startTicking() {
        this._stopTicking();
        this._tickIntervalId = setInterval(() => {
            this._elapsedSeconds += 1;
        }, 1000);
    }

    _stopTicking() {
        if (this._tickIntervalId) {
            clearInterval(this._tickIntervalId);
            this._tickIntervalId = null;
        }
    }

    _showBubble(text, mood) {
        this._clearTimer(this._bubbleTimeoutId);
        this._bubble = { text, mood };
        this._bubbleTimeoutId = setTimeout(() => {
            this._bubble = null;
        }, BUBBLE_MS);
    }

    _clearTimer(timeoutId) {
        if (timeoutId) {
            clearTimeout(timeoutId);
        }
    }

    _blobToBase64(blob) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onloadend = () => {
                const result = String(reader.result);
                resolve(result.substring(result.indexOf(',') + 1));
            };
            reader.onerror = () => reject(new Error('The recording could not be read'));
            reader.readAsDataURL(blob);
        });
    }

    /** Day, month, four-digit year, then the time on the 24-hour clock. */
    _formatMoment(value) {
        if (!value) {
            return 'N/A';
        }
        const moment = new Date(value);
        if (Number.isNaN(moment.getTime())) {
            return 'N/A';
        }
        const day = this._pad(moment.getDate());
        const month = this._pad(moment.getMonth() + 1);
        const year = moment.getFullYear();
        return `${day}/${month}/${year} ${this._pad(moment.getHours())}:${this._pad(
            moment.getMinutes()
        )}`;
    }

    /** A detail that was never recorded is shown as unknown, never as blank. */
    _orNA(value) {
        if (value === null || value === undefined || value === '') {
            return 'N/A';
        }
        return value;
    }

    _pad(value) {
        return String(value).padStart(2, '0');
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _reduceError(error) {
        if (!error) {
            return 'Unknown error';
        }
        if (typeof error === 'string') {
            return error;
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        if (error.message) {
            return error.message;
        }
        return JSON.stringify(error);
    }
}
