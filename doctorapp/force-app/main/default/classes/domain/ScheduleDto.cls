/**
 * Composite shapes for the Schedule domain.
 *
 * `Input` is the Service's input shape (10 related values — the boundary passes
 * them as separated primitives, the Service takes one Dto). `Result` is the
 * composite response shape the Service hands back, because a create has three
 * possible outcomes, not one.
 */
public with sharing class ScheduleDto {
    public class Input {
        // Raw, exactly as the LWC sent them.
        public String startDateTimeRaw;
        public String firstName;
        public String lastName;
        public String phoneNumber;
        public String phoneNumber2;
        public String appointmentType;
        public String durationRaw;
        public String feesRaw;
        public String location;
        public String notes;

        // Parsed by ScheduleValidator once the raw values pass their rules.
        public Datetime startDateTime;
        public Integer durationMinutes;
        public Decimal fees;
    }

    /** CREATED — booked. SLOTS — clashed, free times offered. NO_SLOTS — day full. */
    public class Result {
        @AuraEnabled
        public Schedule__c created { get; set; }
        @AuraEnabled
        public List<ScheduleSlotFinder.TimeSlot> availableSlots { get; set; }
        @AuraEnabled
        public String outcome { get; set; }

        public Result(String outcome) {
            this.outcome = outcome;
            this.availableSlots = new List<ScheduleSlotFinder.TimeSlot>();
        }
    }
}
