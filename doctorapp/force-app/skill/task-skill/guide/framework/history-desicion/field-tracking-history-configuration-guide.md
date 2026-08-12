---
metadata:
  type: reference
  applies_to: Field History Tracking only
  activation:
    mode: conditional
---

# Field Tracking History Configuration Guide

Salesforce Field History Tracking is two metadata switches and nothing else:

1. the **object** must be allowed to keep history — `<enableHistory>true</enableHistory>`
   in `<Object>.object-meta.xml`;
2. every **field** whose old→new values you want must carry
   `<trackHistory>true</trackHistory>` in its `field-meta.xml`.

Once both switches are on, Salesforce writes every subsequent change into the
`<Object>__History` object by itself. **No Apex, no trigger, no Flow.** Tracking
is *not* retroactive: only changes made after deployment are recorded.

---

## Instructions

### Step 1 — Read the scratchpad first (MANDATORY — before any edit)

This guide never asks the user what to track. Everything it needs was recorded
during the interview. Open `scratchpad-memory.md` from the session scratchpad
directory and pull:

| Need | Read from |
|---|---|
| Confirmation this branch applies (`Outcome: Field History Tracking`) | section 3 |
| Field count / retention / field types the user answered (H3, H4, H5) | section 3 |
| Tab name, user story, new behavior | section 1 (Tabs 1, 3, 4) |
| **Data state — object + field that provides the data** | section 7 |
| Apex class/method that will read the history | section 7 |

If section 3 does not say `Outcome: Field History Tracking`, stop — you are in
the wrong branch. Go back to
[history-decision-guide.md](history-decision-guide.md).

---

### Step 2 — Resolve the object from the scratchpad

Derive the SObject API name from what was recorded — the **data state** line in
section 7 first, then the behavior and user story in section 1 (Tabs 3–4), then
the tab name in Tab 1 (a tab is usually named after the object it manages, in
plural — singularise it and add the `__c` suffix).

Confirm the object actually exists in the repo:

```
force-app/main/default/objects/<Object>__c/<Object>__c.object-meta.xml
```

Resolution succeeds only when **one** object is identified and its
`object-meta.xml` is present on disk. Two candidate objects with nothing in the
scratchpad choosing between them is *not* a resolution — it is a stop (Step 3b).

---

### Step 3 — Resolve the fields on that object

List the fields whose changes must be recorded, from the same sources (behavior,
user story, data state). For each candidate, confirm the file exists:

```
force-app/main/default/objects/<Object>__c/fields/<Field>__c.field-meta.xml
```

Keep only fields that resolve to a real `field-meta.xml` on that object. A field
named in the behavior but absent from the object is not silently created here —
it is a stop.

#### Step 3b — Stop protocol (no object, or no fields)

**Stop the process immediately** — do not edit any metadata, do not guess, do not
open a question to fill the gap — when **either** holds:

- **no object resolved**: the scratchpad names no object, names something with no
  `object-meta.xml` in the repo, or leaves two or more objects equally likely;
- **no fields resolved**: no field in the scratchpad maps to a
  `field-meta.xml` under the resolved object's `fields/` folder.

Then tell the user, plainly and in this order:

1. **What stopped** — "no object could be resolved" or "the object resolved to
   `<Object>__c`, but none of the fields could be resolved".
2. **What was read** — quote the section 7 data-state line and the Tab 4 behavior
   verbatim, so the user sees exactly what the resolution was based on.
3. **Why that is not enough** — e.g. the behavior says "show the change history"
   but never names the object or the fields; or `Status` was named but the object
   has `CurrentState__c` and no `Status__c`.
4. **What unblocks it** — the object API name and the exact field API names, so
   the run can be repeated with the gap filled.

Write the stop and its reason back into `scratchpad-memory.md` → section 3 so the
next run does not repeat the dead end. Do not continue to Step 4.

---

### Step 4 — Allow the object to track field history

Open `<Object>__c.object-meta.xml` and set `enableHistory`.

`<enableHistory>` is the metadata form of the object's **Track Field History**
setting. Without it, `<trackHistory>` on a field deploys but records nothing.

**Case A — the element already exists and is `false`:** flip it.

```xml
<!-- before -->
<enableHistory>false</enableHistory>
<!-- after -->
<enableHistory>true</enableHistory>
```

**Case B — the element is absent:** add it in alphabetical order among the
`enable*` elements — after `<enableFeeds>`, before `<enableLicensing>`:

```xml
<!-- force-app/main/default/objects/<Object>__c/<Object>__c.object-meta.xml -->
<enableActivities>true</enableActivities>
<enableBulkApi>true</enableBulkApi>
<enableFeeds>false</enableFeeds>
<enableHistory>true</enableHistory>     <!-- ← the switch -->
<enableLicensing>false</enableLicensing>
```

**Case C — it is already `true`:** change nothing **in the file**, but still deploy
it in Step 6. `true` in the working tree is not evidence that history is enabled
in the org — the element may have been committed and never deployed. Deploying an
unchanged object file is a no-op when the org already agrees, and the fix when it
does not.

> Enabling history creates the `<Object>__History` object in the org. Turning it
> back off later discards the collected history — treat it as one-way.

---

### Step 5 — Turn on tracking for each resolved field

For every field from Step 3, open its `field-meta.xml` and add
`<trackHistory>true</trackHistory>` immediately **before** `<trackTrending>`
(the metadata elements are alphabetical, and every field file in this repo
already carries `<trackTrending>`).

