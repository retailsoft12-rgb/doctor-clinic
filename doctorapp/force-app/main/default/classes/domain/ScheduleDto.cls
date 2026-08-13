/**
 * ScheduleDto — the RESPONSE shape of one appointment as the LWC reads it.
 *
 * sequence-be phase 3, hop 3.6: a Dto is a composite response shape only. It is
 * never accepted at the controller boundary (that takes separated primitives).
 *
 * Property types follow the field-meta.xml <type>, per the
 * `apex-date-datetime-assignment` pitfall:
 *   StartDateTime__c / EndDateTime__c  <type>DateTime</type> -> Datetime
 *   DurationMinutes__c                 <type>Number</type> scale 0 -> Decimal on
 *                                      the SObject, narrowed to Integer here
 *                                      through intValue(), never by assignment
 *   Fees__c                            <type>Currency</type> scale 2 -> Decimal
 */
public with sharing class ScheduleDto {

    @AuraEnabled
    public String id { get; set; }

    @AuraEnabled
    public String name { get; set; }

    @AuraEnabled
    public Datetime startDateTime { get; set; }

    @AuraEnabled
    public Datetime endDateTime { get; set; }

    @AuraEnabled
    public Integer durationMinutes { get; set; }

    @AuraEnabled
    public String firstName { get; set; }

    @AuraEnabled
    public String lastName { get; set; }

    @AuraEnabled
    public String phoneNumber { get; set; }

    @AuraEnabled
    public String phoneNumber2 { get; set; }

    @AuraEnabled
    public String appointmentType { get; set; }

    @AuraEnabled
    public String location { get; set; }

    @AuraEnabled
    public Decimal fees { get; set; }

    @AuraEnabled
    public String notes { get; set; }

    public ScheduleDto() {
    }

    /**
     * Every field read here is selected by ScheduleDao — see the
     * `apex-unqueried-field-access` pitfall: an unqueried field throws on read,
     * so a `!= null` guard cannot protect it. The Dao's SELECT list and this
     * constructor are kept in lock-step.
     */
    public ScheduleDto(Schedule__c row) {
        this.id = row.Id;
        this.name = row.Name;
        this.startDateTime = row.StartDateTime__c;
        this.endDateTime = row.EndDateTime__c;
        this.firstName = row.FirstName__c;
        this.lastName = row.LastName__c;
        this.phoneNumber = row.PhoneNumber__c;
        this.phoneNumber2 = row.PhoneNumber2__c;
        this.appointmentType = row.Type__c;
        this.location = row.Location__c;
        this.fees = row.Fees__c;
        this.notes = row.Notes__c;

        // Decimal -> Integer is a narrowing conversion, never a plain assignment.
        // Written as an if/else rather than a ternary so no branch has to be
        // coerced into the other's type (`apex-ternary-type-inference` pitfall).
        if (row.DurationMinutes__c == null) {
            this.durationMinutes = null;
        } else {
            this.durationMinutes = row.DurationMinutes__c.intValue();
        }
    }

    public static List<ScheduleDto> fromRows(List<Schedule__c> rows) {
        List<ScheduleDto> dtos = new List<ScheduleDto>();
        for (Schedule__c row : rows) {
            dtos.add(new ScheduleDto(row));
        }
        return dtos;
    }
}
