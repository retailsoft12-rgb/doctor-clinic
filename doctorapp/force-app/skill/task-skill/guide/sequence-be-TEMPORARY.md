<!-- merged from: sequence.md (embedded in sequence-be-merge.py) -->

# Back-end sequence — doOperation() request lifecycle

```yaml
sequence:
  title: "doOperation() — request lifecycle"
  summary: "Controller → correctness check (via Dao) → Service → rule validation → persist"


  participants:
    - id: client
      name: Client
    - id: controller
      name: Controller
    - id: domainCorrectness
      name: Domain Correctness
    - id: service
      name: Service
    - id: validator
      name: DomainComplete Validator
    - id: otherService
      name: OtherService
    - id: dao
      name: Dao
    - id: db
      name: DB
      type: datastore

  layout:
    controller: >-
      classes/controller/<feature>/<Name>Controller.cls — thin @AuraEnabled
      orchestration only, no SOQL/DML business logic; every controller ships with
      a <Name>ControllerTest.cls alongside it
    service: >-
      classes/domain/<Name>Service.cls — one Service per domain object; owns the
      DML of its object and reads only through its Dao
    correctness: >-
      classes/domain/DomainCorrectness.cls — input guards; holds no SOQL, it
      resolves input ids through the Dao of the object it guards
    dao: >-
      classes/dao/<Name>Dao.cls — one Dao per domain object; the ONLY layer that
      writes SOQL for that object, query-only, no DML and no business rules
    validator: "classes/domain/DomainCompleteValidator.cls"
    dto: >-
      classes/domain/<Name>Dto.cls — composite / nested RESPONSE shapes only;
    shared: >-
      classes/shared/ — APIResponse (the envelope), ServiceException (the only
      type services throw), plus enums / utils / constants; never duplicated per
      feature

  dbAccessRule: >-
    every SOQL statement in every phase is written inside classes/dao/<Name>Dao.cls
    — the controller, DomainCorrectness, the Service and DomainCompleteValidator
    all reach the database through a Dao and never carry a [SELECT] of their own.
    DML is the one exception: it stays in the Service that owns the object.

  legend:
    call: "solid arrow — synchronous call"
    return: "dashed arrow — return value"

  entry:
    phase: "1 — input correctness"
    doc: "phase-1-input-correctness.md"
    read_when: >-
      always — start here. Each phase carries its own steps and hands off to the
      next one at the end of its file.

  errorHandling:
    scope: "any layer"
    rule: "catch (ServiceException e) → return APIResponse(false, e.message)"
```

