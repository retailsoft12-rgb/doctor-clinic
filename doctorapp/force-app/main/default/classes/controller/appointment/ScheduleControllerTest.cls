/**
 * ScheduleControllerTest — the controller ships with its test class.
 *
 * Covers the three @AuraEnabled methods and, through createSchedule, the
 * predecessor-successor-overlap algorithm: the free case, the busy case with an
 * offer, the full-day case with no offer, and the hour-duration normalisation.
 *
 * All scenarios run on a day 30 days out, because "Date & Time must be in the
 * future" is an input rule — a fixed historical date would fail validation before
 * the algorithm was ever reached.
 */
@IsTest
private class ScheduleControllerTest {

    private static Date futureDay() {
        return Date.today().addDays(30);
    }

    private static String futureDayString() {
        Date day = futureDay();
        return String.valueOf(day.year())
            + '-' + leftPad(day.month())
            + '-' + leftPad(day.day());
    }

    private static String leftPad(Integer value) {
        return value < 10 ? '0' + String.valueOf(value) : String.valueOf(value);
    }

    /** Inserts a stored appointment directly, bypassing the booking rules. */
    private static Schedule__c storedAppointment(Integer hour, Integer minute, Integer durationMinutes) {
        Datetime startAt = Datetime.newInstance(futureDay(), Time.newInstance(hour, minute, 0, 0));
        Schedule__c row = new Schedule__c(
            StartDateTime__c = startAt,
            EndDateTime__c = startAt.addMinutes(durationMinutes),
            FirstName__c = 'Stored',
            LastName__c = 'Patient',
            PhoneNumber__c = '03123456',
            Type__c = 'Checkup',
            DurationMinutes__c = durationMinutes,
            Fees__c = 50,
            Location__c = 'Room 1'
        );
        insert row;
        return row;
    }

    /** A well-formed booking request; individual tests override single values. */
    private static APIResponse book(String startTime, String durationMinutes) {
        return ScheduleController.createSchedule(
            futureDayString(), startTime,
            'Nadia', 'Khoury',
            '+961 3123456', null,
            'Consultation',
            durationMinutes, '75.50',
            'Clinic room 2', 'First visit'
        );
    }

    private static ScheduleDto.BookingResult resultOf(APIResponse response) {
        return (ScheduleDto.BookingResult) response.data;
    }

    // ── getSchedules ─────────────────────────────────────────────────────────

    @IsTest
    static void getSchedulesReturnsEmptyListWhenNothingIsStored() {
        Test.startTest();
        APIResponse response = ScheduleController.getSchedules();
        Test.stopTest();

        Assert.isTrue(response.success, 'An empty clinic is not a failure');
        List<ScheduleDto.ScheduleView> views = (List<ScheduleDto.ScheduleView>) response.data;
        Assert.areEqual(0, views.size(), 'No appointments stored');
    }

    @IsTest
    static void getSchedulesProjectsTheListedFieldsAndHidesTheRest() {
        Schedule__c stored = storedAppointment(10, 0, 30);
        stored.PhoneNumber2__c = '03999888';
        stored.Notes__c = 'Confidential note';
        update stored;

        Test.startTest();
        APIResponse response = ScheduleController.getSchedules();
        Test.stopTest();

        Assert.isTrue(response.success, 'Load succeeded');
        List<ScheduleDto.ScheduleView> views = (List<ScheduleDto.ScheduleView>) response.data;
        Assert.areEqual(1, views.size(), 'One appointment stored');

        ScheduleDto.ScheduleView view = views[0];
        Assert.areEqual('Stored', view.firstName, 'First name is projected');
        Assert.areEqual('Patient', view.lastName, 'Last name is projected');
        Assert.areEqual('03123456', view.phoneNumber, 'Only the first phone is projected');
        Assert.areEqual('Checkup', view.appointmentType, 'Type is projected');
        Assert.areEqual(30, view.durationMinutes.intValue(), 'Duration is projected');
        Assert.areEqual('10:00', view.startTimeLabel, '24-hour clock');
        Assert.isNotNull(view.startDateLabel, 'Date label is formatted server-side');
    }

    // ── createSchedule — validation ──────────────────────────────────────────

