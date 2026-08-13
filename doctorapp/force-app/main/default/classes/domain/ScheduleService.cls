/**
 * ScheduleService — owns every write against Schedule__c and reads only through
 * ScheduleDao. Returns domain data, never an APIResponse: the envelope is the
 * controller's job. Failures leave as ServiceException.
 */
public with sharing class ScheduleService {

    /** The clinic's bookable day (booking-algorithm § 8). Offers live inside it. */
    private static final Integer OPENING_HOUR = 8;
    private static final Integer CLOSING_HOUR = 22;

    /**
     * Book one appointment, or refuse it and offer the day's free times.
     *
     * The candidate arrives already parsed and field-validated by
     * DomainCorrectness — this method is where the BUSINESS rules run.
     *
     * Sequence:
     *   1. normalise the duration and derive the end instant   (§ 2, § 3)
     *   2. read the requested calendar day, and only it        (§ 5)
     *   3. probe predecessor and successor                     (§ 6, § 7)
     *   4. free   → persist, answer BOOKED
     *      busy   → persist NOTHING, answer BUSY with the offer, or NO_SLOTS
     *
     * Invariant: a non-BOOKED request performs ZERO writes — no partial save, no
     * hold, no reservation. "A rejected booking leaves the day unchanged."
     */
    public static ScheduleDto.BookingResult bookSchedule(Schedule__c candidate) {
        try {
            Integer effectiveMinutes =
                DomainCompleteValidator.effectiveDuration(candidate.DurationMinutes__c.intValue());
            Datetime requestedStart = candidate.StartDateTime__c;
            Datetime requestedEnd =
                DomainCompleteValidator.endOf(requestedStart, effectiveMinutes);

            Date requestedDay = requestedStart.date();
            List<Schedule__c> storedDay = ScheduleDao.findSchedulesByDay(
                Datetime.newInstance(requestedDay, Time.newInstance(0, 0, 0, 0)),
                Datetime.newInstance(requestedDay, Time.newInstance(23, 59, 59, 999))
            );

            if (!DomainCompleteValidator.isRequestedTimeFree(storedDay, requestedStart, requestedEnd)) {
                return buildOffer(storedDay, requestedDay, effectiveMinutes);
            }

            // The appointment is shortened to its effective duration, so the stored
            // record always satisfies End = Start + Duration.
            candidate.DurationMinutes__c = effectiveMinutes;
            candidate.EndDateTime__c = requestedEnd;
            insertSchedule(candidate);

            ScheduleDto.BookingResult booked = new ScheduleDto.BookingResult('BOOKED');
            booked.scheduleId = candidate.Id;
            return booked;
        } catch (ServiceException se) {
            throw se;
        } catch (Exception ex) {
            throw new ServiceException('Error creating schedule: ' + ex.getMessage());
        }
    }

    /**
     * Permanently remove one appointment (flow 12 — "Deletion is permanent; no
     * recovery"). A hard delete, not a status flag: Schedule__c carries no
     * RecordStatus__c, so there is no soft-delete convention to honour here.
     */
    public static void deleteSchedule(Schedule__c existing) {
        try {
            delete existing;
        } catch (DmlException dex) {
            throw new ServiceException('DML error deleting schedule: ' + dex.getMessage());
        } catch (Exception ex) {
            throw new ServiceException('Error deleting schedule: ' + ex.getMessage());
        }
    }

    // ── Private ──────────────────────────────────────────────────────────────

    private static void insertSchedule(Schedule__c candidate) {
        try {
            insert candidate;
        } catch (DmlException dex) {
            throw new ServiceException('DML error creating schedule: ' + dex.getMessage());
        }
    }

    /**
     * RULE 7 (§ 8) — alternative slot generation, run only when the request is busy.
     *
     * The requested duration and the requested day stay fixed; only the start moves.
     * Three generators, over the day sorted by start:
     *
     *   G1  opening slot   [OPEN, OPEN + d]          accepted iff OPEN + d ≤ s_a(1)
     *   G2  gap slots      [e_a(i), e_a(i) + d]      accepted iff e_a(i) + d ≤ s_a(i+1)
     *   G3  closing slot   [e_a(n), e_a(n) + d]      accepted iff e_a(n) + d ≤ CLOSE
     *
     * The asymmetry is deliberate: G1 anchors at 08:00 (not midnight), G3 is bounded
     * by 22:00, and G2 is bounded only by its neighbours.
     *
     * KNOWN CONTRADICTION, carried from the algorithm spec (§ 12, X1): a G2/G3 slot
     * starts exactly at a previous appointment's end, which the collision rule treats
     * as occupied. Re-submitting such a slot verbatim is refused again. The spec
     * offers these slots and requires the user to retype the time, so the behaviour is
     * implemented as written rather than silently offset by a minute.
     */
    private static ScheduleDto.BookingResult buildOffer(
        List<Schedule__c> storedDay,
        Date requestedDay,
        Integer effectiveMinutes
    ) {
        Datetime openAt = Datetime.newInstance(requestedDay, Time.newInstance(OPENING_HOUR, 0, 0, 0));
        Datetime closeAt = Datetime.newInstance(requestedDay, Time.newInstance(CLOSING_HOUR, 0, 0, 0));

        // storedDay already arrives ordered by StartDateTime__c ascending (the Dao's
        // ORDER BY), which is what G1/G2/G3 assume.
        List<ScheduleDto.TimeSlot> slots = new List<ScheduleDto.TimeSlot>();
        Set<String> seen = new Set<String>();

        if (storedDay.isEmpty()) {
            // Unreachable through bookSchedule (an empty day never collides), but a
            // correct answer for the generator on its own terms.
            addSlot(slots, seen, openAt, openAt.addMinutes(effectiveMinutes), closeAt);
            return finishOffer(slots);
        }

        // G1 — from opening to the first appointment.
        Datetime firstStart = storedDay[0].StartDateTime__c;
        Datetime openingEnd = openAt.addMinutes(effectiveMinutes);
        if (openingEnd <= firstStart) {
            addSlot(slots, seen, openAt, openingEnd, null);
        }

        // G2 — between consecutive appointments.
        for (Integer i = 0; i < storedDay.size() - 1; i++) {
            Datetime gapStart = DomainCompleteValidator.storedEndOf(storedDay[i]);
            Datetime gapEnd = gapStart.addMinutes(effectiveMinutes);
            if (gapEnd <= storedDay[i + 1].StartDateTime__c) {
                addSlot(slots, seen, gapStart, gapEnd, null);
            }
        }

        // G3 — from the last appointment to closing.
        Datetime tailStart = DomainCompleteValidator.storedEndOf(storedDay[storedDay.size() - 1]);
        Datetime tailEnd = tailStart.addMinutes(effectiveMinutes);
        if (tailEnd <= closeAt) {
            addSlot(slots, seen, tailStart, tailEnd, null);
        }

        return finishOffer(slots);
    }

    /** De-duplicates by the (start, end) pair — the offer is a set, not a list. */
    private static void addSlot(
        List<ScheduleDto.TimeSlot> slots,
        Set<String> seen,
        Datetime slotStart,
        Datetime slotEnd,
        Datetime upperBound
    ) {
        if (upperBound != null && slotEnd > upperBound) {
            return;
        }
        String key = String.valueOf(slotStart) + '|' + String.valueOf(slotEnd);
        if (seen.contains(key)) {
            return;
        }
        seen.add(key);
        slots.add(new ScheduleDto.TimeSlot(slotStart, slotEnd));
    }

    /** Σ ≠ ∅ → BUSY with the offer; Σ = ∅ → NO_SLOTS (flow 8). Zero writes either way. */
    private static ScheduleDto.BookingResult finishOffer(List<ScheduleDto.TimeSlot> slots) {
        ScheduleDto.BookingResult result =
            new ScheduleDto.BookingResult(slots.isEmpty() ? 'NO_SLOTS' : 'BUSY');
        result.slots = slots;
        return result;
    }
}
