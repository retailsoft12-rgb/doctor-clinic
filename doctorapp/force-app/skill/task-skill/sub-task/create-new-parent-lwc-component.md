# Simplified Parent LWC — Add Functionality

Routes a parent LWC functionality request in one pass. This skill does not
implement any task itself and **asks the user nothing** — it loads the pitfall
files and its mandatory guides first (Step 0), then reads the parent LWC
identity, the sub-component
selection, and the functionality requirements out of **`scratchpad-memory.md`**,
places the code, and verifies it.

---

## Rule — `scratchpad-memory.md` is the only input source

Every input this skill needs was gathered by the caller
([create-new-functionality.md](../create-new-functionality.md)) and written into
**`scratchpad-memory.md`** in the session scratchpad directory. The caller hands
this skill the path to that file.

- **Read inputs from the file's numbered sections.** The Source column of every
  input table below names the section to read.
- **Take every value verbatim.** Do not validate, reason about, predict, or
  re-derive a recorded answer.
- **Never re-ask.** If a value is missing, the matching gate fires and control
  returns to the caller — this skill does not open a prompt to fill a gap.
- **Write analysis back to section 9.** Step 4's derived call style and state
  decisions go into the file, not into loose context.

The one exception is reference material, which is read from disk rather than from
the memory file: the pitfall files (`force-app/skill/pitfat/`) and the merged
guides, both loaded in Step 0. Those are not inputs the caller gathered — they
are the rules the recorded inputs get applied under.

---

## Rule — How To Ask User

Use `AskUserQuestion` tool exclusively. Every question directed at the user —
in this skill or any sub-skill loaded after this point — MUST use the
`AskUserQuestion` tool. Plain-text questions are not permitted at any depth.

Apply [guard/interview-discpline](../guard/interview-discpline.md) on every
iteration that has a question step.

---

## Step 0 — Load the pitfalls, then build and load the mandatory guides

**This step runs first — before the Part 1 gate, before reading § 4, before every
other step in this skill.** This skill is where coding starts, so this is where
the pitfall files are read and the guides are **built and then loaded**, in that
order. No gate is evaluated and no code is read or emitted until everything below
is done.

The code this skill generates lives in a **pather (parent)** component. Apply
each guide per its own `activation:` contract — see CLAUDE.md → "Mandatory‑guides
step" for how required / optional guides are read.

#### Pitfalls — load them here, not from `scratchpad-memory.md`

The caller does **not** copy pitfalls into `scratchpad-memory.md`. Read them from
disk at the start of this skill:

1. Glob `force-app/skill/pitfat/**/*.md` to list **every** pitfall file. Do not
   hand-pick and do not filter by what the request "looks like" — relevance is
   judged against the code as it is written, not against the file name.
2. Read each one **in full**. A pitfall is a code-level trap; summarising it
   removes the exact snippet that makes it recognisable.
3. Hold them for Step 5 (placement) and Step 6 (verification) — the emitted code
   is checked against every pitfall, every time.

If the folder holds no `.md` files, note `no pitfall files` and continue — an
empty folder is not a failure.

#### Required guides

Check for `*-TEMPORARY.md` under `../guide/`. If they do not exist, run:

```
python force-app/skill/task-skill/guide/guides-build.py
```

Then understand, in this order:

1. [../guide/sequence-fe-desicion-TEMPORARY.md](../guide/sequence-fe-desicion-TEMPORARY.md)
2. [../guide/sequence-be-TEMPORARY.md](../guide/sequence-be-TEMPORARY.md)
3. [../guide/handle-state-TEMPORARY.md](../guide/handle-state-TEMPORARY.md)

The project-wide soft-delete filter (`soql-exclude-deleted`) is **not** listed
here: it fires automatically from CLAUDE.md whenever a new or edited `SELECT`
in a Dao (`classes/dao/<Name>Dao.cls` — the only layer that queries) touches a
`RecordStatus__c` object, so no per-skill question gates it.

#### Conditional guide — history tracking

- **`history-decision-guide`** ([../guide/framework/history-desicion/history-decision-guide.md](../guide/framework/history-desicion/history-decision-guide.md))

Load it **if and only if** `scratchpad-memory.md` **§ 3 — History-tracking
decision** records **both**:

- `Triggered: yes`, and
- `Run continues: yes`

Any other state — § 3 absent, `Triggered: no`, or `Run continues: no` — means no
history work belongs to this run: **skip the guide silently**, do not open it,
and do not mention it.

When it does apply, the guide reads the recorded `Outcome` out of § 3 and routes
to the one reference that implements it (object + field metadata, deploy
command). Load that reference as well.