    @IsTest
    static void createScheduleRejectsEveryMissingRequiredFieldAtOnce() {
        Test.startTest();
        APIResponse response = ScheduleController.createSchedule(
            null, null, null, null, null, null, null, null, null, null, null);
        Test.stopTest();

        Assert.isFalse(response.success, 'A blank form cannot be booked');
        Assert.areEqual('Validation errors', response.message, 'Panel heading');

        ScheduleDto.BookingResult result = resultOf(response);
        Assert.areEqual('INVALID', result.status, 'Failed on input, never reached the algorithm');

        Set<String> failedFields = new Set<String>();
        for (ScheduleDto.FieldError fieldError : result.fieldErrors) {
            failedFields.add(fieldError.field);
        }
        Assert.areEqual(8, failedFields.size(), 'All eight required fields are reported together');
        Assert.isTrue(failedFields.contains('Date & Time'), 'Date & Time is required');
        Assert.isTrue(failedFields.contains('First Name'), 'First Name is required');
        Assert.isTrue(failedFields.contains('Last Name'), 'Last Name is required');
        Assert.isTrue(failedFields.contains('Phone Number'), 'Phone Number is required');
        Assert.isTrue(failedFields.contains('Type'), 'Type is required');
        Assert.isTrue(failedFields.contains('Duration (min)'), 'Duration is required');
        Assert.isTrue(failedFields.contains('Fees'), 'Fees is required');
        Assert.isTrue(failedFields.contains('Location'), 'Location is required');
    }

    @IsTest
    static void createScheduleRejectsAPastDateTime() {
        Date pastDay = Date.today().addDays(-1);
        String pastDayString = String.valueOf(pastDay.year())
            + '-' + leftPad(pastDay.month())
            + '-' + leftPad(pastDay.day());

        Test.startTest();
        APIResponse response = ScheduleController.createSchedule(
            pastDayString, '10:00', 'Nadia', 'Khoury', '03123456', null,
            'Consultation', '30', '0', 'Room 1', null);
        Test.stopTest();

        Assert.isFalse(response.success, 'The past cannot be booked');
        ScheduleDto.BookingResult result = resultOf(response);
        Assert.areEqual('INVALID', result.status, 'Input rule, not a collision');
        Assert.areEqual(1, result.fieldErrors.size(), 'Only Date & Time is wrong');
        Assert.areEqual('Date & Time must be in the future',
            result.fieldErrors[0].message, 'The reason is stated');
    }

    @IsTest
    static void createScheduleRejectsMalformedPhoneNumbersAndFractionalDurations() {
        Test.startTest();
        APIResponse response = ScheduleController.createSchedule(
            futureDayString(), '10:00', 'Nadia', 'Khoury',
            '12345', '00 1 555 0100',
            'Consultation', '1.5', '10.555', 'Room 1', null);
        Test.stopTest();

        Assert.isFalse(response.success, 'Four fields are malformed');
        ScheduleDto.BookingResult result = resultOf(response);

        Set<String> failedFields = new Set<String>();
        for (ScheduleDto.FieldError fieldError : result.fieldErrors) {
            failedFields.add(fieldError.field);
        }
        Assert.isTrue(failedFields.contains('Phone Number'), 'Five digits is below the 6-digit floor');
        Assert.isTrue(failedFields.contains('Phone Number 2'), 'A non-Lebanese format is rejected');
        Assert.isTrue(failedFields.contains('Duration (min)'), 'Duration must be whole minutes');
        Assert.isTrue(failedFields.contains('Fees'), 'Fees allows at most two decimals');
    }

    @IsTest
    static void createScheduleAcceptsFreeOfChargeAppointments() {
        Test.startTest();
        APIResponse response = ScheduleController.createSchedule(
            futureDayString(), '09:00', 'Nadia', 'Khoury', '961 3123456', null,
            'Follow-up', '30', '0', 'Room 1', null);
        Test.stopTest();

        Assert.isTrue(response.success, 'Fees = 0 is allowed');
        Assert.areEqual('BOOKED', resultOf(response).status, 'Booked on an empty day');
    }

    // ── createSchedule — the algorithm ───────────────────────────────────────

