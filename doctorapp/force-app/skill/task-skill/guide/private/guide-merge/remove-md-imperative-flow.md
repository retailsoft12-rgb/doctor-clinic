# Remove a phase from `imperative-flow/` (FLOW A)

**Script:** `../../guide/private/front-end/sequence/imperative-flow/imperative-flow-merge.py`

FLOW A is a *chain*: five phases, each naming the next. Deleting one leaves a
hole that the merge cannot detect — `next:` and `→ Go to` links would point at a
missing file, and the merge would keep them as file links rather than failing.
**Re-link the chain first, delete last.**

```
phase-1-synchronous-validation → phase-2-spinner-up → phase-3-round-trip
→ phase-4-branch-on-the-response → phase-5-finally-clear-the-flag (next: none)
```

## 1. Confirm the target

1. **Which phase file exactly?**
2. **Is the step really gone, or does it move into a neighbour?** If a neighbour
   absorbs it, that neighbour's numbered actor lines must gain the absorbed
   steps in the same change — do not just delete.
3. **What becomes the predecessor's successor?** Usually the phase after the one
   being removed. If you are removing phase 1, the `## Start` hand-off in
   `INDEX_DOC` must point at the new first phase.
4. **Renumber, or leave the gap?** The convention here is contiguous numbering
   1..N, so renumber. Confirm before doing it — it renames files.

## 2. Find every reference before touching anything

```bash
cd force-app/skill/task-skill/guide
grep -rn "phase-N-your-old-phase" private/ *.py     # next:, → Go to, index links
grep -rn "<its-h1-anchor>" private/ *.py            # hand-written anchor links
```

The `INDEX_DOC` of `imperative-flow-merge.py` and of
`sequence-fe-merge.py` are inside `.py` files, so search those too.

## 3. Re-link the chain

In the **predecessor** file:

- front matter `next:` → the new successor's file name;
- the closing `→ Go to [phase-….md](phase-….md).` link → the same file.

If the removed phase was the **last** one, the new last phase takes
`next: none` and loses its `→ Go to` line entirely.

If the removed phase was the **first** one, update the `## Start` line in
`INDEX_DOC` — it is written as an anchor
(`→ Go to [phase-1-…](#phase-1--…)`) and is not rewritten by the merge, so it
must be corrected by hand and its anchor recomputed.

## 4. Renumber the remaining phases

```bash
cd force-app/skill/task-skill/guide/private/front-end/sequence/imperative-flow
git mv phase-4-branch-on-the-response.md phase-3-branch-on-the-response.md   # lowest first when closing a gap
```

Closing a gap renames **upward-to-downward**, so start with the lowest number
above the gap. In every renamed file fix all four places the number appears: the
front matter `phase:`, the front matter `next:`, the H1, and the closing
`→ Go to` link. Fix the *predecessor's* `next:` and `→ Go to` too — the file it
points at just changed name.

The file name is what orders the document (`PHASE_RE`), and the H1 is what
addresses it. Both have to move together.

## 5. Update `INDEX_DOC`

In `imperative-flow-merge.py`, the front matter `chain:` line lists the steps in
words (`user action → validate → spinner up → Apex → branch → toast → spinner down`).
Remove the step that is gone. This front matter is kept in the merged document,
so a stale `chain:` is reader-visible.

## 6. Delete the file

```bash
git rm force-app/skill/task-skill/guide/private/front-end/sequence/imperative-flow/phase-N-your-old-phase.md
```

## 7. Verify

```bash
python force-app/skill/task-skill/guide/private/front-end/sequence/imperative-flow/imperative-flow-merge.py
python force-app/skill/task-skill/guide/guides-merge.py
```

Both must exit 0. Then walk the chain — this is the check that matters, because
a broken chain does **not** fail the build:

```bash
grep -n "Go to \[phase" force-app/skill/task-skill/guide/guides-TEMPORARY.md
grep -rn "phase-N-your-old-phase" force-app/skill/task-skill/guide/
```

The hand-offs must form an unbroken 1 → N run; the second command must print
nothing.

## 8. The one failure the build will not catch

A `→ Go to [phase-6-gone.md](phase-6-gone.md)` left behind after the file is
deleted is **not** an error to the merge: no anchor matches, so it is rebased and
reported as `. kept link outside the document` — an informational line, exit 0.
Read the `.` lines after a removal; anything named `phase-*` in that list is a
dangling hand-off you missed.
