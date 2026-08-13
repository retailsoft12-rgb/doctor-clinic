/**
 * ScheduleService — the domain service that owns Schedule__c.
 *
 * sequence-be phases 2-3: it reads only through ScheduleDao, holds the DML of
 * its own object, calls DomainCompleteValidator for the business rules, and
 * returns domain data (never an APIResponse — the envelope is the controller's).
 *
 * This class is the implementation of `guide/algorithm/booking-algorithm.md`.
 * The section numbers in the comments below point back at it; the invariants it
 * must preserve are its section 11:
 *
 *   I1  a BOOKED appointment collides with no stored appointment of that day
 *   I2  a non-BOOKED request produces ZERO writes
 *   I3  every offered slot has exactly the requested effective duration
 *   I4  every offered slot lies on the requested calendar day
 *   I5  offers never modify, shift or split an existing appointment
 *   I6  the decision reads at most the appointments of one calendar day
 *   I7  the offered set contains no duplicate (start, end) pair
 */
public with sharing class ScheduleService {

    /** booking-algorithm section 8 — the clinic's bookable day, used for OFFERS. */
    private static final Integer CLINIC_OPEN_HOUR = 8;
    private static final Integer CLINIC_CLOSE_HOUR = 22;

    // ── Read ──────────────────────────────────────────────────────────────────

    /** Every appointment the clinic holds - no hidden or archived records. */
    public static List<Schedule__c> loadSchedules() {
        return ScheduleDao.findAllSchedules();
    }

    // ── Create ────────────────────────────────────────────────────────────────

    /**
     * Answers one of the algorithm's three outcomes:
     *   A) BOOKED       — persisted, booked = true
     *   B) BUSY + OFFER — nothing written, availableSlots non-empty
     *   C) REFUSED      — nothing written, availableSlots empty
     */
    public static ScheduleBookingDto createSchedule(ScheduleInputDto input) {
        try {
            Integer effective = effectiveDuration(input.durationMinutes);

            Schedule__c requested = new Schedule__c();
            requested.StartDateTime__c = input.startDateTime;
            requested.DurationMinutes__c = input.durationMinutes;
            requested.EndDateTime__c = input.startDateTime.addMinutes(effective);
            requested.FirstName__c = input.firstName;
            requested.LastName__c = input.lastName;
            requested.PhoneNumber__c = input.phoneNumber;
            requested.PhoneNumber2__c = input.phoneNumber2;
            requested.Type__c = input.appointmentType;
            requested.Location__c = input.location;
            requested.Fees__c = input.fees;
            requested.Notes__c = input.notes;

            // I6 — one day read, one query, never inside a loop.
            List<Schedule__c> dayRows = loadDay(input.startDateTime);

            return decide(requested, dayRows, effective);
        } catch (ServiceException se) {
            throw se;
        } catch (Exception ex) {
            throw new ServiceException('Error creating schedule: ' + ex.getMessage());
        }
    }

    // ── Update ────────────────────────────────────────────────────────────────

    /**
     * The same decision as createSchedule, with the edited appointment LEFT OUT
     * of the comparison — an appointment keeps its own time slot while it is
     * being edited. Its date and time are fixed and cannot move.
     */
    public static ScheduleBookingDto updateSchedule(Schedule__c existing, ScheduleInputDto input) {
        try {
            DomainCompleteValidator.requireStartDateTimeUnchanged(existing, input.startDateTime);

            Integer effective = effectiveDuration(input.durationMinutes);

            existing.DurationMinutes__c = input.durationMinutes;
            existing.EndDateTime__c = existing.StartDateTime__c.addMinutes(effective);
            existing.FirstName__c = input.firstName;
            existing.LastName__c = input.lastName;
            existing.PhoneNumber__c = input.phoneNumber;
            existing.PhoneNumber2__c = input.phoneNumber2;
            existing.Type__c = input.appointmentType;
            existing.Location__c = input.location;
            existing.Fees__c = input.fees;
            existing.Notes__c = input.notes;

            List<Schedule__c> dayRows = new List<Schedule__c>();
            for (Schedule__c row : loadDay(existing.StartDateTime__c)) {
                if (row.Id != existing.Id) {
                    dayRows.add(row);
                }
            }

            return decide(existing, dayRows, effective);
        } catch (ServiceException se) {
            throw se;
        } catch (Exception ex) {
            throw new ServiceException('Error updating schedule: ' + ex.getMessage());
        }
    }

    // ── Delete ────────────────────────────────────────────────────────────────

    /**
     * Hard delete. Schedule__c carries no RecordStatus__c, so the project's
     * soft-delete pattern does not apply here — which matches the business rule
     * "Deletion is permanent - a deleted appointment cannot be recovered".
     * Deleting frees the time for future bookings and touches nothing else.
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

    // ── The decision (sections 5-8) ───────────────────────────────────────────

    /**
     * Shared by create and update: probe the two neighbours, book or offer.
     * `record` already carries its resolved Start/End; `dayRows` is the day it
     * competes against (for an update, minus itself).
     */
    private static ScheduleBookingDto decide(Schedule__c record,
                                             List<Schedule__c> dayRows,
                                             Integer effective) {
        Schedule__c predecessor = findPredecessor(dayRows, record.StartDateTime__c);
        Schedule__c successor = findSuccessor(dayRows, record.StartDateTime__c);

        ScheduleBookingDto result = new ScheduleBookingDto();

        Boolean free = DomainCompleteValidator.isSlotFree(
            record.StartDateTime__c, record.EndDateTime__c, predecessor, successor);

        if (!free) {
            // I2 / I5 — zero writes, nothing existing is touched, no time held.
            result.booked = false;
            result.availableSlots = buildAvailableSlots(dayRows, record.StartDateTime__c, effective);
            return result;
        }

        persist(record);
        result.booked = true;
        result.schedule = new ScheduleDto(record);
        return result;
    }

    /**
     * booking-algorithm section 6 — PREDECESSOR: of the appointments that start
     * at or before t, the one with the LATEST END. Latest end, not nearest
     * start: the longest overhang is the binding constraint.
     */
    private static Schedule__c findPredecessor(List<Schedule__c> dayRows, Datetime t) {
        Schedule__c best = null;
        for (Schedule__c row : dayRows) {
            if (row.StartDateTime__c == null || row.StartDateTime__c > t) {
                continue;
            }
            if (best == null || endOf(row) > endOf(best)) {
                best = row;
            }
        }
        return best;
    }

    /**
     * booking-algorithm section 6 — SUCCESSOR: of the appointments that start at
     * or after t, the one with the EARLIEST START. An appointment starting
     * exactly at t is both predecessor and successor, which is what makes the
     * "same start time" case collide.
     */
    private static Schedule__c findSuccessor(List<Schedule__c> dayRows, Datetime t) {
        Schedule__c best = null;
        for (Schedule__c row : dayRows) {
            if (row.StartDateTime__c == null || row.StartDateTime__c < t) {
                continue;
            }
            if (best == null || row.StartDateTime__c < best.StartDateTime__c) {
                best = row;
            }
        }
        return best;
    }

    /**
     * booking-algorithm section 8 — the offer. Duration and day stay constant;
     * only the start moves. Three generators:
     *
     *   G1  OPENING  [08:00, 08:00+d]                accepted if 08:00+d <= first start
     *   G2  GAP      [end(i), end(i)+d]              accepted if end(i)+d <= start(i+1)
     *   G3  CLOSING  [end(last), end(last)+d]        accepted if end(last)+d <= 22:00
     *
     * G1 anchors at the fixed opening 08:00 (not 00:00) and G3 is bounded by the
     * fixed closing 22:00, while G2 is bounded only by its neighbours — that
     * asymmetry is deliberate business behaviour, not an oversight.
     */
    private static List<ScheduleSlotDto> buildAvailableSlots(List<Schedule__c> dayRows,
                                                             Datetime requestedStart,
                                                             Integer effective) {
        Date day = requestedStart.date();
        Datetime opensAt = Datetime.newInstance(day, Time.newInstance(CLINIC_OPEN_HOUR, 0, 0, 0));
        Datetime closesAt = Datetime.newInstance(day, Time.newInstance(CLINIC_CLOSE_HOUR, 0, 0, 0));

        List<ScheduleSlotDto> slots = new List<ScheduleSlotDto>();
        Set<String> seen = new Set<String>();          // I7 — de-duplicate (start, end)

        List<Schedule__c> sorted = sortByStart(dayRows);

        if (sorted.isEmpty()) {
            // Defensive: an empty day cannot reach the offer, but if it ever did,
            // the whole bookable day is one free slot.
            addSlot(slots, seen, opensAt, effective, closesAt, day);
            return slots;
        }

        // G1 — opening slot, before the first appointment.
        if (opensAt.addMinutes(effective) <= sorted[0].StartDateTime__c) {
            addSlot(slots, seen, opensAt, effective, null, day);
        }

        // G2 — gap slots between consecutive appointments.
        for (Integer i = 0; i < sorted.size() - 1; i++) {
            Datetime gapStart = endOf(sorted[i]);
            if (gapStart.addMinutes(effective) <= sorted[i + 1].StartDateTime__c) {
                addSlot(slots, seen, gapStart, effective, null, day);
            }
        }

        // G3 — closing slot, after the last appointment.
        Datetime lastEnd = endOf(sorted[sorted.size() - 1]);
        if (lastEnd.addMinutes(effective) <= closesAt) {
            addSlot(slots, seen, lastEnd, effective, closesAt, day);
        }

        return slots;
    }

    /**
     * Adds one candidate slot after the invariant checks.
     * I3 — the slot is exactly `effective` minutes long, by construction.
     * I4 — a slot that would leave the requested day is dropped.
     * I7 — a (start, end) pair already offered is dropped.
     */
    private static void addSlot(List<ScheduleSlotDto> slots, Set<String> seen,
                                Datetime slotStart, Integer effective,
                                Datetime upperBound, Date day) {
        Datetime slotEnd = slotStart.addMinutes(effective);
        if (upperBound != null && slotEnd > upperBound) {
            return;
        }
        if (!DomainCompleteValidator.isOnDay(slotStart, slotEnd, day)) {
            return;
        }
        String key = String.valueOf(slotStart) + '|' + String.valueOf(slotEnd);
        if (seen.contains(key)) {
            return;
        }
        seen.add(key);
        slots.add(new ScheduleSlotDto(slotStart, slotEnd));
    }

    // ── Rules 1 and 2 (sections 2-3) ──────────────────────────────────────────

    /**
     * booking-algorithm section 2 — effective duration.
     *
     *   d = D - 1  when D is a whole number of hours (60, 120, 180, ...)
     *   d = D      otherwise                          (15, 30, 45, 90, ...)
     *
     * A "1 hour" appointment therefore occupies 59 minutes, so the next
     * hour-aligned slot does not touch it — closed intervals make touching a
     * collision (section 3).
     */
    public static Integer effectiveDuration(Integer requested) {
        if (requested == null || requested <= 0) {
            return requested;
        }
        if (Math.mod(requested, 60) == 0) {
            return requested - 1;
        }
        return requested;
    }

    /** booking-algorithm section 3 — end time of a stored appointment. */
    private static Datetime endOf(Schedule__c row) {
        if (row.EndDateTime__c != null) {
            return row.EndDateTime__c;
        }
        Integer stored = null;
        if (row.DurationMinutes__c != null) {
            stored = row.DurationMinutes__c.intValue();
        }
        if (stored == null) {
            return row.StartDateTime__c;
        }
        return row.StartDateTime__c.addMinutes(effectiveDuration(stored));
    }

    // ── Internals ─────────────────────────────────────────────────────────────

    /** booking-algorithm section 5 — the window is [day 00:00:00, day 23:59:59]. */
    private static List<Schedule__c> loadDay(Datetime moment) {
        Date day = moment.date();
        Datetime dayStart = Datetime.newInstance(day, Time.newInstance(0, 0, 0, 0));
        Datetime dayEnd = Datetime.newInstance(day, Time.newInstance(23, 59, 59, 0));
        return ScheduleDao.findSchedulesByDay(dayStart, dayEnd);
    }

    private static List<Schedule__c> sortByStart(List<Schedule__c> rows) {
        List<ScheduleByStart> wrapped = new List<ScheduleByStart>();
        for (Schedule__c row : rows) {
            wrapped.add(new ScheduleByStart(row));
        }
        wrapped.sort();

        List<Schedule__c> sorted = new List<Schedule__c>();
        for (ScheduleByStart item : wrapped) {
            sorted.add(item.record);
        }
        return sorted;
    }

    /** One DML, on this Service's own object, after every rule has passed. */
    private static void persist(Schedule__c record) {
        try {
            upsert record;
        } catch (DmlException dex) {
            throw new ServiceException('DML error saving schedule: ' + dex.getMessage());
        }
    }

    private class ScheduleByStart implements Comparable {
        public Schedule__c record;

        public ScheduleByStart(Schedule__c record) {
            this.record = record;
        }

        public Integer compareTo(Object other) {
            Schedule__c that = ((ScheduleByStart) other).record;
            if (this.record.StartDateTime__c == that.StartDateTime__c) {
                return 0;
            }
            if (this.record.StartDateTime__c > that.StartDateTime__c) {
                return 1;
            }
            return -1;
        }
    }
}
