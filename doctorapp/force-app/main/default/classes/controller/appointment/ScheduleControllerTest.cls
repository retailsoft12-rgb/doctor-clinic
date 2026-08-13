@isTest
private class ScheduleControllerTest {
    /** Tomorrow at a fixed hour, formatted the way the LWC sends it. */
    private static String futureAt(Integer hour, Integer minute) {
        Datetime moment = Datetime.newInstance(
            Date.today().addDays(1),
            Time.newInstance(hour, minute, 0, 0)
        );
        return moment.format('yyyy-MM-dd') + 'T' + moment.format('HH:mm');
    }

    private static APIResponse book(String startDateTime, String duration) {
        return ScheduleController.createSchedule(
            startDateTime,
            'Rana',
            'Haddad',
            '96170123456',
            null,
            'Consultation',
            duration,
            '50',
            'Beirut Clinic, Room 3',
            null
        );
    }

    @isTest
    static void bookingAnAppointmentCreatesItAndItAppearsInTheList() {
        Test.startTest();
        APIResponse created = book(futureAt(10, 0), '30');
        Test.stopTest();

        System.assertEquals(true, created.success, 'The booking should have been accepted');
        System.assertEquals(APIResponse.CODE_OK, created.code, 'Code should be OK');

        APIResponse listed = ScheduleController.getSchedules();
        System.assertEquals(true, listed.success, 'The list should load');
        List<Schedule__c> rows = (List<Schedule__c>) listed.data;
        System.assertEquals(1, rows.size(), 'The new appointment should be in the list');
        System.assertEquals('Rana', rows[0].FirstName__c, 'The patient should be recorded');
        System.assertEquals(
            rows[0].StartDateTime__c.addMinutes(30),
            rows[0].EndDateTime__c,
            'The end moment is derived from the start and the duration'
        );
    }

    @isTest
    static void aWholeHourDurationIsRecordedOneMinuteShorter() {
        Test.startTest();
        APIResponse created = book(futureAt(9, 0), '60');
        Test.stopTest();

        System.assertEquals(true, created.success, 'A one-hour booking should be accepted');
        Schedule__c stored = [SELECT DurationMinutes__c FROM Schedule__c LIMIT 1];
        System.assertEquals(
            59,
            stored.DurationMinutes__c,
            'A whole number of hours is stored one minute shorter so appointments never touch'
        );
    }

    @isTest
    static void everyFailingFieldIsNamedAndNothingIsBooked() {
        Test.startTest();
        APIResponse rejected = ScheduleController.createSchedule(
            '', // Date & Time missing
            '', // First Name missing
            'Haddad',
            'not-a-phone', // bad shape
            null,
            '', // Type missing
            '0', // Duration not greater than zero
            '-5', // Fees below zero
            '', // Location missing
            null
        );
        Test.stopTest();

        System.assertEquals(false, rejected.success, 'The booking should be rejected');
        System.assertEquals(APIResponse.CODE_VALIDATION, rejected.code, 'Code should be VALIDATION');
        System.assertEquals('Validation errors', rejected.message, 'The spec fixes this prefix');
        System.assert(
            rejected.errors.size() >= 6,
            'Every field at fault is named, not just the first: ' + rejected.errors
        );
        System.assertEquals(0, [SELECT COUNT() FROM Schedule__c], 'Nothing may be saved');
    }

    @isTest
    static void aPhoneThatDoesNotMatchTheShapeIsRejected() {
        APIResponse rejected = ScheduleController.createSchedule(
            futureAt(11, 0),
            'Rana',
            'Haddad',
            '12345', // only five digits
            null,
            'Consultation',
            '30',
            '50',
            'Beirut Clinic',
            null
        );

        System.assertEquals(false, rejected.success, 'A short number should be rejected');
        System.assert(
            String.join(rejected.errors, ' ').contains('Invalid phone number format'),
            'The spec fixes this message: ' + rejected.errors
        );
    }

    @isTest
    static void anOverlappingBookingIsRefusedAndFreeTimesAreOffered() {
        System.assertEquals(true, book(futureAt(10, 0), '30').success, 'Setup booking failed');

        Test.startTest();
        // 10:15 starts inside the 10:00–10:30 appointment.
        APIResponse clashed = book(futureAt(10, 15), '30');
        Test.stopTest();

        System.assertEquals(false, clashed.success, 'An overlap must not be booked');
        System.assertEquals(APIResponse.CODE_SLOTS, clashed.code, 'Code should be SLOTS');
        System.assertEquals(
            'Requested time is not available. Here are available slots',
            clashed.message,
            'The spec fixes this message'
        );
        List<ScheduleSlotFinder.TimeSlot> slots = (List<ScheduleSlotFinder.TimeSlot>) clashed.data;
        System.assert(!slots.isEmpty(), 'Free times should be offered');
        System.assertEquals(1, [SELECT COUNT() FROM Schedule__c], 'The day is left exactly as it was');
    }

