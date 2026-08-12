# Remove a guide from `local-data-state/`

**Script:** `../../guide/private/handle-state/data-state/local-data-state/local-data-state-merge.py`

Order matters: **de-register first, delete last.** The script collects with
`rglob("*.md")`, so a deleted file simply vanishes from the merge — but its
`ORDER` entry, its `INDEX_DOC` block and every inbound link stay behind, and the
links become dangling anchors that fail the build.

## 1. Confirm the target

Ask, and do not proceed on a guess:

1. **Which file exactly?** Full name.
2. **Is it being deleted or moved?** If moved to another folder, this is a remove
   here **plus** an add there — run the matching `add-md-*.md` skill afterwards,
   and keep the H1 unchanged so inbound links only need repointing, not rewording.
3. **What happens to the content it holds?** If another guide absorbs it, name
   that guide now — every inbound link found in step 2 gets repointed there
   instead of deleted.

## 2. Find every reference before touching anything

```bash
cd force-app/skill/task-skill/guide
grep -rn "your-old-guide" private/ *.py                      # file links + wiki links + ORDER/TITLES
grep -rn "<its-h1-anchor>" private/ *.py                     # hand-written anchor links
```

Search the `.py` files too — the indexes live inside them now, so a reference to
this guide is as likely to be in an `INDEX_DOC` string as in a `.md`. Expect hits
in at least `local-data-state-merge.py`, and possibly `data-state-merge.py`.

Write the list down. Every hit must be resolved in step 3 or 4.

## 3. De-register from `local-data-state-merge.py`

```python
ORDER = [ ... ]        # drop the "your-old-guide.md" entry
TITLES = { ... }       # drop its entry if it had one
```

`INDEX_DOC` — remove **all** of its parts, not just the link:

- if it was a **Case**: the row in the glance table, the numbered entry-point
  question, and the whole `## Case N: …` block including its trailing `---`.
  Renumber the remaining cases if the numbering is now gapped, and fix the
  `| **N** |` column to match.
- if it was a **supporting guide**: its bullet under `## Also In This Document`.

## 4. Fix every inbound link

For each hit from step 2 that is not in the script you just edited:

- **content absorbed elsewhere** → repoint the link at the absorbing guide's
  file name (`[label](absorbing-guide.md)`); the merge turns it into an anchor.
- **content gone** → delete the link, and the sentence around it if the sentence
  only existed to point there.

Check the parent indexes explicitly — `data-state-merge.py` and
`handle-state-merge.py` both route into this folder.

## 5. Delete the file

```bash
git rm force-app/skill/task-skill/guide/private/handle-state/data-state/local-data-state/your-old-guide.md
```

Use `git rm` so the deletion is staged with the script edits as one change.

## 6. Verify

```bash
python force-app/skill/task-skill/guide/private/handle-state/data-state/local-data-state/local-data-state-merge.py
python force-app/skill/task-skill/guide/guides-merge.py
```

Both must exit 0. A `!` line names an anchor that still points at the guide you
removed — go back to step 4, that reference was missed.

Then confirm it is really gone:

```bash
grep -n "your-old-guide" force-app/skill/task-skill/guide/guides-TEMPORARY.md   # must print nothing
```
