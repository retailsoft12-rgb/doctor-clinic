/**
 * ScheduleControllerTest — the test class every controller in this project ships
 * with (sequence-be phase 3, "After this phase").
 *
 * The scenario cases mirror `guide/algorithm/booking-algorithm.md` section 10
 * one-for-one, so a change to the algorithm shows up here as a named failure
 * rather than as a silent behaviour drift. The worked cases are written on
 * 2026-04-01 in the guide; here they run on a fixed future day, because
 * createSchedule enforces "Date and time must be in the future".
 */
@isTest
private class ScheduleControllerTest {

    private static final String FORMAT = 'yyyy-MM-dd HH:mm:ss';

    // ── Helpers ───────────────────────────────────────────────────────────────

    /** A stable future calendar day, so the "must be in the future" rule passes. */
    private static Date bookingDay() {
        return Date.today().addDays(30);
    }

    private static Datetime at(Integer hour, Integer minute) {
        return Datetime.newInstance(bookingDay(), Time.newInstance(hour, minute, 0, 0));
    }

    private static String moment(Integer hour, Integer minute) {
        return at(hour, minute).format(FORMAT);
    }

    /** Stores an appointment directly, bypassing the booking decision. */
    private static Schedule__c store(String name, Integer hour, Integer minute, Integer duration) {
        Integer effective = ScheduleService.effectiveDuration(duration);
        Schedule__c row = new Schedule__c(
            FirstName__c = name,
            LastName__c = 'Patient',
            PhoneNumber__c = '71123456',
            Type__c = 'Consultation',
            Location__c = 'Room 1',
            Fees__c = 50,
            StartDateTime__c = at(hour, minute),
            DurationMinutes__c = duration,
            EndDateTime__c = at(hour, minute).addMinutes(effective)
        );
        insert row;
        return row;
    }

    private static APIResponse book(String firstName, Integer hour, Integer minute, Integer duration) {
        return ScheduleController.createSchedule(
            moment(hour, minute), firstName, 'Patient', '71123456', null,
            'Consultation', duration, 50, 'Room 1', null);
    }

    /**
     * The offer travels in the data slot as
     * { availabilityRejected: true, availableSlots: [...] }. The cast is to the
     * concrete List<ScheduleSlotDto> — Apex list types are invariant, so casting
     * it to List<Object> would fail at runtime.
     */
    private static List<ScheduleSlotDto> slotsOf(APIResponse response) {
        Map<String, Object> data = (Map<String, Object>) response.data;
        return (List<ScheduleSlotDto>) data.get('availableSlots');
    }

    // ── Unit rules (booking-algorithm section 10, UNIT RULES) ─────────────────

    @isTest
    static void effectiveDurationShortensWholeHoursOnly() {
        Test.startTest();
        System.assertEquals(30, ScheduleService.effectiveDuration(30), '30 stays 30');
        System.assertEquals(45, ScheduleService.effectiveDuration(45), '45 stays 45');
        System.assertEquals(90, ScheduleService.effectiveDuration(90), '90 stays 90');
        System.assertEquals(59, ScheduleService.effectiveDuration(60), '60 normalises to 59');
        System.assertEquals(119, ScheduleService.effectiveDuration(120), '120 normalises to 119');
        Test.stopTest();
    }

    @isTest
    static void collisionPredicateMatchesTheTruthTable() {
        Test.startTest();
        System.assertEquals(true,
            DomainCompleteValidator.collides(at(10, 0), at(10, 30), at(10, 15), at(10, 45)),
            'Overlapping intervals collide');
        System.assertEquals(false,
            DomainCompleteValidator.collides(at(10, 0), at(10, 30), at(11, 0), at(12, 0)),
            'Disjoint intervals do not collide');
        System.assertEquals(true,
            DomainCompleteValidator.collides(at(10, 0), at(10, 30), at(10, 30), at(11, 0)),
            'Touching is occupied — closed intervals');
        Test.stopTest();
    }

    @isTest
    static void endTimeIsStartPlusEffectiveDuration() {
        Test.startTest();
        APIResponse response = book('John', 10, 0, 45);
        Test.stopTest();

        System.assertEquals(true, response.success, response.message);
        ScheduleDto created = (ScheduleDto) response.data;
        System.assertEquals(at(10, 45), created.endDateTime, '10:00 + 45 = 10:45');
    }

