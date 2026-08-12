---
metadata:
  type: reference
  applies_to: SOSL term search only
  activation:
    mode: conditional
---

# SOSL Index Config Guide

A working term search in Salesforce is **one metadata switch and one correctly
shaped query**:

1. the **object** must be allowed into the search index —
   `<enableSearch>true</enableSearch>` in `<Object>__c.object-meta.xml`;
2. the **query** must be a SOSL `FIND` in the Dao, with the term **bound** (never
   concatenated), sanitised, and a `RETURNING` clause that names the fields, the
   soft-delete filter, the order and the limit.

There is **no per-field index switch**. Once the object is searchable, every
field whose `<type>` is indexable is indexed by Salesforce automatically — that
is why [sosl-index-desicion-guide.md](sosl-index-desicion-guide.md) classifies
types instead of looking for a flag. **No Apex trigger, no Flow, no custom
index.**

---

## Instructions

### Step 1 — Read the scratchpad first (MANDATORY — before any edit)

This guide never asks the user what to search. Everything it needs was recorded
during the interview and the decision step. Open `scratchpad-memory.md` and pull:

| Need | Read from |
|---|---|
| Confirmation this branch applies (`Outcome: A` or `Outcome: C`) | section 10 |
| The searched field set and each field's `<type>` | section 10 |
| The non-indexable fields that become a `RETURNING` filter (Outcome C only) | section 10 |
| Tab name, user story, behavior | section 1 (Tabs 1, 3, 4) |
| **Data state — object + field that provides the data** | section 7 |
| Apex class / method that runs the search, and the calling handler | section 7 |
| Event name and `Search` operation type | section 6 |
| Validation rules the term itself must pass | section 8 |

If section 10 records `Outcome: B — SOQL filter search (not by term)`, stop —
you are in the wrong branch. Go back to
[sosl-index-desicion-guide.md](sosl-index-desicion-guide.md).

---

### Step 2 — Resolve the object from the scratchpad

Derive the SObject API name from the **data state** line in section 7 first,
then the behavior and user story in section 1, then Tab 1 (a tab is usually
named after the object it manages, in plural — singularise it and add `__c`).

Confirm it exists in the repo:

```
force-app/main/default/objects/<Object>__c/<Object>__c.object-meta.xml
```

Resolution succeeds only when **one** object is identified and its
`object-meta.xml` is present. Two candidates with nothing in the scratchpad
choosing between them is not a resolution — it is a stop (Step 3b).

> Standard objects (`Account`, `Contact`, `User`, …) are always searchable and
> carry no `enableSearch` element. For a standard object, skip Step 4 entirely
> and go straight to Step 5.

---

### Step 3 — Confirm the fields are still resolvable

Section 10 already lists the searched fields with their types. Re-confirm each
one on disk:

```
force-app/main/default/objects/<Object>__c/fields/<Field>__c.field-meta.xml
```

Keep only fields that resolve to a real `field-meta.xml` **on the resolved
object**. A field named in the behavior but absent from the object is not
silently created here — it is a stop.

#### Step 3b — Stop protocol (no object, or no indexable field)

**Stop the process immediately** — do not edit metadata, do not guess, do not
open a question to fill the gap — when **either** holds:

- **no object resolved**: the scratchpad names no object, names something with no
  `object-meta.xml`, or leaves two or more objects equally likely;
- **no indexable field resolved**: no field in section 10's indexable list maps
  to a `field-meta.xml` under the resolved object's `fields/` folder.

Then tell the user, plainly and in this order:

1. **What stopped** — "no object could be resolved", or "the object resolved to
   `<Object>__c`, but none of the searched fields exist on it".
2. **What was read** — quote the section 7 data-state line and the section 10
   field list verbatim.
3. **Why that is not enough** — e.g. the behavior says "search by title" but the
   object has `Summary__c` and no `Title__c`.
4. **What unblocks it** — the object API name and the exact field API names.

Write the stop and its reason back into `scratchpad-memory.md` → section 10 so
the next run does not repeat the dead end. Do not continue to Step 4.

---

### Step 4 — Allow the object into the search index

Open `<Object>__c.object-meta.xml` and set `enableSearch`.