```xml
<!-- before — force-app/main/default/objects/<Object>__c/fields/<Field>__c.field-meta.xml -->
<required>true</required>
<trackTrending>false</trackTrending>
<type><FieldType></type>

<!-- after -->
<required>true</required>
<trackHistory>true</trackHistory>
<trackTrending>false</trackTrending>
<type><FieldType></type>
```

The placement is the same for every field type — `Text`, `Lookup`, `Picklist`,
`Number`, `Date` — only the surrounding elements differ. If the object already
has a tracked field, open its `field-meta.xml` and copy that placement rather
than inventing one.

#### Step 5b — Check the limits before writing the files

| # | Check | If it fails |
|---|---|---|
| 1 | **20 fields max per object.** Count the fields that will carry `trackHistory=true` after this change: `grep -c trackHistory` across `objects/<Object>__c/fields/` plus the new ones. | Over 20 → stop. The H3 answer ("20 or fewer") no longer holds, so Field History Tracking is not the right approach for this object. Report it and stop; do not silently drop fields to fit. |
| 2 | **Field type is trackable.** Formula, roll-up summary and auto-number fields cannot be tracked at all. | Remove them from the list and tell the user which ones were dropped and why. |
| 3 | **Values are actually captured.** Long text area, rich text and multi-select picklist fields record only *that* a change happened — `OldValue` and `NewValue` come back empty. | If the behavior needs the values, this is the H5 stop condition: report it and stop — a custom history object is required and has no guide yet. |
| 4 | **Retention.** Field History keeps data ~18 months in the org (24 months via API). | If the behavior needs longer, the H4 answer no longer holds — stop and report. |

Checks 1, 3 and 4 re-verify the H3/H4/H5 answers against the real metadata. An
answer that turns out not to match the object invalidates the whole branch — say
so and stop, rather than shipping tracking that cannot deliver the behavior.

---

### Step 6 — Deploy the object first, then the fields

Ship the two switches and nothing else. Deploying the whole object folder drags
along every unrelated field edit sitting in the working tree.

**This is two deploys, in this order — never one combined command.**
`<trackHistory>` on a field is rejected by the org unless history is *already*
enabled on the object **at the moment the field is validated**. Putting both in a
single `sf project deploy start` does not guarantee that order, and the field
fails with:

```
The entity: <Object>__c does not have history tracking enabled
```

**Deploy 1 — the object (enables history in the org):**

```bash
sf project deploy start -m "CustomObject:<Object>__c"
```

Wait for `Status: Succeeded`. Only then run Deploy 2.

**Deploy 2 — the fields (one `-m` per field):**

```bash
sf project deploy start \
  -m "CustomField:<Object>__c.<Field1>__c" \
  -m "CustomField:<Object>__c.<Field2>__c"
```

**Alternative — name the exact files, same two-step order:**

```bash
# 1. object
sf project deploy start \
  -d force-app/main/default/objects/<Object>__c/<Object>__c.object-meta.xml

# 2. fields
sf project deploy start \
  -d force-app/main/default/objects/<Object>__c/fields/<Field1>__c.field-meta.xml \
  -d force-app/main/default/objects/<Object>__c/fields/<Field2>__c.field-meta.xml
```

Rules for building the commands:

- Substitute the object and fields resolved in Steps 2–3 — one `-m
  CustomField:<Object>__c.<Field>__c` (or one `-d <path>`) per field.
- **Deploy 1 runs even when Step 4 was Case C.** A `true` already sitting in the
  working tree proves nothing about the org; skipping the object deploy is what
  produces the "does not have history tracking enabled" failure above. The deploy
  is a harmless no-op when the org is already in sync.
- A field being *untracked* in this run (its `<trackHistory>` removed) belongs in
  Deploy 2 as well — otherwise the org keeps tracking it.
- Never widen either command to `-d force-app/main/default/objects` or
  `-d force-app/main/default`.
- Verify first if you want a dry run: append `--dry-run` to each.

> If Deploy 2 still reports "does not have history tracking enabled", Deploy 1
> did not actually take. Re-read the object in the org before touching the
> fields again — do not retry Deploy 2 on its own.

> **Do not run this command yourself.** Deploys against the connected org are the
> user's call — print the command, say which files it covers, and let them run
> it.

---

### Step 7 — Verify

| # | Check | Fix if it fails |
|---|---|---|
| 1 | The object's `object-meta.xml` has `<enableHistory>true</enableHistory>` | Step 4. |
| 2 | Every resolved field's `field-meta.xml` has `<trackHistory>true</trackHistory>` before `<trackTrending>` | Step 5. |
| 3 | Tracked-field count on the object is ≤ 20 | Step 5b, check 1. |
| 4 | No formula / roll-up / auto-number field is in the list | Step 5b, check 2. |
| 5 | **Two deploy commands were produced, object first then fields** — never one combined command | Step 6. |
| 6 | Deploy 1 names the object even when Step 4 was Case C | Step 6, rules. |
| 7 | Deploy 2 names every field changed in this run, including any field that was *untracked* | Step 6, rules. |
| 8 | Neither command widens to `force-app/main/default` or the whole `objects` folder | Step 6, rules. |
| 9 | The reading side queries `<Object>__History`, not a custom object | Resources, below. |
| 10 | Section 3 of `scratchpad-memory.md` records the object, the fields, and **both** deploy commands that were produced | Write it before finishing. |

---


