# Remove a phase from `wire-flow/` (FLOW B)

**Script:** `../../guide/private/front-end/sequence/wire-flow/wire-flow-merge.py`

FLOW B is a *chain*: six phases, each naming the next. Deleting one leaves a hole
the merge cannot detect — `next:` and `→ Go to` links would point at a missing
file, and the merge keeps them as file links rather than failing.
**Re-link the chain first, delete last.**

```
phase-1-initialization → phase-2-cache-miss-gate → phase-3-spinner-and-gating-field
→ phase-4-round-trip → phase-5-handle-data-error → phase-6-clear-the-flag
```

## 1. Confirm the target

1. **Which phase file exactly?**
2. **Is the step really gone, or does it move into a neighbour?** If a neighbour
   absorbs it, that neighbour's numbered actor lines gain the absorbed steps in
   the same change — do not just delete.
3. **What becomes the predecessor's successor?** Usually the phase after the one
   being removed. If you are removing phase 1, the `## Start` hand-off in
   `INDEX_DOC` must point at the new first phase.
4. **Renumber, or leave the gap?** The convention is contiguous 1..N, so
   renumber. Confirm first — it renames files.

Be careful with the cache-related phases: `phase-2-cache-miss-gate` is what
decides whether the wire reaches the server at all. Removing it is not a
documentation trim, it changes what the flow claims to do — confirm that is
intended.

## 2. Find every reference before touching anything

```bash
cd force-app/skill/task-skill/guide
grep -rn "phase-N-your-old-phase" private/ *.py     # next:, → Go to, index links
grep -rn "<its-h1-anchor>" private/ *.py            # hand-written anchor links
```

The `INDEX_DOC` of `wire-flow-merge.py` and of `sequence-fe-merge.py` are inside
`.py` files, so search those too.

## 3. Re-link the chain

In the **predecessor** file:

- front matter `next:` → the new successor's file name;
- the closing `→ Go to [phase-….md](phase-….md).` link → the same file.

If the removed phase was the **last** one, the new last phase takes `next: none`
and loses its `→ Go to` line.

If it was the **first** one, update the `## Start` line in `INDEX_DOC` — it is
written as an anchor (`→ Go to [phase-1-initialization.md](#phase-1--initialization)`)
and is not rewritten by the merge, so correct it by hand and recompute the anchor.

## 4. Renumber the remaining phases

```bash
cd force-app/skill/task-skill/guide/private/front-end/sequence/wire-flow
git mv phase-4-round-trip.md phase-3-round-trip.md   # lowest first when closing a gap
```

Closing a gap renames from the lowest number above the gap upward. In every
renamed file fix all four places the number appears: the front matter `phase:`,
the front matter `next:`, the H1, and the closing `→ Go to` link. Fix the
predecessor's `next:` and `→ Go to` too — the file it points at just changed name.

The file name orders the document (`PHASE_RE`); the H1 addresses it. Both move
together.

## 5. Update `INDEX_DOC`

In `wire-flow-merge.py`, the front matter `chain:` line lists the steps in words
(`gating field → cache-miss gate → wire fires → { data, error } → flag cleared`).
Remove the step that is gone. This front matter is kept in the merged document,
so a stale `chain:` is reader-visible.

## 6. Delete the file

```bash
git rm force-app/skill/task-skill/guide/private/front-end/sequence/wire-flow/phase-N-your-old-phase.md
```

## 7. Verify

```bash
python force-app/skill/task-skill/guide/private/front-end/sequence/wire-flow/wire-flow-merge.py
python force-app/skill/task-skill/guide/guides-merge.py
```

Both must exit 0. Then walk the chain — this is the check that matters, because
a broken chain does **not** fail the build:

```bash
grep -n "Go to \[phase" force-app/skill/task-skill/guide/guides-TEMPORARY.md
grep -rn "phase-N-your-old-phase" force-app/skill/task-skill/guide/
```

The hand-offs must form an unbroken 1 → N run; the second must print nothing.

## 8. The one failure the build will not catch

A `→ Go to [phase-7-gone.md](phase-7-gone.md)` left behind after the file is
deleted is **not** an error to the merge: no anchor matches, so it is rebased and
reported as `. kept link outside the document` — informational, exit 0. Read the
`.` lines after a removal; anything named `phase-*` there is a dangling hand-off.