    // ── Scenario cases (booking-algorithm section 10) ─────────────────────────

    @isTest
    static void case1EmptyDayAlwaysBooks() {
        Test.startTest();
        APIResponse response = book('John', 10, 0, 30);
        Test.stopTest();

        System.assertEquals(true, response.success, response.message);
        System.assertEquals(1, [SELECT COUNT() FROM Schedule__c], 'One appointment written');
    }

    @isTest
    static void case2SuccessorOnlyFreeBooks() {
        store('John', 10, 0, 30);

        Test.startTest();
        APIResponse response = book('Jane', 9, 0, 30);
        Test.stopTest();

        System.assertEquals(true, response.success, response.message);
        System.assertEquals(2, [SELECT COUNT() FROM Schedule__c], 'Both appointments stored');
    }

    @isTest
    static void case3SuccessorOnlyCollisionOffersTwoSlots() {
        store('John', 10, 0, 30);

        Test.startTest();
        APIResponse response = book('Bob', 9, 45, 30);
        Test.stopTest();

        System.assertEquals(false, response.success, 'Overlap refuses the booking');
        System.assertEquals('Requested time is not available. Here are available slots', response.message);
        System.assertEquals(2, slotsOf(response).size(), 'G1 [08:00,08:30] and G3 [10:30,11:00]');
        System.assertEquals(1, [SELECT COUNT() FROM Schedule__c], 'I2 — zero writes on refusal');
    }

    @isTest
    static void case4PredecessorOnlyFreeBooks() {
        store('John', 10, 0, 30);

        Test.startTest();
        APIResponse response = book('Alice', 15, 0, 45);
        Test.stopTest();

        System.assertEquals(true, response.success, response.message);
    }

    @isTest
    static void case5PredecessorOnlyCollisionOffersTwoSlots() {
        store('Alice', 15, 0, 45);

        Test.startTest();
        APIResponse response = book('Charlie', 15, 30, 45);
        Test.stopTest();

        System.assertEquals(false, response.success, 'Overlap refuses the booking');
        System.assertEquals(2, slotsOf(response).size(), 'G1 [08:00,08:45] and G3 [15:45,16:30]');
    }

    @isTest
    static void case6BothNeighboursFreeInserts() {
        store('John', 10, 0, 30);
        store('Alice', 15, 0, 45);

        Test.startTest();
        APIResponse response = book('Diana', 11, 0, 30);
        Test.stopTest();

        System.assertEquals(true, response.success, response.message);
        System.assertEquals(3, [SELECT COUNT() FROM Schedule__c], 'Inserted between two');
    }

    @isTest
    static void case7CollidesWithPredecessorRejectsTooNarrowGap() {
        store('John', 10, 0, 30);
        store('Diana', 11, 0, 30);

        Test.startTest();
        APIResponse response = book('Frank', 10, 15, 45);
        Test.stopTest();

        System.assertEquals(false, response.success, 'Predecessor collision');
        System.assertEquals(2, slotsOf(response).size(),
            'G2 rejected — the 30 minute gap is narrower than the 45 minute request');
    }

    @isTest
    static void case8CollidesWithSuccessorOffersThreeSlots() {
        store('John', 10, 0, 30);
        store('Diana', 11, 0, 30);

        Test.startTest();
        APIResponse response = book('Grace', 10, 45, 30);
        Test.stopTest();

        System.assertEquals(false, response.success, 'Successor collision');
        System.assertEquals(3, slotsOf(response).size(),
            'G1, G2 (equality accepted) and G3 all fit a 30 minute request');
    }

    @isTest
    static void case9LongAppointmentFitsAWideGap() {
        store('Diana', 11, 0, 30);
        store('Alice', 15, 0, 45);

        Test.startTest();
        APIResponse response = book('Henry', 12, 0, 60);
        Test.stopTest();

        System.assertEquals(true, response.success, response.message);
        ScheduleDto created = (ScheduleDto) response.data;
        System.assertEquals(at(12, 59), created.endDateTime, '60 normalised to 59');
    }

    @isTest
    static void case10IdenticalStartTimeCollides() {
        store('John', 10, 0, 30);

        Test.startTest();
        APIResponse response = book('Ivy', 10, 0, 30);
        Test.stopTest();

        System.assertEquals(false, response.success,
            'A record starting at t is both predecessor and successor');
        System.assertEquals(2, slotsOf(response).size(), 'G1 and G3');
    }

