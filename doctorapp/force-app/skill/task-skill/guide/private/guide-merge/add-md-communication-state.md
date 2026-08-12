# Add a guide to `communication-state/`

**Script:** `../../guide/private/handle-state/communication-state/communication-state-merge.py`
**Output:** `communication-state-TEMPORARY.md` → feeds `handle-state-merge.py` → `guides-merge.py`
**Index:** the `INDEX_DOC` string in that script (there is no `communication-state.md` on disk).

This folder covers **the component talking to Apex**: the round-trip made visible
(spinner) and its failures made visible (toast). It currently holds
`lwc-error-handling-guide.md` and `lwc-request-loading-guide.md`. The script
collects with `rglob("*.md")`, so any `.md` in the folder is merged whether or
not you register it — registering gives it a position and an index entry.

## 1. Confirm this is the right folder

| The new guide is about | Folder |
|---|---|
| surfacing failures, toasts, `.catch`, `success === false` | **here** |
| spinners / in-flight state for an Apex round-trip | **here** |
| what data the component holds and how it is shaped | [add-md-local-data-state.md](add-md-local-data-state.md) |
| drag-drop, expand/collapse, transient UI gestures | [add-md-interaction-state.md](add-md-interaction-state.md) |
| the *sequence* of an Apex call, phase by phase | [add-md-imperative-flow.md](add-md-imperative-flow.md) / [add-md-wire-flow.md](add-md-wire-flow.md) |

The line to hold: this folder describes **state** the component keeps about a
call (`isLoading`, the error channel). The phase-by-phase choreography of the
call itself belongs to the front-end sequence flows.

## 2. Ask these before writing anything

1. **Which communication concern does it own?** One sentence. If it overlaps an
   existing guide, decide now whether to extend that guide instead of adding one.
2. **File name?** kebab-case, `lwc-*-guide.md` to match the siblings. Must not be
   `communication-state.md` (reserved — the script skips that name) and must not
   end in `-TEMPORARY`.
3. **Exact H1 title?** It is the anchor, and must be unique across the whole
   merged tree. Note the siblings' H1s are short and do not repeat the file name
   (`# LWC Error Handling`, `# LWC Apex Loading Spinner`).
4. **READ … when — the trigger bullets.** The index entry is a list of the
   situations the reader is in. Three to five, each a concrete condition
   (`You have a .catch(err => …) from an Apex call that needs user visibility`),
   never a topic label.
5. **The pattern — one sentence, imperative.** Every entry closes with
   `**The pattern:**` naming the API to use and the thing not to do.
6. **Before or after the existing two?** `ORDER` is
   `lwc-error-handling-guide.md` → `lwc-request-loading-guide.md`.
7. **Which existing guides link to it, and which does it link to?**
8. **Should `handle-state-merge.py`'s index mention it?** That index has one
   block per category, not per guide — extend the `**Contains:**` line of the
   Communication State entry rather than adding a new block.

Do not create the file until every answer is in hand.

## 3. Write the `.md`

**The first non-front-matter line must be the H1.** `title_for()` only accepts an
H1 that starts the body; otherwise it injects a title from the file name and the
index link dangles. Front matter is allowed but dropped — only the index keeps
its own.

## 4. Register it in the script

```python
ORDER = [
    "lwc-error-handling-guide.md",
    "lwc-request-loading-guide.md",
    "your-new-guide.md",        # ← at the position answered in Q6
]
```

`TITLES` — only if the file genuinely cannot start with an H1.

`INDEX_DOC` — one block, in the shape the other two use, placed in `ORDER`
position and closed with a `---`:

```markdown
## READ [your-new-guide](#your-h1-anchor) when:

- <trigger bullet from Q4>
- <trigger bullet>
- <trigger bullet>

**The pattern:** <Q5 — the API to use, and the thing never to do>.

---
```

The link text is the file stem, matching the existing entries; the target is the
anchor of the new H1.

## 5. Cross-links

Add the inbound links promised in Q7. If the category summary in
`../../guide/private/handle-state/handle-state-merge.py` no longer describes what
this folder contains, extend the `**Contains:**` sentence of its
`## ⚡ [Communication State Guide](#lwc-communication-state)` block.

## 6. Verify

```bash
python force-app/skill/task-skill/guide/private/handle-state/communication-state/communication-state-merge.py
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
- **Not added to `ORDER`** → still merged, but appended last, after the guides that were meant to follow it.
- **File named `communication-state.md`** → skipped entirely; the script reserves that name.
