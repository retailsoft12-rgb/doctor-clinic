# Add a guide to `local-data-state/`

**Script:** `../../guide/private/handle-state/data-state/local-data-state/local-data-state-merge.py`
**Output:** `local-data-state-TEMPORARY.md` → feeds `data-state-merge.py` → `handle-state-merge.py` → `guides-merge.py`
**Index:** the `INDEX_DOC` string in that script (there is no `local-data-state.md` on disk).

This folder holds the **three cases of LWC data state** plus derived state and
the checklist. Its script collects with `rglob("*.md")`, so any `.md` dropped in
the folder — or in a sub-folder of it — is merged whether or not you register it.
Registering it is what gives it a *position* and an *index entry*.

## 1. Confirm this is the right folder

| The new guide is about | Folder |
|---|---|
| picklists, server indicators, principal entities, derived getters, the state checklist | **here** |
| `localStorage` / cross-component shared context | `data-state/local-storage-state/` → use [add-md-data-state.md](add-md-data-state.md) |
| spinners, toasts, error handling | [add-md-communication-state.md](add-md-communication-state.md) |
| drag-drop, expand/collapse, hover, selection | [add-md-interaction-state.md](add-md-interaction-state.md) |
| modals, drawers, panel visibility | `handle-state/control-state/` → [add-md-handle-state.md](add-md-handle-state.md) |

## 2. Ask these before writing anything

1. **What data problem does it solve, in one sentence?** Decides whether it is a
   new *Case* or a supporting guide — the index has two different shapes for them.
2. **Is it a new Case (4, 5, …) or a supporting guide?** A Case gets a table row,
   an entry-point question and a `## Case N` block. A supporting guide gets one
   bullet under `## Also In This Document`.
3. **File name?** kebab-case, `*-guide.md` like its siblings. Must not be
   `local-data-state.md` (that name is reserved — the script skips it) and must
   not end in `-TEMPORARY`.
4. **Exact H1 title?** This is the anchor and it must be unique across the whole
   merged tree. The siblings carry their case in the title
   (`Principal Data State — Case 3 (Data State)`); match that if it is a Case.
5. **READ WHEN — the trigger lines.** When should a reader open it? Two to four
   lines, phrased as the situation the reader is in, not as a summary.
6. **Key Rule — one sentence.** The index states each case's rule before linking.
7. **Where in the reading order?** Current `ORDER`:
   `picklist-static-options-guide.md` → `server-indicators-guide.md` →
   `principal-data-state-guide.md` → `derived-state.md` →
   `pather-lwc-state-management-checklist-guide.md`. The checklist stays last.
8. **Which existing guides link to it, and which does it link to?** Both
   directions are written as plain file links (`[x](x-guide.md)`) or wiki links
   (`[[x-guide]]`); the merge converts them to anchors.
9. **Does `data-state-merge.py`'s index need to mention it too?** Only if it is a
   new Case — that index carries the numbered decision tree readers arrive on.

Do not create the file until every answer is in hand.

## 3. Write the `.md`

Put it in the folder next to its siblings. **The first non-front-matter line must
be the H1** — `title_for()` only accepts an H1 that starts the body; otherwise it
injects a title from the file name (`My Guide`) and your index link breaks. Front
matter is allowed but dropped: only the index keeps its own.

Links inside the file may point at siblings by file name; leave them as file
links, the merge rewrites them.

## 4. Register it in the script

Three edits, in `local-data-state-merge.py`:

```python
ORDER = [
    ...,
    "your-new-guide.md",      # ← at the position answered in Q7
]
```

`TITLES` — only if the file genuinely cannot start with an H1:

```python
TITLES = {
    "your-new-guide.md": "Exact Title That Becomes The Anchor",
}
```

`INDEX_DOC` — a **new Case** needs all three of these:

```markdown
| **4** | Your Case Name | What it is | Example |          ← the glance table

4. **Is it <the entry-point question>?**
   → **[READ Case 4: Your Case Name](#your-h1-anchor)**   ← the entry point list

## Case 4: Your Case Name                                  ← the case block

**READ WHEN:** <trigger lines from Q5>

**Key Rule:** <Q6>

[→ Read full guide: Your Case Name](#your-h1-anchor)

---
```

A **supporting guide** needs only:

```markdown
- **[Your Guide Title](#your-h1-anchor)** — <one line on what it is for>.
```

added under `## Also In This Document`.

## 5. Cross-links

Add the inbound links promised in Q8 to the sibling guides. If a parent index
should route to it, edit the `INDEX_DOC` of
`../../guide/private/handle-state/data-state/data-state-merge.py` the same way —
its shape is a numbered decision tree (`### N. **Is it …?**` → `→ **[READ: X](#anchor)**`).

## 6. Verify

```bash
python force-app/skill/task-skill/guide/private/handle-state/data-state/local-data-state/local-data-state-merge.py
python force-app/skill/task-skill/guide/guides-merge.py
```

Both must exit 0 with no `!` line. Then confirm the guide actually landed and is
addressable:

```bash
grep -n "merged from: your-new-guide.md" force-app/skill/task-skill/guide/guides-TEMPORARY.md
grep '^# ' force-app/skill/task-skill/guide/guides-TEMPORARY.md | sort | uniq -d
```

The first must print a line; the second must print nothing.

## 7. What breaks silently

- **H1 not the first line** → title injected from the file name, index link dangles.
- **A duplicate H1 anywhere in the tree** → anchor numbered `-1`, links land on the wrong section.
- **Anchor typed by hand** → `report_dangling` catches it as `!`, so never ship a run that prints one.
- **Not added to `ORDER`** → still merged, but appended after the checklist, out of reading order.
- **File named `local-data-state.md`** → skipped entirely; the script reserves that name.
