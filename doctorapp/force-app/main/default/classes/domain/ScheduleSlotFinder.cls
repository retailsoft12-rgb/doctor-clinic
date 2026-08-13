/**
 * The two algorithms the spec names in `important-metadata`:
 *
 *   predecessor-successor-overlap-algorithm
 *   neighbouring-appointment-gap-algorithm
 *
 * Neither has a guide file on disk (guide/algorithm/ holds only
 * item-order-score and pocker-method), so both are implemented from the
 * behaviour text of the client-flow spec, which specifies them completely.
 *
 * Pure in-memory: no SOQL, no DML. The Service hands it the rows.
 */
public with sharing class ScheduleSlotFinder {
    /** The clinic's bookable day, used only when free times are worked out. */
    public static final Integer DAY_OPEN_HOUR = 8;
    public static final Integer DAY_CLOSE_HOUR = 22;

    /** A free time offered back to the user: a start moment and an end moment. */
    public class TimeSlot {
        @AuraEnabled
        public String startLabel { get; set; }
        @AuraEnabled
        public String endLabel { get; set; }
        /** 'yyyy-MM-ddTHH:mm' — what the user types back into Date & Time. */
        @AuraEnabled
        public String startIso { get; set; }

        public TimeSlot(Datetime slotStart, Datetime slotEnd) {
            this.startLabel = slotStart.format('HH:mm');
            this.endLabel = slotEnd.format('HH:mm');
            this.startIso = slotStart.format('yyyy-MM-dd') + 'T' + slotStart.format('HH:mm');
        }
    }

    /**
     * predecessor-successor-overlap-algorithm.
     *
     * "gathers every appointment already booked on that same day, and checks the
     * new one against the one that would come immediately before it and the one
     * that would come immediately after it."
     *
     * Returns the appointment that clashes, or null when the slot is free. Two
     * appointments may not overlap by even a single minute; touching end-to-start
     * is NOT an overlap.
     *
     * @param sameDay must be ordered by StartDateTime__c ASC (the Dao does this).
     */
    public static Schedule__c findOverlap(
        Datetime newStart,
        Datetime newEnd,
        List<Schedule__c> sameDay
    ) {
        Schedule__c predecessor = null;
        Schedule__c successor = null;

        for (Schedule__c existing : sameDay) {
            if (existing.StartDateTime__c == null) {
                continue;
            }
            if (existing.StartDateTime__c <= newStart) {
                // Latest appointment starting at or before the new one.
                predecessor = existing;
            } else if (successor == null) {
                // First appointment starting after the new one.
                successor = existing;
            }
        }

        if (predecessor != null && endOf(predecessor) > newStart) {
            return predecessor;
        }
        if (successor != null && successor.StartDateTime__c < newEnd) {
            return successor;
        }
        return null;
    }

    /**
     * neighbouring-appointment-gap-algorithm.
     *
     * "the gap from 8 in the morning up to the first appointment of the day, the
     * gap after each appointment up to the one that follows it, and the time
     * after the last appointment of the day up to 10 at night - and only where
     * the gap is at least as long as the requested duration."
     *
     * Each qualifying gap yields ONE offer, sized to the requested duration —
     * which is what the business rule "A free time offered is always exactly as
     * long as the appointment the user asked for" requires. The gap boundaries
     * are exactly the ones the behaviour text lists.
     */
    public static List<TimeSlot> findFreeSlots(
        Date day,
        Integer durationMinutes,
        List<Schedule__c> sameDay
    ) {
        List<TimeSlot> slots = new List<TimeSlot>();
        if (durationMinutes == null || durationMinutes < 1) {
            return slots;
        }

        Datetime dayOpen = Datetime.newInstance(day, Time.newInstance(DAY_OPEN_HOUR, 0, 0, 0));
        Datetime dayClose = Datetime.newInstance(day, Time.newInstance(DAY_CLOSE_HOUR, 0, 0, 0));

        Datetime cursor = dayOpen;
        for (Schedule__c existing : sameDay) {
            if (existing.StartDateTime__c == null) {
                continue;
            }
            Datetime existingStart = existing.StartDateTime__c;
            Datetime existingEnd = endOf(existing);

            if (existingStart > cursor) {
                addSlotIfLongEnough(slots, cursor, existingStart, durationMinutes, dayClose);
            }
            if (existingEnd > cursor) {
                cursor = existingEnd;
            }
        }
        addSlotIfLongEnough(slots, cursor, dayClose, durationMinutes, dayClose);

        return slots;
    }

    /**
     * The end of an appointment. EndDateTime__c is derived on write, but it is a
     * nullable field, so fall back to start + duration rather than trusting it
     * blindly on rows written by anything other than this feature.
     */
    private static Datetime endOf(Schedule__c record) {
        if (record.EndDateTime__c != null) {
            return record.EndDateTime__c;
        }
        Integer minutes = record.DurationMinutes__c == null
            ? 0
            : record.DurationMinutes__c.intValue();
        return record.StartDateTime__c.addMinutes(minutes);
    }

    private static void addSlotIfLongEnough(
        List<TimeSlot> slots,
        Datetime gapStart,
        Datetime gapEnd,
        Integer durationMinutes,
        Datetime dayClose
    ) {
        // A gap that starts before the clinic opens is clipped to opening time;
        // one that ends after closing is clipped to closing time.
        Datetime effectiveEnd = gapEnd > dayClose ? dayClose : gapEnd;
        if (effectiveEnd <= gapStart) {
            return;
        }
        Long gapMinutes = (effectiveEnd.getTime() - gapStart.getTime()) / (1000 * 60);
        if (gapMinutes < durationMinutes) {
            return;
        }
        slots.add(new TimeSlot(gapStart, gapStart.addMinutes(durationMinutes)));
    }
}
