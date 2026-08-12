# Add a guide to `data-state/`

**Script:** `../../guide/private/handle-state/data-state/data-state-merge.py`
**Output:** `data-state-TEMPORARY.md` → feeds `handle-state-merge.py` → `guides-merge.py`
**Index:** the `INDEX_DOC` string in that script (there is no `data-state.md` on disk).

This is a **parent** merge, and it behaves differently from the leaf folders:
it does **not** glob. `collect()` walks the explicit `PARTS` list only, so a new
`.md` dropped anywhere under `data-state/` is invisible until you list it. There
is no "it merged but in the wrong order" failure mode here — it either is in
`PARTS` or it does not exist.

```python
PARTS = [
    "local-data-state/local-data-state-TEMPORARY.md",   # produced by the child script
    "local-storage-state/local-storage-state.md",       # a plain guide, merged directly
]
```

## 1. Decide which of the three shapes you are adding

| What you are adding | Shape | Where |
|---|---|---|
| a guide about picklists, server indicators, principal entities, derived state | a sibling in the existing case folder | stop — use [add-md-local-data-state.md](add-md-local-data-state.md) |
| a single guide about a **new** data category (as `local-storage-state.md` is) | **shape A** — a new folder holding one `.md`, added to `PARTS` | here |
| a category that needs several guides of its own | **shape B** — a new sub-folder with its own `*-merge.py`, added to `CHILD`/`PARTS` | here |

Shape B is a bigger change: it means writing a new merge script. Copy
`local-data-state-merge.py` as the template — it is the leaf-folder form, with
`ORDER`, `TITLES`, `INDEX_DOC` and `rglob` collection — and then this file's
`CHILD` constant must become a list, since it currently holds exactly one script.

## 2. Ask these before writing anything

1. **Which data category does it own?** It must be a category the current
   decision tree does not already route to. The tree has five branches:
   shared context (localStorage), picklists, server indicators, principal data,
   derived values. A sixth needs to be genuinely disjoint from those.
2. **Shape A or shape B?** From the table above.
3. **Folder and file name?** Siblings pair them (`local-storage-state/local-storage-state.md`).
   Must not be `data-state.md` — that name is reserved for the embedded index.
4. **Exact H1 title?** It is the anchor, unique across the whole merged tree.
5. **The decision-tree question.** The index routes by question, not by topic:
   `Is it shared application context (workspace ID, workflow ID, user theme)?`
   Write the new one in that voice, with concrete examples in parentheses.
6. **READ WHEN — one line.** Each branch closes with a `**READ WHEN:**` line
   naming the situations that send a reader there.
7. **Where in the tree?** Branches are numbered 1–5 and the numbering is
   sequential; inserting in the middle renumbers everything after it.
8. **Where in `PARTS`?** `PARTS` order is the document order — the index promises
   the branches in its own order, so keep the two consistent.
9. **Which guides link to it, and which does it link to?**

Do not create anything until every answer is in hand.

## 3. Write the guide

Create the folder and the `.md`. **The first non-front-matter line must be the
H1** — this parent maps sections to anchors with `anchors_in()`, which reads the
first H1 after each `<!-- merged from: … -->` marker. No H1, no anchor, and every
link to the guide dangles. Unlike the leaf scripts, this one has no `TITLES`
fallback: an H1 in the file is the only way.

For **shape B**, also create `<name>-merge.py` from the `local-data-state-merge.py`
template, and give it its own `INDEX_DOC`, `ORDER` and `OUTPUT` name.

## 4. Register it in `data-state-merge.py`

**Shape A** — one line:

```python
PARTS = [
    "local-data-state/local-data-state-TEMPORARY.md",
    "local-storage-state/local-storage-state.md",
    "your-category/your-category.md",        # ← at the position answered in Q8
]
```

**Shape B** — the child must run before the merge, so its `-TEMPORARY.md` is
fresh. `CHILD` is currently a single path and `run_child()` runs just that one;
turn both into a list (`CHILDREN`, looping as `handle-state-merge.py` does) and
add the new `-TEMPORARY.md` to `PARTS`.

`INDEX_DOC` — a new branch in the decision tree, at the position from Q7:

```markdown
### 6. **<the question from Q5, with concrete examples>?**
   → **[READ: Your Category Guide](#your-h1-anchor)**
   **READ WHEN:** <Q6>.
```

Renumber the following branches if you inserted in the middle. If the guide is a
supporting one rather than a routing branch, add it instead to the closing
paragraph that already names the Three Cases index and the checklist.

## 5. Cross-links

Add the inbound links promised in Q9. Then decide whether
`../../guide/private/handle-state/handle-state-merge.py` needs to change: its
index has one block per state category, and its `**Contains:**` line for
`## 📊 [Data State Guide](#data-state-guide)` summarises exactly this tree.

## 6. Verify

```bash
python force-app/skill/task-skill/guide/private/handle-state/data-state/data-state-merge.py
python force-app/skill/task-skill/guide/guides-merge.py
```

Both must exit 0 with no `!` line. `missing part: …` means the `PARTS` entry does
not resolve — check the path is relative to `data-state/` and that a shape-B
child actually produced its output.

```bash
grep -n "merged from: your-category" force-app/skill/task-skill/guide/guides-TEMPORARY.md
grep '^# ' force-app/skill/task-skill/guide/guides-TEMPORARY.md | sort | uniq -d
```

The first must print a line; the second must print nothing.

## 7. What breaks silently

- **Not in `PARTS`** → the guide does not exist as far as the merge is concerned. No warning.
- **No H1 in the file** → `anchors_in()` finds nothing, and every link to it dangles. There is no `TITLES` fallback in this script.
- **A duplicate H1 anywhere in the tree** → anchor numbered `-1`, links land on the wrong section.
- **Shape B without wiring the child run** → the merge uses whatever stale `-TEMPORARY.md` is on disk, or fails with `missing part` on a clean checkout.
- **`PARTS` order out of step with the index numbering** → the document reads in a different order than the tree promises.
