# Remove a guide from `handle-state/`

**Script:** `../../guide/private/handle-state/handle-state-merge.py`

This is the top of the state tree, and it does **not** glob — `collect()` walks
the explicit `PARTS` list and `run_children()` runs the sub-merges named in
`CHILDREN`. Deleting a file before de-registering it fails the build with
`missing part: …`. **De-register first, delete last.**

## 1. Confirm the target

1. **Which file exactly?** Is it a direct part (`control-state/control-state.md`)
   or a guide *inside* one of the three child folders? If it is inside a child,
   stop and use that folder's skill —
   [data-state](remove-md-data-state.md) ·
   [communication-state](remove-md-communication-state.md) ·
   [interaction-state](remove-md-interaction-state.md). This script never sees
   those files individually; it only sees their merged output.
2. **Is a whole category going?** Removing a category means removing its
   `PARTS` entry, its `CHILDREN` entry if it had a merge script, its
   `INDEX_DOC` block, and the folder itself.
3. **Deleted or moved?** If moved, this is a remove here **plus** an add in the
   destination — keep the H1 unchanged so inbound links only need repointing.
4. **Who absorbs its content?** Name the guide now; inbound links get repointed
   there rather than deleted.

## 2. Find every reference before touching anything

```bash
cd force-app/skill/task-skill/guide
grep -rn "your-old-guide" private/ *.py        # file links, wiki links, PARTS, CHILDREN
grep -rn "<its-h1-anchor>" private/ *.py       # hand-written anchor links
```

The indexes live inside the `.py` files, so search them too. A category at this
level is linked from the sibling categories as well as from the index — expect
hits in several `INDEX_DOC` strings and in `guides-merge.py`.

## 3. De-register from `handle-state-merge.py`

```python
CHILDREN = [ ... ]   # drop the (script, output) tuple if the folder had a merge script
PARTS = [ ... ]      # drop the entry for the .md, or for the child's -TEMPORARY.md
```

`INDEX_DOC` — remove the whole block: the `## <emoji> [Category](#anchor)`
heading, its `**READ when:**` bullets, its `**Contains:**` line and the trailing
`---`.

## 4. Fix every inbound link

- **content absorbed** → repoint at the absorbing guide's file name; the merge
  converts it to an anchor.
- **content gone** → delete the link and any sentence that only existed to carry it.

Two places to check by hand:

- the sibling categories' `INDEX_DOC` strings, which cross-reference each other;
- `../../guide/guides-merge.py`, whose index calls this guide *"the four state
  categories (data, control, communication, interaction)"*. Removing one makes
  that sentence wrong.

## 5. Delete the file

```bash
git rm force-app/skill/task-skill/guide/private/handle-state/your-category/your-old-guide.md
```

If the whole category is going, `git rm -r` the folder — including its
`*-merge.py` — and `rm` any untracked `*-TEMPORARY.md` left inside it.

## 6. Verify

```bash
python force-app/skill/task-skill/guide/private/handle-state/handle-state-merge.py
python force-app/skill/task-skill/guide/guides-merge.py
```

Both must exit 0. Three distinct failures to read:

- `missing part: …` → a `PARTS` entry still names something that is gone.
- `missing child merge script: …` → a `CHILDREN` entry still names a deleted script.
- `! link to missing anchor: …` → an inbound reference was missed in step 4.

```bash
grep -n "your-old-guide" force-app/skill/task-skill/guide/guides-TEMPORARY.md   # must print nothing
```
