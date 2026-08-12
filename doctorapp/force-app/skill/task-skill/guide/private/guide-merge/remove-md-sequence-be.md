# Remove a phase from `back-end/sequence/`

**Script:** `../../guide/private/back-end/sequence/sequence-be-merge.py`

The `doOperation()` lifecycle is a *chain*: each phase hands off to the next by
name. Deleting one leaves a hole the merge cannot detect — a `## → Next:` link to
a missing file is kept as a file link and reported as informational, not as an
error. **Re-link the chain first, delete last.**

```
phase-1-input-correctness → phase-2-delegate-to-service → phase-3-persist
```

## 1. Confirm the target

1. **Which phase file exactly?**
2. **Which layer loses its step?** Removing a phase removes a layer from the
   documented lifecycle — controller, DomainCorrectness, Service,
   DomainCompleteValidator, Dao. If the layer still runs at runtime and only the
   *document* is being reorganised, a neighbour must absorb its steps in the same
   change.
3. **What becomes the predecessor's successor?** If you are removing phase 1,
   the `entry:` block in `INDEX_DOC` and the `**Entry:**` link below the yaml
   both have to point at the new first phase.
4. **Renumber, or leave the gap?** The convention is contiguous 1..N, so
   renumber. Confirm first — it renames files.

## 2. Find every reference before touching anything

```bash
cd force-app/skill/task-skill/guide
grep -rn "phase-N-your-old-phase" private/ *.py     # → Next: links, entry:, index links
grep -rn "<its-h1-anchor>" private/ *.py            # hand-written anchor links
```

Search the `.py` files: the index lives inside `sequence-be-merge.py` as a yaml
block, and `phase-1-input-correctness.md` is named there in `entry: doc:`.

Also check the sibling phases for `[sequence.md](sequence.md)`-style references —
those point at the embedded index, not at a phase, and must be left alone.

## 3. Re-link the chain

In the **predecessor** file, repoint the closing section:

```markdown
## → Next: [Phase N — Title](phase-N-title.md)
```

at the new successor, and rewrite the sentence under it — it describes what the
next phase picks up, and that has changed.

If the removed phase was the **last** one, the new last phase drops its
`## → Next:` section entirely.

## 4. Renumber the remaining phases

```bash
cd force-app/skill/task-skill/guide/private/back-end/sequence
git mv phase-3-persist.md phase-2-persist.md    # lowest first when closing a gap
```

In every renamed file fix three places: the H1 `# Phase N — …`, the `phase:` line
in its fenced `yaml` block, and its closing `## → Next:` link. Then fix the
predecessor's `## → Next:` — the file it names just changed.

The file name orders the document (`PHASE_RE`); the H1 addresses it. Both move
together.

## 5. Update `INDEX_DOC`

In `sequence-be-merge.py`, inside the fenced `yaml` block:

- `summary:` — the pipeline line (`Controller → correctness check (via Dao) →
  Service → rule validation → persist`) now over-states what the guide contains;
- `entry:` `phase:` and `doc:` — if phase 1 changed;
- `participants:` — drop an actor no remaining phase involves;
- `dbAccessRule:` / `layout:` — check they still describe only layers that remain.

Below the yaml, the `**Entry:** → [Phase 1 — Input correctness](#phase-1--input-correctness)`
line is a hand-written anchor and is not rewritten by the merge. Correct it and
recompute the anchor if phase 1 changed.

## 6. Delete the file

```bash
git rm force-app/skill/task-skill/guide/private/back-end/sequence/phase-N-your-old-phase.md
```

## 7. Verify

```bash
python force-app/skill/task-skill/guide/private/back-end/sequence/sequence-be-merge.py
python force-app/skill/task-skill/guide/guides-merge.py
```

Both must exit 0. Expect the usual `.` lines for `guard/`, `performance/` and
`soql-exclude-deleted-guide.md` — those are correct. If the removed phase held
the only reference to one of them, that `.` line disappears; that is fine.

Then walk the chain:

```bash
grep -n "→ Next: \[Phase" force-app/skill/task-skill/guide/guides-TEMPORARY.md
grep -rn "phase-N-your-old-phase" force-app/skill/task-skill/guide/
```

The hand-offs must form an unbroken 1 → N run; the second must print nothing.

## 8. The one failure the build will not catch

A `## → Next: [Phase 4 — Gone](phase-4-gone.md)` left behind after the file is
deleted is **not** an error: no anchor matches, so it is rebased and reported as
`. kept link outside the document` — informational, exit 0. Read the `.` lines
after a removal. Anything named `phase-*` in that list is a dangling hand-off;
only the four `guard/` / `performance/` / `soql-exclude-deleted-guide.md` entries
belong there.
