# Phase 3 — Persist

Every business rule has already passed; this phase reads what the write needs,
writes, and returns. Class placement and the preconditions of the whole
lifecycle are in [sequence.md](sequence.md) → `layout` / `precondition`.

```yaml
phase: "3 — persist"
participants: [service, otherService, dao, db, controller, client]
steps:
  1 - opt: "optional"
    steps:
      - from: service
        to: otherService
        type: call
        message: "subOp"
      - from: otherService
        to: service
        type: return
        message: "done"
  2 - from: service
    to: dao
    type: call
    message: "find<Noun>(criteria)"
  3 - from: dao
    to: db
    type: call
    message: "SOQL (owned object)"
  4 - from: dao
    to: service
    type: return
    message: "records"
  5 - from: service
    to: db
    type: call
    message: "DML (own object)"
  6 - from: service
    to: controller
    type: return
    message: "result"
  7 - from: controller
    to: client
    type: return
    message: "APIResponse(ok, data)"
```

**Layer split of this phase:** the `dao` holds every **query** against its
object; the `service` holds every **write** against its object. A Service that
needs to read another object's rows calls that object's Service (hop 3.1), never
that object's Dao directly.

---

## Hop 3.1 — `service` → `otherService`  *(call — `subOp`, OPTIONAL)*

Fires only when the operation must also read or write **another domain's
object**. It is the `opt` fragment of this phase.

**Signature rule**

```apex
public static <SObject|Dto|void> <verbNoun>(<params>)   // on the OWNING Service
```

- A Service never queries or DMLs an object it does not own, and never reaches
  for another object's Dao. It calls the owning Service, which runs hops 3.2–3.5
  for its own object and returns the result.
- The sub-operation throws `ServiceException`; the calling Service lets it
  propagate (its own `catch` re-wraps with its message).
- The return hop (`done`) carries whatever the owning Service returns — a record,
  a list, or nothing.

**Input-format rule**

- Pass the record or the scalar the other Service needs — the caller does not
  build that object's SOQL and does not build its criteria.
- Same shape rule as every other hop: 2 or fewer scalars → primitives; 3+ related
  values or a nested payload → one `<Name>Dto`.
- One call per sub-operation, **outside** any loop. A bulk parent operation calls
  a bulk sub-operation once (`<Owner>Service.clearParentFromChildren(parentId)`),
  never one call per record — see
  [guard/apex-governor-limit-guard](../../../../../guard/apex-governor-limit-guard.md)
  and [performance/apex-bulk-soql](../../../../../performance/apex-bulk-soql.md).

**Message names — always reuse a name that already exists**

`<Owner>Service.find<Owner>ById(<owner>Id)` ·
`<Owner>Service.load<Noun>By<Parent>(<parent>Id)` ·
`<Owner>Service.clearParentFromChildren(parentId)` ·
`<Owner>Service.increase<Metric>(<owner>Id, <amount>)` ·
`<Owner>Service.load<Noun>()`

---

## Hop 3.2 — `service` → `dao`  *(call — `find<Noun>(criteria)`)*

Every read this phase needs — the rows that feed the write, the duplicate check,
the parent lookup — goes through the Dao of the object being read.

**Signature rule**

```apex
public with sharing class <Name>Dao {
    public static List<<Object>__c>     find<Noun>(<criteria>)
    public static Map<Id, <Object>__c>  find<Noun>ByIds(Set<Id> ids)
    public static <Object>__c           find<Noun>ById(Id recordId)
}
```

- One Dao per domain object, in `classes/dao/<Name>Dao.cls`, alongside the
  `<Name>Service` that owns the same object.
- **Query only.** No DML, no business rules, no `APIResponse`, no
  `ServiceException` — the Dao returns rows and lets the Service decide what an
  empty result means.
- Static, `public with sharing`, named `find…` / `load…` for what it returns.
- Returns an SObject, a `List<SObject>`, or a `Map<Id, SObject>` — never a
  wrapper and never `null` for a collection.

**Input-format rule**

- Pass the ids or criteria the Service **already holds**; the Dao does not
  re-derive them.
- 2 or fewer scalars → primitives; 3+ related filters → one `<Name>CriteriaDto`.
- Sets, not single ids, whenever the operation is bulk: one
  `find<Noun>ByIds(ids)` **outside** the loop, never one call per record.

**Message names — existing shapes**

