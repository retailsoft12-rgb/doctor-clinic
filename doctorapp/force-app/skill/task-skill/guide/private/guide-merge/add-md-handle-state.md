# Add a guide to `handle-state/`

**Script:** `../../guide/private/handle-state/handle-state-merge.py`
**Output:** `handle-state-TEMPORARY.md`, written **outside** `private/`, into `guide/` itself.
**Index:** the `INDEX_DOC` string in that script (there is no `handle-state.md` on disk).

This is the **top of the state tree**: the four categories of LWC state. It does
**not** glob — `collect()` walks the explicit `PARTS` list, and `CHILDREN` names
the sub-merges to run first.

```python
CHILDREN = [ data-state-merge.py, communication-state-merge.py, interaction-state-merge.py ]

PARTS = [
    "data-state/data-state-TEMPORARY.md",             # child output
    "control-state/control-state.md",                 # a plain guide, merged directly
    "communication-state/communication-state-TEMPORARY.md",
    "interaction-state/interaction-state-TEMPORARY.md",
]
```

`control-state/` is the shape to copy for a single-guide category: a folder, one
`.md`, no merge script of its own.

## 1. Confirm you are adding a *category*, not a guide

| What you are adding | Where |
|---|---|
| a guide about data shape, picklists, principal entities | [add-md-local-data-state.md](add-md-local-data-state.md) |
| a guide about localStorage or a new data category | [add-md-data-state.md](add-md-data-state.md) |
| a guide about spinners / errors | [add-md-communication-state.md](add-md-communication-state.md) |
| a guide about drag, hover, expand | [add-md-interaction-state.md](add-md-interaction-state.md) |
| a guide about modals, drawers, panel visibility | a sibling inside `control-state/` — **here**, shape A |
| a **fifth category of state**, alongside data / control / communication / interaction | **here**, shape A or B |

A fifth category is a real claim: it must not be storable inside the four. Say
which of the four it would otherwise fall into and why that is wrong, before
adding it.

**Shape A** — one folder, one `.md`, added to `PARTS` (as `control-state/` is).
**Shape B** — a folder with several guides and its own `*-merge.py`, added to
both `CHILDREN` and `PARTS`. Copy `interaction-state-merge.py` as the template
for shape B; it is the smallest leaf script.

## 2. Ask these before writing anything

1. **Which category, and why is it not one of the four?** One paragraph.
2. **Shape A or shape B?**
3. **Folder and file name?** Match `control-state/control-state.md`. Must not be
   `handle-state.md` — that name is reserved for the embedded index.
4. **Exact H1 title?** It is the anchor, unique across the whole merged tree.
   Note the existing categories' H1s do not all match their folder names
   (`control-state.md` opens `# LWC Control State`), which is exactly why the
   index links by computed anchor and not by file name.
5. **READ when — the trigger bullets.** Four bullets, each a task the reader is
   starting (`Implementing modal or drawer visibility logic`).
6. **Contains — one sentence.** Every category block closes with a
   `**Contains:**` summary of the patterns inside it.
7. **An emoji for the heading?** The four use 📊 🎛️ ⚡ 👆. Pick one that is not
   already taken.
8. **Where in `PARTS`, and where in the index?** Index order is data → control →
   communication → interaction, and `PARTS` follows it. Keep them consistent.
9. **Which guides link to it, and which does it link to?**

Do not create anything until every answer is in hand.

## 3. Write the guide

Create the folder and the `.md`. **The first non-front-matter line must be the
H1** — this script maps sections to anchors with `anchors_in()`, which reads the
first H1 after each `<!-- merged from: … -->` marker. No H1, no anchor, and every
link to the category dangles. There is no `TITLES` fallback in this script.

For **shape B**, also write `<name>-merge.py` from the `interaction-state-merge.py`
template with its own `INDEX_DOC`, `ORDER` and `OUTPUT` name.

## 4. Register it in `handle-state-merge.py`

**Shape A**:

```python
PARTS = [
    ...,
    "your-category/your-category.md",     # ← at the position answered in Q8
]
```

**Shape B** — both lists:

```python
CHILDREN = [
    ...,
    (
        HERE / "your-category" / "your-category-merge.py",
        HERE / "your-category" / "your-category-TEMPORARY.md",
    ),
]

PARTS = [
    ...,
    "your-category/your-category-TEMPORARY.md",
]
```

`INDEX_DOC` — one block, at the Q8 position, closed with a `---`:

```markdown
## <emoji> [Your Category Guide](#your-h1-anchor)

**READ when:**
- <trigger bullet from Q5>
- <trigger bullet>
- <trigger bullet>
- <trigger bullet>

**Contains:** <Q6>.

---
```

## 5. Cross-links

Add the inbound links promised in Q9. Then check
`../../guide/guides-merge.py`: its index describes this guide as *"the four state
categories (data, control, communication, interaction)"*. A fifth category makes
that sentence wrong — update it in the same change.

## 6. Verify

```bash
python force-app/skill/task-skill/guide/private/handle-state/handle-state-merge.py
python force-app/skill/task-skill/guide/guides-merge.py
```

Both must exit 0 with no `!` line. `missing part: …` means a `PARTS` entry does
not resolve; `missing child merge script: …` means a `CHILDREN` path is wrong.

```bash
grep -n "merged from: your-category" force-app/skill/task-skill/guide/guides-TEMPORARY.md
grep '^# ' force-app/skill/task-skill/guide/guides-TEMPORARY.md | sort | uniq -d
```

The first must print a line; the second must print nothing.

## 7. What breaks silently

- **Not in `PARTS`** → the guide does not exist as far as the merge is concerned. No warning.
- **Shape B added to `PARTS` but not `CHILDREN`** → the child never runs; the merge uses a stale `-TEMPORARY.md`, or fails with `missing part` on a clean checkout.
- **No H1 in the file** → `anchors_in()` finds nothing and every link to the category dangles. No `TITLES` fallback here.
- **A duplicate H1 anywhere in the tree** → anchor numbered `-1`, links land on the wrong section.
- **The "four categories" wording left in `guides-merge.py`** → the top-level index now under-counts what it indexes.
