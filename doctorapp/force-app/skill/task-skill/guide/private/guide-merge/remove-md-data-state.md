# Remove a guide from `data-state/`

**Script:** `../../guide/private/handle-state/data-state/data-state-merge.py`

This parent does **not** glob — `collect()` walks the explicit `PARTS` list. So
the failure mode is the opposite of a leaf folder: delete the `.md` first and the
next run stops with `missing part: …` and exit 1. **De-register first, delete
last.**

```python
PARTS = [
    "local-data-state/local-data-state-TEMPORARY.md",
    "local-storage-state/local-storage-state.md",
]
```

## 1. Confirm the target

1. **Which file exactly?** And is it a direct part (listed in `PARTS`) or a guide
   *inside* the `local-data-state/` child? If it is inside the child, stop —
   use [remove-md-local-data-state.md](remove-md-local-data-state.md); this
   script never sees those files individually.
2. **Deleted or moved?** If moved, this is a remove here **plus** an add in the
   destination — keep the H1 unchanged so inbound links only need repointing.
3. **Who absorbs its content?** Name the guide now; inbound links get repointed
   there rather than deleted.
4. **Is a whole sub-folder going, or one file out of several?** Removing a
   sub-folder that has its own `*-merge.py` also means removing the child run
   (`CHILD` / `run_child()`) — leaving it wired makes the merge fail on a
   missing script.

## 2. Find every reference before touching anything

```bash
cd force-app/skill/task-skill/guide
grep -rn "your-old-guide" private/ *.py        # file links, wiki links, PARTS
grep -rn "<its-h1-anchor>" private/ *.py       # hand-written anchor links
```

The indexes live inside the `.py` files, so search them too. A guide at this
level is usually routed to from several places — expect hits in
`data-state-merge.py`, in `handle-state-merge.py`, and in sibling guides that
cross-reference it (`[[local-storage-state]]`-style wiki links included).

## 3. De-register from `data-state-merge.py`

```python
PARTS = [ ... ]     # drop the entry for the file (or the child's -TEMPORARY.md)
```

If a sub-folder with its own script is going, also remove its `CHILD` entry and,
if it was the only child, the `run_child()` call and its contribution to the exit
code in `main()`.

`INDEX_DOC` — remove the whole branch: the `### N. **Is it …?**` question, the
`→ **[READ: …](#anchor)**` line and its `**READ WHEN:**` line. **Renumber the
remaining branches** — the tree is numbered 1–5 and a gap reads as a mistake.
Check the closing paragraph too; it names specific documents by anchor.

## 4. Fix every inbound link

- **content absorbed** → repoint at the absorbing guide's file name; the merge
  converts it to an anchor.
- **content gone** → delete the link and any sentence that only existed to carry it.

Check `handle-state-merge.py`'s `**Contains:**` line for the Data State category
— it summarises this decision tree and will now over-promise.

## 5. Delete the file

```bash
git rm force-app/skill/task-skill/guide/private/handle-state/data-state/your-category/your-old-guide.md
```

If the folder is now empty, remove the folder too — and its `*-merge.py` and any
stale `*-TEMPORARY.md` in it, which is untracked and needs a plain `rm`.

## 6. Verify

```bash
python force-app/skill/task-skill/guide/private/handle-state/data-state/data-state-merge.py
python force-app/skill/task-skill/guide/guides-merge.py
```

Both must exit 0. Two distinct failures to read:

- `missing part: …` → a `PARTS` entry still names something that is gone.
- `! link to missing anchor: …` → an inbound reference was missed in step 4.

```bash
grep -n "your-old-guide" force-app/skill/task-skill/guide/guides-TEMPORARY.md   # must print nothing
```
