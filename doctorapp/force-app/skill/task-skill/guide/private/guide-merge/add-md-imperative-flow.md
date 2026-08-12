# Add a phase to `imperative-flow/` (FLOW A)

**Script:** `../../guide/private/front-end/sequence/imperative-flow/imperative-flow-merge.py`
**Output:** `sequence-imperative-flow-TEMPORARY.md` → feeds `sequence-fe-merge.py` → `guides-merge.py`
**Index:** the `INDEX_DOC` string in that script (there is no `sequence-imperative-flow.md` on disk).

FLOW A is the **write-type** Apex call (`cacheable = No`). It is a *chain*, not a
list: five phases, each handing off to the next by name. Adding one is a
renumbering job, not a file drop.

```
phase-1-synchronous-validation → phase-2-spinner-up → phase-3-round-trip
→ phase-4-branch-on-the-response → phase-5-finally-clear-the-flag (next: none)
```

The script collects with `glob("*.md")` — non-recursive — and orders by the
`phase-N` prefix (`PHASE_RE`), so **the file name decides the position**. There
is no `ORDER` list to edit. Files whose name does not start with `phase-` sort
first, before phase 1.

## 1. Confirm this is the right flow

| The step you are documenting belongs to | Flow |
|---|---|
| a write (`cacheable = false`), imperative `apexMethod({...}).then().catch()` | **here** — FLOW A |
| a read (`cacheable = true`), `@wire` with a function handler | [add-md-wire-flow.md](add-md-wire-flow.md) — FLOW B |
| the choice between the two flows | [add-md-sequence-fe.md](add-md-sequence-fe.md) |
| what happens server-side once the call lands | [add-md-sequence-be.md](add-md-sequence-be.md) |

## 2. Ask these before writing anything

1. **What does the phase do, and why is it not part of an existing one?** Five
   phases is a deliberate shape; a sixth must be a distinct step in the chain,
   not a detail of a step.
2. **Where in the chain does it go?** Between which two existing phases, or at
   the end. This decides how much renumbering follows.
3. **Its number and file name.** `phase-N-kebab-title.md`. Inserting at position
   3 means every file from the old 3 onward is renamed — plan the renames now.
4. **Exact H1?** The convention is `# Phase N — <lowercase title>`, and the em
   dash matters: `Phase 3 — round trip` slugs to `phase-3--round-trip`, with
   **two** hyphens. Compute the anchor, do not type it.
5. **`title:` for the front matter.** A short phrase, lowercase, the same one
   used in the H1 after the em dash.
6. **What is the predecessor, and what is the successor?** Both have to be
   edited: the predecessor's `next:` and its closing `→ Go to …` line, and this
   phase's own.
7. **Are there branches?** Existing phases use `**ELSE**` / `**OR**` before an
   alternative hand-off. Say which arrows leave this phase and where each goes.
8. **Does the flow summary change?** `INDEX_DOC`'s front matter carries
   `chain: user action → validate → spinner up → Apex → branch → toast → spinner down`.
   A new phase almost always changes that line.

Do not create the file until every answer is in hand.

## 3. Write the phase file

Match the siblings exactly — front matter, then H1, then the numbered actor
lines, then the hand-off:

```markdown
---
phase: 3
title: round trip — the call is in flight
next: phase-4-branch-on-the-response.md
---

# Phase 3 — round trip

1. **component.js → Apex @AuraEnabled** — `apexMethod({ params })`
2. **Apex @AuraEnabled ⇢ component.js** — `APIResponse | rejection`

→ Go to [phase-4-branch-on-the-response.md](phase-4-branch-on-the-response.md).
```

Rules the merge depends on:

- **The H1 must be the first line after the front matter.** Front matter is
  parsed off and dropped (only the index keeps its own); the H1 becomes the
  anchor. Without one, `title_for()` injects `Phase 3 Round Trip` from the file
  name and every link to the phase dangles.
- **Hand-off links stay file links.** Write
  `[phase-4-branch-on-the-response.md](phase-4-branch-on-the-response.md)` — the
  merge rewrites the target to `#phase-4--branch-on-the-response`. Never write
  the anchor by hand.
- **The last phase carries `next: none`** and no `→ Go to` line.

## 4. Renumber the chain

If you inserted rather than appended, for every phase after the insertion point:

```bash
git mv phase-4-branch-on-the-response.md phase-5-branch-on-the-response.md   # etc, highest first
```

Rename **from the highest number down**, so no rename collides with an existing
file. Then in each renamed file fix all four places the number appears:

- the front matter `phase:` value,
- the front matter `next:` file name,
- the H1 `# Phase N — …`,
- the closing `→ Go to [phase-N+1-….md](phase-N+1-….md)` link.

And in the file *before* the insertion point: its `next:` and its `→ Go to` link
now point at the new phase.

## 5. Update `INDEX_DOC`

In `imperative-flow-merge.py`:

- the front matter `chain:` line, if the sequence of steps changed (Q8);
- the `## Start` hand-off, **only** if you inserted a new phase 1 —
  `→ Go to [phase-1-synchronous-validation.md](#phase-1--synchronous-validation)`
  is written as an anchor there and will not be rewritten for you.

Note that this index keeps its front matter in the merged document (it names
FLOW A, which the decision index selects between), so `chain:` is reader-visible.

## 6. Verify

```bash
python force-app/skill/task-skill/guide/private/front-end/sequence/imperative-flow/imperative-flow-merge.py
python force-app/skill/task-skill/guide/guides-merge.py
```

Both must exit 0 with no `!` line. Then walk the chain in the output — every
phase must be reachable from `## Start`:

```bash
grep -n "Go to \[phase" force-app/skill/task-skill/guide/guides-TEMPORARY.md
grep '^# ' force-app/skill/task-skill/guide/guides-TEMPORARY.md | sort | uniq -d
```

The hand-off targets must form an unbroken 1 → N run; the second command must
print nothing.

## 7. What breaks silently

- **Renaming files but not the `next:` / `→ Go to` links** → the merge still
  builds (both point at real anchors), but the chain reads out of order. Only the
  `grep` walk in step 6 catches this.
- **A hand-written anchor** with one hyphen where the em dash produced two →
  `!` line, build fails. Compute it.
- **A file not named `phase-N-…`** → sorted *before* phase 1, at the top of the flow.
- **File named `sequence-imperative-flow.md`** → skipped entirely; the script reserves that name.
- **A duplicate H1 anywhere in the tree** → note FLOW A and FLOW B both have a
  `Phase 1`; their titles are what keep the anchors distinct. Never give a FLOW A
  phase the same title as the FLOW B phase of the same number.
