/**
 * ScheduleBookingDto — the composite result of a booking attempt.
 *
 * booking-algorithm section 0: a request produces exactly one of three answers,
 * and this shape carries all three without losing the offer:
 *
 *   A) BOOKED       booked = true,  schedule set,        availableSlots empty
 *   B) BUSY + OFFER booked = false, schedule null,       availableSlots non-empty
 *   C) REFUSED      booked = false, schedule null,       availableSlots empty
 *
 * The Service returns domain data, never an envelope (hop 3.6). The controller
 * is what turns B and C into APIResponse(false, ...) with their own messages.
 */
public with sharing class ScheduleBookingDto {

    @AuraEnabled
    public Boolean booked { get; set; }

    @AuraEnabled
    public ScheduleDto schedule { get; set; }

    @AuraEnabled
    public List<ScheduleSlotDto> availableSlots { get; set; }

    public ScheduleBookingDto() {
        this.booked = false;
        this.availableSlots = new List<ScheduleSlotDto>();
    }
}
