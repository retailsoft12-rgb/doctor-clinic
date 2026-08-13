/**
 * ScheduleSlotDto — one free time of the requested day, offered to the admin
 * after a booking is refused.
 *
 * booking-algorithm section 8: a slot is a (start, end) pair of exactly the
 * requested effective duration, on the requested calendar day. It is an OFFER,
 * never a reservation — nothing is held by returning one.
 */
public with sharing class ScheduleSlotDto {

    @AuraEnabled
    public Datetime startDateTime { get; set; }

    @AuraEnabled
    public Datetime endDateTime { get; set; }

    public ScheduleSlotDto(Datetime startDateTime, Datetime endDateTime) {
        this.startDateTime = startDateTime;
        this.endDateTime = endDateTime;
    }
}
