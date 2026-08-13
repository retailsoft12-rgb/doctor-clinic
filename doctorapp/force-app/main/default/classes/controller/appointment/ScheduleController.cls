/**
 * ScheduleController — the @AuraEnabled surface of the Appointments tab.
 *
 * sequence-be phase 1, hop 1.0: thin orchestration only. Guards, then
 * delegation. No SOQL and no DML here — reads reach the database through
 * ScheduleDao (behind DomainCorrectness / ScheduleService), writes through
 * ScheduleService. Every exit path of every method returns an APIResponse, and
 * every body is wrapped in try/catch so a ServiceException from any layer
 * becomes a failure envelope rather than an unhandled AuraHandledException.
 *
 * Input format (hop 1.0, MANDATORY): one separated primitive parameter per value
 * the LWC sends — never a wrapper, never a Map. Parameter names match the keys
 * the LWC puts in its `{ ... }` payload character for character, because
 * @salesforce/apex binds by name.
 *
 * Date & Time crosses as a String in 'yyyy-MM-dd HH:mm:ss' local wall-clock
 * form, not as a Datetime. StartDateTime__c is <type>DateTime</type>, so the
 * conversion happens once at this edge (`apex-date-datetime-assignment`
 * pitfall: keep the UI-facing type at the boundary, convert on the edge, and
 * never guard a parse with a bare newInstance(null, ...)).
 */
