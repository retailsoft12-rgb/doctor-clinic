---
activation:
  mode: cross-cutting
  source: CLAUDE.md
---

# SOQL: Exclude Soft‑Deleted Records

Custom objects in this project use a soft‑delete pattern: deletion sets
`RecordStatus__c = 'deleted'` rather than removing the row. That **write** is a
DML and stays in the Service that owns the object (`ItemService.deleteItem`,
`BucketService.deleteBucket`). The matching **read** filter is what this skill
enforces, and it belongs one layer down, in the Dao.

A Dao method that omits the `RecordStatus__c != 'deleted'` filter returns
**stale, logically‑deleted records** to every caller above it — the guard, the
Service, the validator, the LWC — and silently corrupts every downstream
calculation (weight rollups, board counts, links, exports).

This skill is the guardrail that prevents that leak. Every retrieval must
filter out deleted rows in the Dao's SOQL — never in the Service after the
fact, and never by re‑filtering the list the Dao returned.

---

## Where this skill applies (layer rule)

| Layer | Class | Does it carry SOQL? | This skill applies? |
|---|---|---|---|
| Controller | `classes/controller/<feature>/<Name>Controller.cls` | no | no — if you find a `[SELECT]` here, move it to a Dao |
| Domain correctness | `classes/domain/DomainCorrectness.cls` | no — calls `<Name>Dao.find<Noun>ById` | no — fix the Dao method it calls |
| Service | `classes/domain/<Name>Service.cls` | no for reads (calls its Dao); **yes for DML** | no — but its soft‑delete DML writes `'deleted'` |
| Validator | `classes/domain/DomainCompleteValidator.cls` | no — pure in‑memory | no |
| **Dao** | **`classes/dao/<Name>Dao.cls`** | **yes — the only layer that does** | **yes — every method** |

If a query turns up outside `classes/dao/`, the fix is not to add the filter
where it sits: move the query into the object's Dao first, then apply Step 2
there.

---

## Instructions

### Step 1 — Detect a query that needs the filter

Before finalizing any Dao method that contains `[SELECT ... FROM ...]`, scan
it for these signals. If **any** match, the query must be rewritten in Step 2:

| # | Signal | Example |
|---|--------|---------|
| 1 | `[SELECT ... FROM <Object>__c WHERE Id = :id]` with no `RecordStatus__c` clause | `ItemDao.findItemById`, `BucketDao.findBucketById` — including the one behind `DomainCorrectness.requireItemExists` |
| 2 | `[SELECT ... FROM <Object>__c WHERE <FK>__c = :parentId]` with no `RecordStatus__c` clause | "load by bucket", "load by workspace" |
| 3 | Subquery in a parent SELECT: `(SELECT ... FROM Children__r)` with no filter | parent‑with‑children loaders |
| 4 | Aggregate (`COUNT()`, `SUM()`) over a custom object with no `RecordStatus__c` filter | rollups, dashboards |
| 5 | Bulk finder `WHERE Id IN :ids` with no filter | `ItemDao.findItemsByIds` behind a bulk guard |
| 6 | Filter is `RecordStatus__c = 'active'` only, but the object's lifecycle has more states (e.g. `completed`, `in_progress`) that callers expect | `BucketDao.findActiveBucket`, `BucketDao.findUncompletedBucketsByWorkspace` |

---

### Step 2 — Rewrite the query to exclude deletes

Apply whichever variant fits the caller's intent:

**Variant A — exclude only deleted rows** (the default; preserves all other
lifecycle states):

```apex
WHERE Id = :itemId AND RecordStatus__c != 'deleted'
```

**Variant B — restrict to a specific live status** (only when the caller
genuinely wants one state, e.g. unassigned/board views):

```apex
WHERE Bucket__c = :bucketId AND RecordStatus__c = 'active'
```

Pick the variant by asking: *"if a row had `RecordStatus__c = 'completed'`,
should this query return it?"* If yes → Variant A. If no → Variant B.

Whichever variant you pick, it goes in the Dao's `WHERE` clause. Never filter
the returned list in the Service — that still burns the query and still counts
the deleted rows against the row limit.

