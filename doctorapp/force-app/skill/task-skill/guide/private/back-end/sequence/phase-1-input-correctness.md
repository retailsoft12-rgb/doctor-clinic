# Phase 1 — Input correctness

Everything in this phase happens **before** the Service is touched: the parameter
list of the `@AuraEnabled` method, the blank checks, and the existence guards.
Class placement and the preconditions of the whole lifecycle are in
[sequence.md](sequence.md) → `layout` / `precondition`.

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
  [phase 2](phase-2-delegate-to-service.md) keeps its own input rules.

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
  Service reads through in [phase 3](phase-3-persist.md) hop 3.2. A guard reuses
  the existing finder before adding one.
- **Query only.** The Dao does not throw, does not build a message, and does not
  know it is being called by a guard.

**Input-format rule**

- Pass the **raw input value** through unchanged — the `String` id from the
  parameter list, or the `Set<Id>` from a bulk input parameter.
- One Dao call per guard, **outside** any loop: a payload of many ids calls
  `find<Noun>ByIds(ids)` once, never `find<Noun>ById` per element
  ([guard/apex-governor-limit-guard](../../../../../guard/apex-governor-limit-guard.md)).
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
  ([soql-exclude-deleted-guide](../../../soql-exclude-deleted-guide.md)).

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

## → Next: [Phase 2 — Delegate to service](phase-2-delegate-to-service.md)

The controller now holds the **resolved records**. Continue there for the
signature and input format of the Service call and the business-rule check.