public with sharing class ScheduleController {

    // ── Read ──────────────────────────────────────────────────────────────────

    /**
     * Every appointment the clinic holds, in the order they are stored.
     * cacheable = true -> the LWC consumes it with @wire and re-reads it with
     * refreshApex after every mutation.
     */
    @AuraEnabled(cacheable=true)
    public static APIResponse getSchedules() {
        try {
            List<Schedule__c> rows = ScheduleService.loadSchedules();
            return new APIResponse(true, 'Appointments loaded successfully',
                                   ScheduleDto.fromRows(rows));
        } catch (Exception ex) {
            return new APIResponse(false, 'Failed to retrieve schedules: ' + ex.getMessage());
        }
    }

    // ── Create ────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static APIResponse createSchedule(String startDateTime,
                                             String firstName,
                                             String lastName,
                                             String phoneNumber,
                                             String phoneNumber2,
                                             String appointmentType,
                                             Integer durationMinutes,
                                             Decimal fees,
                                             String location,
                                             String notes) {
        try {
            ScheduleInputDto input = buildInput(startDateTime, firstName, lastName,
                                                phoneNumber, phoneNumber2, appointmentType,
                                                durationMinutes, fees, location, notes);

            // Date & time must be in the future — a create rule only. An edit
            // keeps its original moment, which may already be in the past.
            DomainCorrectness.requireFutureDateTime(input.startDateTime, 'Date & Time');

            ScheduleBookingDto result = ScheduleService.createSchedule(input);
            return envelope(result, 'Appointment created successfully');
        } catch (Exception ex) {
            return new APIResponse(false, 'Failed to create schedule: ' + ex.getMessage());
        }
    }

    // ── Update ────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static APIResponse updateSchedule(String scheduleId,
                                             String startDateTime,
                                             String firstName,
                                             String lastName,
                                             String phoneNumber,
                                             String phoneNumber2,
                                             String appointmentType,
                                             Integer durationMinutes,
                                             Decimal fees,
                                             String location,
                                             String notes) {
        try {
            if (String.isBlank(scheduleId)) {
                return new APIResponse(false, 'scheduleId is required');
            }

            // Phase 1 guard: the appointment must exist. The record it returns is
            // what crosses to the Service — never the id again (hop 2.1).
            Schedule__c existing = DomainCorrectness.requireScheduleExists(scheduleId);

            ScheduleInputDto input = buildInput(startDateTime, firstName, lastName,
                                                phoneNumber, phoneNumber2, appointmentType,
                                                durationMinutes, fees, location, notes);

            ScheduleBookingDto result = ScheduleService.updateSchedule(existing, input);
            return envelope(result, 'Appointment updated successfully');
        } catch (Exception ex) {
            return new APIResponse(false, 'Failed to update schedule: ' + ex.getMessage());
        }
    }

    // ── Delete ────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static APIResponse deleteSchedule(String scheduleId) {
        try {
            if (String.isBlank(scheduleId)) {
                return new APIResponse(false, 'scheduleId is required');
            }

            Schedule__c existing = DomainCorrectness.requireScheduleExists(scheduleId);
            ScheduleService.deleteSchedule(existing);

            return new APIResponse(true, 'Appointment deleted successfully');
        } catch (Exception ex) {
            return new APIResponse(false, 'Failed to delete schedule: ' + ex.getMessage());
        }
    }

    // ── Internals ─────────────────────────────────────────────────────────────

    /**
     * Turns the booking outcome into the envelope the LWC branches on.
     *
     * A refused booking is NOT an exception — it is a legitimate answer that
     * carries the offer with it, so it travels as APIResponse(false, ...) with
     * `availabilityRejected` in the data slot. That flag is what lets the LWC
     * tell "the time is taken, here are alternatives" apart from a genuine
     * failure, without matching on message text.
     */
    private static APIResponse envelope(ScheduleBookingDto result, String successMessage) {
        if (result.booked) {
            return new APIResponse(true, successMessage, result.schedule);
        }

        String message = result.availableSlots.isEmpty()
            ? 'No available slots for the requested date'
            : 'Requested time is not available. Here are available slots';

        Map<String, Object> data = new Map<String, Object>{
            'availabilityRejected' => true,
            'availableSlots' => result.availableSlots
        };
        return new APIResponse(false, message, data);
    }

    /**
     * Phase 1 input correctness for the ten appointment values, then the
     * assembled Service input. Every guard throws ServiceException, which the
     * caller's catch turns into APIResponse(false, message).
     */
    private static ScheduleInputDto buildInput(String startDateTime,
                                               String firstName,
                                               String lastName,
                                               String phoneNumber,
                                               String phoneNumber2,
                                               String appointmentType,
                                               Integer durationMinutes,
                                               Decimal fees,
                                               String location,
                                               String notes) {
        ScheduleInputDto input = new ScheduleInputDto();

        input.startDateTime = parseMoment(startDateTime, 'Date & Time');

        DomainCorrectness.requireText(firstName, 'First Name', 50);
        DomainCorrectness.requireText(lastName, 'Last Name', 50);
        DomainCorrectness.requirePhone(phoneNumber, 'Phone Number');
        DomainCorrectness.requireOptionalPhone(phoneNumber2, 'Phone Number 2');
        DomainCorrectness.requireText(appointmentType, 'Type', 255);
        DomainCorrectness.requirePositiveDuration(durationMinutes, 'Duration');
        DomainCorrectness.requireNonNegativeFees(fees, 'Fees');
        DomainCorrectness.requireText(location, 'Location', 500);

        input.firstName = firstName.trim();
        input.lastName = lastName.trim();
        input.phoneNumber = phoneNumber.trim();
        input.phoneNumber2 = String.isBlank(phoneNumber2) ? null : phoneNumber2.trim();
        input.appointmentType = appointmentType.trim();
        input.durationMinutes = durationMinutes;
        input.fees = fees;
        input.location = location.trim();
        input.notes = String.isBlank(notes) ? null : notes.trim();

        return input;
    }

    /**
     * 'yyyy-MM-dd HH:mm:ss' local wall clock -> Datetime.
     *
     * Datetime.valueOf reads the string in the running user's time zone, which
     * is the clinic's own clock — the same basis every later comparison uses
     * (.date() / .time() / Datetime.newInstance are all local), so a value
     * round-trips unchanged.
     */
    private static Datetime parseMoment(String raw, String label) {
        if (String.isBlank(raw)) {
            throw new ServiceException(label + ' is required');
        }
        try {
            return Datetime.valueOf(raw.trim());
        } catch (Exception ex) {
            throw new ServiceException(label + ' is not a valid date and time');
        }
    }
}
