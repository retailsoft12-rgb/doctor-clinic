---
metadata:
  type: reference
  applies_to: history / audit / change-log functionality
  activation:
    mode: conditional
---

# History Decision Guide

Entry point for every "track the changes" requirement. The **decision is already
made** before this guide is read: `create-new-functionality` → Step 1c ran the
H1–H7 sequence and wrote the outcome into `scratchpad-memory.md` → section 3.

This guide's only job is to **read that outcome and open the matching
reference**. Exactly one reference is loaded per run — the branch that does not
apply is never read.

---

## Instructions

### Step 1 — Read the decision (MANDATORY — first action)

Open `scratchpad-memory.md` from the session scratchpad directory and read
**section 3 — History-tracking decision**. Take these three lines:

| Line in section 3 | What it decides here |
|---|---|
| `Triggered:` | whether a history requirement exists at all |
| `Outcome:` | which reference below to open |
| `Run continues:` | whether the run is still alive |

Do **not** ask the user anything in this step. Do not re-run H1–H7. Do not
re-evaluate an outcome you disagree with — the answers that produced it are in
the same section, and the user already gave them.

**Gate — stop before routing if any of these hold:**

- `scratchpad-memory.md` does not exist, or has no section 3 → stop. Tell the
  user the history decision was never recorded and that
  `create-new-functionality` → Step 1c must run first.
- `Triggered: no` → stop. There is no history requirement in this run; this
  guide does not apply.
- `Run continues: no` → stop. The run was already halted at Step 1c; nothing
  here restarts it.

---

### Step 2 — Route on `Outcome`

Open **one** reference — the row that matches the recorded `Outcome` verbatim.

---

## 🗂️ [Field Tracking History Configuration Guide](field-tracking-history-configuration-guide.md)

**READ when:** section 3 records `Outcome: Field History Tracking`.

**Contains:** how to resolve the target object and its fields out of the
scratchpad, how to switch the object to `<enableHistory>true</enableHistory>`,
how to set `<trackHistory>true</trackHistory>` on each field that needs it, the
20-field and field-type limits that invalidate the choice, the narrow deploy
command that ships only the history-related metadata, and the `<Object>__History`
read pattern.

**This is the only implemented branch.**

---

## ⛔ Branches with no reference yet

| `Outcome` in section 3 | Reference | What to do |
|---|---|---|
| `Setup Audit Trail` | not written | stop — see below |
| `Chatter Feed Tracking` | not written | stop — see below |
| `Field Audit Trail (Shield)` | not written | stop — see below |
| `Custom history object` | not written | stop — see below |

These outcomes are **decided but not implemented**: no guide has been written for
them yet. `create-new-functionality` → Step 1c already stops the run when it
produces one of them, so reaching this guide with such an outcome means the run
escaped that gate.

When it happens, stop here and tell the user:

- which outcome section 3 records and which H-question decided it (quote the
  question and their answer verbatim from the section 3 table),
- that only **Field History Tracking** has an implementation guide today, so
  there is nothing to follow for the approach their answers point to,
- that the interview is preserved in `scratchpad-memory.md` and does not have to
  be redone.

Do not improvise an implementation, do not substitute Field History Tracking for
what was decided, and do not reopen the H1–H7 questions hoping for a different
answer.

---

### Step 3 — One run, one branch

Once a reference is opened, stay in it. A run never reads two history references
and never switches branch mid-implementation. If the opened reference itself
stops the run (e.g. the object or fields cannot be resolved), that stop is final
for this run.

---

## Adding a new branch later

When a reference is written for one of the unimplemented outcomes:

1. Add the file next to this one under `guide/framework/history-desicion/`.
2. Give it a `## 🗂️ [<name>](<file>.md)` block above, with the **READ when**
   line naming the exact `Outcome` string from section 3.
3. Delete its row from the "no reference yet" table.

Keep one outcome per reference. The routing above stays a straight lookup on the
recorded `Outcome`, never a re-derivation of the decision.
