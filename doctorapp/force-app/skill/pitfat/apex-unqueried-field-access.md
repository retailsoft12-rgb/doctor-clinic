Name: Apex unqueried field access — reading a field that was not in the SELECT throws SObjectException, so a `!= null` guard cannot protect it: the read IS the throw.

Abstract


// PROBLEM — the guard itself throws when the parent was never queried
Item__c row = [SELECT Id, Parent__c FROM Item__c WHERE Id = :itemId];
if (row.Parent__r == null) { ... }   // SObjectException: row retrieved via SOQL
                                     // without querying the requested field

// SOLUTION — query every field the consumer reads
Item__c row = [SELECT Id, Parent__c, Parent__r.Name FROM Item__c WHERE Id = :itemId];
Rule: a field is queried-and-null or never-queried; only the first returns null, the second throws. Every Dao read feeding a Dto carries the full field set that Dto touches.
