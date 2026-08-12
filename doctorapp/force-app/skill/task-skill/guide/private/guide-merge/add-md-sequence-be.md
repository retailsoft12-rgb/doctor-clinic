# Add a phase to `back-end/sequence/`

**Script:** `../../guide/private/back-end/sequence/sequence-be-merge.py`
**Output:** `sequence-be-TEMPORARY.md`, written **outside** `private/`, into `guide/` itself.
**Index:** the `INDEX_DOC` string in that script (there is no `sequence.md` on disk).

This is the `doOperation()` request lifecycle: **Controller → correctness check
(via Dao) → Service → rule validation → persist.** Three phases today, and it is
a *chain* — each phase hands off to the next by name.

```
phase-1-input-correctness → phase-2-delegate-to-service → phase-3-persist
```

The script collects with `glob("*.md")` — non-recursive — and orders by the
`phase-N` prefix (`PHASE_RE`), so **the file name decides the position**. There
is no `ORDER` list. Files not named `phase-*` sort first, before phase 1.

Two things make this folder different from the front-end flows:

- **No YAML front matter.** These phases carry their metadata in a fenced
  `yaml` block *inside* the body, below the H1. Do not add front matter — it
  would be parsed off and dropped.
- **Links out of the tree.** The phases point at `guard/apex-governor-limit-guard.md`,
  `performance/apex-bulk-soql.md`, `performance/apex-method-monitor.md` and
  `soql-exclude-deleted-guide.md`, which live outside `private/`. Those cannot
  become anchors; `rebase()` re-expresses them relative to `guide/`, where the
  output lands, and they are reported as `. kept link outside the document`.
  That is expected, not a failure.

## 1. Confirm this is the right folder

| The step you are documenting | Folder |
|---|---|
| server-side: controller, correctness, service, validator, Dao, DML | **here** |
| the browser side of the same call — spinner, toast, `.then()` | [add-md-imperative-flow.md](add-md-imperative-flow.md) |
| the browser side of a read — `@wire`, cache gate | [add-md-wire-flow.md](add-md-wire-flow.md) |
| which front-end flow a task belongs to | [add-md-sequence-fe.md](add-md-sequence-fe.md) |

## 2. Ask these before writing anything

1. **What does the phase do, and which layer owns it?** Name the class in the
   `layout` vocabulary the index already defines: controller, DomainCorrectness,
   Service, DomainCompleteValidator, Dao. A phase that does not map to a layer
   is probably a step inside an existing phase.
2. **Where in the chain?** Between which two phases, or at the end.
3. **Its number and file name.** `phase-N-kebab-title.md`. Inserting in the
   middle renames every later file — plan the renames now.
4. **Exact H1?** The convention is `# Phase N — Title Case`, and the em dash
   matters: `Phase 2 — Delegate to service` slugs to `phase-2--delegate-to-service`,
   with **two** hyphens. Compute the anchor, do not type it.
5. **The `phase:` line for its yaml block.** `"N — kebab or prose title"`,
   matching the siblings.
6. **Predecessor and successor.** The predecessor's closing
   `## → Next: [Phase N — Title](phase-N-….md)` section has to be repointed, and
   this phase needs its own.
7. **Does it touch the database?** If so, restate the `dbAccessRule` that
   applies: every SOQL goes in `classes/dao/<Name>Dao.cls`; DML stays in the
   Service that owns the object. The phases repeat this rule where it binds.
8. **Does the index summary change?** `INDEX_DOC`'s yaml carries `summary:`
   (`Controller → correctness check (via Dao) → Service → rule validation →
   persist`) and an `entry:` block. A new phase usually changes `summary:`, and a
   new *first* phase changes `entry:` and the `**Entry:**` link below the yaml.

Do not create the file until every answer is in hand.

## 3. Write the phase file

Match the siblings — H1 first, a short prose lead, the yaml block, the steps,
then the hand-off section:

````markdown
# Phase 2 — Delegate to service

