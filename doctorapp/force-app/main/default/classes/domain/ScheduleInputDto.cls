/**
 * ScheduleInputDto — the appointment values the Service works with.
 *
 * sequence-be phase 2, hop 2.1: the CONTROLLER boundary takes one separated
 * primitive per value the LWC sends (never a wrapper). One layer in, the Service
 * carries "3+ related values or a nested payload -> one <Name>Dto", which is
 * exactly this shape: the ten appointment values travel together because they
 * describe one appointment.
 *
 * Input-only — it carries no @AuraEnabled properties and never crosses back to
 * the client. ScheduleDto is the response shape.
 */
public with sharing class ScheduleInputDto {

    public Datetime startDateTime;
    public String firstName;
    public String lastName;
    public String phoneNumber;
    public String phoneNumber2;
    public String appointmentType;
    public Integer durationMinutes;
    public Decimal fees;
    public String location;
    public String notes;
}
