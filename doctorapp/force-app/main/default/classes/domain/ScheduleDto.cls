/**
 * ScheduleDto — response-only shapes for the appointment feature.
 *
 * Never accepted as a controller input (the boundary takes separated primitives);
 * only returned. Every property is @AuraEnabled so the LWC can read it.
 */
public class ScheduleDto {

    /**
     * One row of the appointment list.
     *
     * PhoneNumber2__c and Notes__c are deliberately NOT projected — flow 2:
     * "A second contact number exists but is not shown in the at-a-glance view"
     * and "Notes are kept but not displayed". The list cannot leak what it must
     * not render.
     *
     * The two date labels are formatted server-side, in the running user's time
     * zone, because "All times and durations are treated in the clinic's local
     * time zone" and a raw Datetime crossing the wire would be re-interpreted by
     * the browser's zone.
     */
    public class ScheduleView {
        @AuraEnabled public String id { get; set; }
        /** `day month year`, e.g. "15 May 2026" (flow 2). */
        @AuraEnabled public String startDateLabel { get; set; }
        /** 24-hour clock, e.g. "14:30" (flow 2). */
        @AuraEnabled public String startTimeLabel { get; set; }
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String lastName { get; set; }
        @AuraEnabled public String phoneNumber { get; set; }
        @AuraEnabled public String appointmentType { get; set; }
        @AuraEnabled public String location { get; set; }
        @AuraEnabled public Decimal durationMinutes { get; set; }
        @AuraEnabled public Decimal fees { get; set; }

        public ScheduleView(Schedule__c row) {
            this.id = row.Id;
            this.startDateLabel = row.StartDateTime__c == null
                ? null
                : row.StartDateTime__c.format('dd MMMM yyyy');
            this.startTimeLabel = row.StartDateTime__c == null
                ? null
                : row.StartDateTime__c.format('HH:mm');
            this.firstName = row.FirstName__c;
            this.lastName = row.LastName__c;
            this.phoneNumber = row.PhoneNumber__c;
            this.appointmentType = row.Type__c;
            this.location = row.Location__c;
            this.durationMinutes = row.DurationMinutes__c;
            this.fees = row.Fees__c;
        }
    }

    /** One invalid field and the reason, as the Server Error panel lists them. */
    public class FieldError {
        /** The form label the LWC shows, e.g. "Phone Number". */
        @AuraEnabled public String field { get; set; }
        @AuraEnabled public String message { get; set; }

        public FieldError(String field, String message) {
            this.field = field;
            this.message = message;
        }
    }

    /** One free time offered when the requested time is taken (flow 7). */
    public class TimeSlot {
        @AuraEnabled public String startLabel { get; set; }
        @AuraEnabled public String endLabel { get; set; }

        public TimeSlot(Datetime slotStart, Datetime slotEnd) {
            this.startLabel = slotStart.format('HH:mm');
            this.endLabel = slotEnd.format('HH:mm');
        }
    }

    /**
     * The one shape carrying all four booking outcomes.
     *
     * status = 'BOOKED'   → scheduleId is set, slots and fieldErrors empty
     *          'BUSY'     → slots non-empty, nothing written
     *          'NO_SLOTS' → slots empty, nothing written (flow 8)
     *          'INVALID'  → fieldErrors non-empty, nothing written (flow 6)
     */
    public class BookingResult {
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String scheduleId { get; set; }
        @AuraEnabled public List<TimeSlot> slots { get; set; }
        @AuraEnabled public List<FieldError> fieldErrors { get; set; }

        public BookingResult(String status) {
            this.status = status;
            this.slots = new List<TimeSlot>();
            this.fieldErrors = new List<FieldError>();
        }
    }
}