`<enableSearch>` is the metadata form of the object's **Allow Search** setting.
Without it, the object is not in the index at all: a `FIND … RETURNING
<Object>__c` deploys and runs, returns zero rows forever, and throws no error —
the worst failure mode in this guide.

**Case A — the element exists and is `false`:** flip it.

```xml
<!-- before -->
<enableSearch>false</enableSearch>
<!-- after -->
<enableSearch>true</enableSearch>
```

**Case B — the element is absent:** add it in alphabetical order among the
`enable*` elements — after `<enableReports>`, before `<enableSharing>`:

```xml
<!-- force-app/main/default/objects/<Object>__c/<Object>__c.object-meta.xml -->
<enableActivities>true</enableActivities>
<enableBulkApi>true</enableBulkApi>
<enableFeeds>false</enableFeeds>
<enableHistory>false</enableHistory>
<enableLicensing>false</enableLicensing>
<enableReports>true</enableReports>
<enableSearch>true</enableSearch>          <!-- ← the switch -->
<enableSharing>true</enableSharing>
<enableStreamingApi>true</enableStreamingApi>
```

**Case C — it is already `true`:** change nothing **in the file**, but still
deploy it in Step 8. `true` in the working tree is not evidence that the object
is searchable in the org — the element may have been committed and never
deployed. Deploying an unchanged object file is a no-op when the org already
agrees, and the fix when it does not.

> Enabling search backfills the index for existing rows asynchronously. Right
> after the deploy, a search can return fewer rows than the object holds. That is
> expected and resolves on its own — do not "fix" it by widening the query.

---

### Step 5 — Verify the fields, then leave them alone

There is nothing to write in any `field-meta.xml` for search. What there is, is
one last check per field before the query is built:

| # | Check | If it fails |
|---|---|---|
| 1 | The field has no `<formula>` element. | Formula fields are never indexed regardless of `<type>`. Drop it from the term set and tell the user; if it was the only field, the run falls back to Outcome B. |
| 2 | `<type>` is not `EncryptedText`. | Ciphertext is not indexed. Drop it and say so. |
| 3 | For `<type>LongTextArea</type>` / `Html`: only the leading portion (~2 000 characters) is reliably matched. | If the behavior needs a term found deep in a long body, say so up front — do not present the search as exhaustive. |
| 4 | For `<type>MultiselectPicklist</type>`: the term matches one selected value, not the packed `a;b;c` string. | Adjust the expectation in the behavior, not the query. |
| 5 | Any field used in the `RETURNING … WHERE` clause (Outcome C) is a real field on the same object. | Fix the clause; a filter field does **not** have to be indexable — it is evaluated as SOQL. |

Optionally, when the `RETURNING` clause filters or sorts on one specific field
that is highly selective, marking it `<externalId>true</externalId>` or
`<unique>true</unique>` gives that filter a custom index. This is a **SOQL**
optimisation for the filter half of Outcome C — it has no effect on what the
term matches. Only do it when the behavior actually filters on that field.

---

### Step 6 — Write the SOSL in the Dao

The Dao is the only layer in this project that touches the database
([sequence.md](../../private/back-end/sequence/sequence.md) → `dbAccessRule`) — SOSL included. A
`FIND` in a controller or a Service is the same violation as a `SELECT` there.

```apex
// classes/dao/ItemDao.cls
public with sharing class ItemDao {

    private static final Integer MIN_TERM_LENGTH = 2;
    private static final Integer MAX_RESULTS     = 50;

    public static List<Item__c> searchItems(String term, Id workspaceId) {
        String safeTerm = sanitizeSearchTerm(term);
        if (safeTerm == null) {
            return new List<Item__c>();       // too short — never a bare FIND
        }

        List<List<SObject>> results = [
            FIND :safeTerm
            IN ALL FIELDS
            RETURNING Item__c (
                Id, Name, Summary__c, Priority__c
                WHERE Workspace__c = :workspaceId
                  AND RecordStatus__c != 'deleted'
                ORDER BY Name ASC
                LIMIT :MAX_RESULTS
            )
        ];
        return (List<Item__c>) results[0];
    }

    private static String sanitizeSearchTerm(String term) {
        if (String.isBlank(term)) return null;
        String cleaned = term.trim();
        if (cleaned.length() < MIN_TERM_LENGTH) return null;
        // escape every SOSL reserved character so a stray ? * { } does not
        // become a wildcard or a malformed search
        cleaned = cleaned.replaceAll('([\\?&\\|!\\{\\}\\[\\]\\(\\)\\^~\\*:\\\\"\'\\+\\-])', '\\\\$1');
        return cleaned + '*';                 // trailing wildcard only
    }
}
```