---

### Step 3 — Reference rewrites

The Dao methods below show the pattern correctly applied and the gaps this
skill exists to close.

#### ✅ Already compliant — use these as the template

```apex
// classes/dao/ItemDao.cls
public with sharing class ItemDao {

    public static List<Item__c> findUnassignedItems(Id workspaceId, Set<Id> typeIds,
                                                    Integer offset, Integer pageSize) {
        return [
            SELECT Id, Name, Summary__c, Weight__c
            FROM Item__c
            WHERE ItemType__c IN :typeIds
              AND RecordStatus__c = 'active'           // ← Variant B: only active
              AND Bucket__c = null
            ORDER BY Priority__c ASC, EndDate__c DESC
            LIMIT :pageSize OFFSET :offset
        ];
    }

    public static List<SubItem__c> findSubItemsByItem(Id itemId) {
        return [
            SELECT Id, Name, Summary__c
            FROM SubItem__c
            WHERE Item__c = :itemId
              AND RecordStatus__c != 'deleted'         // ← Variant A: exclude deleted
            ORDER BY CreatedDate DESC
        ];
    }
}
```

```apex
// classes/dao/ItemTypeDao.cls
public static List<ItemType__c> findItemTypesByWorkspace(Id workspaceId) {
    return [
        SELECT Id, Name
        FROM ItemType__c
        WHERE Workspace__c = :workspaceId
          AND RecordStatus__c != 'deleted'             // ← Variant A
        ORDER BY Name ASC
    ];
}
```

#### ❌ Non‑compliant — must be rewritten

**The guard path** — `DomainCorrectness.requireItemExists` looks clean, but the
leak is in the Dao method it calls. Fix the Dao, not the guard:

```apex
// classes/domain/DomainCorrectness.cls — unchanged, carries no SOQL
public static Item__c requireItemExists(String itemId) {
    Item__c item = ItemDao.findItemById(itemId);
    if (item == null) throw new ServiceException('Item not found: ' + itemId);
    return item;
}

// classes/dao/ItemDao.cls
// BEFORE — the guard happily resolves a deleted item
public static Item__c findItemById(String itemId) {
    List<Item__c> rows = [
        SELECT Id, Name, Summary__c, RecordStatus__c
        FROM Item__c
        WHERE Id = :itemId
        LIMIT 1
    ];
    return rows.isEmpty() ? null : rows[0];
}

// AFTER — Variant A applied; the guard now throws 'Item not found' for a
// soft-deleted id, which is exactly what the caller expects
public static Item__c findItemById(String itemId) {
    List<Item__c> rows = [
        SELECT Id, Name, Summary__c, RecordStatus__c
        FROM Item__c
        WHERE Id = :itemId AND RecordStatus__c != 'deleted'
        LIMIT 1
    ];
    return rows.isEmpty() ? null : rows[0];
}
```

**The bulk guard path** — same leak, one query wide:

```apex
// classes/dao/ItemDao.cls
// BEFORE — a bulk guard's containsKey check passes for deleted ids
public static Map<Id, Item__c> findItemsByIds(Set<Id> ids) {
    return new Map<Id, Item__c>([SELECT Id, Name FROM Item__c WHERE Id IN :ids]);
}

// AFTER — Variant A applied
public static Map<Id, Item__c> findItemsByIds(Set<Id> ids) {
    return new Map<Id, Item__c>([
        SELECT Id, Name FROM Item__c
        WHERE Id IN :ids AND RecordStatus__c != 'deleted'
    ]);
}
```

**The service read path** — the rows that feed a write:

```apex
// classes/dao/ItemDao.cls
// BEFORE — the Service clears the bucket pointer on deleted items too (wasted DML)
public static List<Item__c> findItemsByBucket(Id bucketId) {
    return [SELECT Id, Bucket__c FROM Item__c WHERE Bucket__c = :bucketId];
}

// AFTER — Variant A applied
public static List<Item__c> findItemsByBucket(Id bucketId) {
    return [
        SELECT Id, Bucket__c FROM Item__c
        WHERE Bucket__c = :bucketId AND RecordStatus__c != 'deleted'
    ];
}
```

