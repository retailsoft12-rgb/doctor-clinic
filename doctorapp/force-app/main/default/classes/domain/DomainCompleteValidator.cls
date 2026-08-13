/**
 * DomainCompleteValidator — business logic.
 *
 * sequence-be phase 2, hop 2.2: the state and invariant rules of the domain, one
 * method per recorded Tab 5b rule. Pure in-memory — no SOQL, no DML. It receives
 * data the Service already loaded and never fetches anything itself.
 *
 * Two shapes live here, both sanctioned by the guide:
 *   requireXxx(...) -> throws ServiceException when the rule is violated
 *   isXxx(...)      -> pure predicate, never throws
 *
 * The overlap check is a PREDICATE, not a guard, and that is deliberate: a
 * refused booking does not end the request — it produces the offer of free slots
 * (booking-algorithm section 8). Throwing here would throw the offer away.
 */
public with sharing class DomainCompleteValidator {

    /**
     * booking-algorithm section 3 — collision predicate over CLOSED intervals.
     *
     *   Collide(x, y)  <=>  s_x <= e_y  AND  s_y <= e_x
     *
     * Closed on both ends means TOUCHING IS OCCUPIED: an appointment may not
     * start at the exact instant another ends.
     */
    public static Boolean collides(Datetime startA, Datetime endA,
                                   Datetime startB, Datetime endB) {
        if (startA == null || endA == null || startB == null || endB == null) {
            return false;
        }
        return startA <= endB && startB <= endA;
    }

    /**
     * booking-algorithm section 7 — the booking decision.
     *
     *   Free(N)  <=>  (P = null OR NOT Collide(N,P))  AND  (S = null OR NOT Collide(N,S))
     *
     * Two probes are complete: no third appointment of the day can collide
     * without one of them colliding first (section 6, correctness proof). Both
     * probes carry StartDateTime__c and EndDateTime__c because ScheduleDao
     * selects them (`apex-unqueried-field-access`).
     */
    public static Boolean isSlotFree(Datetime start, Datetime finish,
                                     Schedule__c predecessor, Schedule__c successor) {
        if (predecessor != null &&
            collides(start, finish, predecessor.StartDateTime__c, predecessor.EndDateTime__c)) {
            return false;
        }
        if (successor != null &&
            collides(start, finish, successor.StartDateTime__c, successor.EndDateTime__c)) {
            return false;
        }
        return true;
    }

    /**
     * "An appointment's date and time are fixed once it is booked - a different
     * time means a different appointment."
     *
     * The edit form shows Date & Time read-only; this is the server-side half of
     * that rule, so a hand-built request cannot move a booked appointment.
     */
    public static void requireStartDateTimeUnchanged(Schedule__c existing, Datetime submitted) {
        if (submitted == null) {
            return;
        }
        if (existing.StartDateTime__c != submitted) {
            throw new ServiceException('Appointment date and time cannot be changed');
        }
    }

    /**
     * booking-algorithm invariant I4 — every offered slot lies on the requested
     * calendar day. The generators anchor to that day by construction; this is
     * the assertion that keeps it true if a generator is ever changed.
     */
    public static Boolean isOnDay(Datetime slotStart, Datetime slotEnd, Date requestedDay) {
        if (slotStart == null || slotEnd == null || requestedDay == null) {
            return false;
        }
        return slotStart.date() == requestedDay && slotEnd.date() == requestedDay;
    }
}
