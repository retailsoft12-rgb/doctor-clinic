/**
 * The Schedule domain Service — owns every DML against Schedule__c and reads
 * only through ScheduleDao. Throws ServiceException on failure; it never builds
 * an APIResponse (the envelope is the controller's job).
 */
public with sharing class ScheduleService {
    public static final String OUTCOME_CREATED = 'CREATED';
    public static final String OUTCOME_SLOTS = 'SLOTS';
    public static final String OUTCOME_NO_SLOTS = 'NO_SLOTS';

    /** Every appointment the clinic holds. */
    public static List<Schedule__c> loadSchedules() {
        return ScheduleDao.findAllSchedules();
    }

    /**
     * Books an appointment, or explains why it could not be booked.
     *
     * Order matters and follows the spec exactly: field rules first (nothing is
     * queried for an input that is already invalid), then the derived end
     * moment, then the same-day rows, then the clash check, then the DML.
     */
    public static ScheduleDto.Result createSchedule(ScheduleDto.Input input) {
        // Throws with the full field-error list when anything fails its rule.
        ScheduleValidator.requireValidInput(input);

        Integer storedDuration = ScheduleValidator.applyWholeHourShortening(input.durationMinutes);
        Datetime startMoment = input.startDateTime;
        Datetime endMoment = startMoment.addMinutes(storedDuration);
        Date bookingDay = startMoment.date();

        Datetime dayStart = Datetime.newInstance(bookingDay, Time.newInstance(0, 0, 0, 0));
        Datetime dayEnd = dayStart.addDays(1);
        List<Schedule__c> sameDay = ScheduleDao.findSchedulesBetween(dayStart, dayEnd);

        Schedule__c clash = ScheduleSlotFinder.findOverlap(startMoment, endMoment, sameDay);
        if (clash != null) {
            // Nothing is booked and nothing is held while the user decides.
            List<ScheduleSlotFinder.TimeSlot> freeSlots = ScheduleSlotFinder.findFreeSlots(
                bookingDay,
                storedDuration,
                sameDay
            );
            ScheduleDto.Result rejected = new ScheduleDto.Result(
                freeSlots.isEmpty() ? OUTCOME_NO_SLOTS : OUTCOME_SLOTS
            );
            rejected.availableSlots = freeSlots;
            return rejected;
        }

        Schedule__c record = new Schedule__c(
            StartDateTime__c = startMoment,
            EndDateTime__c = endMoment,
            FirstName__c = input.firstName.trim(),
            LastName__c = input.lastName.trim(),
            PhoneNumber__c = input.phoneNumber.trim(),
            // Blank is "no second number at all", so it is stored as null.
            PhoneNumber2__c = String.isBlank(input.phoneNumber2) ? null : input.phoneNumber2.trim(),
            Type__c = input.appointmentType.trim(),
            DurationMinutes__c = storedDuration,
            Fees__c = input.fees,
            Location__c = input.location.trim(),
            Notes__c = String.isBlank(input.notes) ? null : input.notes.trim()
        );

        try {
            insert record;
        } catch (DmlException dex) {
            throw new ServiceException('DML error creating schedule: ' + dex.getMessage());
        } catch (Exception ex) {
            throw new ServiceException('Error creating schedule: ' + ex.getMessage());
        }

        ScheduleDto.Result created = new ScheduleDto.Result(OUTCOME_CREATED);
        created.created = record;
        return created;
    }

    /**
     * Permanent delete — no copy is kept, and the time it held is free again.
     * A null record means it was already gone, which the spec treats as a
     * non-event rather than an error.
     */
    public static void deleteSchedule(Schedule__c record) {
        if (record == null) {
            return;
        }
        try {
            delete record;
        } catch (DmlException dex) {
            throw new ServiceException('DML error deleting schedule: ' + dex.getMessage());
        } catch (Exception ex) {
            throw new ServiceException('Error deleting schedule: ' + ex.getMessage());
        }
    }
}
