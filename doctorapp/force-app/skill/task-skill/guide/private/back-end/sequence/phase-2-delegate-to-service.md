# Phase 2 — Delegate to service

The controller arrives here holding **resolved records**, not raw ids. Class
placement and the preconditions of the whole lifecycle are in
[sequence.md](sequence.md) → `layout` / `precondition`.

```yaml
phase: "2 — delegate to service"
participants: [controller, service, validator]
steps:
  1 - from: controller
    to: service
    type: call
    message: "doOperation(record, related, params)"
  2 - from: service
    to: DomainCompleteValidator
    type: call
    message: "requireRule(data)"
  3 - from: DomainCompleteValidator
    to: service
    type: return
    message: "ok (else throw)"
```

---

## What DomainCompleteValidator is for (MANDATORY)

`DomainCompleteValidator` enforces **business logic** — the state and invariant
rules of the domain. Its rule set for a given iteration is the **Tab 5b —
business logic validation rules** answer recorded in `scratchpad-memory.md`
(section 1, consolidated into section 7). Read the rules out of that file and
turn each one into a `requireXxx(...)` call. Never re-ask for them
(CLAUDE.md → "Ask ONLY in the caller").

- Each recorded rule → one validator method that throws `ServiceException` when
  violated. Reuse an existing method when the rule already has one.
- Existence checks are **not** business logic — they belong to
  `DomainCorrectness`, which already ran in the previous phase and guards
  controller **input** only, never a foreign key of an already-retrieved record.
- The validator is called **from the Service**, never from the controller.

---

## Hop 2.1 — `controller` → `service`  *(call — `doOperation(record, related, params)`)*

**Signature rule**

```apex
public with sharing class <Name>Service {
    public static <SObject|Dto|void> <verbNoun>(<SObject> record, <SObject> related, <params>)
}
```

- `public with sharing`, static methods, named for the use case.
- Lives in `classes/domain/<Name>Service.cls` — one Service per domain object;
  create the Service when the object has none.
