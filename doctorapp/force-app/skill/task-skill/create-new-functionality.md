---
name: create-new-functionality
description: >
  Creates new functionality from scratch. Creates the run's scratchpad-memory.md
  (Step 0), gathers context (Step 1), resolves the history-tracking approach when
  the request involves history (Step 1c), records the search-by-term requirement
  when the request involves a typed-term search (Step 1d), locates or identifies
  the pather
  (Step 2), determines if a new child component is needed (Step 2b), collects
  validation rules (Step 3), then branches to the appropriate sub-skill. Every
  answer and every finding is written to scratchpad-memory.md, which is the only
  context the sub-skills read from, so nothing is ever re-asked.
---

# Create New Functionality

Turns a "create me a new functionality" request into the correct interview for
building new features in-place. A new functionality can be built in one of two
shapes: as a **child component dispatching events to an existing pather** (child
+ pather workflow), or as a **standalone interactive pather** calling Apex
directly (pather-only workflow). This skill detects the shape, runs the matching
interview, and carries the already-known answers forward so nothing is asked
twice.

---

## Instructions

### Step 0 — Create `scratchpad-memory.md` (MANDATORY — first action of the run)

The **first** thing this skill does on every invocation — before Step 1, before
any question — is create a temporary working file named **`scratchpad-memory.md`**
in the session scratchpad directory.

