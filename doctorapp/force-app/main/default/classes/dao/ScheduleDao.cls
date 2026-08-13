/**
 * ScheduleDao — the ONLY layer that writes SOQL against Schedule__c.
 *
 * sequence-be dbAccessRule: the controller, DomainCorrectness, the Service and
 * DomainCompleteValidator all reach the database through here and never carry a
 * [SELECT] of their own. Query only — no DML, no business rules, no
 * ServiceException, no APIResponse. An empty result is returned as null (single)
 * or an empty list (many); deciding what emptiness MEANS is the caller's job.
 *
 * Soft delete: Schedule__c carries no RecordStatus__c field, so the
 * `soql-exclude-deleted` filter does not apply to this object. Deletion is a
 * hard DELETE in ScheduleService, which matches the business rule "Deletion is
 * permanent - a deleted appointment cannot be recovered".
 *
 * Every method selects the full field set that ScheduleDto reads. Narrowing the
 * list would make the Dto's constructor throw on the dropped field rather than
 * read null (`apex-unqueried-field-access` pitfall).
 */
public with sharing class ScheduleDao {

    /**
     * Every appointment the clinic holds.
     *
     * No ORDER BY, deliberately: "Appointments appear in the order they are
     * stored - no sorting, filtering, searching, or paging."
     */
    public static List<Schedule__c> findAllSchedules() {
        return [
            SELECT Id, Name, StartDateTime__c, EndDateTime__c, DurationMinutes__c,
                   FirstName__c, LastName__c, PhoneNumber__c, PhoneNumber2__c,
                   Type__c, Location__c, Fees__c, Notes__c
            FROM Schedule__c
        ];
    }

    /** One appointment by id — null when nothing matched, never a QueryException. */
    public static Schedule__c findScheduleById(String recordId) {
        List<Schedule__c> rows = [
            SELECT Id, Name, StartDateTime__c, EndDateTime__c, DurationMinutes__c,
                   FirstName__c, LastName__c, PhoneNumber__c, PhoneNumber2__c,
                   Type__c, Location__c, Fees__c, Notes__c
            FROM Schedule__c
            WHERE Id = :recordId
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    /**
     * Every appointment stored on one calendar day.
     *
     * booking-algorithm section 5 (day scope): an appointment is classified by
     * its START only, and the window is [day 00:00:00, day 23:59:59]. This is
     * the single query the whole booking decision reads (cost model section 9:
     * "Day read: 1 query"), so it is never called inside a loop.
     */
    public static List<Schedule__c> findSchedulesByDay(Datetime dayStart, Datetime dayEnd) {
        return [
            SELECT Id, Name, StartDateTime__c, EndDateTime__c, DurationMinutes__c,
                   FirstName__c, LastName__c, PhoneNumber__c, PhoneNumber2__c,
                   Type__c, Location__c, Fees__c, Notes__c
            FROM Schedule__c
            WHERE StartDateTime__c >= :dayStart
              AND StartDateTime__c <= :dayEnd
        ];
    }
}