    @isTest
    static void fullDayOffersNothing() {
        store('John', 10, 0, 30);

        Test.startTest();
        // 900 minutes cannot fit before 10:00 nor between 10:30 and 22:00.
        APIResponse response = book('Zoe', 10, 0, 900);
        Test.stopTest();

        System.assertEquals(false, response.success, 'Refused');
        System.assertEquals('No available slots for the requested date', response.message);
        System.assertEquals(0, slotsOf(response).size(), 'No slot is long enough');
    }

    // ── Read ──────────────────────────────────────────────────────────────────

    @isTest
    static void getSchedulesReturnsEveryAppointment() {
        store('John', 10, 0, 30);
        store('Alice', 15, 0, 45);

        Test.startTest();
        APIResponse response = ScheduleController.getSchedules();
        Test.stopTest();

        System.assertEquals(true, response.success, response.message);
        List<ScheduleDto> rows = (List<ScheduleDto>) response.data;
        System.assertEquals(2, rows.size(), 'Every appointment is visible');
    }

    @isTest
    static void getSchedulesOnAnEmptyClinicReturnsAnEmptyList() {
        Test.startTest();
        APIResponse response = ScheduleController.getSchedules();
        Test.stopTest();

        System.assertEquals(true, response.success, response.message);
        List<ScheduleDto> rows = (List<ScheduleDto>) response.data;
        System.assertEquals(0, rows.size(), 'Empty list, never null');
    }

    // ── Update ────────────────────────────────────────────────────────────────

    @isTest
    static void updateAppliesTheNewValuesAndKeepsItsOwnSlot() {
        Schedule__c existing = store('John', 10, 0, 30);

        Test.startTest();
        APIResponse response = ScheduleController.updateSchedule(
            existing.Id, moment(10, 0), 'Johnathan', 'Patient', '+961 71123456',
            '961 3123456', 'Follow-up', 30, 75, 'Room 2', 'Bring previous results');
        Test.stopTest();

        System.assertEquals(true, response.success, response.message);
        Schedule__c reloaded = [
            SELECT FirstName__c, Type__c, Fees__c, Location__c, Notes__c, PhoneNumber2__c
            FROM Schedule__c WHERE Id = :existing.Id
        ];
        System.assertEquals('Johnathan', reloaded.FirstName__c, 'First name updated');
        System.assertEquals('Follow-up', reloaded.Type__c, 'Type updated');
        // .intValue() on the Decimal: assertEquals(Integer, Decimal) compares a
        // 75 against a 75.00 and reports them as different.
        System.assertEquals(75, reloaded.Fees__c.intValue(), 'Fees updated');
    }

    @isTest
    static void updateRefusesToMoveTheAppointmentToAnotherMoment() {
        Schedule__c existing = store('John', 10, 0, 30);

        Test.startTest();
        APIResponse response = ScheduleController.updateSchedule(
            existing.Id, moment(11, 0), 'John', 'Patient', '71123456', null,
            'Consultation', 30, 50, 'Room 1', null);
        Test.stopTest();

        System.assertEquals(false, response.success, 'Date and time cannot be changed');
        System.assertEquals(true, response.message.contains('cannot be changed'), response.message);
    }

    @isTest
    static void updateThatWouldOverlapANeighbourIsRefused() {
        Schedule__c existing = store('John', 10, 0, 30);
        store('Diana', 11, 0, 30);

        Test.startTest();
        // Stretching John to 90 minutes runs him into Diana at 11:00.
        APIResponse response = ScheduleController.updateSchedule(
            existing.Id, moment(10, 0), 'John', 'Patient', '71123456', null,
            'Consultation', 90, 50, 'Room 1', null);
        Test.stopTest();

        System.assertEquals(false, response.success, 'Overlap with the successor');
        Schedule__c reloaded = [SELECT DurationMinutes__c FROM Schedule__c WHERE Id = :existing.Id];
        System.assertEquals(30, reloaded.DurationMinutes__c.intValue(),
            'I2 — nothing written on refusal');
    }

    @isTest
    static void updateOfAMissingAppointmentFails() {
        Test.startTest();
        APIResponse response = ScheduleController.updateSchedule(
            '000000000000000AAA', moment(10, 0), 'John', 'Patient', '71123456', null,
            'Consultation', 30, 50, 'Room 1', null);
        Test.stopTest();

        System.assertEquals(false, response.success, 'The appointment must exist');
    }