The controller arrives here holding **resolved records**, not raw ids. Class
placement and the preconditions of the whole lifecycle are in
[sequence.md](sequence.md) → `layout` / `precondition`.

```yaml
phase: "2 — delegate to service"
...
```

---

## → Next: [Phase 3 — Persist](phase-3-persist.md)

<one or two sentences on what the next phase picks up>
````

Rules the merge depends on:

- **The H1 must be the very first line.** No front matter. The H1 becomes the
  anchor; without one, `title_for()` injects a title from the file name and every
  link to the phase dangles.
- **Hand-off and cross links stay file links.** Write
  `[Phase 3 — Persist](phase-3-persist.md)` — the merge rewrites the target to
  `#phase-3--persist`. Never write the anchor by hand.
- **`[sequence.md](sequence.md)` still resolves.** The file is gone but the name
  is registered as `INDEX_NAME`, and the index section answers to it. Keep using
  that link when referring to `layout` / `dbAccessRule` / `legend`.
- **Links to `guard/` and `performance/`** are written with `../../../` hops
  relative to *this folder*; `rebase()` fixes them for the output location. Write
  them as they resolve from here, not from `guide/`.

## 4. Renumber the chain

If you inserted rather than appended:

```bash
cd force-app/skill/task-skill/guide/private/back-end/sequence
git mv phase-3-persist.md phase-4-persist.md    # highest first when opening a gap
```

Rename **from the highest number down**. Then in each renamed file fix three
places: the H1 `# Phase N — …`, the `phase:` line in its yaml block, and its
closing `## → Next: [Phase N+1 — …](phase-N+1-….md)` section. And repoint the
predecessor's `## → Next:` at the new phase.

## 5. Update `INDEX_DOC`

In `sequence-be-merge.py`, inside the fenced `yaml` block:

- `summary:` — the one-line pipeline, if the sequence changed;
- `entry:` (`phase:` and `doc:`) — only if you inserted a new first phase;
- `participants:` — if the phase introduces an actor the list does not name;
- `layout:` — if it introduces a class family the list does not describe.

And below the yaml, the `**Entry:** → [Phase 1 — Input correctness](#phase-1--input-correctness)`
line is written as an anchor by hand — it is not rewritten by the merge, so it
must be corrected and recomputed if phase 1 changed.

## 6. Verify

```bash
python force-app/skill/task-skill/guide/private/back-end/sequence/sequence-be-merge.py
python force-app/skill/task-skill/guide/guides-merge.py
```

Both must exit 0 with no `!` line. Expect four `.` lines naming the `guard/`,
`performance/` and `soql-exclude-deleted-guide.md` links — those are correct.
If your new phase adds an outside link, a fifth `.` line appears; confirm the
rebased path exists from `guide/`:

```bash
ls force-app/skill/task-skill/guide/<the rebased path printed in the . line>
```

Then walk the chain and check uniqueness:

```bash
grep -n "→ Next: \[Phase" force-app/skill/task-skill/guide/guides-TEMPORARY.md
grep '^# ' force-app/skill/task-skill/guide/guides-TEMPORARY.md | sort | uniq -d
```

## 7. What breaks silently

- **Adding YAML front matter** → parsed off and dropped; the metadata disappears
  from the merged document. It belongs in a fenced `yaml` block in the body.
- **Renaming files but not the `## → Next:` links** → the merge still builds, but
  the chain reads out of order. Only the `grep` walk catches it.
- **A hand-written anchor** with one hyphen where the em dash produced two →
  `!` line, build fails.
- **A file not named `phase-N-…`** → sorted before phase 1, at the top of the guide.
- **File named `sequence.md`** → skipped entirely; the script reserves that name
  for the embedded index.
- **A phase title shared with a front-end phase** → duplicate H1 across the merged
  tree, anchor numbered `-1`. Back-end titles are Title Case and front-end ones
  lowercase, which is what keeps `Phase 1` apart in three places.
