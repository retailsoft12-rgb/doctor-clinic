# Add a guide to `interaction-state/`

**Script:** `../../guide/private/handle-state/interaction-state/interaction-state-merge.py`
**Output:** `interaction-state-TEMPORARY.md` → feeds `handle-state-merge.py` → `guides-merge.py`
**Index:** the `INDEX_DOC` string in that script (there is no `interaction-state.md` on disk).

This folder covers **ephemeral, transient UI state** — what the user is doing
right now: dragging, hovering, expanding, selecting. Never persisted, never sent
to the server. It holds `drag-drop-guide.md` and `expanded-collapsed-guide.md`.
The script collects with `rglob("*.md")`, so any `.md` in the folder is merged
whether or not you register it — registering gives it a position and an entry.

## 1. Confirm this is the right folder

| The new guide is about | Folder |
|---|---|
| a gesture in progress — drag, hover, select, expand | **here** |
| state that survives the gesture and is read back later | [add-md-local-data-state.md](add-md-local-data-state.md) |
| modal / drawer / panel visibility a user command opens and closes | `handle-state/control-state/` → [add-md-handle-state.md](add-md-handle-state.md) |
| spinners and error toasts around an Apex call | [add-md-communication-state.md](add-md-communication-state.md) |

The test to apply: **if the value must still be right after the interaction
ends, it is not interaction state.** Interaction state is cleared on `dragend`,
on close, on blur.

## 2. Ask these before writing anything

1. **Which interaction does it own, and what clears it?** Both halves are
   required — an interaction-state guide that never says when the state is
   cleared is incomplete, and every existing guide here ends on that rule.
2. **File name?** kebab-case, `*-guide.md`. Must not be `interaction-state.md`
   (reserved — the script skips that name) and must not end in `-TEMPORARY`.
3. **Exact H1 title?** It is the anchor, unique across the whole merged tree.
   Siblings name the interaction fully — `# Drag and Drop Interaction State Guide`,
   `# Expanded/Collapsed State Guide`.
4. **Read when — one sentence.** The index entry opens with a single
   `**Read when:**` line naming the component work that triggers the read
   (`Implementing or editing accordion … functionality`), not a topic.
5. **Covers — the bullet list.** Three to five bullets: the state variables, the
   lifecycle, the clearing rule, the computed getters. This is the shape both
   existing entries use.
6. **Before or after the existing two?** `ORDER` is `drag-drop-guide.md` →
   `expanded-collapsed-guide.md`.
7. **Which existing guides link to it, and which does it link to?** Note
   `control-state/control-state.md` also discusses drag-and-drop from the
   control side — check whether it should point here.
8. **Should `handle-state-merge.py`'s index mention it?** That index has one
   block per category — extend the `**Contains:**` line of the Interaction State
   entry rather than adding a block.

Do not create the file until every answer is in hand.

## 3. Write the `.md`

**The first non-front-matter line must be the H1**, or `title_for()` injects a
title from the file name and the index link dangles. End the guide on the
clearing rule from Q1 — that is the convention of this folder.

## 4. Register it in the script

```python
ORDER = [
    "drag-drop-guide.md",
    "expanded-collapsed-guide.md",
    "your-new-guide.md",       # ← at the position answered in Q6
]
```

`TITLES` — only if the file genuinely cannot start with an H1.

`INDEX_DOC` — one entry under `## 📋 Reference Guides`, in `ORDER` position:

```markdown
### [your-new-guide](#your-h1-anchor)
**Read when:** <Q4 — the component work that triggers the read>.

Covers:
- <state variables it defines>
- <the lifecycle, event by event>
- <what clears it, and when>
- <computed getters / CSS class patterns>
```

The last entry in the section is followed by the file's closing `---`; keep that
`---` last.

## 5. Cross-links

Add the inbound links promised in Q7. If the category summary in
`../../guide/private/handle-state/handle-state-merge.py` no longer covers what
this folder holds, extend the `**Contains:**` sentence of its
`## 👆 [Interaction State Guide](#interaction-state-management-guide)` block.

## 6. Verify

```bash
python force-app/skill/task-skill/guide/private/handle-state/interaction-state/interaction-state-merge.py
python force-app/skill/task-skill/guide/guides-merge.py
```

Both must exit 0 with no `!` line. Then:

```bash
grep -n "merged from: your-new-guide.md" force-app/skill/task-skill/guide/guides-TEMPORARY.md
grep '^# ' force-app/skill/task-skill/guide/guides-TEMPORARY.md | sort | uniq -d
```

The first must print a line; the second must print nothing.

## 7. What breaks silently

- **H1 not the first line** → title injected from the file name, index link dangles.
- **A duplicate H1 anywhere in the tree** → anchor numbered `-1`, links land on the wrong section.
- **Not added to `ORDER`** → still merged, but appended after both existing guides.
- **File named `interaction-state.md`** → skipped entirely; the script reserves that name.
