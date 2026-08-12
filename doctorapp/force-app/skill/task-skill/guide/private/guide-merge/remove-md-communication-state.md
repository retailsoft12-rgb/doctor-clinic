# Remove a guide from `communication-state/`

**Script:** `../../guide/private/handle-state/communication-state/communication-state-merge.py`

**De-register first, delete last.** The script collects with `rglob("*.md")`, so
deleting the file removes it from the merge immediately — but its `ORDER` entry,
its `INDEX_DOC` block and every inbound link stay behind, and those links become
dangling anchors that fail the build.

## 1. Confirm the target

1. **Which file exactly?**
2. **Deleted or moved?** If moved, this is a remove here **plus** an add in the
   destination — run that folder's `add-md-*.md` afterwards, and keep the H1
   unchanged so inbound links only need repointing.
3. **Who absorbs its content?** Name the guide now; every inbound link found
   below gets repointed there rather than deleted.

Removing one of the two current guides leaves this folder with a single guide.
That is allowed — the merge does not require two — but say so in the change, and
check whether `handle-state-merge.py`'s Communication State block still describes
a category worth its own entry.

## 2. Find every reference before touching anything

```bash
cd force-app/skill/task-skill/guide
grep -rn "your-old-guide" private/ *.py        # file links, wiki links, ORDER, TITLES
grep -rn "<its-h1-anchor>" private/ *.py       # hand-written anchor links
```

Search the `.py` files: the indexes live inside them now. Expect hits in
`communication-state-merge.py`, and likely in `handle-state-merge.py`.

## 3. De-register from `communication-state-merge.py`

```python
ORDER = [ ... ]     # drop the "your-old-guide.md" entry
TITLES = { ... }    # drop its entry if it had one
```

`INDEX_DOC` — remove the whole block, from its `## READ [...] when:` heading
through the `**The pattern:**` line and the trailing `---`. Leaving the heading
and dropping only the link would leave a section pointing nowhere.

## 4. Fix every inbound link

For each remaining hit from step 2:

- **content absorbed** → repoint at the absorbing guide's file name; the merge
  converts it to an anchor.
- **content gone** → delete the link and the sentence that existed only to
  carry it.

Check `handle-state-merge.py`'s `**Contains:**` line for the Communication State
category — if it advertises a pattern that just left, correct it.

## 5. Delete the file

```bash
git rm force-app/skill/task-skill/guide/private/handle-state/communication-state/your-old-guide.md
```

## 6. Verify

```bash
python force-app/skill/task-skill/guide/private/handle-state/communication-state/communication-state-merge.py
python force-app/skill/task-skill/guide/guides-merge.py
```

Both must exit 0. A `!` line names an anchor still pointing at the removed guide
— that reference was missed in step 4.

```bash
grep -n "your-old-guide" force-app/skill/task-skill/guide/guides-TEMPORARY.md   # must print nothing
```
