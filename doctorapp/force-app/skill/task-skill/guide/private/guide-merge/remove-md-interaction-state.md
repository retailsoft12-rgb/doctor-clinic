# Remove a guide from `interaction-state/`

**Script:** `../../guide/private/handle-state/interaction-state/interaction-state-merge.py`

**De-register first, delete last.** The script collects with `rglob("*.md")`, so
deleting the file drops it from the merge at once — but its `ORDER` entry, its
`INDEX_DOC` entry and every inbound link stay behind, and those links become
dangling anchors that fail the build.

## 1. Confirm the target

1. **Which file exactly?**
2. **Deleted or moved?** If moved, this is a remove here **plus** an add in the
   destination — run that folder's `add-md-*.md` afterwards, keeping the H1
   unchanged so inbound links only need repointing.
3. **Who absorbs its content?** Name the guide now; inbound links get repointed
   there rather than deleted.

If you are removing drag-and-drop from here, check
`control-state/control-state.md` first — it covers drag-and-drop from the control
side and may already hold, or may need to absorb, the part being dropped.

## 2. Find every reference before touching anything

```bash
cd force-app/skill/task-skill/guide
grep -rn "your-old-guide" private/ *.py        # file links, wiki links, ORDER, TITLES
grep -rn "<its-h1-anchor>" private/ *.py       # hand-written anchor links
```

The indexes live inside the `.py` files, so search them too. Expect hits in
`interaction-state-merge.py`, and possibly `handle-state-merge.py` and
`control-state/control-state.md`.

## 3. De-register from `interaction-state-merge.py`

```python
ORDER = [ ... ]     # drop the "your-old-guide.md" entry
TITLES = { ... }    # drop its entry if it had one
```

`INDEX_DOC` — remove the whole entry: the `### [name](#anchor)` heading, its
`**Read when:**` line and the entire `Covers:` list. Keep the file's closing
`---` after the last remaining entry.

## 4. Fix every inbound link

- **content absorbed** → repoint at the absorbing guide's file name; the merge
  converts it to an anchor.
- **content gone** → delete the link and any sentence that only existed to carry it.

Check `handle-state-merge.py`'s `**Contains:**` line for the Interaction State
category and correct it if it advertises the pattern that just left.

## 5. Delete the file

```bash
git rm force-app/skill/task-skill/guide/private/handle-state/interaction-state/your-old-guide.md
```

## 6. Verify

```bash
python force-app/skill/task-skill/guide/private/handle-state/interaction-state/interaction-state-merge.py
python force-app/skill/task-skill/guide/guides-merge.py
```

Both must exit 0. A `!` line names an anchor still pointing at the removed guide
— that reference was missed in step 4.

```bash
grep -n "your-old-guide" force-app/skill/task-skill/guide/guides-TEMPORARY.md   # must print nothing
```