`<Name>Dao.find<Noun>ByIds(ids)` · `<Name>Dao.find<Noun>ById(recordId)` ·
`<Name>Dao.find<Noun>By<Parent>(<parent>Id)` ·
`<Name>Dao.findDuplicatesByName(name, <parent>Id)` ·
`<Name>Dao.find<Noun>Referencing(<related>Id)`

---

## Hop 3.3 — `dao` → `db`  *(call — `SOQL (owned object)`)*

The **only** place a SOQL statement is written for that object.

**Signature rule**

- One query per Dao method, against the Dao's own object only.
- Bound variables always (`WHERE Id IN :ids`), never string concatenation.
- Select the fields the caller actually reads, plus `Id`; add `LIMIT` on any
  existence or duplicate check.
- Soft-deleted rows are excluded in the query itself —
  `AND RecordStatus__c != 'deleted'` on every object that carries the field
  ([soql-exclude-deleted-guide](../../../soql-exclude-deleted-guide.md)).
- Never inside a `for` — see
  [performance/apex-bulk-soql](../../../../../performance/apex-bulk-soql.md) and
  [guard/apex-governor-limit-guard](../../../../../guard/apex-governor-limit-guard.md).

**Message names — existing shapes**

`[SELECT <fields> FROM <Object>__c WHERE Id IN :ids AND RecordStatus__c != 'deleted']` ·
`[SELECT <fields> FROM <Object>__c WHERE <Parent>__c = :parentId AND RecordStatus__c != 'deleted' ORDER BY <field>]` ·
`[SELECT Id FROM <Object>__c WHERE Name = :name AND <Parent>__c = :parentId AND RecordStatus__c != 'deleted' LIMIT 1]`

---

## Hop 3.4 — `dao` → `service`  *(return — `records`)*

**Signature rule**

| Read | Return type |
|---|---|
| one row expected | `<Object>__c` — or `null` when nothing matched |
| many rows | `List<<Object>__c>` — empty list, never `null` |
| rows to be looked up by id | `Map<Id, <Object>__c>` |
| existence / duplicate check | `List<<Object>__c>` with `LIMIT 1` |

- The Dao returns **raw rows**. It does not throw when the result is empty and it
  does not translate a miss into a message.
- The Service is what turns an empty result into meaning — a
  `ServiceException`, a validator call
  (`DomainCompleteValidator.require<Rule>(duplicates)`), or a default value.
- The rows returned here are the ones the Service mutates and writes in hop 3.5;
  they are not re-queried before the DML.

---

## Hop 3.5 — `service` → `db`  *(call — `DML (own object)`)*

**Signature rule**

- `insert` / `update` / `upsert` / `delete` on the Service's **own** SObject only.
- Wrapped in `try { … } catch (DmlException dex) { … } catch (Exception ex) { … }`,
  each re-thrown as `ServiceException`.
- Soft delete is an `update` of `RecordStatus__c = 'deleted'`, not a hard
  `delete` — objects carrying `RecordStatus__c` are never physically removed
  ([soql-exclude-deleted-guide](../../../soql-exclude-deleted-guide.md)).

**Input-format rule**

- **One DML per object, after the loop.** Collect into a `List<SObject>` and
  write once; never DML inside a `for`.
- The rows that feed the write came from one Dao call (hop 3.2), bound with
  `IN :ids` — never a query per record, and never a query written here.
- The record written is the one the guard resolved or the Dao returned and the
  Service mutated; do not re-query it to write it.

**Message names — existing shapes**

`insert record` · `update record` · `update records` ·
`record.RecordStatus__c = 'deleted'; update record` ·
`'DML error creating <object>: ' + dex.getMessage()` ·
`'DML error updating <object>: ' + dex.getMessage()` ·
`'Error updating <object>: ' + ex.getMessage()`

---

## Hop 3.6 — `service` → `controller`  *(return — `result`)*

**Signature rule** — the Service returns **domain data**, never an envelope:

| Result | Return type |
|---|---|
| one record touched | the SObject — `<Object>__c` |
| several records touched | `List<<Object>__c>` |
| composite / nested shape | `<Name>Dto` in `classes/domain/<Name>Dto.cls` |
| nothing to hand back | `void` |

- `APIResponse` never crosses this hop — the Service does not know about it.
- A DTO carries `@AuraEnabled` properties matching the shape the LWC expects.

**Message names — existing return shapes**