**Entry:** → [Phase 1 — Input correctness](#phase-1--input-correctness) — always start here.
Each phase carries its own steps and hands off to the next one at the end of its section.

<!-- merged from: phase-1-input-correctness.md -->

# Phase 1 — Input correctness

Everything in this phase happens **before** the Service is touched: the parameter
list of the `@AuraEnabled` method, the blank checks, and the existence guards.
Class placement and the preconditions of the whole lifecycle are in
[sequence.md](#back-end-sequence--dooperation-request-lifecycle) → `layout` / `precondition`.

```yaml
phase: "1 — input correctness"
participants: [client, controller, domainCorrectness, dao, db]
steps:
  0 - from: client
    to: controller
    type: call
    message: "request(params)"
  1 - from: controller
    to: domainCorrectness
    type: call
    message: "requireXxxExists"
  2 - from: domainCorrectness
    to: dao
    type: call
    message: "find<Noun>ById(<noun>Id)"
  3 - from: dao
    to: db
    type: call
    message: "SELECT (exists)"
  4 - from: db
    to: dao
    type: return
    message: "rows | empty"
  5 - from: dao
    to: domainCorrectness
    type: return
    message: "record | null"
  6 - from: domainCorrectness
    to: controller
    type: return
    message: "record (else throw)"
```

**Layer split of this phase:** `DomainCorrectness` decides **meaning** (missing
→ `ServiceException`); the `Dao` holds the **query**. The guard carries no
`[SELECT]` of its own — same rule as phase 3, where the Service reads through
the Dao too.

---

## What DomainCorrectness is for (MANDATORY)

`DomainCorrectness` validates **the controller's input only** — the ids and
values that arrived in *this* request's parameter list. It is **not** used to
validate a foreign key on a record that has already been retrieved.

- ✅ **Input** — the LWC sent `<noun>Id`, `<parent>Id`, `<related>Id`:
  `DomainCorrectness.require<Noun>Exists(<noun>Id)`.
- ❌ **Not a foreign key of a retrieved record** — the `<Object>__c` is already
  in hand and you want its `<Parent>__c` / `<Related>__c` row. That id was never
  user input; it came out of the database and is already referentially valid. Do
  not re-guard it here.

When a related record is genuinely needed further down, the **owning Service**
resolves it (service isolation — see phase 2), e.g.
`<Owner>Service.find<Owner>ById(...)`,
`<Owner>Service.load<Noun>By<Parent>(...)`.

Business rules never run in this phase — they belong to
`DomainCompleteValidator`, one phase later.

---

## Hop 1.0 — `client` → `controller`  *(call — `request(params)`)*

The entry signature. This is where the input format is decided.

**Signature rule**

```apex
@AuraEnabled                       // write operation
@AuraEnabled(cacheable=true)       // pure read consumed by @wire
public static APIResponse <verbNoun>(<params>)
```

- Return type is **always** `APIResponse` — never an SObject, never `void`.
- The whole body is wrapped in `try { … } catch (Exception ex) { … }`.
- Lives in `classes/controller/<feature>/<Name>Controller.cls` — **thin
  orchestration only**: guards, then delegation. No SOQL and no DML in the
  controller: reads reach the database through a Dao, writes through a Service.
- The LWC reaches it as `@salesforce/apex/<Controller>.<method>`; the method must
  exist before the LWC imports it.

**Input-format rule — SEPARATED inputs (MANDATORY)**

The controller boundary takes **one primitive parameter per value the LWC
sends**, whatever the count. There is no wrapper at this hop.

```apex
// ✅ separated inputs — one parameter per value
public static APIResponse link<Noun>To<Noun>(String from<Noun>Id, String to<Noun>Id, String linkType)

// ❌ never at the controller boundary
public static APIResponse link<Noun>To<Noun>(<Name>Dto dto)
public static APIResponse link<Noun>To<Noun>(Map<String, Object> params)
```

- Ids are typed `String` at the boundary, cast/validated inside — never `Id`.
- A parameter name matches, character for character, the key the LWC sends in
  its `{ ... }` call payload — `@salesforce/apex` binds by name.
- Many values do **not** justify a wrapper: a 5-input method declares 5
  parameters, each one blank-checked (hop 1.1) and guarded (hop 1.2) on its own.
- A **collection** of one kind of value is still a separated input —
  `List<String> <noun>Ids` / `Set<Id> <noun>Ids` — one parameter, resolved by
  the bulk guard.
- `classes/domain/<Name>Dto.cls` stays a **response-only** shape: it is what the
  Service returns for a composite/nested result, never what the controller
  accepts. This rule is phase 1 only — the Service in
  [phase 2](#phase-2--delegate-to-service) keeps its own input rules.

**Message names — always reuse a name that already exists**

`load<Noun>s(<parent>Id)` · `get<Noun>s(<parent>Id)` · `create<Noun>(name)` ·
`update<Noun><Field>(<noun>Id, <field>)` ·
`move<Noun>To<Parent>(<noun>Id, <parent>Id)` ·
`link<Noun>To<Noun>(from<Noun>Id, to<Noun>Id, linkType)` ·
`change<Noun>State(<noun>Id, from<State>Id, to<State>Id)` ·
`load<Noun>BySearchTerm(<parent>Id, searchTerm, exclude<Noun>Id)`

---

## Hop 1.1 — `controller` → `domainCorrectness`  *(call — `requireXxxExists`)*

Runs **after** the blank checks, **before** the Service call.

**Blank checks first — one per required field**

```apex
if (String.isBlank(<noun>Id))    return new APIResponse(false, '<noun>Id is required');
if (String.isBlank(from<State>Id)) return new APIResponse(false, 'from<State>Id is required');
if (String.isBlank(to<State>Id))   return new APIResponse(false, 'to<State>Id is required');
```

Message format is fixed: `'<field> is required'`.

**Signature rule**

```apex
public static <SObject> requireXxxExists(String xxxId)          // returns the record
public static void       requireOptionalXxxExists(String xxxId) // no-ops on blank
public static Map<Id, <SObject>> requireXxxsExist(Set<Id> ids)  // bulk input
```

- Static, `public`, lives only in `classes/domain/DomainCorrectness.cls`.
- Takes the **raw input value** — one separated parameter as declared at the
  boundary (`String` id, or `Set<Id>` for a bulk input) — never a retrieved
  SObject and never a wrapper.
- Returns the record so the controller can hand it to the Service; throws
  `ServiceException` when missing.
- **No SOQL in the guard body.** The row comes from `<Name>Dao` (hop 1.2); the
  guard only decides what an empty result means.
- Add a new `requireXExists` here only when the request introduces a new object.
  If the object has no Dao yet, create `classes/dao/<Name>Dao.cls` first — the
  guard never falls back to an inline query.

**Input-format rule**

- One call per **input** id, in the order the parameters are declared.
- Optional inputs use the `requireOptionalXxxExists` variant, which no-ops on
  blank instead of throwing.
- A collection parameter carrying many ids calls the bulk variant once
  (`require<Noun>sExist(<noun>Ids)`), never a guard inside a loop.

**Message names — always use one of the existing methods**

`require<Noun>Exists(<noun>Id)` · `require<Noun>ExistsByName(<name>, <parent>Id)` ·
`require<Noun>sExist(<noun>Ids)` · `requireOptional<Noun>Exists(<noun>Id)` ·
`require<Noun>Active(<noun>Id)` · `requireOptional<Noun>Active(<noun>Id)` ·
`require<Noun>BelongsTo<Parent>(<noun>Id, <parent>Id)` · `requireUserExists(userId)`

---

## Hop 1.2 — `domainCorrectness` → `dao`  *(call — `find<Noun>ById(<noun>Id)`)*

The guard does not query. It asks the Dao of the object it is guarding for the
row, exactly as the Service does in phase 3.

**Signature rule**

```apex
public with sharing class <Name>Dao {
    public static <Object>__c           find<Noun>ById(String recordId)   // null when absent
    public static Map<Id, <Object>__c>  find<Noun>ByIds(Set<Id> ids)      // bulk input
}
```

- One Dao per domain object, in `classes/dao/<Name>Dao.cls` — the same class the
  Service reads through in [phase 3](#phase-3--persist) hop 3.2. A guard reuses
  the existing finder before adding one.
- **Query only.** The Dao does not throw, does not build a message, and does not
  know it is being called by a guard.

**Input-format rule**

- Pass the **raw input value** through unchanged — the `String` id from the
  parameter list, or the `Set<Id>` from a bulk input parameter.
- One Dao call per guard, **outside** any loop: a payload of many ids calls
  `find<Noun>ByIds(ids)` once, never `find<Noun>ById` per element
  ([guard/apex-governor-limit-guard](../../guard/apex-governor-limit-guard.md)).
- The Dao method must select the fields the **Service** reads downstream — the
  guard's return value is what the Service receives.

**Message names — existing shapes**

`<Name>Dao.find<Noun>ById(<noun>Id)` · `<Name>Dao.find<Noun>ByIds(<noun>Ids)` ·
`<Name>Dao.find<Noun>ByName(<name>, <parent>Id)` ·
`<Name>Dao.find<Noun>By<Parent>(<noun>Id, <parent>Id)`

---

## Hop 1.3 — `dao` → `db`  *(call — `SELECT (exists)`)*

The **only** place a SOQL statement is written for that object — in this phase
and every other.

**Input-format rule**

- Bind the input id: `WHERE Id = :xxxId LIMIT 1` (single) or `WHERE Id IN :ids`
  (bulk). One query per Dao method, never a query inside a loop.
- Select only what the caller needs downstream, plus `Id`; add `LIMIT` on any
  existence check.
- Objects carrying `RecordStatus__c` add `AND RecordStatus__c != 'deleted'`
  ([soql-exclude-deleted-guide](soql-exclude-deleted-guide.md)).

**Message names — existing shapes**

`SELECT Id, Name FROM <Object>__c WHERE Id = :<noun>Id LIMIT 1` ·
`SELECT … FROM <Object>__c WHERE Id = :<noun>Id AND RecordStatus__c != 'deleted' LIMIT 1` ·
`SELECT … FROM <Object>__c WHERE Id IN :<noun>Ids AND RecordStatus__c != 'deleted'` ·
`SELECT … FROM <Object>__c WHERE Id = :<noun>Id AND <Parent>__c = :<parent>Id LIMIT 1`

---

## Hop 1.4 — `db` → `dao`  *(return — `rows | empty`)*

**Format rule** — the query lands in a `List<SObject>` (or a `Map<Id, SObject>`
in bulk), never a single-row assignment that throws `QueryException` on empty.

---

## Hop 1.5 — `dao` → `domainCorrectness`  *(return — `record | null`)*

**Format rule**

| Guard | Dao returns |
|---|---|
| single input id | `<Object>__c` — or `null` when nothing matched |
| bulk input ids | `Map<Id, <Object>__c>` — empty map, never `null` |

- The Dao hands back **raw rows**. It never throws `ServiceException` and never
  translates a miss into a message — that is the guard's job in the next hop.

---

## Hop 1.6 — `domainCorrectness` → `controller`  *(return — `record (else throw)`)*

**Signature rule**

- Found → return the record the Dao gave back (or the populated
  `Map<Id, SObject>`).
- Missing → `throw new ServiceException('<Object> not found: ' + id)` —
  `ServiceException` only, never a bare `Exception`.
- Bulk guards assert **every** requested id is a key of the returned map before
  returning — `containsKey` in memory, never a second query.

**Message names — existing throw messages**

`'<Object> not found'` · `'<Object> not found: ' + <noun>Id` ·
`'<Object> not found: ' + <name>` ·
`'<Object> not found or deleted: ' + <noun>Id` ·
`'<Object> does not belong to the specified <Parent>'` ·
`'User does not exist'`

The controller does not catch this individually — it lands in the method's
`catch (Exception ex)` and becomes
`new APIResponse(false, 'Error <doing X>: ' + ex.getMessage())`.

---

## Where the rules come from

The input rules enforced in this phase are the **Tab 5a — input validation
rules** answer recorded in `scratchpad-memory.md` (section 1, consolidated in
section 7). Read them from the file; never re-ask
(CLAUDE.md → "Ask ONLY in the caller"). The **Tab 5b** business-logic answers do
not belong here — they are the next phase's.

---

## Reference implementation

```apex
// Controller — hops 1.0 / 1.1
@AuraEnabled
public static APIResponse link<Noun>To<Noun>(String from<Noun>Id, String to<Noun>Id, String linkType) {
    try {
        if (String.isBlank(from<Noun>Id)) return new APIResponse(false, 'from<Noun>Id is required');
        if (String.isBlank(to<Noun>Id))   return new APIResponse(false, 'to<Noun>Id is required');
        if (String.isBlank(linkType))     return new APIResponse(false, 'linkType is required');

        <Object>__c from<Noun> = DomainCorrectness.require<Noun>Exists(from<Noun>Id);
        <Object>__c to<Noun>   = DomainCorrectness.require<Noun>Exists(to<Noun>Id);
        // → next phase
    } catch (Exception ex) {
        return new APIResponse(false, 'Error linking <object>: ' + ex.getMessage());
    }
}
```

```apex
// DomainCorrectness — hops 1.2 / 1.6 (no SOQL here; meaning only)
public static <Object>__c require<Noun>Exists(String <noun>Id) {
    <Object>__c record = <Name>Dao.find<Noun>ById(<noun>Id);          // 1.2 → 1.5
    if (record == null) {
        throw new ServiceException('<Object> not found: ' + <noun>Id);
    }
    return record;
}

public static Map<Id, <Object>__c> require<Noun>sExist(Set<Id> <noun>Ids) {
    Map<Id, <Object>__c> byId = <Name>Dao.find<Noun>ByIds(<noun>Ids);  // one call, outside any loop
    for (Id <noun>Id : <noun>Ids) {                                    // in-memory check, no SOQL
        if (!byId.containsKey(<noun>Id)) {
            throw new ServiceException('<Object> not found: ' + <noun>Id);
        }
    }
    return byId;
}
```

```apex
// Dao — hops 1.3 / 1.4 (the query lives here, and only here)
public with sharing class <Name>Dao {
    public static <Object>__c find<Noun>ById(String recordId) {
        List<<Object>__c> rows = [SELECT Id, Name, <Field>__c
                                  FROM <Object>__c
                                  WHERE Id = :recordId
                                    AND RecordStatus__c != 'deleted'
                                  LIMIT 1];
        return rows.isEmpty() ? null : rows[0];
    }

    public static Map<Id, <Object>__c> find<Noun>ByIds(Set<Id> ids) {
        return new Map<Id, <Object>__c>([SELECT Id, Name, <Field>__c
                                         FROM <Object>__c
                                         WHERE Id IN :ids
                                           AND RecordStatus__c != 'deleted']);
    }
}
```

`classes/controller/<feature>/<Name>Controller.cls` ·
`classes/domain/DomainCorrectness.cls` · `classes/dao/<Name>Dao.cls`

---

## → Next: [Phase 2 — Delegate to service](#phase-2--delegate-to-service)

The controller now holds the **resolved records**. Continue there for the
signature and input format of the Service call and the business-rule check.

<!-- merged from: phase-2-delegate-to-service.md -->

# Phase 2 — Delegate to service

The controller arrives here holding **resolved records**, not raw ids. Class
placement and the preconditions of the whole lifecycle are in
[sequence.md](#back-end-sequence--dooperation-request-lifecycle) → `layout` / `precondition`.

```yaml
phase: "2 — delegate to service"
participants: [controller, service, validator]
steps:
  1 - from: controller
    to: service
    type: call
    message: "doOperation(record, related, params)"
  2 - from: service
    to: validator
    type: call
    message: "requireRule(data)"
  3 - from: validator
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
[phase 1](#phase-1--input-correctness) is passed to the Service as the SObject
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
([phase 3](#phase-3--persist) hop 3.1).

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
  ([phase 3](#phase-3--persist) hop 3.3), never here and never in the validator.

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

## → Next: [Phase 3 — Persist](#phase-3--persist)

Every business rule has passed. Continue there for the DML, the cross-domain
sub-operation, and the `APIResponse` the controller returns.

<!-- merged from: phase-3-persist.md -->

# Phase 3 — Persist

Every business rule has already passed; this phase reads what the write needs,
writes, and returns. Class placement and the preconditions of the whole
lifecycle are in [sequence.md](#back-end-sequence--dooperation-request-lifecycle) → `layout` / `precondition`.

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
  [guard/apex-governor-limit-guard](../../guard/apex-governor-limit-guard.md)
  and [performance/apex-bulk-soql](../../performance/apex-bulk-soql.md).

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
  ([soql-exclude-deleted-guide](soql-exclude-deleted-guide.md)).
- Never inside a `for` — see
  [performance/apex-bulk-soql](../../performance/apex-bulk-soql.md) and
  [guard/apex-governor-limit-guard](../../guard/apex-governor-limit-guard.md).

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
  ([soql-exclude-deleted-guide](soql-exclude-deleted-guide.md)).

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
[performance/apex-method-monitor](../../performance/apex-method-monitor.md) —
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