- Returns the SObject it touched, a `<Name>Dto` for a composite shape, or `void`.
- Throws `ServiceException` on failure — never returns `APIResponse` (the
  envelope is the controller's job).

**Input-format rule — RESOLVED RECORDS, ONE PER GUARD (MANDATORY)**

**Every id that went through a `DomainCorrectness` call in
[phase 1](phase-1-input-correctness.md) is passed to the Service as the SObject
that guard returned — never as the id again.** The guard already paid for the
query; handing the Service the id would make it re-query the row it was just
given, and the guard's return value would be thrown away.

The mapping is one-for-one and mechanical:

| Phase 1 hop 1.1 | Phase 2 hop 2.1 parameter |
|---|---|
| `<Object>__c record = DomainCorrectness.require<Noun>Exists(<noun>Id)` | `<Object>__c record` |
| `<Parent>__c parent = DomainCorrectness.require<Parent>Exists(<parent>Id)` | `<Parent>__c parent` |
| `Map<Id, <Object>__c> byId = DomainCorrectness.require<Noun>sExist(<noun>Ids)` | `Map<Id, <Object>__c> byId` (or `byId.values()`) |
| `DomainCorrectness.requireOptional<Noun>Exists(<noun>Id)` → record or `null` | `<Object>__c <noun>` — `null` when the input was blank |

```apex
// ✅ every guarded id arrives as its record
<Object>__c  from<Noun> = DomainCorrectness.require<Noun>Exists(from<Noun>Id);
<Object>__c  to<Noun>   = DomainCorrectness.require<Noun>Exists(to<Noun>Id);
<Name>Service.link<Noun>To<Noun>(from<Noun>, to<Noun>, linkType);

// ❌ guarded, then passed as an id anyway — the Service re-queries what it was handed
<Name>Service.link<Noun>To<Noun>(from<Noun>Id, to<Noun>Id, linkType);

// ❌ the record is passed but a second guarded id is not
<Name>Service.move<Noun>To<Parent>(record, <parent>Id);   // parent was guarded → pass `parent`
```

- This holds for **every** guarded parameter of the call, not just the first.
  A method that guarded three ids passes three records.
- The Service **never re-queries a record it received**, and never calls
  `DomainCorrectness` itself — the guard is a controller-phase step.
- Remaining scalars follow the same shape rule as the boundary: 2 or fewer →
  primitives; 3+ related values or a nested payload → one `<Name>Dto`.
- An id stays a raw `String` **only when no guard ran on it** — a value the
  Service just writes into a lookup field or compares in memory. If a
  `requireXxxExists` exists for it, the record wins.
- A Service cannot touch another service
**Message names — always reuse a name that already exists**

Every `<noun>` below is the **record** the guard returned, not `<noun>Id`:

`<Name>Service.update<Noun><Field>(existing, <field>)` ·
`<Name>Service.assign<Noun>(existing, <member>)` ·
`<Name>Service.move<Noun>To<Parent>(existing, <parent>)` ·
`<Name>Service.change<Noun>State(record, from<State>, to<State>, rules)` ·
`<Name>Service.link<Noun>To<Noun>(from<Noun>, to<Noun>, from<Type>, to<Type>, linkType)` ·
`<Name>Service.create<Noun>(record)` · `<Name>Service.complete<Noun>(record)` ·
`<Name>Service.load<Noun>s(<parent>)` ·
`<Owner>Service.load<Noun>By<Parent>(<parent>)`

The lone exception is a cross-Service read whose parent was **never** a guarded
input — that one still travels as `<parent>Id`
([phase 3](phase-3-persist.md) hop 3.1).

---

## Hop 2.2 — `service` → `validator`  *(call — `requireRule(data)`)*

**Signature rule**

```apex
public static void requireXxx(<already-loaded data>)          // throws on violation
public static <SObject> requireXxx(<already-loaded data>)     // returns the matched record
public static Boolean isXxx(<SObject>)                        // pure predicate, no throw
```

- Static, `public`, lives only in `classes/domain/DomainCompleteValidator.cls`.
- Named `requireXxx` — it validates one invariant and throws `ServiceException`
  when violated. `isXxx` variants return a `Boolean` and never throw.
- **No SOQL and no DML inside the validator.** It is pure in-memory logic.

**Input-format rule**

- The validator receives **data the Service already loaded** — an SObject, a
  scalar, or a `List<SObject>`. It never fetches anything itself.
- Where a validator signature still takes an id (`target<Parent>Id`,
  `from<State>Id`, `<owner>Id`), the Service reads it **off the record it was
  handed** — `require<Noun>NotInDifferent<Parent>(record, target<Parent>.Id)`.
  The Service does not keep the raw input id around to feed the validator.
- Uniqueness / FK-guard rules: **the Service asks the Dao for the rows and
  passes the result list**; the validator only asserts the list is empty. The
  `[SELECT]` itself is written in `classes/dao/<Name>Dao.cls`
  ([phase 3](phase-3-persist.md) hop 3.3), never here and never in the validator.

  ```apex
  List<<Object>__c> duplicates =
      <Name>Dao.findDuplicatesByName(record.Name, record.<Parent>__c);
  DomainCompleteValidator.require<Noun>NameUniquePer<Parent>(duplicates);
  ```
- One call per recorded rule, ordered cheapest-first so an obvious violation
  throws before more work is done.
- Bulk operations validate in memory over the collection — never one validator
  call per record inside a query loop.

**Message names — always use one of the existing methods**

`require<Noun>NameUniquePer<Parent>(duplicates)` · `require<Noun>Unique(duplicates)` ·
`requireNoActive<Noun>In<Parent>(active<Noun>)` ·
`require<Noun>IsStartable(record)` · `require<Noun>IsCompletable(record)` ·
`require<Noun>NotInDifferent<Parent>(record, target<Parent>Id)` ·
`require<Rule>Allowed(from<State>Id, to<State>Id, rules)` ·
`require<Rule>BelongsTo<Owner>(rule, <owner>Id)` ·
`require<Rule>EndpointsDifferent(from<State>Id, to<State>Id)` ·
`require<Rule>IsPending(rule)` · `require<Rule>Pass(record, <related>)` ·
`requireFrom<State>NotEnd(from<State>)` · `requireTo<State>NotStart(to<State>)` ·
`require<Related>AssignedTo<Noun>(record, <related>Id)` ·
`requireNo<Noun>sReference<Related>(referencing<Noun>s)` ·
`requireCurrentUserMemberFor<Parent>(member, userId)` ·
`requireSame<Parent>For<Noun>Link(from<Noun>, to<Noun>)` ·
`is<Condition>(record)` · `safeOffset(offset)` · `safePageSize(pageSize, defaultPageSize)`

---

## Hop 2.3 — `validator` → `service`  *(return — `ok (else throw)`)*

**Signature rule**

- Rule holds → return `void`, or the record the rule matched
  (`require<Rule>Allowed` returns the `<Rule>__c` that carries the validation
  fields for the next check).
- Rule violated → `throw new ServiceException('<what is wrong>')`.
- The Service does **not** catch this to convert it — it propagates to the
  controller's `catch`, which turns it into `APIResponse(false, message)`.

**Message names — existing throw messages**

`'A <object> with this name already exists in this <parent>'` ·
`'<Parent> already has an active <object> in progress'` ·
`'<Object> can only be started from future status, current status: ' + record.RecordStatus__c` ·
`'<Object> can only be completed from in_progress status, current status: ' + record.RecordStatus__c` ·
`'<Object> cannot be moved from one <parent> to another <parent>'` ·
`'From <State> and To <State> must be different'` ·
`'<Rule> name already exists in this <Owner>'` ·
`'<Rule> from current <state> to target <state> is not allowed by the <owner>'` ·
`'Cannot create a <rule> from an end <state>'` ·
`'Cannot create a <rule> to the start <state>'` ·
`'<Related> is not assigned to this <Object>'` ·
`'Cannot delete <Object>: ' + referencing<Noun>s.size() + ' <Related>(s) still reference it'` ·
`'Cannot link <object>s that belong to different <parent>s'` ·
`'User ' + userId + ' is not an active member of this <parent>'`

---

## Reference implementation

```apex
// Controller — hop 2.1: every guarded id crosses as its record
<Object>__c record  = DomainCorrectness.require<Noun>Exists(<noun>Id);     // phase 1
<Parent>__c parent  = DomainCorrectness.require<Parent>Exists(<parent>Id); // phase 1
<Object>__c updated = <Name>Service.move<Noun>To<Parent>(record, parent);  // not (<noun>Id, <parent>Id)
```

```apex
public static <Object>__c complete<Noun>(<Object>__c record) {
    try {
        DomainCompleteValidator.require<Noun>IsCompletable(record);   // hop 2.2 / 2.3
        record.RecordStatus__c = 'completed';
        update<Noun>(record);                                          // → next phase
        return record;
    } catch (Exception ex) {
        throw new ServiceException('Error completing <object>: ' + ex.getMessage());
    }
}
```

`classes/domain/<Name>Service.cls` ·
`classes/domain/DomainCompleteValidator.cls` · `classes/dao/<Name>Dao.cls`

---

You cannot go before check that all participant is exist
## → Next: [Phase 3 — Persist](phase-3-persist.md)

Every business rule has passed. Continue there for the DML, the cross-domain
sub-operation, and the `APIResponse` the controller returns.