    @isTest
    static void aFullDayOffersNoFreeTimes() {
        // 08:00 for 14 hours — stored as 839 minutes, so it ends at 21:59 and
        // leaves only a one-minute gap before the clinic closes at 22:00.
        System.assertEquals(true, book(futureAt(8, 0), '840').success, 'Setup booking failed');

        Test.startTest();
        APIResponse full = book(futureAt(9, 0), '30');
        Test.stopTest();

        System.assertEquals(false, full.success, 'Nothing may be booked on a full day');
        System.assertEquals(APIResponse.CODE_NO_SLOTS, full.code, 'Code should be NO_SLOTS');
        System.assertEquals(
            'No available slots for the requested date',
            full.message,
            'The spec fixes this message'
        );
    }

    @isTest
    static void aMomentInThePastIsNotAccepted() {
        Datetime past = Datetime.now().addDays(-1);
        APIResponse rejected = book(past.format('yyyy-MM-dd') + 'T' + past.format('HH:mm'), '30');

        System.assertEquals(false, rejected.success, 'A past moment must be rejected');
        System.assert(
            String.join(rejected.errors, ' ').contains('must be in the future'),
            'The future rule should be named: ' + rejected.errors
        );
    }

    @isTest
    static void aFreeVisitIsBookable() {
        APIResponse created = ScheduleController.createSchedule(
            futureAt(14, 0),
            'Rana',
            'Haddad',
            '70123456',
            '+961 70123457',
            'Check-up',
            '20',
            '0', // free of charge, but still recorded
            'Tripoli Clinic',
            'Patient asked for a morning slot next time'
        );

        System.assertEquals(true, created.success, 'A visit at no charge should still be bookable');
        Schedule__c stored = [SELECT Fees__c, PhoneNumber2__c, Notes__c FROM Schedule__c LIMIT 1];
        System.assertEquals(0, stored.Fees__c, 'Zero fees are recorded, not treated as missing');
        System.assertNotEquals(null, stored.PhoneNumber2__c, 'A valid second number is kept');
    }

    @isTest
    static void aBlankSecondNumberIsStoredAsNoNumberAtAll() {
        System.assertEquals(true, book(futureAt(15, 0), '30').success, 'Setup booking failed');

        Schedule__c stored = [SELECT PhoneNumber2__c FROM Schedule__c LIMIT 1];
        System.assertEquals(
            null,
            stored.PhoneNumber2__c,
            'Empty means no second number at all, not an empty one'
        );
    }

    @isTest
    static void deletingAnAppointmentRemovesItForGood() {
        System.assertEquals(true, book(futureAt(16, 0), '30').success, 'Setup booking failed');
        Schedule__c stored = [SELECT Id FROM Schedule__c LIMIT 1];

        Test.startTest();
        APIResponse deleted = ScheduleController.deleteSchedule(stored.Id);
        Test.stopTest();

        System.assertEquals(true, deleted.success, 'The delete should succeed');
        System.assertEquals(0, [SELECT COUNT() FROM Schedule__c], 'No copy is kept');
    }

    @isTest
    static void deletingAnAppointmentThatIsAlreadyGoneIsNotAnError() {
        System.assertEquals(true, book(futureAt(17, 0), '30').success, 'Setup booking failed');
        Schedule__c stored = [SELECT Id FROM Schedule__c LIMIT 1];
        Id goneId = stored.Id;
        delete stored;

        Test.startTest();
        APIResponse deleted = ScheduleController.deleteSchedule(goneId);
        Test.stopTest();

        System.assertEquals(
            true,
            deleted.success,
            'An appointment already gone changes nothing else and is not reported as a failure'
        );
    }

    @isTest
    static void deletingWithoutChoosingAnAppointmentIsRefused() {
        APIResponse refused = ScheduleController.deleteSchedule('');
        System.assertEquals(false, refused.success, 'An appointment must be chosen first');
        System.assertEquals('scheduleId is required', refused.message, 'The message format is fixed');
    }

    @isTest
    static void anEmptyClinicLoadsAsAnEmptyListRatherThanAnError() {
        APIResponse listed = ScheduleController.getSchedules();

        System.assertEquals(true, listed.success, 'No appointments is a normal state, not an error');
        System.assertEquals(
            0,
            ((List<Schedule__c>) listed.data).size(),
            'The empty clinic returns an empty list'
        );
    }
}
