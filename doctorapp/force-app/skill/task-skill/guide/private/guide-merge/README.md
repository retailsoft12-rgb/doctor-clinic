# Guide-merge skills — add or remove a `.md` in the merged guide tree

Every folder under `guide/private/` is built into one document by its own
`*-merge.py`. The folder index is **not** a file any more: it lives in the
`INDEX_DOC` string inside that script. So adding or removing a guide is never
just a file operation — the script has to be edited in the same change, or the
merge silently drops the guide, or links to it break.

There are two skills per script. Find the folder you are touching, use its pair.

| The folder you are adding to / removing from | Add | Remove |
|---|---|---|
| `private/handle-state/data-state/local-data-state/` | [add-md-local-data-state.md](add-md-local-data-state.md) | [remove-md-local-data-state.md](remove-md-local-data-state.md) |
| `private/handle-state/data-state/` | [add-md-data-state.md](add-md-data-state.md) | [remove-md-data-state.md](remove-md-data-state.md) |
| `private/handle-state/communication-state/` | [add-md-communication-state.md](add-md-communication-state.md) | [remove-md-communication-state.md](remove-md-communication-state.md) |
| `private/handle-state/interaction-state/` | [add-md-interaction-state.md](add-md-interaction-state.md) | [remove-md-interaction-state.md](remove-md-interaction-state.md) |
| `private/handle-state/` (incl. `control-state/`) | [add-md-handle-state.md](add-md-handle-state.md) | [remove-md-handle-state.md](remove-md-handle-state.md) |
| `private/front-end/sequence/imperative-flow/` (FLOW A phases) | [add-md-imperative-flow.md](add-md-imperative-flow.md) | [remove-md-imperative-flow.md](remove-md-imperative-flow.md) |
| `private/front-end/sequence/wire-flow/` (FLOW B phases) | [add-md-wire-flow.md](add-md-wire-flow.md) | [remove-md-wire-flow.md](remove-md-wire-flow.md) |
| `private/front-end/sequence/` (the flow decision) | [add-md-sequence-fe.md](add-md-sequence-fe.md) | [remove-md-sequence-fe.md](remove-md-sequence-fe.md) |
| `private/back-end/sequence/` (doOperation phases) | [add-md-sequence-be.md](add-md-sequence-be.md) | [remove-md-sequence-be.md](remove-md-sequence-be.md) |
| `guide/` — a whole new top-level guide | [add-md-guides.md](add-md-guides.md) | [remove-md-guides.md](remove-md-guides.md) |

## The three rules every one of them enforces

**1. The H1 is the address.** A guide is linked by the anchor of its own first
H1. Compute the anchor, never guess it:

```
lowercase → drop every char that is not a word char, space or hyphen → spaces to hyphens
```

Stripped punctuation leaves its spaces behind, so `Phase 1 — Input correctness`
becomes `phase-1--input-correctness` — **two** hyphens. Same for `&`, `/`, `:`.

```bash
python -c "import re,sys;print(re.sub(r'[^\w\s-]','',sys.argv[1]).strip().lower().replace(' ','-'))" "Your H1 Here"
```

**2. The H1 must be unique across the whole merged document.** All ten merges
end up in `guides-TEMPORARY.md`. Two identical H1s make GitHub number the second
anchor `-1`, and every link meant for it lands silently on the first.

```bash
grep '^# ' force-app/skill/task-skill/guide/guides-TEMPORARY.md | sort | uniq -d   # must print nothing
```

```powershell
Select-String '^# ' force-app/skill/task-skill/guide/guides-TEMPORARY.md | Group-Object Line | Where-Object Count -gt 1
```

**3. Nothing is done until the full tree builds.** Run the folder's own script,
then the root one. Both must exit 0 and print no `!` line.

```bash
python force-app/skill/task-skill/guide/guides-merge.py
```

`. kept link outside the document` lines are **not** failures — they are the four
guides that live outside `private/` (`guard/`, `performance/`, the `guide/` root)
and stay file links by design. Only `!` is an error.

The scripts resolve their own directory, so they can be run from anywhere; every
command in these skills is written to be run from the repo root.
