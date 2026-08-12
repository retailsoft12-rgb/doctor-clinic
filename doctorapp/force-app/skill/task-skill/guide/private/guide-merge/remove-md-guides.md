# Remove a top-level guide from `guide/`

**Script:** `../../guide/guides-merge.py`

This is the root. It merges the outputs of three subtree scripts under its own
embedded index:

```python
SCRIPTS = [
    (private/handle-state/handle-state-merge.py,      guide/handle-state-TEMPORARY.md),
    (private/front-end/sequence/sequence-fe-merge.py, guide/sequence-fe-desicion-TEMPORARY.md),
    (private/back-end/sequence/sequence-be-merge.py,  guide/sequence-be-TEMPORARY.md),
]
```

Removing at this level removes **a whole subtree**, not a file. It is the largest
change in this family and the one most likely to break something outside the
guide tree, because other skills load these outputs by name.

## 1. Confirm the target

1. **Which top-level guide?** Name the script and the output it produces.
2. **Is the subject gone, or does it move?** If it moves into one of the other
   two trees, this is a remove here **plus** an add there — and every guide
   inside it has to land somewhere, not just its index.
3. **What loads it today?** At minimum
   `../create-new-parent-lwc-component.md` Step 0 names all three outputs and
   forbids falling back to the sources. Removing one without editing that skill
   leaves it waiting for a file that is never produced.
4. **Are you removing the guide, or only unpublishing it?** Dropping it from
   `SCRIPTS` stops it being merged *and* stops it being written individually to
   `guide/` — those are the same list. If the subtree should still build on its
   own, keep the script on disk and say so.

Answer 3 before touching anything. This is the step that turns a tidy removal
into a broken skill.

## 2. Find every reference before touching anything

```bash
cd force-app/skill/task-skill
grep -rn "your-topic-TEMPORARY" .          # the output name, in skills and scripts
grep -rn "your-topic" guide/private/ guide/*.py
grep -rn "<its-index-h1-anchor>" guide/private/ guide/*.py
```

Search the whole `task-skill/` folder, not just `guide/` — the consumers of these
outputs are the skill documents one level up.

## 3. De-register from `guides-merge.py`

```python
SCRIPTS = [ ... ]     # drop the (script, output) tuple
```

`INDEX_DOC` — remove its numbered entry and **renumber the rest**. Then re-read
the lead-in sentence:

> The three guides the skills load, merged into one document. Read them in this
> order: what state the component holds, how the front end calls Apex, then what
> the back end does with the call.

Both the count (*"three"*) and the narrative have to be corrected — that sentence
is the index's claim about what the document is.

## 4. Fix every consumer

- `../create-new-parent-lwc-component.md` — Step 0 loads the outputs by name;
  remove the one that is gone, and check the steps that reference its content.
  Its Step 7 cleanup globs `guide/**/*-TEMPORARY.md`, so it needs no change.
- Any note or memory that says *"the three guides"*.
- Cross-links from the surviving trees into the removed one — those become
  dangling anchors and will fail the build.

## 5. Delete the subtree

```bash
git rm -r force-app/skill/task-skill/guide/private/your-area/your-topic/
rm force-app/skill/task-skill/guide/your-topic-TEMPORARY.md     # untracked build output
```

Delete nested `*-TEMPORARY.md` intermediates inside the subtree the same way —
they are untracked, so `git rm` will not take them.

## 6. Verify

```bash
python force-app/skill/task-skill/guide/guides-merge.py
```

Must exit 0. What to read in the output:

- `missing merge script: …` → the `SCRIPTS` entry was not removed.
- `! link to missing anchor: …` → a surviving tree still links into the one you
  removed; go back to step 4.
- the banner list must show only the remaining scripts, and the closing
  *"all N guide(s) also written to guide/ on their own"* list must match.

```bash
grep -rn "your-topic" force-app/skill/task-skill/guide/guides-TEMPORARY.md   # must print nothing
ls force-app/skill/task-skill/guide/*-TEMPORARY.md
```

The `ls` must no longer list the removed output. If it still does, it is a stale
file from a previous run — delete it, or the next reader will load a guide that
is no longer built.
