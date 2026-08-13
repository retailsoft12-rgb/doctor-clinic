/**
 * The ONLY layer that writes SOQL for Schedule__c.
 *
 * Query-only: it never throws, never builds a message and never runs a business
 * rule — callers decide what an empty result means.
 *
 * Note on soft delete: Schedule__c carries no RecordStatus__c field, so the
 * project-wide `AND RecordStatus__c != 'deleted'` filter does not apply here.
 * That matches the spec — "A deleted appointment is removed for good".
 */
public with sharing class ScheduleDao {
    /**
     * Every field the Dto/view-model downstream reads. Selecting the full set is
     * what keeps a consumer from hitting SObjectException on an unqueried field —
     * the read itself is the throw, so a null-guard cannot protect against it.
     */
    private static final String FIELD_LIST =
        'Id, Name, StartDateTime__c, EndDateTime__c, FirstName__c, LastName__c, ' +
        'PhoneNumber__c, PhoneNumber2__c, Type__c, Location__c, Notes__c, ' +
        'DurationMinutes__c, Fees__c, CreatedDate';

    /**
     * Every appointment the clinic holds — no filter, no paging.
     *
     * Ordered by CreatedDate so the list is "the order it holds them" (the order
     * they were added) rather than the undefined order a SOQL query without an
     * ORDER BY returns. The spec rules out user-facing sorting, not determinism.
     */
    public static List<Schedule__c> findAllSchedules() {
        return Database.query(
            'SELECT ' + FIELD_LIST + ' FROM Schedule__c ORDER BY CreatedDate ASC'
        );
    }

    /**
     * Every appointment already booked on one calendar day, earliest first.
     * Feeds both the overlap check and the free-time computation.
     */
    public static List<Schedule__c> findSchedulesBetween(Datetime dayStart, Datetime dayEnd) {
        return [
            SELECT
                Id,
                Name,
                StartDateTime__c,
                EndDateTime__c,
                FirstName__c,
                LastName__c,
                PhoneNumber__c,
                PhoneNumber2__c,
                Type__c,
                Location__c,
                Notes__c,
                DurationMinutes__c,
                Fees__c,
                CreatedDate
            FROM Schedule__c
            WHERE StartDateTime__c >= :dayStart AND StartDateTime__c < :dayEnd
            ORDER BY StartDateTime__c ASC
        ];
    }

    /** Null when nothing matched — the guard decides what that means. */
    public static Schedule__c findScheduleById(String recordId) {
        List<Schedule__c> rows = [
            SELECT
                Id,
                Name,
                StartDateTime__c,
                EndDateTime__c,
                FirstName__c,
                LastName__c,
                PhoneNumber__c,
                PhoneNumber2__c,
                Type__c,
                Location__c,
                Notes__c,
                DurationMinutes__c,
                Fees__c,
                CreatedDate
            FROM Schedule__c
            WHERE Id = :recordId
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }
}
