/**
 * Input guards — validates the controller's input only (the ids and values that
 * arrived in this request's parameter list).
 *
 * Holds no SOQL of its own: it resolves ids through the Dao of the object it
 * guards and only decides what an empty result means.
 */
public with sharing class DomainCorrectness {
    /**
     * Returns the appointment, or null when the id is blank or nothing matched.
     *
     * Deliberately non-throwing. The spec makes an already-deleted appointment a
     * non-event: "If the appointment is already gone by the time the delete is
     * confirmed, system still shows the freshly loaded list and changes nothing
     * else." A throwing guard here would turn that into an error the spec says
     * it is not.
     */
    public static Schedule__c requireOptionalScheduleExists(String scheduleId) {
        if (String.isBlank(scheduleId)) {
            return null;
        }
        // A malformed id is "not found", not a crash. Id.valueOf is the only
        // reliable check; String does not support `instanceof Id`.
        Id recordId;
        try {
            recordId = Id.valueOf(scheduleId);
        } catch (Exception ex) {
            return null;
        }
        return ScheduleDao.findScheduleById(recordId);
    }

    /** Throws when the appointment is genuinely required to exist. */
    public static Schedule__c requireScheduleExists(String scheduleId) {
        Schedule__c record = requireOptionalScheduleExists(scheduleId);
        if (record == null) {
            throw new ServiceException('Schedule not found: ' + scheduleId);
        }
        return record;
    }
}