Rules the shape above encodes — keep every one of them:

| # | Rule | Why |
|---|---|---|
| 1 | **Bind the term (`FIND :safeTerm`)** — never build the FIND by concatenating user input. | String concatenation into `Search.query()` is SOSL injection. |
| 2 | **Sanitise before binding.** | A bound value is still parsed: an unescaped `{`, `"` or `?` throws `MALFORMED_SEARCH`, and a bare `*` silently widens the search. |
| 3 | **Two characters minimum**, checked before the query. | Salesforce rejects a shorter term; returning an empty list is the graceful answer. |
| 4 | **Trailing wildcard only.** `*term` is invalid — a search term cannot begin with a wildcard. | Leading wildcards are not supported by the index. |
| 5 | **The soft-delete filter goes inside `RETURNING`.** | The rule this `Outcome` carries in with it from [sosl-index-desicion-guide.md](sosl-index-desicion-guide.md) → Step 4; the search index does not know about `RecordStatus__c`. |
| 6 | **`LIMIT` inside `RETURNING`, always.** | A SOSL query returns at most 2 000 rows across all objects; an unbounded search hands the LWC a wall of rows. |
| 7 | **Return `results[0]` cast to the object's list type.** | `FIND` returns `List<List<SObject>>`, one inner list per `RETURNING` object, in declaration order. |
| 8 | **One SOSL per user action.** The limit is 20 SOSL queries per transaction — far tighter than SOQL's 100. | A SOSL inside a loop blows the limit at 21 iterations. |

#### Scoping the FIND — what SOSL can and cannot narrow

SOSL scopes the term with `IN ALL FIELDS`, `IN NAME FIELDS`, `IN EMAIL FIELDS`,
`IN PHONE FIELDS` or `IN SIDEBAR FIELDS`. **It cannot scope to an arbitrary
custom field** — there is no `IN Summary__c`.

| Behavior recorded in section 1 | What to write |
|---|---|
| "search by name" / "find the item called…" | `IN NAME FIELDS` — the tightest, fastest scope |
| "search by email" / "by phone" | `IN EMAIL FIELDS` / `IN PHONE FIELDS` |
| any named custom field, or several fields | `IN ALL FIELDS` — and say plainly that the term may also match other indexed text on the record |
| no field named (the derived default set) | `IN ALL FIELDS` |

Do not fake a narrower scope by re-filtering the returned rows in Apex — the
row was already found and returned; filtering it out afterwards only hides the
match from the user while still burning the query.

---

### Step 7 — Respect index latency

The search index is populated **asynchronously**. A record inserted a moment ago
is not necessarily findable yet.

- **Never** insert a record and then re-read it with SOSL in the same flow to
  return it to the LWC. Return the inserted record (or re-read it by id with
  SOQL) instead.
- **Never** assert "the record now exists" from an empty SOSL result — an empty
  result means *not indexed yet or no match*, and the two are indistinguishable.
- A "search that must see the record instantly after save" requirement is a
  **SOQL** requirement. Say so, and route it back through
  [sosl-index-desicion-guide.md](sosl-index-desicion-guide.md) → Outcome B.

---

### Step 8 — Deploy the object, and nothing else

Only the object metadata changed, so only the object metadata ships. Deploying
the whole object folder drags along every unrelated field edit sitting in the
working tree.

```bash
sf project deploy start -m "CustomObject:<Object>__c"
```

**Alternative — name the exact file:**

```bash
sf project deploy start \
  -d force-app/main/default/objects/<Object>__c/<Object>__c.object-meta.xml
```

Rules for building the command:

