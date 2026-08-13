/**
 * ScheduleController — the @AuraEnabled surface of the Appointments tab
 * (`c-manage-appointment`). Thin orchestration only: blank checks, guards, then
 * delegation. No SOQL and no DML of its own — reads go through ScheduleDao,
 * writes through ScheduleService.
 *
 * Every exit path returns APIResponse.
 */
public with sharing class ScheduleController {

    /**
     * Flow 1 — every appointment the clinic holds.
     *
     * cacheable = true: the LWC consumes this through @wire and calls refreshApex
     * after a create or a delete, which is what "the list is reloaded" means.
     */
    @AuraEnabled(cacheable=true)
    public static APIResponse getSchedules() {
        try {
            List<ScheduleDto.ScheduleView> views = new List<ScheduleDto.ScheduleView>();
            for (Schedule__c row : ScheduleDao.findAllSchedules()) {
                views.add(new ScheduleDto.ScheduleView(row));
            }
            return new APIResponse(true, 'Schedules loaded successfully', views);
        } catch (Exception ex) {
            return new APIResponse(false, 'Failed to retrieve schedules: ' + ex.getMessage());
        }
    }

    /**
     * Flow 6 — book one appointment.
     *
     * One primitive parameter per value the form sends; no wrapper at this
     * boundary. Everything arrives as String because the form holds strings and
     * parsing is part of the validation — "1.5" is a failed Duration rule, not a
     * cast error.
     *
     * Three failure shapes, all in the `data` slot so the Server Error panel can
     * render them:
     *   INVALID  → fieldErrors, one entry per invalid field, values kept
     *   BUSY     → slots, the day's free times long enough for the request
     *   NO_SLOTS → neither; the day is full relative to this duration
     */
    @AuraEnabled
    public static APIResponse createSchedule(
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
        try {
            DomainCorrectness.ScheduleInputResult validated =
                DomainCorrectness.validateScheduleInput(
                    startDate, startTime, firstName, lastName,
                    phoneNumber, phoneNumber2, appointmentType,
                    durationMinutes, fees, location, notes
                );

            if (!validated.isValid()) {
                ScheduleDto.BookingResult invalid = new ScheduleDto.BookingResult('INVALID');
                invalid.fieldErrors = validated.errors;
                return new APIResponse(false, 'Validation errors', invalid);
            }

            ScheduleDto.BookingResult result = ScheduleService.bookSchedule(validated.candidate);

            if (result.status == 'BOOKED') {
                return new APIResponse(true, 'Schedule created successfully', result);
            }
            if (result.status == 'BUSY') {
                return new APIResponse(
                    false, 'Requested time is not available. Here are available slots', result);
            }
            return new APIResponse(false, 'No available slots for the requested date', result);
        } catch (Exception ex) {
            return new APIResponse(false, 'Failed to create schedule: ' + ex.getMessage());
        }
    }

    /**
     * Flow 12 — permanently delete one appointment.
     *
     * An appointment that is already gone is NOT an error: "If the appointment no
     * longer exists at confirmation, the list reloads unchanged." So the row is
     * resolved through the Dao and a successful envelope is returned, rather than
     * calling DomainCorrectness.requireScheduleExists, which would throw.
     */
    @AuraEnabled
    public static APIResponse deleteSchedule(String scheduleId) {
        try {
            if (String.isBlank(scheduleId)) {
                return new APIResponse(false, 'scheduleId is required');
            }

            Id recordId;
            try {
                recordId = Id.valueOf(scheduleId);
            } catch (Exception idEx) {
                return new APIResponse(false, 'scheduleId is not a valid record id');
            }

            Schedule__c existing = ScheduleDao.findScheduleById(recordId);
            if (existing == null) {
                return new APIResponse(true, 'Schedule already removed');
            }

            ScheduleService.deleteSchedule(existing);
            return new APIResponse(true, 'Schedule deleted successfully');
        } catch (Exception ex) {
            return new APIResponse(false, 'Failed to delete schedule: ' + ex.getMessage());
        }
    }
}
