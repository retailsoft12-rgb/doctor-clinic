# Add a phase to `wire-flow/` (FLOW B)

**Script:** `../../guide/private/front-end/sequence/wire-flow/wire-flow-merge.py`
**Output:** `sequence-wire-flow-TEMPORARY.md` → feeds `sequence-fe-merge.py` → `guides-merge.py`
**Index:** the `INDEX_DOC` string in that script (there is no `sequence-wire-flow.md` on disk).

FLOW B is the **read-type** Apex call (`cacheable = Yes`) — `@wire` with a
function handler. It is a *chain*, not a list: six phases, each handing off to
the next by name. Adding one is a renumbering job, not a file drop.

```
phase-1-initialization → phase-2-cache-miss-gate → phase-3-spinner-and-gating-field
→ phase-4-round-trip → phase-5-handle-data-error → phase-6-clear-the-flag
```

The script collects with `glob("*.md")` — non-recursive — and orders by the
`phase-N` prefix (`PHASE_RE`), so **the file name decides the position**. There
is no `ORDER` list to edit. Files whose name does not start with `phase-` sort
first, before phase 1.

## 1. Confirm this is the right flow

| The step you are documenting belongs to | Flow |
|---|---|
| a read (`cacheable = true`), `@wire` with a function handler | **here** — FLOW B |
| a write (`cacheable = false`), imperative `.then().catch()` | [add-md-imperative-flow.md](add-md-imperative-flow.md) — FLOW A |
| the choice between the two flows | [add-md-sequence-fe.md](add-md-sequence-fe.md) |
| what happens server-side once the call lands | [add-md-sequence-be.md](add-md-sequence-be.md) |

FLOW B has steps FLOW A does not — the gating field, the cache-miss gate, the
LDS cache path. A phase about *whether the wire fires at all* belongs here and
has no FLOW A equivalent.

## 2. Ask these before writing anything

1. **What does the phase do, and why is it not part of an existing one?** Six
   phases is a deliberate shape; a seventh must be a distinct step in the chain,
   not a detail of a step.
2. **Where in the chain does it go?** Between which two existing phases, or at
   the end.
3. **Its number and file name.** `phase-N-kebab-title.md`. Inserting at position
   3 means every file from the old 3 onward is renamed — plan the renames now.
4. **Exact H1?** The convention is `# Phase N — <lowercase title>`, and the em
   dash matters: `Phase 2 — cache-miss gate` slugs to `phase-2--cache-miss-gate`,
   with **two** hyphens. Compute the anchor, do not type it.
5. **`title:` for the front matter.** Note the FLOW B convention is a fuller
   phrase than the H1 — `title: cache-miss gate — will this assignment reach the
   server?` against `# Phase 2 — cache-miss gate`. The H1 is the anchor; the
   `title:` is the question the phase answers.
6. **What is the predecessor, and what is the successor?** Both get edited: the
   predecessor's `next:` and its closing `→ Go to …` line, and this phase's own.
7. **Are there branches?** FLOW B phases fork on the cache — existing files use
   `**OR**` before the LDS-served path. Say which arrows leave this phase.
8. **Does the flow summary change?** `INDEX_DOC`'s front matter carries
   `chain: gating field → cache-miss gate → wire fires → { data, error } → flag cleared`.
   A new phase almost always changes that line.

Do not create the file until every answer is in hand.

## 3. Write the phase file

Match the siblings exactly — front matter, then H1, then the numbered actor
lines, then the hand-off:

```markdown
---
phase: 3
title: spinner and gating field — commit to the round-trip
next: phase-4-round-trip.md
---

# Phase 3 — spinner and gating field

1. **component.js → self** — set `isLoading = true`
2. **component.js → self** — assign the gating field, `$param` changes

→ Go to [phase-4-round-trip.md](phase-4-round-trip.md).
```

Rules the merge depends on:

- **The H1 must be the first line after the front matter.** Front matter is
  parsed off and dropped (only the index keeps its own); the H1 becomes the
  anchor. Without one, `title_for()` injects a title from the file name and every
  link to the phase dangles.
- **Hand-off links stay file links.** Write
  `[phase-4-round-trip.md](phase-4-round-trip.md)` — the merge rewrites the
  target to `#phase-4--round-trip`. Never write the anchor by hand.
- **The last phase carries `next: none`** and no `→ Go to` line.

## 4. Renumber the chain

If you inserted rather than appended, for every phase after the insertion point:

```bash
git mv phase-5-handle-data-error.md phase-6-handle-data-error.md   # highest first when opening a gap
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

In `wire-flow-merge.py`:

- the front matter `chain:` line, if the sequence of steps changed (Q8);
- the `## Start` hand-off, **only** if you inserted a new phase 1 —
  `→ Go to [phase-1-initialization.md](#phase-1--initialization)` is written as
  an anchor there and will not be rewritten for you.

This index keeps its front matter in the merged document (it names FLOW B, which
the decision index selects between), so `chain:` is reader-visible.

## 6. Verify

```bash
python force-app/skill/task-skill/guide/private/front-end/sequence/wire-flow/wire-flow-merge.py
python force-app/skill/task-skill/guide/guides-merge.py
```

Both must exit 0 with no `!` line. Then walk the chain in the output:

```bash
grep -n "Go to \[phase" force-app/skill/task-skill/guide/guides-TEMPORARY.md
grep '^# ' force-app/skill/task-skill/guide/guides-TEMPORARY.md | sort | uniq -d
```

The hand-off targets must form an unbroken 1 → N run; the second command must
print nothing.

## 7. What breaks silently

- **Renaming files but not the `next:` / `→ Go to` links** → the merge still
  builds, but the chain reads out of order. Only the `grep` walk catches it.
- **A hand-written anchor** with one hyphen where the em dash produced two →
  `!` line, build fails. Compute it.
- **A file not named `phase-N-…`** → sorted *before* phase 1, at the top of the flow.
- **File named `sequence-wire-flow.md`** → skipped entirely; the script reserves that name.
- **A title shared with the FLOW A phase of the same number** → duplicate H1,
  anchor numbered `-1`, and links meant for one flow land in the other. FLOW A
  and FLOW B both have a `Phase 1`; only their titles keep them apart.