- Substitute the object resolved in Step 2.
- **Deploy runs even when Step 4 was Case C.** A `true` already in the working
  tree proves nothing about the org; skipping the deploy is what produces the
  "search returns nothing, forever" failure.
- No field deploy belongs here — Step 5 changed no `field-meta.xml`. If you did
  set `<externalId>`/`<unique>` on a filter field, ship it as its own
  `-m "CustomField:<Object>__c.<Field>__c"` and say why.
- Never widen to `-d force-app/main/default/objects` or `-d force-app/main/default`.
- Verify first if you want a dry run: append `--dry-run`.

> **Do not run this command yourself.** Deploys against the connected org are the
> user's call — print the command, say which file it covers, and let them run it.

---

### Step 9 — Tests see no index

SOSL returns **nothing** in an Apex test unless the results are fixed. A test
that inserts rows and expects `searchItems` to find them fails for a reason that
has nothing to do with the code.

```apex
@IsTest
static void searchItemsReturnsMatch() {
    Item__c item = TestDataFactory.insertItem('Sprint planning');

    Test.setFixedSearchResults(new List<Id>{ item.Id });   // ← without this: empty

    Test.startTest();
    List<Item__c> found = ItemDao.searchItems('Sprint', item.Workspace__c);
    Test.stopTest();

    System.assertEquals(1, found.size(), 'the fixed search result should come back');
}
```

`setFixedSearchResults` forces which **ids** the `FIND` returns; the
`RETURNING … WHERE` clause is still applied on top, so the test still proves the
filter (workspace scoping, `RecordStatus__c != 'deleted'`) works. Cover at least:
the match, a term shorter than two characters, and a soft-deleted row that must
not come back.

---

### Step 10 — Verify

| # | Check | Fix if it fails |
|---|---|---|
| 1 | The object's `object-meta.xml` has `<enableSearch>true</enableSearch>` (or is a standard object) | Step 4. |
| 2 | No `field-meta.xml` was edited "to enable search" | Step 5 — there is no such switch. |
| 3 | No field in the term set carries a `<formula>` element or `<type>EncryptedText</type>` | Step 5, checks 1–2. |
| 4 | The `FIND` sits in `classes/dao/<Name>Dao.cls` — not in a controller, Service, guard or validator | Step 6. |
| 5 | The term is **bound** (`FIND :safeTerm`), never concatenated | Step 6, rule 1. |
| 6 | The term is sanitised and the two-character minimum is enforced before the query | Step 6, rules 2–3. |
| 7 | No leading wildcard anywhere in the term | Step 6, rule 4. |
| 8 | The `RETURNING` clause carries `RecordStatus__c != 'deleted'` (or the positive filter) and a `LIMIT` | Step 6, rules 5–6. |
| 9 | The `IN … FIELDS` scope matches what the behavior actually asked for, and no result is re-filtered in Apex afterwards | Step 6, scoping table. |
| 10 | Exactly one SOSL per user action — none inside a loop | Step 6, rule 8. |
| 11 | Nothing inserts a record and then searches for it in the same flow | Step 7. |
| 12 | One deploy command was produced, naming only the object file, and it was printed rather than run | Step 8. |
| 13 | The tests call `Test.setFixedSearchResults` | Step 9. |
| 14 | Section 10 of `scratchpad-memory.md` records the object, the searched fields with their types, the `IN … FIELDS` scope, and the deploy command that was produced | Write it before finishing. |

---

## Resources

### Governor limits that bite here

| Limit | Value |
|---|---|
| SOSL queries per Apex transaction | 20 |
| Records returned per SOSL query (all objects combined) | 2 000 |
| Records returned per `RETURNING` object | whatever its `LIMIT` says, within the 2 000 |
| Minimum term length | 2 characters |

### Why `LIKE '%term%'` is not the fallback

A leading wildcard cannot use an index, so the query scans every row. On a small
sandbox object it looks fine; on a populated org it is rejected outright with
`Non-selective query against large object type`. When SOSL is not available for
the field, the answer is a different **filter**, not a slower term match — see
[sosl-index-desicion-guide.md](sosl-index-desicion-guide.md) → Outcome B.
