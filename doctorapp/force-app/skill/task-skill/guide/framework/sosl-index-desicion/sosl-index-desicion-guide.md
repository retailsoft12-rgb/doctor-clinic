---
metadata:
  type: reference
  applies_to: search / lookup / filter functionality that matches a typed term
  activation:
    mode: conditional
---

# SOSL Index Decision Guide

Entry point for every "let the user type something and find the matching
records" requirement. Two engines can serve it and they are not
interchangeable:

| Engine | Matches | Needs |
|---|---|---|
| **SOSL** (`FIND {term} RETURNING ...`) | a typed term, against the **search index** | every searched field's type must be indexable, and the object must allow search |
| **SOQL** (`SELECT ... WHERE ...`) | exact values, ranges, `IN` sets | nothing — but it cannot match a term across arbitrary fields without a non-selective `LIKE '%…%'` scan |

Unlike [history-decision-guide.md](../history-desicion/history-decision-guide.md),
**no interview produced this decision**. It is derived here, from metadata that
is already on disk: the field's `<type>` element decides the branch. This guide
therefore asks the user **nothing** — it reads, classifies, records, and routes.

Exactly one reference is loaded per run. The branch that does not apply is never
read.

---

## Instructions

### Step 1 — Read the request (MANDATORY — first action)

Open `scratchpad-memory.md` from the session scratchpad directory and pull:

| Need | Read from |
|---|---|
| Confirmation a term search exists at all | section 10 (`Triggered:`), or the behavior in section 1 (Tab 4 / Tab 6) when the caller kept no section 10 |
| The verbatim phrase that asked for the search | section 10, or section 1 |
| **The fields the term is matched against** | section 10 → `Fields named for the search`, then section 7 (data state), then the behavior in section 1 |
| The object being searched | section 7 (data state), then Tab 1 (tab name) |
| Where the search runs from (handler / event) | section 6 — the event operation type is `Search` |

Do **not** ask the user which fields to search, which engine to use, or whether
a field is indexed. Every one of those is answerable from the recorded behavior
plus the object's metadata in this repo.

**Gate — stop before classifying if any of these hold:**

- `scratchpad-memory.md` does not exist, or records no search requirement → stop.
  This guide does not apply; nothing here starts a search feature on its own.
- The recorded search is **not by term** — the user picks a value from a
  picklist, a date range, a checkbox, or a lookup id → stop. That is an ordinary
  filtered read: follow the back-end phases, and do not open the SOSL config
  reference.
- The object cannot be resolved to a real
  `force-app/main/default/objects/<Object>__c/<Object>__c.object-meta.xml` → stop
  and report it, the same way
  [field-tracking-history-configuration-guide.md](../history-desicion/field-tracking-history-configuration-guide.md)
  → Step 3b does. Do not guess an object.

---

### Step 2 — Collect the fields the term is matched against

Two cases, and only two.

#### Case 1 — no field is named for the search

The behavior says "search items", "find by keyword", "type to filter" and never
names a field.

**Build the default field set from field types, not from a guess.** List every
field on the resolved object and keep the ones whose `<type>` appears in the
**indexable** column of Step 3:

```bash
grep -l "<type>\(Text\|TextArea\|LongTextArea\|Html\|Email\|Phone\|Url\|AutoNumber\)</type>" \
  force-app/main/default/objects/<Object>__c/fields/*.field-meta.xml
```

Add the object's Name field (the standard `Name`, or the field carrying
`<isNameField>true</isNameField>`) — it is indexed and is what users expect a
bare term to hit first.

That kept list **is** the searched field set. Record it in section 10 as
`Fields (derived — none named)` with each field and its type, so the next reader
sees what the default resolved to instead of re-deriving it.

If the kept list is empty — the object carries no indexable field at all — the
outcome is **B** (Step 4), not an empty SOSL.

#### Case 2 — fields are named for the search

