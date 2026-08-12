# Add a guide to `front-end/sequence/`

**Script:** `../../guide/private/front-end/sequence/sequence-fe-merge.py`
**Output:** `sequence-fe-desicion-TEMPORARY.md`, written **outside** `private/`, into `guide/` itself.
**Index:** the `INDEX_DOC` string in that script (there is no `sequence-fe-desicion.md` on disk).

This folder holds **the decision**, not the steps: which Apex call flow a task
belongs to. The steps live in the two child folders.

```python
CHILDREN = [
    imperative-flow/imperative-flow-merge.py  -> sequence-imperative-flow-TEMPORARY.md,   # FLOW A
    wire-flow/wire-flow-merge.py              -> sequence-wire-flow-TEMPORARY.md,         # FLOW B
]
```

`collect()` is a **hybrid**: it globs this folder's own `*.md` (non-recursive)
and puts them *before* the two child outputs. `sort_key` places non-`phase-*`
files first, alphabetically by stem. There is no `ORDER` list. The folder is
currently empty of `.md` files — the index is embedded and the flows are
children — so anything you add here is the first thing a reader meets after the
decision itself.

## 1. Confirm what you are adding

| What you are adding | Where |
|---|---|
| a phase of the write flow | [add-md-imperative-flow.md](add-md-imperative-flow.md) — FLOW A |
| a phase of the read flow | [add-md-wire-flow.md](add-md-wire-flow.md) — FLOW B |
| something that helps **choose** between the flows, or applies to both | **here**, shape A |
| a **third flow** | **here**, shape B |
| what the server does with the call | [add-md-sequence-be.md](add-md-sequence-be.md) |

**Shape A** — one `.md` in this folder. It is merged automatically by the glob;
you edit `INDEX_DOC` to route to it.

**Shape B** — a new flow: a sub-folder with its own `*-merge.py`, added to
`CHILDREN`. Copy `wire-flow-merge.py` as the template; keep its front matter
convention, because this parent re-emits a child's front matter as a fenced yaml
block precisely so the flow can name itself (`flow: FLOW B — …`).

## 2. Ask these before writing anything

1. **Is it really flow-independent?** Anything true only of writes belongs to
   FLOW A, only of reads to FLOW B. This folder is for what comes *before* the
   choice, or what binds both.
2. **Shape A or shape B?** A third flow needs a `cacheable`/method-type rule that
   the current two do not cover. State it before adding one.
3. **File name?** kebab-case. Must **not** start with `phase-` (that prefix is
   reserved for the chain ordering) and must not be `sequence-fe-desicion.md`,
   which the script skips as the reserved index name.
4. **Exact H1 title?** It is the anchor, unique across the whole merged tree.
   The index's own H1 is `# Front-end sequence — choosing the Apex call flow`.
5. **Where does the reader arrive from?** The index sends readers to a flow with
   two bullets. A shape-A guide has to be reachable — decide whether it is read
   *before* the choice (a new line above the bullets) or *alongside* it.
6. **For shape B: the `flow:`, `applies-to:`, `chain:` and `entry:` front
   matter.** They are reader-visible in the merged document.
7. **Do the object-data instructions still hold?** The index opens by telling the
   reader to read `force-app/main/default/objects/<Object>__c/fields/` first. A
   new pre-decision guide either sits under that instruction or replaces it —
   decide which, and do not leave two competing "first, do this" openings.
8. **Does the `<!-- TODO -->` comment in `INDEX_DOC` apply to your change?** It
   records an open question about analysing the scratchpad tab answer. Leave it
   in place unless your guide resolves it — in which case say so explicitly.

Do not create anything until every answer is in hand.

## 3. Write the guide

**Shape A** — a plain `.md` in this folder. **The first non-front-matter line
must be the H1**; front matter on a local file is parsed off and dropped (only
the index keeps its own), so put nothing load-bearing there.

**Shape B** — the folder, its phase files (see the FLOW A / FLOW B add skills for
the phase conventions) and `<flow>-merge.py` copied from `wire-flow-merge.py`,
with its own `INDEX_NAME`, `INDEX_DOC`, `OUTPUT` name and `## Start` hand-off.

## 4. Register it

**Shape A** — nothing to add to a list; the glob finds it. Only `INDEX_DOC`
changes, in `sequence-fe-merge.py`:

```markdown
Then pick the flow the task belongs to:

- Read-type method (`cacheable = true`) → **[FLOW B — @wire with function handler](#flow-b--wire-with-function-handler-cacheable--yes)**
- Write-type method (`cacheable = false`) → **[FLOW A — imperative Apex call](#flow-a--imperative-apex-call-cacheable--no)**
```

Add your routing line in the same voice — condition first, then the arrow, then
the bolded link to the anchor.

**Shape B** — the child tuple, in the order the flows should read:

```python
CHILDREN = [
    ...,
    (
        HERE / "your-flow" / "your-flow-merge.py",
        HERE / "your-flow" / "sequence-your-flow-TEMPORARY.md",
    ),
]
```

plus a third bullet in the flow-choice list. Note the two existing anchors carry
the `cacheable` value in the title, which is what makes the choice
self-documenting — keep that.

## 5. Cross-links

If a flow phase should point at your guide, add a plain file link there; the
merge converts it. Check `../../guide/guides-merge.py`: its index describes this
guide as *"which Apex call flow a task belongs to, and every phase of the flow it
picks"* — a third flow or a new pre-decision step may make that wording thin.

## 6. Verify

```bash
python force-app/skill/task-skill/guide/private/front-end/sequence/sequence-fe-merge.py
python force-app/skill/task-skill/guide/guides-merge.py
```

Both must exit 0 with no `!` line. `missing part: …` on a shape-B addition means
the child ran but did not write the output name listed in `CHILDREN`.

```bash
grep -n "merged from: your-new-guide.md" force-app/skill/task-skill/guide/guides-TEMPORARY.md
grep '^# ' force-app/skill/task-skill/guide/guides-TEMPORARY.md | sort | uniq -d
```

The first must print a line; the second must print nothing.

## 7. What breaks silently

- **A local file named `phase-…`** → sorted with the phases, ahead of the flows it was meant to introduce.
- **H1 not the first line** → title injected from the file name, index link dangles.
- **Shape B whose child script writes its output elsewhere** → `missing part`, or worse, a stale file merged from a previous run.
- **A shape-B child without front matter** → the flow loses its self-identifying `flow:` block, which this parent deliberately preserves as a fenced yaml block.
- **A duplicate H1 anywhere in the tree** → anchor numbered `-1`, links land on the wrong section.