    @IsTest
    static void createScheduleBooksOnAnEmptyDay() {
        Test.startTest();
        APIResponse response = book('10:00', '30');
        Test.stopTest();

        Assert.isTrue(response.success, 'An empty day always books');
        ScheduleDto.BookingResult result = resultOf(response);
        Assert.areEqual('BOOKED', result.status, 'Case 1 — no predecessor, no successor');
        Assert.isNotNull(result.scheduleId, 'The new appointment has an id');

        List<Schedule__c> stored = [SELECT Id, StartDateTime__c, EndDateTime__c FROM Schedule__c];
        Assert.areEqual(1, stored.size(), 'Exactly one write');
        Assert.areEqual(
            stored[0].StartDateTime__c.addMinutes(30), stored[0].EndDateTime__c,
            'End is derived from start + duration');
    }

    @IsTest
    static void createScheduleShortensAWholeHourByOneMinute() {
        Test.startTest();
        APIResponse response = book('12:00', '60');
        Test.stopTest();

        Assert.isTrue(response.success, 'A one-hour appointment books on an empty day');

        Schedule__c stored = [
            SELECT StartDateTime__c, EndDateTime__c, DurationMinutes__c FROM Schedule__c LIMIT 1
        ];
        Assert.areEqual(59, stored.DurationMinutes__c.intValue(),
            '60 minutes is shortened to 59 so the next hour-aligned slot does not touch it');
        Assert.areEqual(stored.StartDateTime__c.addMinutes(59), stored.EndDateTime__c,
            'End matches the effective duration');
    }

    @IsTest
    static void createScheduleBooksBetweenTwoNeighboursWithoutTouchingThem() {
        storedAppointment(10, 0, 30);   // 10:00 – 10:30
        storedAppointment(15, 0, 45);   // 15:00 – 15:45

        Test.startTest();
        APIResponse response = book('11:00', '30');   // 11:00 – 11:30
        Test.stopTest();

        Assert.isTrue(response.success, 'The gap is wide enough');
        Assert.areEqual('BOOKED', resultOf(response).status, 'Case 4 — inserted between two');
        Assert.areEqual(3, [SELECT COUNT() FROM Schedule__c], 'The two neighbours are untouched');
    }

    @IsTest
    static void createScheduleRefusesAnOverlapAndOffersTheDaysFreeTimes() {
        storedAppointment(10, 0, 30);   // 10:00 – 10:30

        Test.startTest();
        APIResponse response = book('09:45', '30');   // 09:45 – 10:15 hits the successor
        Test.stopTest();

        Assert.isFalse(response.success, 'An overlap is refused');
        Assert.areEqual('Requested time is not available. Here are available slots',
            response.message, 'The panel sentence');

        ScheduleDto.BookingResult result = resultOf(response);
        Assert.areEqual('BUSY', result.status, 'Busy, with an offer');
        Assert.areEqual(1, [SELECT COUNT() FROM Schedule__c], 'Zero writes on a refused booking');

        Set<String> offered = new Set<String>();
        for (ScheduleDto.TimeSlot slot : result.slots) {
            offered.add(slot.startLabel + '-' + slot.endLabel);
        }
        Assert.areEqual(2, offered.size(), 'One opening slot and one closing slot');
        Assert.isTrue(offered.contains('08:00-08:30'), 'G1 — from opening to the first appointment');
        Assert.isTrue(offered.contains('10:30-11:00'), 'G3 — from the last appointment to closing');
    }

    @IsTest
    static void createScheduleRejectsAGapThatIsTooNarrowForTheRequest() {
        storedAppointment(10, 0, 30);   // 10:00 – 10:30
        storedAppointment(11, 0, 30);   // 11:00 – 11:30

        Test.startTest();
        APIResponse response = book('10:15', '45');   // hits the predecessor
        Test.stopTest();

        Assert.isFalse(response.success, 'The request overlaps 10:00 – 10:30');
        ScheduleDto.BookingResult result = resultOf(response);
        Assert.areEqual('BUSY', result.status, 'Busy, with an offer');

        Set<String> offered = new Set<String>();
        for (ScheduleDto.TimeSlot slot : result.slots) {
            offered.add(slot.startLabel + '-' + slot.endLabel);
        }
        Assert.areEqual(2, offered.size(), 'The 30-minute gap cannot hold 45 minutes');
        Assert.isTrue(offered.contains('08:00-08:45'), 'G1 fits');
        Assert.isTrue(offered.contains('11:30-12:15'), 'G3 fits');
        Assert.isFalse(offered.contains('10:30-11:15'), 'G2 is rejected — the gap is only 30 minutes');
    }