#### Required guide — CSS (loaded here, applied in Step 7)

- **`lwc-css-design-guide`** ([../guide/lwc-css-design-guide.md](../guide/lwc-css-design-guide.md))

`mode: required` — no gate, no question. Load it **now**, alongside the three
guides above, because its BEM block/element naming (§ 7) constrains the class
names Step 5 writes into the template: a constraint that arrives after emission
forces the markup to be rewritten. Writing the CSS itself is the last thing this
skill does — Step 7, after the full code is emitted.

#### The recorded tab answers — the last thing to read

After the three guides, read the user's own answers to the main tab questions out
of `scratchpad-memory.md` **§ 1 — Tab answers**: the tab name (Tab 1), the user
story (Tab 3), and the behavior (Tab 4). They are what the guides get applied
*to*. Take them verbatim; do not re-ask, re-derive, or second-guess them (Step 3
reads the rest of the context the same way).

#### Gate: guides are built, then everything is loaded

Do not evaluate the Part 1 gate until, in this order:

1. every file in `force-app/skill/pitfat/` is read in full,
2. all three required guides (1 → 2 → 3) are loaded in their order, plus
   `lwc-css-design-guide`, plus the conditional history guide if § 3 triggered
   it,
3. the § 1 tab answers (Tabs 1, 3, 4) are read.

Then coding may start. If a pitfall or guide file cannot be opened, **STOP** and
report which path failed — do not proceed on a partial load.

---

## Part 1 — Entry Point & Context Lock (Input & Gate)

### Input

This part of the skill requires the following inputs before proceeding.
Do not proceed to Step 1 until the parent LWC name is provided. (Step 0 has
already run — the guides load before this gate, not after it.)

#### Required Inputs

| # | Item | Source | Format |
|---|---|---|---|
| 1 | **Parent LWC name** | `scratchpad-memory.md` § 4 — Pather location | Full component name (e.g., `manageItems`) |

#### Optional Inputs

| # | Item | Source | Format |
|---|---|---|---|
| O1 | **Existing parent LWC code** | `scratchpad-memory.md` § 4 (paths) → read the files | Complete `.js`, `.html`, `Validator.js` if parent already exists (§ 4 status `NEW PATHER` means "not yet created") |

---

### Gate: Verify parent LWC name is provided (Part 1)

**Before proceeding to Step 1, open `scratchpad-memory.md` and verify § 4 carries
the parent LWC name (input 1).**

If **`scratchpad-memory.md` is missing, or § 4 has no pather name**, **STOP
immediately** and reply with:

> **Parent LWC Name Missing — Cannot Proceed**
>
> `scratchpad-memory.md` § 4 (Pather location) does not carry a pather name. This
> skill cannot lock the parent identity without it.
>
> **Missing input:**
> - 1. Parent LWC name — `scratchpad-memory.md` § 4
> - Reason: Cannot proceed with the interview without knowing the parent component
>
> **Action:** The caller writes § 4 in its Step 2a. Return control to the caller;
> do not ask the user. Re-enter at Step 1 once § 4 is written (the guides are
> already loaded and are not re-done).

**Do not guess or invent the parent LWC name. Do not proceed to Step 1 until it is provided.**

---

## Part 2 — Functionality Interview (Input & Gate)

### Input

This part of the skill requires the following inputs before code generation begins.
All of them are read from **`scratchpad-memory.md`** — this skill asks for none of
them. Do not proceed to Step 4 until all required inputs are present.

#### Required Inputs

| # | Item | Source | Format |
|---|---|---|---|
| 1 | **Parent LWC name** | From Part 1 (`scratchpad-memory.md` § 4) | Full component name (e.g., `manageItems`) |
| 2 | **Sub-components** | `scratchpad-memory.md` § 5 | Comma-separated list of sub-component names within the pather (e.g., "Summary, Status, Description") |
| 3 | **User stories** | `scratchpad-memory.md` § 1, Tab 3 | Each operation (Load/Update/Create/Delete) must have its own story |
| 4 | **Behavior prompt** | `scratchpad-memory.md` § 1, Tab 4 | Functional spec that covers every user story |
| 5 | **Validation rules** | `scratchpad-memory.md` § 8 (consolidated list) | Validation rules for this functionality (or "none") |
| 6 | **Data state** | `scratchpad-memory.md` § 7 | Object + field name that provides the data |
| 7 | **Reusable base component** | `scratchpad-memory.md` § 6 (base components the pather already uses) | Which existing base component to use (`c-ao-input`, `c-ao-btn`, `c-ao-combobox`, `lightning-*`, or none) |
| 8 | **Placement plan** | `scratchpad-memory.md` § 6 | Template insertion point, handler function pattern, location in the code, template structure, event name |
| 9 | **Apex target** | `scratchpad-memory.md` § 7 | Apex class + method, signature, return shape |


