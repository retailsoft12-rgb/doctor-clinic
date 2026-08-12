# Add a top-level guide to `guide/`

**Script:** `../../guide/guides-merge.py`
**Output:** `guides-TEMPORARY.md` — the whole private tree as one document.
**Index:** the `INDEX_DOC` string in that script (there is no `guides.md` on disk).

This is the root. It runs the three top-level merges and then merges their
outputs under its own index:

```python
SCRIPTS = [
    (private/handle-state/handle-state-merge.py,      guide/handle-state-TEMPORARY.md),
    (private/front-end/sequence/sequence-fe-merge.py, guide/sequence-fe-desicion-TEMPORARY.md),
    (private/back-end/sequence/sequence-be-merge.py,  guide/sequence-be-TEMPORARY.md),
]
```

It does **not** glob and it does **not** merge loose `.md` files. Adding a guide
here means adding a **fourth subtree with its own merge script** — there is no
lighter shape at this level. A single new document belongs inside one of the
three existing trees.

## 1. Confirm this is really a fourth top-level guide

| What you are adding | Where |
|---|---|
| anything about what state the component holds | [add-md-handle-state.md](add-md-handle-state.md) |
| anything about how the front end calls Apex | [add-md-sequence-fe.md](add-md-sequence-fe.md) |
| anything about what the back end does with the call | [add-md-sequence-be.md](add-md-sequence-be.md) |
| a standalone guide read on its own, never merged (CSS, SOQL, reusable components) | drop it in `guide/` and link it — **not** this skill; it stays a file link and is reported as `. kept link outside the document` |
| a fourth subject the three trees do not cover | **here** |

The index states the reading order as a claim: *state the component holds → how
the front end calls Apex → what the back end does with the call.* A fourth guide
has to fit that narrative or change it. Say which, in words, before starting.

## 2. Ask these before writing anything

1. **What subject does it own, and why is it not part of the three?** One
   paragraph. This is the question that decides whether the change is warranted.
2. **Where in the reading order?** `SCRIPTS` order is document order, and the
   index's numbered list mirrors it. Both change together.
3. **Folder under `private/`, script name, output name.** The convention is
   `private/<area>/<topic>/<topic>-merge.py` → `<topic>-TEMPORARY.md`, written
   into `guide/` (not into `private/`) — that is what `GUIDE_ROOT` does in the
   three existing top-level scripts.
4. **Exact H1 for the new guide's `INDEX_DOC`?** It is the anchor this root index
   links to, and must be unique across the whole merged tree.
5. **The one-line description for the root index.** The existing three are a
   bolded link followed by an em dash and a clause, e.g. *"the four state
   categories (data, control, communication, interaction), each with its own
   storage, scope and update rules."*
6. **Does anything load the three guides by name?**
   `../create-new-parent-lwc-component.md` names
   `handle-state-TEMPORARY.md`, `sequence-fe-desicion-TEMPORARY.md` and
   `sequence-be-TEMPORARY.md` individually in its Step 0. A fourth guide is
   invisible to that skill until it is listed there too.
7. **Is the Step 7 cleanup still correct?** It globs `guide/**/*-TEMPORARY.md`,
   which already catches any new output. Confirm your output matches that glob.

Do not create anything until every answer is in hand.

## 3. Write the subtree

Create `private/<area>/<topic>/` and its guides, then `<topic>-merge.py`. Copy
whichever existing script matches the shape you need:

| Your subtree | Template |
|---|---|
| one folder, several sibling guides | `interaction-state-merge.py` (glob + `ORDER` + `INDEX_DOC`) |
| a chain of numbered phases | `wire-flow-merge.py` (glob + `PHASE_RE` ordering) |
| a parent over sub-folders | `handle-state-merge.py` (`CHILDREN` + `PARTS`) |

Whichever you copy, the top-level script must:

- resolve `GUIDE_ROOT` and write `OUTPUT` into `guide/`, not into `private/`;
- carry its own `INDEX_NAME` / `INDEX_DOC` with a unique H1;
- exit non-zero on a dangling anchor, so the root run fails loudly.

## 4. Register it in `guides-merge.py`

```python
SCRIPTS = [
    ...,
    (
        PRIVATE / "your-area" / "your-topic" / "your-topic-merge.py",
        HERE / "your-topic-TEMPORARY.md",
    ),
]
```

The second element is checked after the run — `run_scripts()` reports
*"reported success but X is missing"* if the script exits 0 without writing it.

`INDEX_DOC` — a numbered entry, at the Q2 position:

```markdown
4. **[Your Guide Title](#your-h1-anchor)** — <the one-line description from Q5>.
```

Renumber the list if you inserted in the middle, and check the lead-in sentence
(*"Read them in this order: …"*) still names the sequence correctly.

## 5. Update what loads the guides

`main()` prints every guide it also wrote individually — that list comes from
`SCRIPTS`, so it updates itself. What does not update itself:

- `../create-new-parent-lwc-component.md` Step 0, which names the three outputs
  by file name;
- any skill or note that says *"the three guides"*.

## 6. Verify

```bash
python force-app/skill/task-skill/guide/guides-merge.py
```

Must exit 0 with no `!` line, and the run must print all four script banners.
Then:

```bash
grep -n "merged from: your-topic-TEMPORARY.md" force-app/skill/task-skill/guide/guides-TEMPORARY.md
grep '^# ' force-app/skill/task-skill/guide/guides-TEMPORARY.md | sort | uniq -d
```

The first must print a line; the second must print nothing — this check matters
more here than anywhere else, since a fourth subtree is the most likely source of
a title that collides with one of the existing 35 sections.

## 7. What breaks silently

- **A new script that writes its output inside `private/`** → `guides-merge.py` reports it missing, or merges a stale copy from `guide/`.
- **A child that exits 0 on a dangling anchor** → the root run inherits a broken document without failing. Keep `return 0 if report_dangling(text) else 1`.
- **`SCRIPTS` order out of step with the index numbering** → the document reads in a different order than the index promises.
- **A title that collides with an existing section** → anchor numbered `-1`, and links meant for the new guide land in an old one.
- **`create-new-parent-lwc-component.md` not updated** → the new guide builds but is never loaded by the skill that consumes the tree.