`<Object>__c updated` · `<Object>__c created<Object>` ·
`List<<Object>__c> <nouns>` · `<Name>Dto result` ·
`List<<Name>Dto> <nouns>` · `<Name>ResponseDto response`

---

## Hop 3.7 — `controller` → `client`  *(return — `APIResponse(ok, data)`)*

**Signature rule**

```apex
return new APIResponse(true,  '<Thing> <past-tense verb>', data);    // success
return new APIResponse(false, '<field> is required');                // input failure
return new APIResponse(false, 'Error <doing X>: ' + ex.getMessage()); // caught failure
```

- **Always** `APIResponse` — every exit path of every `@AuraEnabled` method.
- Every method body is wrapped in `try/catch`; the `catch (Exception ex)` is the
  single place a `ServiceException` from any layer becomes a failure envelope
  (the sequence-level `errorHandling` rule).

**Input-format rule (the `data` slot)**

- One record or one list → pass it directly:
  `new APIResponse(true, '<Thing> updated successfully', updated)`.
- Several named pieces → one `Map<String, Object>` keyed by the names the LWC
  reads:

  ```apex
  Map<String, Object> data = new Map<String, Object>{
      '<flag>'   => result.<flag>,
      '<record>' => result.<record>
  };
  return new APIResponse(true, '<Thing> <verb-ed> successfully', data);
  ```
- Nothing to return → the two-argument constructor,
  `new APIResponse(true, '<Thing> deleted successfully')`.

**Message names — always reuse an existing message**

Success: `'<Things> loaded successfully'` · `'<Thing> created successfully'` ·
`'<Thing> updated successfully'` · `'<Thing> deleted successfully'` ·
`'<Thing> <verb-ed> successfully'`

Failure: `'<param> is required'` ·
`'Error loading <things>: ' + ex.getMessage()` ·
`'Error creating <thing>: ' + ex.getMessage()` ·
`'Error updating <thing>: ' + ex.getMessage()` ·
`'Error <doing X>: ' + ex.getMessage()`

---

## After this phase

The request ends here — the `APIResponse` is back in the LWC and there is no
next phase.

**Ship the test class.** Every controller in this project ships with a
`<Name>ControllerTest.cls` alongside it; add or extend it for the method just
written before the work is considered done.

Any `@AuraEnabled` method whose body reached SOQL/SOSL/DML is profiled by
[performance/apex-method-monitor](../../../../../performance/apex-method-monitor.md) —
consent for profiling was already collected upfront by the caller, so nothing is
asked here.

---

## Reference implementation

```apex
// Dao — hop 3.3 (the query lives here, and only here)
public with sharing class <Related>Dao {
    public static List<<Related>__c> find<Related>ByParent(Id parentId) {
        return [SELECT Id, <Field>__c, <Field2>__c
                FROM <Related>__c
                WHERE <Parent>__c = :parentId
                  AND RecordStatus__c != 'deleted'];
    }
}
```

```apex
// Service — hops 3.1 → 3.6
public static <Name>Dto <verbNoun>(<Object>__c record,
                                   <Target>__c target,
                                   List<<Rule>__c> rules) {
    try {
        <Rule>__c rule =
            DomainCompleteValidator.require<Rule>Allowed(record.<Field>__c, target.Id, rules);

        List<<Related>__c> related =
            <Related>Dao.find<Related>ByParent(rule.Id);                  // 3.2 → 3.4 — own object
        DomainCompleteValidator.require<Rule>Pass(record, related);

        record.<Field>__c = target.Id;
        update<Name>(record);                                             // 3.5 — own object

        Boolean <flag> = DomainCompleteValidator.is<Condition>(target);
        <Owner>__c updatedOwner = null;
        if (<flag> && String.isNotBlank(record.<Owner>__c)) {
            updatedOwner = <Owner>Service.increase<Metric>(               // 3.1 — other Service owns it
                record.<Owner>__c, record.<Amount>__c);
        }
        return new <Name>Dto(<flag>, updatedOwner);                       // 3.6
    } catch (Exception ex) {
        throw new ServiceException('Error <doing X>: ' + ex.getMessage());
    }
}
```

`classes/domain/<Name>Service.cls` · `classes/dao/<Name>Dao.cls` ·
`classes/domain/<Name>Dto.cls` ·
`classes/controller/<feature>/<Name>Controller.cls` ·
`classes/shared/APIResponse.cls`
