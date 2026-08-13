/**
 * DomainCompleteValidator — the business rules of the appointment domain.
 *
 * Pure in-memory logic: no SOQL, no DML. Every method receives data the Service
 * already loaded. Called from the Service, never from the controller.
 *
 * Rules implemented here are the predecessor-successor-overlap algorithm of
 * `force-app/skill/task-skill/guide/algorithm/booking-algorithm.md`:
 *   § 2  effective duration      → effectiveDuration
 *   § 3  end time                → endOf
 *   § 4  collision predicate     → collides
 *   § 6  the two neighbours      → findPredecessor / findSuccessor
 *   § 7  the booking decision    → isRequestedTimeFree
 */
public class DomainCompleteValidator {

    /**
     * RULE 1 (§ 2) — effective duration.
     *
     *   d = D_req - 1   when D_req is a whole number of hours (60, 120, 180 …)
     *   d = D_req       otherwise
     *
     * A "1 hour" appointment therefore occupies 59 minutes, so the next
     * hour-aligned appointment does not touch it — touching is a collision (§ 4).
     * The spec states this as a business rule of its own: "Duration given as a
     * whole number of hours is shortened by one minute to prevent adjacent
     * appointments from touching."
     */
    public static Integer effectiveDuration(Integer requestedMinutes) {
        if (requestedMinutes == null) {
            return null;
        }
        if (Math.mod(requestedMinutes, 60) == 0 && requestedMinutes >= 60) {
            return requestedMinutes - 1;
        }
        return requestedMinutes;
    }

    /** RULE 2 (§ 3) — end time is derived, never entered: e = s + d. */
    public static Datetime endOf(Datetime startInstant, Integer effectiveMinutes) {
        if (startInstant == null || effectiveMinutes == null) {
            return null;
        }
        return startInstant.addMinutes(effectiveMinutes);
    }

    /**
     * RULE 3 (§ 4) — collision predicate over CLOSED intervals.
     *
     *   Collide(x, y) ⟺ s_x ≤ e_y ∧ s_y ≤ e_x
     *
     * Closed on both ends means the last minute is still occupied: an appointment
     * may not start at the exact instant another ends. That is what makes
     * "must never overlap (even by one minute)" true.
     */
    public static Boolean collides(
        Datetime startX,
        Datetime endX,
        Datetime startY,
        Datetime endY
    ) {
        return startX <= endY && startY <= endX;
    }

    /**
     * RULE 5 (§ 6) — the PREDECESSOR: among the appointments starting at or before
     * the requested instant, the one with the LATEST end.
     *
     * Selected by latest END rather than latest start on purpose: the longest
     * overhang, not the nearest start, is the binding constraint.
     *
     * Returns null when no appointment starts at or before the requested instant.
     */
    public static Schedule__c findPredecessor(List<Schedule__c> storedDay, Datetime requestedStart) {
        Schedule__c predecessor = null;
        Datetime latestEnd = null;
        for (Schedule__c stored : storedDay) {
            if (stored.StartDateTime__c > requestedStart) {
                continue;
            }
            Datetime storedEnd = storedEndOf(stored);
            if (latestEnd == null || storedEnd > latestEnd) {
                latestEnd = storedEnd;
                predecessor = stored;
            }
        }
        return predecessor;
    }

    /**
     * RULE 5 (§ 6) — the SUCCESSOR: among the appointments starting at or after the
     * requested instant, the one with the EARLIEST start.
     *
     * An appointment starting exactly at the requested instant belongs to BOTH sets
     * — it is predecessor and successor at once (the "same start time" case).
     *
     * Returns null when no appointment starts at or after the requested instant.
     */
    public static Schedule__c findSuccessor(List<Schedule__c> storedDay, Datetime requestedStart) {
        Schedule__c successor = null;
        for (Schedule__c stored : storedDay) {
            if (stored.StartDateTime__c < requestedStart) {
                continue;
            }
            if (successor == null || stored.StartDateTime__c < successor.StartDateTime__c) {
                successor = stored;
            }
        }
        return successor;
    }

    /**
     * RULE 6 (§ 7) — the booking decision.
     *
     *   Free(N) ⟺ (P = ⊥ ∨ ¬Collide(N,P)) ∧ (S = ⊥ ∨ ¬Collide(N,S))
     *
     * Two probes are complete — no third appointment of the day can collide without
     * one of them colliding too (§ 6, correctness proof). This is a predicate, not a
     * `requireXxx`: a busy slot is not an exception, it is the branch that produces
     * the offer in flow 7.
     */
    public static Boolean isRequestedTimeFree(
        List<Schedule__c> storedDay,
        Datetime requestedStart,
        Datetime requestedEnd
    ) {
        Schedule__c predecessor = findPredecessor(storedDay, requestedStart);
        if (predecessor != null
            && collides(requestedStart, requestedEnd,
                        predecessor.StartDateTime__c, storedEndOf(predecessor))) {
            return false;
        }

        Schedule__c successor = findSuccessor(storedDay, requestedStart);
        if (successor != null
            && collides(requestedStart, requestedEnd,
                        successor.StartDateTime__c, storedEndOf(successor))) {
            return false;
        }

        return true;
    }

    /**
     * The end instant of a stored appointment.
     *
     * EndDateTime__c is persisted at booking time and is the value used. The
     * fallback recomputes it from the stored duration so a row written before this
     * feature existed — or by a data load that left the field empty — still probes
     * correctly instead of throwing on a null comparison.
     */
    public static Datetime storedEndOf(Schedule__c stored) {
        if (stored.EndDateTime__c != null) {
            return stored.EndDateTime__c;
        }
        Integer minutes = stored.DurationMinutes__c == null
            ? 0
            : stored.DurationMinutes__c.intValue();
        return stored.StartDateTime__c.addMinutes(minutes);
    }
}
