# Remove a guide from `front-end/sequence/`

**Script:** `../../guide/private/front-end/sequence/sequence-fe-merge.py`

This folder holds **the decision** — which Apex call flow a task belongs to — and
the two flows as children.

```python
CHILDREN = [
    imperative-flow/imperative-flow-merge.py  -> sequence-imperative-flow-TEMPORARY.md,   # FLOW A
    wire-flow/wire-flow-merge.py              -> sequence-wire-flow-TEMPORARY.md,         # FLOW B
]
```

`collect()` is a hybrid: this folder's own `*.md` are globbed, the two child
outputs are listed explicitly. So a **local** `.md` disappears from the merge the
moment it is deleted, while a **child** output that is still in `CHILDREN` fails
the build with `missing part`. **De-register first, delete last** covers both.

## 1. Confirm the target

1. **Which file exactly?** A local `.md` in this folder, or a phase inside
   `imperative-flow/` or `wire-flow/`? If it is a phase, stop — use
   [remove-md-imperative-flow.md](remove-md-imperative-flow.md) or
   [remove-md-wire-flow.md](remove-md-wire-flow.md). This script never sees phase
   files individually, only the merged flow.
2. **Is a whole flow going?** Removing a flow means removing its `CHILDREN`
   tuple, its bullet from the flow-choice list, and the folder with its merge
   script. It also means the decision it was one half of no longer has two
   branches — say what the reader does instead.
3. **Who absorbs its content?** Name the guide now; inbound links get repointed
   there rather than deleted.

## 2. Find every reference before touching anything

```bash
cd force-app/skill/task-skill/guide
grep -rn "your-old-guide" private/ *.py        # file links, wiki links, CHILDREN
grep -rn "<its-h1-anchor>" private/ *.py       # hand-written anchor links
```

Search the `.py` files — the indexes live inside them. A guide at this level is
usually referenced from the phase files of both flows as well as from the index.

## 3. De-register from `sequence-fe-merge.py`

**A local `.md`** — nothing to remove from a list; only `INDEX_DOC` changes.
Delete the routing line that pointed at it, and check the surrounding sentence
still reads (`Then pick the flow the task belongs to:` must still be followed by
the flow bullets).

**A whole flow** — drop its `CHILDREN` tuple and its bullet from:

```markdown
- Read-type method (`cacheable = true`) → **[FLOW B — @wire …](#flow-b--…)**
- Write-type method (`cacheable = false`) → **[FLOW A — imperative …](#flow-a--…)**
```

Leaving one bullet turns a decision into an instruction — rewrite the lead-in
line accordingly rather than leaving `Then pick the flow` above a single option.

Leave the `<!-- TODO -->` comment in place unless the removal resolves it.

## 4. Fix every inbound link

- **content absorbed** → repoint at the absorbing guide's file name; the merge
  converts it to an anchor.
- **content gone** → delete the link and any sentence that only existed to carry it.

Check `../../guide/guides-merge.py`: its index describes this guide as *"which
Apex call flow a task belongs to, and every phase of the flow it picks"*. If a
flow is gone, that wording is now wrong.

## 5. Delete the file

```bash
git rm force-app/skill/task-skill/guide/private/front-end/sequence/your-old-guide.md
```

For a whole flow, `git rm -r` the folder — including its `*-merge.py` — and `rm`
the untracked `*-TEMPORARY.md` inside it.

## 6. Verify

```bash
python force-app/skill/task-skill/guide/private/front-end/sequence/sequence-fe-merge.py
python force-app/skill/task-skill/guide/guides-merge.py
```

Both must exit 0. Two distinct failures to read:

- `missing part: …` → a `CHILDREN` output is still listed but no longer produced.
- `! link to missing anchor: …` → an inbound reference was missed in step 4.

```bash
grep -n "your-old-guide" force-app/skill/task-skill/guide/guides-TEMPORARY.md   # must print nothing
```