---

### Step 4 — Verify with the checklist

Before presenting the rewritten code, walk this checklist. If any row fails,
go back to Step 2:

| # | Check | Fix if it fails |
|---|-------|-----------------|
| 1 | Every `[SELECT]` in the change sits in `classes/dao/<Name>Dao.cls` — none in a controller, Service, guard or validator | Move the query into the object's Dao, then apply the filter there. |
| 2 | Every `[SELECT ... FROM <Object>__c]` (where the object has `RecordStatus__c`) has either `RecordStatus__c != 'deleted'` or `RecordStatus__c = '<live state>'` in its `WHERE` clause | Add the appropriate filter (Variant A or B). |
| 3 | Every Dao method reached by a `DomainCorrectness.require<Noun>Exists` guard carries the filter | Add Variant A — otherwise the guard resolves deleted rows as valid input. |
| 4 | Every relationship subquery (`(SELECT ... FROM Children__r)`) has the same filter | Add `WHERE RecordStatus__c != 'deleted'` to the inner SELECT. |
| 5 | Every aggregate/`COUNT()` query carries the filter | Same as #2. |
| 6 | Variant B (`= 'active'`) is only used where the caller truly wants one state, not as a shortcut | Switch to Variant A (`!= 'deleted'`) when other live states (`completed`, `in_progress`, etc.) should be included. |
| 7 | No caller re‑filters `RecordStatus__c` in Apex after the Dao returned | Move the condition into the Dao's `WHERE` clause. |
| 8 | If the query intentionally reads deleted rows (audit/restore), a single‑line comment in the Dao justifies it | Add `// intentional: includes RecordStatus__c='deleted' for <reason>`. |
| 9 | Functional behaviour preserved — the guard's null branch and the Service's empty‑list branch still work after the filter | Re‑test the empty‑result branch. |

---

## Resources

### Objects with `RecordStatus__c` in this project

Item__c, SubItem__c, Bucket__c, Topic__c (via store contract), ItemLink__c,
ItemType__c, WorkspaceMember__c, TopicLink__c (via IsActive),
ValidationRule__c, WorkflowTransition__c.

If a new custom object is added with a `RecordStatus__c` field, this skill
applies to its Dao automatically — no edit needed.

### Lifecycle values seen in this codebase

| Value | Set by | Example |
|---|---|---|
| `active` | default on insert | `prepareItemForInsert` sets `item.RecordStatus__c = 'active'` |
| `deleted` | soft‑delete DML in the Service | `ItemService.deleteItem`, `BucketService.deleteBucket` |
| `in_progress` | bucket start | `BucketService.startBucket` |
| `completed` | bucket complete | `BucketService.completeBucket` |

Variant A (`!= 'deleted'`) is the safe default because it admits every live
state — present and future — without code changes. Reach for Variant B only
when the view truly wants one state.

---

## Optional Logic

### Pair with `apex-bulk-soql`

When bulkifying a method via the `apex-bulk-soql` skill, the single bulk query
moves into a Dao method and this filter goes on **that** query — not on the
per‑record query you're removing:

```apex
// classes/dao/XDao.cls
public static Map<Id, X__c> findXByIds(Set<Id> ids) {
    return new Map<Id, X__c>([
        SELECT Id, /* every field the caller reads */
        FROM X__c
        WHERE Id IN :ids AND RecordStatus__c != 'deleted'   // ← this skill
    ]);
}
```

### When the filter is legitimately omitted

A Dao query may omit `RecordStatus__c != 'deleted'` only when:

- The intent is to read deleted rows (audit log, restore UI, admin tooling).
- The object has no `RecordStatus__c` field (e.g. `Workspace__c`) — say so in
  the Dao's class comment so the next reader doesn't hunt for a missing filter.
- The filter is already enforced by a stricter clause that implies live state
  (e.g. `WHERE Id IN :liveIds` where `liveIds` was produced by a prior
  filtered query — but even here, a defence‑in‑depth filter is cheap and
  preferred).

In the audit/restore case, add a one‑line comment in the Dao method so future
readers don't "fix" the query and reintroduce the leak.