The behavior names them ("search by summary", "find by name or email", "filter
on the code"). Take exactly those, resolve each to

```
force-app/main/default/objects/<Object>__c/fields/<Field>__c.field-meta.xml
```

and drop any that has no file on disk — reporting which ones were dropped and
why. A field named in the behavior but absent from the object is never created
here.

---

### Step 3 — Classify each field's `<type>`

Read the `<type>` element out of each resolved `field-meta.xml`. The metadata
value — not the label in the UI — decides the branch.

#### ✅ Indexable by SOSL

| `<type>` in `field-meta.xml` | Field type | Note |
|---|---|---|
| `Text` | Text | the common case; also the Name field |
| `TextArea` | Text Area | |
| `LongTextArea` | Text Area (Long) | indexed, but only the first ~2 000 characters are reliably matched |
| `Html` | Text Area (Rich) | markup is stripped before indexing |
| `Email` | Email | |
| `Phone` | Phone | punctuation is normalised, so `+1 (555)` matches `1555` |
| `Url` | URL | |
| `AutoNumber` | Auto Number | |
| `MultiselectPicklist` | Multi-select Picklist | matched value-by-value |

#### ❌ Not indexable — a term can never match these

| `<type>` in `field-meta.xml` | Field type | Why it fails |
|---|---|---|
| `Number`, `Currency`, `Percent` | numeric | not in the search index — compare them, don't search them |
| `Date`, `DateTime`, `Time` | date/time | same — these belong in a range filter |
| `Checkbox` | Checkbox | two values; a term search over a boolean is meaningless |
| `Location` | Geolocation | use a distance filter |
| `Summary` | Roll-Up Summary | derived at query time, never indexed |
| *(any type, with a `<formula>` element)* | Formula | computed at read time, never indexed — **check for `<formula>` before trusting `<type>`, a text formula still says `Text`** |
| `EncryptedText` | Encrypted Text (Classic) | ciphertext is not indexed |
| `Lookup`, `MasterDetail` | relationship | the term never matches an id; to match the **parent's** name, return the parent object in its own `RETURNING` clause instead |

#### ⚠️ Verify before relying on it

| `<type>` | Why |
|---|---|
| `Picklist` (single-select) | searchable on most objects, but not guaranteed across every object/edition. Treat a single-select picklist as a **SOQL equality filter** (`WHERE Status__c = :value`) — that is both correct and selective — and keep it out of the term set. |

---

### Step 4 — Produce the outcome

Split the searched field set from Step 2 by the classification in Step 3, then
read the outcome off this table:

| Indexable fields | Non-indexable fields | Outcome |
|---|---|---|
| one or more | none | **A — SOSL term search** |
| none | one or more | **B — SOQL filter search (not by term)** |
| one or more | one or more | **C — SOSL term + SOQL filter** |

- **Outcome A** — every field the term touches is in the index. The term search
  runs as SOSL over exactly those fields.
- **Outcome B** — nothing the user wants to match is indexable. **The feature
  stops being a term search.** It becomes a filtered read: equality, `IN`, and
  range predicates on the real field types, driven by a picklist / number input /
  date picker in the LWC rather than a free-text box.
- **Outcome C** — the term matches the indexable subset via SOSL, and the
  non-indexable fields become a `WHERE` clause **inside** the `RETURNING`
  clause, which SOSL supports natively:

  ```apex
  FIND :term IN ALL FIELDS
  RETURNING Item__c (Id, Name, Summary__c
                     WHERE Weight__c >= :minWeight
                       AND RecordStatus__c != 'deleted'
                     ORDER BY Name ASC LIMIT 50)
  ```

#### The rule every outcome carries

Whichever outcome is recorded, the read it produces still excludes soft-deleted
rows — [soql-exclude-deleted-guide.md](../../soql-exclude-deleted-guide.md) is
cross-cutting and applies to all three:

| Outcome | Where the filter lands |
|---|---|
| **A** | inside the SOSL `RETURNING` clause — the search index does not know about `RecordStatus__c` |
| **B** | the Dao's `WHERE` clause, like any other filtered read |
| **C** | inside `RETURNING`, alongside the non-indexable `WHERE` predicates |

This rule is stated **here and only here**. The branch reference does not repeat
it — it applies it. Attach it to the `Outcome` you record in section 10, so the
run that opens the branch carries the rule in with the decision rather than
re-reading this guide for it.

**Write to `scratchpad-memory.md` → section 10** before routing: the searched
field set with each field's `<type>`, which fields fell on each side, the
`Outcome`, and the rule from the table above that produced it. Also set
`Search approach:` in the file header. This happens for every outcome — the
memory file is the record of what was decided and why.

---

### Step 5 — Route on `Outcome`

Open **one** reference — the row that matches the recorded `Outcome`.

---

## 🗂️ [SOSL Index Config Guide](sosl-index-config-guide.md)

**READ when:** section 10 records `Outcome: A — SOSL term search` **or**
`Outcome: C — SOSL term + SOQL filter`.

**Contains:** how to switch the object to `<enableSearch>true</enableSearch>`,
why there is no per-field search switch to set, the narrow deploy command that
ships only the searchable-object metadata, the Dao-layer SOSL method shape with
a bound search term, term sanitising and the two-character minimum, the
`RETURNING` clause with the soft-delete filter, the SOSL governor limits, the
index-latency rule, and `Test.setFixedSearchResults` for the tests.

**This is the only branch with a configuration reference** — because it is the
only branch that configures anything.

---

## ⛔ Outcome B — no reference to open

`Outcome: B — SOQL filter search (not by term)` is a decided outcome with
**nothing to configure**: SOQL needs no search index, no object switch, and no
deploy of its own. Do not open the config guide, and do not "make it work
anyway" with a term.

Follow the paths that already exist in this skill set:

| What | Where |
|---|---|
| The query lives in the Dao, nowhere else | [sequence.md](../../private/back-end/sequence/sequence.md) → `dbAccessRule` |
| Soft-deleted rows stay out of it | Step 4 → *The rule every outcome carries* |
| Selectivity and bulk shape | [apex-bulk-soql.md](../../../../performance/apex-bulk-soql.md) |

And tell the user plainly, in this order:

1. **What changed** — the requested search matches on
   `<field> (<type>)`, which is not in the search index, so it cannot be a term
   search.
2. **What was read** — quote the behavior line from section 1 and the `<type>`
   values found in the `field-meta.xml` files, verbatim.
3. **What it becomes instead** — the concrete filter shape (`WHERE Priority__c =
   :priority`, `WHERE EndDate__c >= :from AND EndDate__c <= :to`) and the LWC
   input that drives it, in place of the free-text box.
4. **What would unblock a real term search** — an indexable field carrying the
   text the user wants to match.

> **Never substitute `LIKE '%term%'` for the SOSL that was ruled out.** A leading
> wildcard cannot use any index: the query degrades to a full scan, and on a
> large object Salesforce rejects it outright with
> `Non-selective query against large object type`. It is the one shortcut this
> whole decision exists to prevent.

---

### Step 6 — One run, one branch

Once a reference is opened, stay in it. A run never reads both branches and
never switches engine mid-implementation. If the opened reference itself stops
the run (e.g. the object cannot be made searchable), that stop is final for this
run.

---

## Adding a new branch later

When a reference is written for another search engine (Einstein Search, an
external index, a `Search.suggestRecords` typeahead):

1. Add the file next to this one under `guide/framework/sosl-index-desicion/`.
2. Give it a `## 🗂️ [<name>](<file>.md)` block above, with the **READ when**
   line naming the exact `Outcome` string from section 10.
3. Add its row to the Step 4 outcome table so the classification actually
   reaches it.

Keep one outcome per reference. The routing above stays a straight lookup on the
recorded `Outcome`, never a re-derivation of the decision.