    @IsTest
    static void createScheduleReportsNoAvailableSlotsWhenTheDayCannotHoldTheDuration() {
        storedAppointment(12, 0, 60);   // 12:00 – 13:00

        Test.startTest();
        // 10 hours (effective 599 minutes) starting inside the stored appointment.
        APIResponse response = book('12:30', '600');
        Test.stopTest();

        Assert.isFalse(response.success, 'The requested time is taken');
        Assert.areEqual('No available slots for the requested date',
            response.message, 'Flow 8 sentence');

        ScheduleDto.BookingResult result = resultOf(response);
        Assert.areEqual('NO_SLOTS', result.status, 'The day is full relative to this duration');
        Assert.areEqual(0, result.slots.size(), 'No times are listed');
        Assert.areEqual(1, [SELECT COUNT() FROM Schedule__c], 'Nothing was written');
    }

    @IsTest
    static void createScheduleRefusesAnIdenticalStartTime() {
        storedAppointment(10, 0, 30);

        Test.startTest();
        APIResponse response = book('10:00', '30');
        Test.stopTest();

        Assert.isFalse(response.success,
            'The same start makes one appointment both predecessor and successor');
        Assert.areEqual('BUSY', resultOf(response).status, 'Busy, with an offer');
    }

    @IsTest
    static void createScheduleTreatsTouchingAsOccupied() {
        storedAppointment(10, 0, 30);   // 10:00 – 10:30

        Test.startTest();
        APIResponse response = book('10:30', '30');   // starts exactly when the other ends
        Test.stopTest();

        Assert.isFalse(response.success,
            'Closed intervals — an appointment may not start at the instant another ends');
        Assert.areEqual('BUSY', resultOf(response).status, 'Busy, with an offer');
    }

    // ── deleteSchedule ───────────────────────────────────────────────────────

    @IsTest
    static void deleteSchedulePermanentlyRemovesTheAppointment() {
        Schedule__c stored = storedAppointment(10, 0, 30);

        Test.startTest();
        APIResponse response = ScheduleController.deleteSchedule(stored.Id);
        Test.stopTest();

        Assert.isTrue(response.success, 'The delete succeeded');
        Assert.areEqual(0, [SELECT COUNT() FROM Schedule__c], 'Permanently removed, not flagged');
    }

    @IsTest
    static void deleteScheduleDoesNotFailWhenTheAppointmentIsAlreadyGone() {
        Schedule__c stored = storedAppointment(10, 0, 30);
        Id goneId = stored.Id;
        delete stored;

        Test.startTest();
        APIResponse response = ScheduleController.deleteSchedule(goneId);
        Test.stopTest();

        Assert.isTrue(response.success,
            'A missing appointment reloads the list unchanged; it is not an error');
    }

    @IsTest
    static void deleteScheduleRejectsBlankAndMalformedIds() {
        Test.startTest();
        APIResponse blankResponse = ScheduleController.deleteSchedule('');
        APIResponse malformedResponse = ScheduleController.deleteSchedule('not-an-id');
        Test.stopTest();

        Assert.isFalse(blankResponse.success, 'An appointment must be selected');
        Assert.areEqual('scheduleId is required', blankResponse.message, 'Fixed message format');
        Assert.isFalse(malformedResponse.success, 'A malformed id is rejected before any query');
    }

    @IsTest
    static void deletingOneAppointmentLeavesTheOthersAlone() {
        Schedule__c first = storedAppointment(10, 0, 30);
        storedAppointment(15, 0, 45);

        Test.startTest();
        ScheduleController.deleteSchedule(first.Id);
        Test.stopTest();

        Assert.areEqual(1, [SELECT COUNT() FROM Schedule__c], 'Only the selected one is removed');
    }
}