#### Optional Inputs

| # | Item | Source | Format |
|---|---|---|---|
| O1 | **Parent code files** | `scratchpad-memory.md` § 4 (paths) → read the files | Complete `.js`, `.html`, `Validator.js` if parent already exists |
| O2 | **Existing handlers** | Code inspection | Names of existing handler methods (for updating vs. creating new) |
| O3 | **Existing validators** | `scratchpad-memory.md` § 8 | Validator file(s) and functions already in place |
| O4 | **History-tracking decision** | `scratchpad-memory.md` § 3 | `Triggered` / `Outcome` / `Run continues`. Present only when the request involves history — it gates the optional `history-decision-guide` in Step 0 and nothing else |

---

### Gate: Verify all functionality inputs are present (Part 2)

**Before proceeding to Step 4, read `scratchpad-memory.md` and verify all required
inputs (1–9 above) are present in their named sections.** Do not gate on the
call-style inputs (§ 1 Tabs 6a/6c, § 2 Tabs 7–9) — the guide gates on those.

If **any required input is missing** (its section is absent or blank — `n/a` does
not count as missing), **STOP immediately** and reply with:

> **Functionality Context Incomplete — Cannot Proceed**
>
> `scratchpad-memory.md` does not carry all required inputs. This skill cannot
> proceed to code generation without them.
>
> **Missing inputs:**
> - [List each missing item by number, name, and section, e.g., "4. Behavior prompt — § 1, Tab 4"]
> - [Reason why it's needed, e.g., "Cannot determine handler logic without behavior spec"]
>
> **Action:** The caller fills the missing section of `scratchpad-memory.md`. Do
> not ask the user for it here — return control to the caller, then re-enter at
> Step 4.

**Do not guess, invent, or assume missing inputs. Do not emit any code.**

---

## Instructions

> Step 0 (load the guides) already ran — it is the first step of this skill and
> sits above Part 1's gate.

## Part 1 — Entry Point & Context Lock

### Step 1 — Read the parent LWC name

**Do not ask.** Read the pather (parent LWC) name and its file paths from
`scratchpad-memory.md` **§ 4 — Pather location**. Take it verbatim.

§ 4 also carries the pather's status (`found` / `NEW PATHER`); when it is `found`,
read the `.js`, `.html`, and validator files at the recorded paths (optional input
O1).

This name stays fixed for the whole invocation and is echoed in the tracker line
(see Resources). Do not infer or guess it — if § 4 is absent or empty, the Part 1
gate fires and control returns to the caller.

---

## Part 2 — Functionality Implementation

### Step 2 — Read parent LWC and sub-component selection

**Do not ask.** Read both from `scratchpad-memory.md`:

1. **Parent LWC selection** (§ 4) — which parent LWC (name or path) this
   functionality is for. The caller may name a different pather per run to apply
   the same functionality elsewhere.

2. **Sub-component selection** (§ 5) — the comma-separated list of sub-component
   names the functionality applies to, plus each one's status. These are
   sections/parts that exist inline within the pather template, not external
   `c-*` components. Example: "Summary, Status, Description".

Take both verbatim.

---

### Step 3 — Read the functionality context

**Do not ask and do not run an FAQ.** The caller already gathered every answer
below and wrote it into `scratchpad-memory.md`. Read them from the sections named
here:

- **§ 1, Tab 3** — User stories (each operation: Load/Update/Create/Delete)
- **§ 1, Tab 4** — Behavior prompt (must cover every user story)
- **§ 8** — Validation rules (the consolidated list: existing + new)
- **§ 7** — Data state (object + field that provides the data), plus the Apex
  class and method to call
- **§ 6** — Placement plan: template insertion point, handler function pattern,
  location in the code, template structure, event name, and the reusable base
  components the pather already uses (`c-ao-input`, `c-ao-btn`, `c-ao-combobox`,
  `lightning-*`, or none)

Apex integration requirements:

- **§ 1, Tab 6b** — Additional performance requirements (feeds the Apex-side
  guides in Step 0, not the call-style decision)

**Do not read the call-style answers here** — method cacheability (§ 1, Tab 6a),
visibility/urgency (§ 1, Tab 6c), and the data-load answers (§ 2, Tabs 7–9) are
read by [sequence-fe-desicion](../guide/sequence-fe-desicion-TEMPORARY.md) when
Step 4 applies it.

Take all answers verbatim. Do not validate, reason about, or predict them — and
do not re-ask any of them. These questions belong to the caller
([create-new-functionality.md](../create-new-functionality.md)); this skill only
consumes their recorded answers. If a section is missing, the Part 2 gate fires
and control returns to the caller.

---

### Step 4 — Analyze Apex call style and state management

**AI analysis (not user question). Apply the guides loaded in Step 0.**

1. From **`sequence-fe-desicion`**, derive the call style. That
   guide owns the decision logic end to end — read-type methods take the wire
   flow, everything else the imperative flow, each with its own merged-in
   sequence. Its inputs are the recorded answers in § 1 Tabs 6a/6c and § 2 Tabs
   7–9. Follow its branches; do not restate or re-derive them here.

2. From **`handle-state`**, select the state category that applies
   (Data State / Control State / Communication State / Interaction State). This
   determines state field naming and storage rules (e.g., `_isLoading`,
   `_selectedId`, `_draftData`).

3. **Write to `scratchpad-memory.md` → § 9 (Sub-skill analysis):** state category,
   call style (`@wire` or imperative), gating field name, `refreshApex` strategy,
   and initialization approach (pre-defined or lazy-set).

---

### Step 5 — Place code in the right layer

Every input for this step comes out of `scratchpad-memory.md`, plus the guides
loaded in Step 0. The parent LWC files at the § 4 paths are what gets written.

| What | Section |
|---|---|
| Parent files to edit | § 4 |
| Sub-components in scope | § 5 |
| Placement plan + base components | § 6 |
| Apex class, method, data state | § 7 |
| Validation rules | § 8 |
| State category, call style, gating field, `refreshApex`, init | § 9 |

Follow the placement plan recorded in **§ 6** verbatim — the template insertion
point, handler function pattern, location in the code, template structure, and
event name were already resolved by the caller against the real files. Do not
re-derive them.

- Sub-component data surfaces as derived **getters** (never a parallel tracked
  copy of child state).
- Each sub-component section gets exactly one handler (e.g.,
  `handleSummaryUpdate`), named to the § 6 handler pattern and wired with the § 6
  event listener.
- Apex calls target the class and method recorded in **§ 7**, and follow the hop
  signatures and input formats in **`sequence-be`** (Step 0 guide 2).
- Mutations go through state update methods that unpack Apex responses into
  de-normalized principal fields (never nest the full object).
- Failures raise a `ShowToastEvent`.
- Keep the parent as the orchestration layer — it listens, calls Apex, and
  updates principal state from responses; it does not optimistically mutate
  state before the Apex result lands.
- No emitted line reproduces a trap from the pitfall files loaded in Step 0 —
  check as the code is written, not only at Step 6.

---

### Step 6 — Verify with the execution checklist

Run both verifications against the emitted code before this unit of work is
considered done:

1. The state-management rules in `handle-state` (loaded in Step 0)
   — check every emitted state field against its category, naming, and storage
   rules.
2. Every pitfall file loaded in Step 0, one at a time, against the code just
   written — Apex and JavaScript alike. A pitfall that matches is a defect: fix
   it before the step is considered done.

---

### Step 7 — Apply `lwc-css-design-guide`

**Do not ask.** This is not a question — it is the last step, run unconditionally
once the full code from Steps 5–6 is emitted. The guide
([../guide/lwc-css-design-guide.md](../guide/lwc-css-design-guide.md)) is
`mode: required` and was already loaded in Step 0.

Write the CSS for every new parent-side UI surface from it, end-to-end:
Atlassian/Jira palette (§ 2), type scale (§ 3), spacing and radii (§ 4), BEM
naming matching the classes Step 5 put in the template (§ 7), the four
interactive states on every control (§ 8), and the shared patterns (§ 9). Finish
with the guide's own commit checklist (§ 15).

If the parent-side UI introduced no new styleable markup, note `no new CSS
surface` and move on — that is the only case where nothing is written, and it is
a fact about the emitted code, not a user choice.

Never invent CSS without `lwc-css-design-guide` — it codifies the project's
visual language so new parent-side UI blends with the rest of the codebase
without visual tuning.

This is the last step. When the guides, placement, and checklist all finish (code
emitted and accepted), exit this skill and return control to the caller.

---

## Resources

### Iteration tracker

Print this line at the top of every skill-level message so the iteration state is
visible:

```
[Parent: <name> | Step: <N> | Sub-components: <pending|list> | Memory: scratchpad-memory.md]
```

`Parent` and `Sub-components` are echoed from `scratchpad-memory.md` § 4 and § 5 —
they are never typed in by hand.
