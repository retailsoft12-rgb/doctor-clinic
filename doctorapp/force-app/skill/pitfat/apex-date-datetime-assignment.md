Name: Apex Date/Datetime assignment — Date and Datetime never assign to each other, so a Dto property or Service input typed Date against a DateTime field fails to compile ("Illegal assignment from Datetime to Date"), in BOTH directions.

Abstract


// PROBLEM — the field is DateTime, the Dto/input is Date
// Item__c.StartDate__c is <type>DateTime</type>
public Date startDate { get; set; }
this.startDate      = row.StartDate__c;    // Illegal assignment from Datetime to Date
item.StartDate__c   = input.startDate;     // Illegal assignment from Date to Datetime

// SOLUTION — keep the UI-facing type, convert on both boundaries, null-guarded
this.startDate      = row.StartDate__c == null ? null : row.StartDate__c.date();
item.StartDate__c   = input.startDate == null
                          ? null
                          : Datetime.newInstance(input.startDate, Time.newInstance(0, 0, 0, 0));
Rule: the field-meta.xml <type> is the truth — read it before typing the Dto property. When the UI sends a date-only value (input type="date"), keep Date on the Apex surface and convert at the Dao/Service edge; convert on the read AND the write with the same timezone basis (.date() out, midnight-local in) so a value round-trips unchanged. Never guard with a bare Datetime.newInstance(null, ...) — it throws.
