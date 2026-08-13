/**
 * ScheduleDao — the ONLY layer that writes SOQL against Schedule__c.
 *
 * Query only: no DML, no business rules, no APIResponse, no ServiceException.
 * It returns raw rows and lets the Service decide what an empty result means.
 *
 * Schedule__c carries no RecordStatus__c field, so the project-wide
 * soft-delete filter (`AND RecordStatus__c != 'deleted'`) does not apply here —
 * deletion of an appointment is a hard delete (flow 12: "Deletion is permanent").
 */
public with sharing class ScheduleDao {

    /**
     * Every appointment the clinic holds — flow 1, "no hidden or archived records".
     *
     * The spec asks for "the order they are stored ... no sorting". A SOQL result
     * with no ORDER BY has no guaranteed order at all, so storage order is made
     * explicit and deterministic here as creation order. This is not a user-facing
     * sort: there is no sort control, and the order never changes.
     *
     * Every field this selects is read downstream by ScheduleDto.ScheduleView —
     * a field left out of the SELECT throws SObjectException on read, and a
     * `!= null` guard cannot protect it (the read IS the throw).
     */
    public static List<Schedule__c> findAllSchedules() {
        return [
            SELECT Id, Name, StartDateTime__c, EndDateTime__c,
                   FirstName__c, LastName__c, PhoneNumber__c, PhoneNumber2__c,
                   Type__c, DurationMinutes__c, Fees__c, Location__c, Notes__c
            FROM Schedule__c
            ORDER BY CreatedDate ASC, Id ASC
        ];
    }

    /** One appointment by id, or null when nothing matched. Never throws. */
    public static Schedule__c findScheduleById(Id recordId) {
        List<Schedule__c> rows = [
            SELECT Id, Name, StartDateTime__c, EndDateTime__c,
                   FirstName__c, LastName__c, PhoneNumber__c, PhoneNumber2__c,
                   Type__c, DurationMinutes__c, Fees__c, Location__c, Notes__c
            FROM Schedule__c
            WHERE Id = :recordId
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    /**
     * The appointments stored on one calendar day, ascending by start.
     *
     * Day scope (booking-algorithm § 5): an appointment belongs to the day of its
     * START, so the window filters StartDateTime__c only. An appointment whose end
     * crosses midnight stays owned by its start day.
     *
     * Selects StartDateTime__c, EndDateTime__c and DurationMinutes__c because the
     * Service reads all three when it probes the neighbours and builds the offer.
     */
    public static List<Schedule__c> findSchedulesByDay(Datetime dayStart, Datetime dayEnd) {
        return [
            SELECT Id, StartDateTime__c, EndDateTime__c, DurationMinutes__c
            FROM Schedule__c
            WHERE StartDateTime__c >= :dayStart
              AND StartDateTime__c <= :dayEnd
            ORDER BY StartDateTime__c ASC
        ];
    }
}
