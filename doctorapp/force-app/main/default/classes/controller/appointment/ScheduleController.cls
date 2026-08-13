/**
 * Thin @AuraEnabled orchestration for the Appointments tab — guards, then
 * delegation. No SOQL and no DML here: reads reach the database through
 * ScheduleDao, writes through ScheduleService.
 *
 * Every exit path of every method returns APIResponse.
 */
public with sharing class ScheduleController {
    /** The exact message prefixes the client-flow spec fixes. */
    private static final String MSG_LOAD_FAILED = 'Failed to retrieve schedules';
    private static final String MSG_CREATE_FAILED = 'Failed to create schedule';
    private static final String MSG_VALIDATION = 'Validation errors';
    private static final String MSG_SLOTS = 'Requested time is not available. Here are available slots';
    private static final String MSG_NO_SLOTS = 'No available slots for the requested date';

    /**
     * Every appointment the clinic holds. Cacheable so the LWC consumes it with
     * @wire and can refreshApex it after a write.
     */
    @AuraEnabled(cacheable=true)
    public static APIResponse getSchedules() {
        try {
            return new APIResponse(true, 'Schedules loaded successfully', ScheduleService.loadSchedules());
        } catch (Exception ex) {
            return new APIResponse(false, MSG_LOAD_FAILED + ': ' + ex.getMessage());
        }
    }

    /**
     * Books an appointment. Separated inputs — one primitive parameter per value
     * the LWC sends; each parameter name matches the key in the LWC payload
     * character for character, because @salesforce/apex binds by name.
     */
    @AuraEnabled
    public static APIResponse createSchedule(
        String startDateTime,
        String firstName,
        String lastName,
        String phoneNumber,
        String phoneNumber2,
        String appointmentType,
        String durationMinutes,
        String fees,
        String appointmentLocation,
        String notes
    ) {
        try {
            ScheduleDto.Input input = new ScheduleDto.Input();
            input.startDateTimeRaw = startDateTime;
            input.firstName = firstName;
            input.lastName = lastName;
            input.phoneNumber = phoneNumber;
            input.phoneNumber2 = phoneNumber2;
            input.appointmentType = appointmentType;
            input.durationRaw = durationMinutes;
            input.feesRaw = fees;
            input.location = appointmentLocation;
            input.notes = notes;

            return toResponse(ScheduleService.createSchedule(input));
        } catch (ServiceException se) {
            // A field-rule failure carries the per-field list the panel names.
            if (!se.fieldErrors.isEmpty()) {
                return new APIResponse(false, MSG_VALIDATION)
                    .withCode(APIResponse.CODE_VALIDATION)
                    .withErrors(se.fieldErrors);
            }
            return new APIResponse(false, MSG_CREATE_FAILED + ': ' + se.getMessage());
        } catch (Exception ex) {
            return new APIResponse(false, MSG_CREATE_FAILED + ': ' + ex.getMessage());
        }
    }

    /**
     * Deletes an appointment for good.
     *
     * An appointment that is already gone is NOT an error — the spec says the
     * freshly loaded list is shown and nothing else changes — so the guard is
     * the non-throwing variant and a missing record still returns success.
     */
    @AuraEnabled
    public static APIResponse deleteSchedule(String scheduleId) {
        try {
            if (String.isBlank(scheduleId)) {
                return new APIResponse(false, 'scheduleId is required');
            }
            Schedule__c record = DomainCorrectness.requireOptionalScheduleExists(scheduleId);
            ScheduleService.deleteSchedule(record);
            return new APIResponse(true, 'Schedule deleted successfully');
        } catch (Exception ex) {
            return new APIResponse(false, 'Error deleting schedule: ' + ex.getMessage());
        }
    }

    /** Turns the Service's three outcomes into the envelope the LWC branches on. */
    @TestVisible
    private static APIResponse toResponse(ScheduleDto.Result result) {
        if (result.outcome == ScheduleService.OUTCOME_CREATED) {
            return new APIResponse(true, 'Schedule created successfully', result.created);
        }
        if (result.outcome == ScheduleService.OUTCOME_SLOTS) {
            return new APIResponse(false, MSG_SLOTS, result.availableSlots)
                .withCode(APIResponse.CODE_SLOTS);
        }
        return new APIResponse(false, MSG_NO_SLOTS).withCode(APIResponse.CODE_NO_SLOTS);
    }
}