    // ── Delete ────────────────────────────────────────────────────────────────

    @isTest
    static void deleteRemovesTheAppointmentPermanently() {
        Schedule__c existing = store('John', 10, 0, 30);

        Test.startTest();
        APIResponse response = ScheduleController.deleteSchedule(existing.Id);
        Test.stopTest();

        System.assertEquals(true, response.success, response.message);
        System.assertEquals(0, [SELECT COUNT() FROM Schedule__c], 'Row is gone');
    }

    @isTest
    static void deleteWithoutAnIdIsRejected() {
        Test.startTest();
        APIResponse response = ScheduleController.deleteSchedule('');
        Test.stopTest();

        System.assertEquals(false, response.success, 'An appointment must be selected');
        System.assertEquals('scheduleId is required', response.message);
    }

    @isTest
    static void deleteOfAnAlreadyRemovedAppointmentFails() {
        Schedule__c existing = store('John', 10, 0, 30);
        delete existing;

        Test.startTest();
        APIResponse response = ScheduleController.deleteSchedule(existing.Id);
        Test.stopTest();

        System.assertEquals(false, response.success, 'The appointment must still exist');
    }

    // ── Input correctness (Tab 5a rules, re-checked server side) ──────────────

    @isTest
    static void pastMomentsAreRefused() {
        Test.startTest();
        APIResponse response = ScheduleController.createSchedule(
            Datetime.now().addDays(-1).format(FORMAT), 'John', 'Patient', '71123456', null,
            'Consultation', 30, 50, 'Room 1', null);
        Test.stopTest();

        System.assertEquals(false, response.success, 'Date & Time must be in the future');
        System.assertEquals(true, response.message.contains('must be in the future'), response.message);
    }

    @isTest
    static void blankFirstNameIsRefused() {
        Test.startTest();
        APIResponse response = ScheduleController.createSchedule(
            moment(10, 0), '  ', 'Patient', '71123456', null,
            'Consultation', 30, 50, 'Room 1', null);
        Test.stopTest();

        System.assertEquals(false, response.success, 'First Name is required');
        System.assertEquals(true, response.message.contains('First Name is required'), response.message);
    }

    @isTest
    static void malformedPhoneNumberIsRefused() {
        Test.startTest();
        APIResponse response = ScheduleController.createSchedule(
            moment(10, 0), 'John', 'Patient', '12345', null,
            'Consultation', 30, 50, 'Room 1', null);
        Test.stopTest();

        System.assertEquals(false, response.success, '5 digits is below the 6 digit minimum');
    }

    @isTest
    static void lebaneseCountryCodeIsAccepted() {
        Test.startTest();
        APIResponse response = ScheduleController.createSchedule(
            moment(10, 0), 'John', 'Patient', '+961 71123456', '961 3123456',
            'Consultation', 30, 50, 'Room 1', null);
        Test.stopTest();

        System.assertEquals(true, response.success, response.message);
    }

    @isTest
    static void zeroDurationIsRefused() {
        Test.startTest();
        APIResponse response = ScheduleController.createSchedule(
            moment(10, 0), 'John', 'Patient', '71123456', null,
            'Consultation', 0, 50, 'Room 1', null);
        Test.stopTest();

        System.assertEquals(false, response.success, 'Duration must be greater than 0 minutes');
    }

    @isTest
    static void negativeFeesAreRefusedButZeroIsAllowed() {
        Test.startTest();
        APIResponse refused = ScheduleController.createSchedule(
            moment(10, 0), 'John', 'Patient', '71123456', null,
            'Consultation', 30, -1, 'Room 1', null);
        APIResponse free = ScheduleController.createSchedule(
            moment(14, 0), 'Jane', 'Patient', '71123456', null,
            'Consultation', 30, 0, 'Room 1', null);
        Test.stopTest();

        System.assertEquals(false, refused.success, 'Fees must be 0 or more');
        System.assertEquals(true, free.success, 'Free-of-charge appointments are allowed');
    }

    @isTest
    static void unparseableMomentIsRefused() {
        Test.startTest();
        APIResponse response = ScheduleController.createSchedule(
            'not-a-date', 'John', 'Patient', '71123456', null,
            'Consultation', 30, 50, 'Room 1', null);
        Test.stopTest();

        System.assertEquals(false, response.success, 'Unparseable input is rejected, not thrown');
    }
}