**Pitfalls are not loaded here.** `scratchpad-memory.md` holds interview answers
and findings only — it is not a pitfall catalog. The pitfall files are read
straight from `force-app/skill/pitfat/` by the sub-skill at code-writing time
(Step 6 → the sub-skill's Step 0), together with the merged guides. Do not glob,
read, copy, or summarise a pitfall file anywhere in this caller skill.

**Purpose:** `scratchpad-memory.md` is the single record of this caller run. It
holds every tab answer and every piece of information the iteration derives, so
the sub-skills in Step 6 read their inputs out of the file instead of being
handed loose context. It is the caller's memory for the whole iteration.

Rules:

- Create it **once**, at the start of the run. If a file is left over from a
  previous run, overwrite it — one run, one memory file.
- Write to it **as each step completes**, never batched at the end. A step is not
  finished until its section is written.
- Record user answers **verbatim**. Do not validate, summarise, second-guess, or
  reason about an answer while writing it (CLAUDE.md → "Shared FAQ responsibility").
- **Never ask a question to fill a section.** A section the iteration genuinely
  cannot fill is written as `n/a` plus a one-line reason.
- Sub-skills **read** this file for their inputs and write their own analysis
  back into section 9. They never re-ask anything that is already in it.

Seed the file with this skeleton, then fill each section in its own step:

```markdown
# Scratchpad Memory — <tab name> / <short functionality title>

Caller: create-new-functionality
Flow: <pending | A (pather-only) | B (child + pather)>
History approach: <pending | n/a | Field History Tracking | other — run stopped>
Search approach: <pending | n/a | A — SOSL | B — SOQL filter (not by term) | C — SOSL + SOQL filter>
Status: <in progress | complete | stopped>

## 1. Tab answers — Step 1

| Tab | Question | Answer (verbatim) |
|---|---|---|
| 1 | Tab name | |
| 2 | Sub-component name | |
| 3 | New user story | |
| 4 | New behavior | |
| 5a | Input validation rules | |
| 5b | Business logic validation rules | |
| 6a | Cacheable requirement | |
| 6b | Additional performance requirements | |
| 6c | Visibility/urgency | |

## 2. Data-load answers — Step 1b (read operations only)

| Tab | Question | Answer (verbatim) |
|---|---|---|
| 7 | Expand-driven load | |
| 8 | Load timing | |
| 9 | Load on page creation | |

## 3. History-tracking decision — Step 1c (history requests only)

- Triggered: <yes | no — no history signal in the tab answers>
- Trigger evidence (verbatim phrase from Tab 1 / 3 / 4):

| Q | Question | Answer (verbatim) |
|---|---|---|
| H1 | Record data change, or setup/configuration change | |
| H2 | Queryable old/new values, or user-visible only | |
| H3 | Fields tracked per object | |
| H4 | Retention period | |
| H5 | Field types tracked | |
| H6 | Salesforce Shield available | |
| H7 | Custom capture logic needed | |

- Outcome: <Field History Tracking | Setup Audit Trail | Chatter Feed Tracking |
  Field Audit Trail (Shield) | Custom history object | n/a>
- Deciding question (the one that ended the sequence):
- Run continues: <yes — Field History Tracking | no — run stopped at Q#>

## 4. Pather location — Step 2a

- Pather name:
- Status: <found | NEW PATHER>
- `.js` path:
- `.html` path:
- Validator path (if any):

## 5. Sub-component location — Step 2b

- Sub-component name:
- Status: <none | Option A — reusable child component | Option B — template
  section in the pather | NEW template section>
- Path / template reference:

## 6. Branch logic — Step 2c

- Flow: <A | B>
- Where in the template the new sub-component section goes:
- Handler function pattern:
- Location in the code:
- Template structure the sub-component should have:
- Event name:
- Event operation type (Flow B): <Create | Update | Delete | Load | Search>
- Event payload shape (Flow B):
- Base components the pather already uses (reusable base-component candidates):

## 7. Apex target — Step 3

- Apex class:
- Apex method:
- Method signature / parameters:
- Return shape:
- Handler that calls it:
- How pather state is updated from the response:
- Data state (object + field that provides the data):

## 8. Validation rules — Step 4

- Existing validator file(s) found:
- Existing validation functions that apply:
- Inline validation already in place:
- New input rules (Tab 5a):
- New business logic rules (Tab 5b):
- Consolidated rule list passed to the sub-skill:

## 9. Sub-skill analysis — written back by the sub-skill

- State category (Data / Control / Communication / Interaction):
- Call style (`@wire` | imperative):
- Wire gating field:
- `refreshApex` strategy:
- Gating-field initialization (pre-defined | lazy-set):

## 10. Search-by-term requirement — Step 1d (search requests only)

- Triggered: <yes | no — no search-by-term signal in the tab answers>
- Trigger evidence (verbatim phrase from Tab 3 / 4):
- Fields named for the search (verbatim, or `none named`):
- Object being searched:
- Fields resolved + `<type>` (filled by the decision guide):
- Outcome (filled by the decision guide): <A — SOSL term search |
  B — SOQL filter search (not by term) | C — SOSL term + SOQL filter | n/a>
```

---

### Step 1 — Gather all context

This skill applies when the request is to **create a new functionality** (not
update existing behavior, not a template-only tweak, not a bug fix). Confirm that
first; if it is an update / cosmetic / bug request, skip — see "When to skip".

Ask the user via `AskUserQuestion`, in batches of at most four fields per call,
in the order below:

> **Tab 1 — Tab Name:** *"What is the tab name for this functionality? . If creating a new TAB, provide the tab name you want to create."*
>
> **Tab 2 — Sub-component name:** *"What is the sub-component name where this functionality should live? "*
>
> **Tab 3 — New user story:** *"Describe the new user story or requirement that this functionality fulfills."*
>
> **Tab 4 — New behavior:** *"Describe the new behavior and how the functionality should work."*
>
> **Tab 5a — Input validation rules:** *"What input validation rules must pass before executing the behavior? . List any rules, or leave blank if none are needed."*
>
> **Tab 5b — Business logic validation rules:** *"What business logic or state validation rules must pass? List any rules, or leave blank if none are needed."*
>
> **Tab 6a — Cacheable requirement:** *"Should the Apex method be cacheable (i.e., decorated with `@AuraEnabled(cacheable=true)`)? (yes/no)"*
>
> **Tab 6b — Additional performance requirements:** *"Are there any other performance or caching requirements? (e.g., 'cache should be cleared on record update', 'method should use @future', or leave blank if none)"*
>
> **Tab 6c — Visibility/urgency:** *"How important is it for this value to be visible to other users as soon as possible? (Very important / Important / Not important)"*

Record all answers verbatim — preserve every detail:
- **Pather name** → Identifies the pather file as `manage<tabName>` in `force-app/main/default/lwc/`, or new if not found.
- **Sub-component name** → Identifies whether a separate child component is needed (mandatory, never blank — use "none" for pather-only).
- **New user story** → Target requirement (will be sent to LLM for context).
- **New behavior** → How the functionality should work (will be sent to LLM for context).
- **Validation rules (5a–5b)** → Input and business logic validation requirements.
- **Cacheability (6a–6b)** → Apex method caching and performance requirements.
- **Visibility/urgency (6c)** → Feeds the visibility-urgency branch of
  `lwc-apex-call-implementation-guide`, which the sub-skill uses to pick the
  `@wire` + `refreshApex` strategy. Record the answer only — the sub-skill decides
  what to do with it.

**Write to `scratchpad-memory.md` → section 1 (Tab answers).** One row per tab:
tab number, question, and the user's answer verbatim. Do not proceed to Step 1b
until section 1 is written.

---

### Step 1b — Data-load requirements (CONDITIONAL — read operations only)

**LLM analyzes the new behavior from Step 1, Tab 4.** This step runs **only when
the behavior includes a read / load operation** — fetching, listing, displaying,
or refreshing records. A write-only behavior (create / update / delete with no
read) has no data-load requirement.

**If the behavior has NO read operation** → ask nothing. Write
`n/a — behavior has no read operation` into section 2 of `scratchpad-memory.md`
and proceed to Step 1c.

**If the behavior HAS a read operation** → ask the user via `AskUserQuestion`:

> **Tab 7 — Expand-driven load decision:** *"Is this data load triggered by an expand action — should data load when a user expands a section? (yes/no)"*
>
> **Tab 8 — Load timing:** *"When should the data load relative to the expand action? (on-expand when the user clicks, or on-create when the Tab first loads)"* — ask only when Tab 7 = yes; record `n/a` otherwise.
>
> **Tab 9 — Load on page creation:** *"Should this data load when the page loads? (yes/no)"*

Record all answers verbatim:
- **Expand-driven load (Tab 7)** → Confirms whether an expand action triggers the load
- **Load timing (Tab 8)** → When the load fires (on-create vs on-expand)
- **Load on page creation (Tab 9)** → Feeds the wire-initialization analysis in
  `lwc-apex-call-implementation-guide`: it decides whether the gating field starts
  with a defined value or as `undefined`. Record the answer only — the sub-skill
  decides what to do with it.

**Write to `scratchpad-memory.md` → section 2 (Data-load answers)**, then proceed
to Step 1c.

---

### Step 1c — History-tracking approach (CONDITIONAL — history requests only)

**LLM analyzes the main tab input from Step 1** — Tab 1 (tab name), Tab 3 (user
story) and Tab 4 (new behavior) — looking for a **history signal**: the request
mentions history, audit, change log, tracking changes, "who changed what",
old/previous value, timeline of changes, or anything equivalent.

**If there is NO history signal** → ask nothing. Write
`Triggered: no — no history signal in the tab answers` into section 3 of
`scratchpad-memory.md` and proceed to Step 1d.

**If there IS a history signal** → this optional tab is required. Record the
verbatim phrase that triggered it in section 3, then run the question sequence
below.

#### Internal constraint — DO NOT reveal before the outcome is decided

> Only **Field History Tracking** is supported by this skill set today; no
> implementation guide has been written for Setup Audit Trail, Chatter Feed
> Tracking, Field Audit Trail (Shield), or a custom history object.
>
> **Do not mention this constraint, and do not hint at a preferred answer, while
> the sequence is running.** Stating it up front biases the answers and the
> resulting design. Reveal it only *after* the sequence produces an outcome, and
> only when the outcome is not Field History Tracking.

#### The question sequence

Ask **one question at a time** via `AskUserQuestion`, in order. Each answer
decides whether to continue or to stop — never batch ahead, and never skip a
question because an earlier answer made it "look" obvious. Record each answer
verbatim into the section 3 table as it arrives.

> **Q1 (H1) — What kind of change are you tracking — record data, or setup/configuration?**
> - *Record field values changing* (e.g. a Status field going from Open to Closed) → continue to Q2.
> - *Admin/metadata changes* (someone edited a field definition, permission, workflow) → **Setup Audit Trail**. Outcome decided; stop the sequence.

> **Q2 (H2) — Do you need the actual old/new values stored and queryable, or just visibility for users?**
> - *Just want users to see changes in context, socially* → **Chatter Feed Tracking**. Outcome decided; stop the sequence.
> - *Need structured, queryable old→new values* → continue to Q3.

> **Q3 (H3) — How many fields per object do you need to track?**
> - *20 or fewer* → Field History Tracking is enough so far; continue to Q4 to confirm it fits.
> - *21 to 60* → **Field Audit Trail (Shield) or a custom history object**. Outcome decided; stop the sequence.
> - *More than 60, or very custom* → **Custom history object** (Apex trigger or Flow). Outcome decided; stop the sequence.

> **Q4 (H4) — How long must you retain the history?**
> - *~18–24 months is fine* → Field History Tracking still fits; continue to Q5.
> - *Up to 10 years / compliance requirement* → **Field Audit Trail (Shield)**. Outcome decided; stop the sequence.
> - *Indefinite, on your own terms* → **Custom history object** (you control retention). Outcome decided; stop the sequence.

> **Q5 (H5) — What field types are you tracking?**
> - *Standard types* (text, picklist, number, date, lookup, etc.) → Field History Tracking captures old and new values fine; continue to Q6.
> - *Long text areas, rich text, or multi-select picklists* → standard tracking only records that a change happened, not the values. If the actual values are needed → **Custom history object**. Outcome decided; stop the sequence. If only "a change happened" is needed, continue to Q6.

> **Q6 (H6) — Do you have Salesforce Shield, or budget for it?**
> - *Yes* → **Field Audit Trail** unlocks (more fields, longer retention). Outcome decided; stop the sequence.
> - *No* → the choice stays between Field History Tracking (it fits the limits so far) and a custom history object; continue to Q7.

> **Q7 (H7) — Do you need custom logic — conditional capture, computed values, tracking relationships, or writing to an external system?**
> - *No, straightforward value tracking* → **Field History Tracking**. Sequence complete.
> - *Yes* → **Custom history object** with Apex/Flow, or push to an external store. Outcome decided; stop the sequence.

Any question not reached because the sequence stopped earlier is recorded as
`n/a — sequence stopped at Q<n>`.

#### Recording the outcome — always

**Write to `scratchpad-memory.md` → section 3** as soon as the sequence ends:
every answer verbatim, the **Outcome**, the **deciding question**, and whether
the run continues. Also set `History approach:` in the file header. This happens
for every outcome, including the ones that stop the run — the memory file is the
record of what was decided and why.

#### Branch on the outcome

- **Outcome = Field History Tracking** → the run continues. Set
  `Run continues: yes — Field History Tracking` in section 3 and proceed to
  Step 1d. Do not mention the internal constraint. The implementation of the
  tracking itself is routed by
  [history-decision-guide.md](guide/framework/history-desicion/history-decision-guide.md), which
  reads the outcome back out of section 3.
- **Any other outcome** → **stop the run here.** Set
  `Run continues: no — run stopped at Q<n>` in section 3 and `Status: stopped`
  in the header. Do not run Step 2 or anything after it, and do not call any
  sub-skill.

  Now — and only now — tell the user plainly:
  - which approach their answers point to (e.g. "Field Audit Trail (Shield)"),
  - which answer decided it (quote the question and their answer),
  - that this skill only has an implementation guide for **Field History
    Tracking**, so there is nothing written yet for the approach they need,
  - where the run's record is (`scratchpad-memory.md`), so the interview does not
    have to be redone.

  Offer the concrete next step: if they revisit the deciding answer and it turns
  out Field History Tracking does fit, re-run this skill and the run continues.
  Do not improvise an implementation for an unsupported approach.

---

### Step 1d — Search-by-term signal (CONDITIONAL — search requests only)

**LLM analyzes the tab answers from Step 1** — Tab 3 (user story) and Tab 4 (new
behavior) — looking for a **search-by-term signal**: the user types a term / a
keyword / free text into a box and records are matched against it ("search",
"find by", "type to filter", "lookup by name", "keyword", "autocomplete", or
anything equivalent).

A filter the user *picks* rather than types — a picklist value, a date range, a
checkbox, a lookup id — is **not** a term search. It is an ordinary filtered
read and this step does not fire for it.

**If there is NO search-by-term signal** → ask nothing. Write
`Triggered: no — no search-by-term signal in the tab answers` into section 10 of
`scratchpad-memory.md`, set `Search approach: n/a` in the header, and proceed to
Step 2.

**If there IS a search-by-term signal** → **ask nothing here either.** The engine
choice is not an interview: it is derived from the field types already on disk.
Record in section 10:

- `Triggered: yes`
- the verbatim phrase from Tab 3 / Tab 4 that triggered it,
- the fields the behavior names for the search, verbatim — or `none named` when
  it names none. Do not invent a field list; `none named` is a valid, expected
  answer that the decision guide knows how to resolve.

The decision itself — SOSL or a SOQL filter search — is made by
[sosl-index-desicion-guide.md](guide/framework/sosl-index-desicion/sosl-index-desicion-guide.md),
which reads section 10 back out and writes the `Outcome` into it. That guide is
opened in Step 6, once the object and the Apex target are resolved (sections 4–7)
— not here. Proceed to Step 2.

---

### Step 2 — Locate pather and analyze implementation

Using the pather name from Step 1, determine if the pather exists and retrieve its files.

#### Step 2a — Grep for the pather class

Grep the codebase for the pather class file:
- Pattern: `manage<tabName>` (from Step 1, Tab 1)
- Expected file: `force-app/main/default/lwc/manage<tabName>/manage<tabName>.js`
- Retrieve both `.js` and `.html` files if the pather exists

**Branch logic:**
- **Pather found** → Proceed to Step 2b (check for sub-component)
- **Pather not found** → Mark as "NEW PATHER" and proceed to Step 2b

**Write to `scratchpad-memory.md` → section 4 (Pather location):** the pather
name, its status (`found` / `NEW PATHER`), and the resolved `.js`, `.html`, and
validator paths. This section is what the sub-skill reads as its parent LWC
identity — if it is not written, the sub-skill's Part 1 gate fires.

#### Step 2b — Search for the sub-component

If a sub-component name was provided (Step 1, Tab 2) and it is NOT "none":
- Pattern: `<subComponentName>`
- Search in `force-app/main/default/lwc/` for:
  - **Option A:** A reusable child component directory: `force-app/main/default/lwc/<subComponentName>/<subComponentName>.js`
  - **Option B:** A template reference in the pather `.html`: `<c-<subComponentName>`
- If found as Option A: It's a separate, reusable child component. Retrieve the child `.js` and `.html` files (proceed to Step 2c, Flow B)
- If found as Option B: The sub-component is a template section within the pather; it is NOT separate (proceed to Step 2c, Flow A)
- If not found: It's a NEW sub-component that will be added as a template section within the pather (NOT as a reusable child) (proceed to Step 2c, Flow A)

**Write to `scratchpad-memory.md` → section 5 (Sub-component location):** the
sub-component name, its status (`none` / Option A — reusable child component /
Option B — template section in the pather / NEW template section), and the path
or template reference that was matched.

#### Step 2c — Branch logic based on findings

**Flow A — Pather-only (sub-component is "none" OR template section OR new sub-component):**

The functionality will live directly in the pather with no separate reusable child component.
This includes:
- Sub-component name is "none" (pather-only)
- Sub-component exists only as a template section reference in the pather
- Sub-component name provided but doesn't exist (will be created as a template section within pather, not as reusable)

1. LLM Analyse:
   - Pather `.html` file (if pather exists)
   - Pather `.js` file (if pather exists)
   - New user story (Step 1, Tab 3)
   - New behavior (Step 1, Tab 4)
2. LLM identify:
   - Where in the template the new sub-component section should be placed
   - Handler function pattern (where to add the new handler, if needed)
   - Location in the code (template section, handler method, etc.)
   - If sub-component is new, what template structure it should have
   - The event name the section fires
   - Which base components the pather already uses (`c-ao-input`, `c-ao-btn`,
     `c-ao-combobox`, `lightning-*`, or none) — the reusable base-component
     candidates for the new section
3. **Write to `scratchpad-memory.md` → section 6 (Branch logic):** `Flow: A`, plus
   every item identified above — template insertion point, handler function
   pattern, location in the code, template structure, event name, and base
   components. Also set `Flow: A (pather-only)` in the file header.
4. Proceed to Step 3a (pather-only analysis)

**Flow B — Child + pather (separate reusable child component exists):**

The functionality will be split across a reusable child component and pather handler.
This applies ONLY when:
- Sub-component exists as a separate reusable child component directory (Option A found in Step 2b)

1. LLM Analyse:
   - Child `.js` file
   - Child `.html` file
   - New user story (Step 1, Tab 3)
   - New behavior (Step 1, Tab 4)
2. LLM identify:
   - The dispatched event name pattern (e.g., `dispatch<EventName>` or `@api onSomeEvent`)
   - Event operation type (Create / Update / Delete / Load / Search)
   - Event payload shape
   - Where in the pather template the child should be placed, and the handler
     function pattern that will listen to the event
   - Which base components the child already uses (reusable base-component
     candidates)
3. **Write to `scratchpad-memory.md` → section 6 (Branch logic):** `Flow: B`, plus
   the event name, operation type, payload shape, template placement, handler
   function pattern, and base components. Also set `Flow: B (child + pather)` in
   the file header.
4. Proceed to Step 3b (child + pather analysis)

---

### Step 3 — Analyze what to build

#### Step 3a — Pather-only analysis

Functionality will live directly in the pather with no child component.

1. LLM ask for:
   - Pather `.html` file (if exists) or empty template structure (if new pather)
   - Pather `.js` file (if exists) or empty class skeleton (if new pather)
   - New user story (Step 1, Tab 3)
   - New behavior (Step 1, Tab 4)

2. LLM Analyse:
   - Where the new handler function should be placed
   - What the handler function should do
   - What Apex method it should call, and the Apex class that method lives in
   - The method signature / parameters and the shape it returns
   - What object + field provides the data (the data state)
   - Event name(s) or trigger point(s)

3. **Write to `scratchpad-memory.md` → section 7 (Apex target):** the Apex class,
   the Apex method, its signature and return shape, the handler that calls it, how
   the pather state is updated from the response, and the data state. Then proceed
   to Step 4 (validation gathering).

#### Step 3b — Pather + child analysis

Functionality will be split across a child component and pather handler.

1. **For the child**, LLM ask for:
   - Child `.js` file (if exists) or empty class skeleton (if new child)
   - Child `.html` file (if exists) or empty template structure (if new child)
   - New user story (Step 1, Tab 3)
   - New behavior (Step 1, Tab 4)

2. Ask LLM to:
   - Identify what the child component should do and expose
   - Determine the dispatched event name and payload shape
   - Identify validation that should live in the child

3. **For the pather**, LLM ask for:
   - Pather `.html` file (if exists)
   - Pather `.js` file (if exists)
   - New user story (Step 1, Tab 3)
   - New behavior (Step 1, Tab 4)

4. Ask LLM to:
   - Identify where the child should be placed in the pather template
   - Identify the handler function that should listen to the child's event
   - Identify the Apex method that should be called from the handler, and the
     Apex class that method lives in
   - Identify the method signature / parameters and the shape it returns
   - Identify what object + field provides the data (the data state)
   - Identify how the pather state should be updated from the response

5. **Write to `scratchpad-memory.md`:** the child-side findings into section 6
   (Branch logic), and the Apex class, Apex method, signature, return shape,
   calling handler, state-update approach, and data state into section 7 (Apex
   target). Then proceed to Step 4 (validation gathering).

---

### Step 4 — Gather and analyze validation rules

Before invoking the sub-skills, collect validation rules that apply to the new functionality.

**Step 4a — Locate validation in the codebase**

1. LLM searches for existing validation patterns (if pather or child exists):
   - **For pather-only (Flow A):** In the pather `.js` file, look for:
     - Separate `<patherName>Validator.js` file (check for imports in pather `.js`)
     - Inline validation logic in handler methods
     - State-based guards (e.g., `if (!this.field) return;`)
   - **For child + pather (Flow B):** In the child `.js` file, look for:
     - Separate `<childName>Validator.js` file (check for imports in child `.js`)
     - Inline validation logic in handler methods
2. If validator file(s) exist, retrieve and document all exported validation functions.
3. Document what inline validation patterns are already in place.

**Write to `scratchpad-memory.md` → section 8 (Validation rules):** the validator
file(s) found, the exported validation functions, and the inline validation
already in place.

**Step 4b — Reference validation rules from Step 1**

Read the validation rules already recorded in `scratchpad-memory.md` → section 1:
- **Tab 5a answer** → Input validation rules
- **Tab 5b answer** → Business logic validation rules

No re-asking needed; these were collected upfront in Step 1 and are already in
the memory file.

**Step 4c — Combine existing and new validation rules**

1. LLM analyzes:
   - Which existing validation functions from Step 4a apply to the new behavior?
   - Which new validation rules from user's answer (Step 4b) must be added?
   - Are there existing inline validators that should be converted to the validator file?
2. Compile a consolidated list of all validation rules (existing + new) that apply
   to the new functionality.
3. **Write the consolidated list to `scratchpad-memory.md` → section 8
   (Validation rules).** This is how it reaches the sub-skill — do not pass it
   separately.
4. Proceed to Step 5.

---

### Step 5 — Reference non-functional requirements

Before proceeding to the sub-skills, re-read the non-functional requirements
already recorded in `scratchpad-memory.md` (sections 1, 2 and 3) and confirm each
one is present:

#### **Cacheability, performance, and visibility (section 1, Tabs 6a–6c)**
- **Tab 6a answer** → Cacheable requirement (yes/no), determines if `@AuraEnabled(cacheable=true)` should be applied
- **Tab 6b answer** → Additional performance requirements (async execution, cache invalidation, etc.)
- **Tab 6c answer** → Visibility/urgency (Very important / Important / Not important)

#### **Data-load requirements (section 2, Tabs 7–9, read operations only)**
- **Tab 7 answer** → Whether expand-driven load applies (yes/no, or "n/a" if the behavior has no read)
- **Tab 8 answer** → Load timing: on-create, on-expand, or "n/a" if not expand-driven
- **Tab 9 answer** → Load on page creation (yes/no, or "n/a" if the behavior has no read)

#### **History-tracking approach (section 3, Q H1–H7, history requests only)**
- **Outcome** → `Field History Tracking` when the step ran (any other outcome
  stopped the run at Step 1c), or "n/a" when there was no history signal
- **H3 / H4 / H5 answers** → the field count, retention window, and field types
  the tracked history must cover

#### **Search-by-term requirement (section 10, search requests only)**
- **Triggered** → `yes` when the behavior matches a typed term against records,
  or `no` when there is no term search in this run
- **Fields named for the search** → the field list recorded verbatim, or
  `none named` — the decision guide derives the default set from it

No re-asking needed; these were collected upfront in Steps 1, 1b, 1c and 1d.
Sections 3 and 10 were derived by analysis rather than asked — if one is
empty, go back and fill it from the recorded answers, do not open a new prompt.

Mark `Status: complete` in the `scratchpad-memory.md` header.

---

### Step 6 — Branch to the appropriate sub-skill

After non-functional requirements are collected (Steps 1–5), branch based on the
findings from Step 2. **`scratchpad-memory.md` is the context.** Hand the
sub-skill the path to the file — do not restate its contents, and do not pass any
answer out of band. The sub-skill reads every input it needs from the file's
sections:

| Sub-skill needs | Reads from |
|---|---|
| Pitfalls to check the generated code against | **not** `scratchpad-memory.md` — the sub-skill globs and reads `force-app/skill/pitfat/**/*.md` itself at its Step 0, every file, every time, right before it writes code |
| Parent LWC name and code paths | section 4 |
| Sub-component selection | section 5 |
| User stories, behavior, validation answers | section 1 (Tabs 3, 4, 5a, 5b) |
| Cacheability, visibility/urgency | section 1 (Tabs 6a, 6b, 6c) |
| Expand action, load timing, load on page creation | section 2 (Tabs 7, 8, 9) |
| History-tracking approach and its constraints | section 3 (Q H1–H7), routed by [history-decision-guide.md](guide/framework/history-desicion/history-decision-guide.md) |
| Template placement, handler pattern, event name | section 6 |
| Apex class and method, data state | section 7 |
| Consolidated validation rules | section 8 |
| Search engine for a term search, and its configuration | section 10, routed by [sosl-index-desicion-guide.md](guide/framework/sosl-index-desicion/sosl-index-desicion-guide.md) — **opened only when section 10 records `Triggered: yes`**; when it records `Triggered: no`, the guide is never read |

**Flow A — Pather-only (no separate reusable child component):**

Call: [create-new-parent-lwc-component.md](sub-task/create-new-parent-lwc-component.md)
with the path to `scratchpad-memory.md`.

**Flow B — Child + pather (separate reusable child component exists):**

1. **First**, call: [create-new-child-and-parent-lwc.md](sub-task/create-new-child-and-parent-lwc.md)
   with the path to `scratchpad-memory.md`.

   The child-and-parent skill combines child creation and parent event-handler
   wiring in one pass, producing child `.js`/`.html`/`Validator.js` and parent
   handler methods with correct state management derived from the behavior.

---

### Step 7 — One iteration stays in one branch

Once Step 2 detects the branch (Flow A or Flow B), stay in it. Do not switch
branches mid-iteration. The flow routes to the correct sub-skill based on the
architecture detected in Step 2.

---

## When to skip

Skip this skill when:

- The work is updating an **existing** functionality — use
  `update-existing-functionality` instead.
- The work is purely **cosmetic** (styling, layout, no new behavior) — no interview is needed.
- The work is a **bug fix** (correcting broken behavior) — use appropriate bug-fix flow instead.

Do not skip on the basis that "the feature is small" — small features that
skip the interview routinely end up with tangled logic or broken architecture
and have to be rewritten on the next pass.
