"""Merge the LWC state management guide into handle-state-TEMPORARY.md.

The sources live under guide/private/handle-state/; the merged output is written
one level outside that private tree, into guide/ itself — beside
lwc-css-design-guide.md and lwc-apex-call-implementation-guide.md. Only the child
TEMPORARY files stay private, since they are intermediates of this merge.

The index that used to live in handle-state.md is now embedded in this script
(INDEX_DOC below) — it heads the merged document. Two steps:

1. Run the child merge scripts, so their outputs are always fresh:
       data-state/data-state-merge.py                   -> data-state-TEMPORARY.md
       communication-state/communication-state-merge.py -> communication-state-TEMPORARY.md
       interaction-state/interaction-state-merge.py     -> interaction-state-TEMPORARY.md
2. Merge INDEX_DOC followed by those three outputs and control-state/control-state.md
   — control-state has no sub-guides of its own, so it contributes its single
   file directly.

The result is one self-contained document: every link between the guides is
rewritten from an external file reference to an internal anchor, including
Obsidian wiki links:

    [Control State Guide](control-state/control-state.md)
    → [Control State Guide](#lwc-control-state)

Guides that arrive inside a child TEMPORARY file are still link targets: their
`<!-- merged from: x.md -->` markers say which source each section came from, so
a link to x.md resolves to that section's heading — however deep the nesting.

A stale handle-state-TEMPORARY.md is deleted before the merge runs, so the file
is always re-created from scratch rather than overwritten in place — each child
script does the same for its own output.

Run it from anywhere — the target directory is the one holding this script:

    python handle-state-merge.py
"""

import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
# guide/ — two levels up from guide/private/handle-state/. The merged output is
# published there, beside lwc-css-design-guide.md, so consumers never reach into
# private/; only the sources being merged live under it.
GUIDE_ROOT = HERE.parents[1]
OUTPUT = GUIDE_ROOT / "handle-state-TEMPORARY.md"

# Where the index text used to live. Kept as a name only — the content below is
# the source of truth, and no such file is read.
INDEX_NAME = "handle-state.md"

INDEX_DOC = """# LWC State Management Guide

## Initialization Lifecycle (connectedCallback Order)

Every LWC that loads both **picklist/static options** and **principal data** must follow this order in `connectedCallback`:

1. **Load picklists first** (Case 1 data).  
   - Call the methods that populate `@track stateXOptions = []`.
   - These are reference data; they load quickly and rarely change.
   - **Why first?** So that any computed getters or UI logic that depends on them (e.g., lookup labels) works correctly when principal data arrives.

2. **Load principal data** (Case 3 data) after picklists have resolved.  
   - Load buckets, items, topics, etc. using the appropriate service/apex method.
   - This includes loading server indicators (Case 2) alongside the principal data.

**Example:**

```javascript
connectedCallback() {
    this.loadReferences();      // step 1
}


Four categories of LWC state, each with its own storage, scope, and update rules. Use this index to find the guide that matches your situation.

---

## 📊 [Data State Guide](#data-state-guide)

**READ when:**
- You're deciding what kind of data to store (shared app context, picklists, principal data, derived values)
- Adding or modifying component data that comes from the server or localStorage
- Determining whether data should be stored in multiple places or computed on the fly
- Working with pagination metadata or server-side sync flags

**Contains:** Decision tree for picklists vs server indicators vs principal data, localStorage patterns for shared context, and detailed implementation guides for each data type.

---

## 🎛️ [Control State Guide](#lwc-control-state)

**READ when:**
- Implementing modal or drawer visibility logic
- Building drag-and-drop functionality with drop zones
- Managing UI surface visibility (panels, accordions, confirmations)
- Wiring up visual feedback for user interactions

**Contains:** Patterns for modal open/close, drag-and-drop state tracking with visual feedback, rules for clearing state after interactions, and computed getters for CSS classes.

---

## ⚡ [Communication State Guide](#lwc-communication-state)

**READ when:**
- Wiring spinners or loading indicators for Apex calls
- Handling errors from backend operations and displaying them to users
- Implementing success/failure feedback (toasts, error messages)
- Managing async operation state (in-flight, success, failure)

**Contains:** Patterns for loading spinners tied to imperative calls, error handling with ShowToastEvent, and how to structure the round-trip lifecycle from user action to backend sync.

---

## 👆 [Interaction State Guide](#interaction-state-management-guide)

**READ when:**
- Implementing drag-and-drop interaction (drag sources, targets, visual feedback)
- Building expandable/collapsible sections or accordions
- Tracking what's selected, hovered, or expanded in the UI
- Managing ephemeral transient UI state that doesn't persist

**Contains:** Drag-and-drop patterns and expanded/collapsed state management, with lifecycle rules for clearing state after interactions complete.

---
"""

# (merge script, the file it produces) — run before the merge below.
CHILDREN = [
    (
        HERE / "data-state" / "data-state-merge.py",
        HERE / "data-state" / "data-state-TEMPORARY.md",
    ),
    (
        HERE / "communication-state" / "communication-state-merge.py",
        HERE / "communication-state" / "communication-state-TEMPORARY.md",
    ),
    (
        HERE / "interaction-state" / "interaction-state-merge.py",
        HERE / "interaction-state" / "interaction-state-TEMPORARY.md",
    ),
]

# Merged after the index, in the order the index presents them.
PARTS = [
    "data-state/data-state-TEMPORARY.md",
    "control-state/control-state.md",
    "communication-state/communication-state-TEMPORARY.md",
    "interaction-state/interaction-state-TEMPORARY.md",
]

FRONT_MATTER_RE = re.compile(r"\A---\r?\n.*?\r?\n---[ \t]*\r?\n?", re.DOTALL)
H1_RE = re.compile(r"^#[ \t]+(.+?)[ \t]*$", re.MULTILINE)
HEADING_RE = re.compile(r"^#{1,6}[ \t]+(.+?)[ \t]*#*$", re.MULTILINE)
# The provenance marker a merge writes ahead of each section it pulls in.
MARKER_RE = re.compile(r"^<!--[ \t]*merged from:[ \t]*(.+?)[ \t]*-->[ \t]*$", re.MULTILINE)
# ](some/path.md) or ](some/path.md#fragment) — internal links have no .md part.
FILE_LINK_RE = re.compile(r"\]\((?!https?:)([^)#\s]+\.md)(#[^)\s]*)?\)")
ANCHOR_LINK_RE = re.compile(r"\]\((#[^)\s]+)\)")
# Obsidian wiki links: [[note]], [[note#section]], [[note|label]].
WIKI_LINK_RE = re.compile(r"\[\[([^\]|#]+?)(?:#([^\]|]+))?(?:\|([^\]]+))?\]\]")
SLUG_STRIP_RE = re.compile(r"[^\w\s-]", re.UNICODE)


def split_front_matter(text):
    """Return (front_matter, body). front_matter is "" when there is none."""
    match = FRONT_MATTER_RE.match(text)
    if not match:
        return "", text.strip()
    return match.group(0).strip(), text[match.end():].strip()


def slug(heading):
    """GitHub-style anchor: lowercase, punctuation dropped, spaces to hyphens."""
    return SLUG_STRIP_RE.sub("", heading.strip().lower()).replace(" ", "-")


def run_children():
    """Refresh every child TEMPORARY file. Returns True when all succeeded."""
    ok = True
    for script, _ in CHILDREN:
        if not script.exists():
            print(f"missing child merge script: {script}")
            ok = False
            continue
        result = subprocess.run([sys.executable, str(script)], cwd=str(script.parent))
        if result.returncode != 0:
            print(f"{script.name} failed with exit code {result.returncode}")
            ok = False
    return ok


def collect():
    """Resolve PARTS to paths, reporting the ones that are missing."""
    files, missing = [], []
    for part in PARTS:
        path = HERE / part
        if path.is_file():
            files.append(path)
        else:
            missing.append(part)
    return files, missing


def anchors_in(text, name):
    """Map every source file represented in `text` to its section anchor.

    A part that is itself a merge carries `<!-- merged from: x.md -->` markers,
    so each guide inside it stays an addressable link target.
    """
    found = {}
    top = H1_RE.search(text)
    if top:
        found[name] = slug(top.group(1))

    markers = list(MARKER_RE.finditer(text))
    for index, marker in enumerate(markers):
        end = markers[index + 1].start() if index + 1 < len(markers) else len(text)
        heading = H1_RE.search(text, marker.end(), end)
        if not heading:
            continue
        # A label may carry a note, e.g. "x.md (embedded in x-merge.py)".
        source = marker.group(1).split(" (")[0].strip()
        found[Path(source).name] = slug(heading.group(1))
    return found


def rebase(target, source_dir):
    """Re-express a relative link so it still resolves from OUTPUT's folder."""
    if target.startswith("/"):
        return target
    try:
        resolved = (source_dir / target).resolve()
        return os.path.relpath(resolved, OUTPUT.parent).replace("\\", "/")
    except (OSError, ValueError):  # unresolvable, or another drive on Windows
        return target


def rewrite_links(text, anchors, source_dir):
    """Turn links to a merged file into links to that file's anchor."""
    stems = {Path(name).stem: anchor for name, anchor in anchors.items()}

    def replace_file(match):
        target, fragment = match.group(1), match.group(2)
        anchor = anchors.get(Path(target).name)
        if anchor:
            return f"]({fragment or '#' + anchor})"
        # Outside this merge — keep the link, pointed at from where OUTPUT lives.
        return f"]({rebase(target, source_dir)}{fragment or ''})"

    def replace_wiki(match):
        target, fragment, label = (g.strip() if g else g for g in match.groups())
        anchor = stems.get(Path(target).stem)
        if not anchor:
            return match.group(0)
        return f"[{label or target}](#{slug(fragment) if fragment else anchor})"

    return WIKI_LINK_RE.sub(replace_wiki, FILE_LINK_RE.sub(replace_file, text))


def available_anchors(text):
    """Every anchor the merged document offers, duplicates numbered as GitHub does."""
    seen, anchors = {}, set()
    for heading in HEADING_RE.findall(text):
        base = slug(heading)
        count = seen.get(base, 0)
        anchors.add(base if count == 0 else f"{base}-{count}")
        seen[base] = count + 1
    return anchors


def report_dangling(text):
    """Report unresolved links. Only a broken anchor is an error."""
    anchors = available_anchors(text)
    dangling = sorted({a for a in ANCHOR_LINK_RE.findall(text) if a[1:] not in anchors})
    kept = sorted({m.group(1) for m in FILE_LINK_RE.finditer(text)})
    kept += sorted({m.group(0) for m in WIKI_LINK_RE.finditer(text)})
    for anchor in dangling:
        print(f"  ! link to missing anchor: {anchor}")
    for link in kept:
        # Not a failure: these point outside the merged tree by design.
        print(f"  . kept link outside the document: {link}")
    return not dangling


def reset_output():
    """Delete the TEMPORARY file when it already exists, so it is re-created."""
    if OUTPUT.exists():
        OUTPUT.unlink()
        print(f"removed existing {OUTPUT.name}")


def build_sections(files):
    """Return (sections, anchors) — the index first, then each resolved part."""
    index_front_matter, index_body = split_front_matter(INDEX_DOC)
    sections = [
        (f"{INDEX_NAME} (embedded in {Path(__file__).name})", index_front_matter, index_body, HERE)
    ]
    anchors = {INDEX_NAME: slug(H1_RE.search(index_body).group(1))}

    for path in files:
        front_matter, body = split_front_matter(path.read_text(encoding="utf-8"))
        anchors.update(anchors_in(body, path.name))
        sections.append((path.relative_to(HERE).as_posix(), front_matter, body, path.parent))
    return sections, anchors


def merge(sections, anchors):
    chunks = []
    for index, (label, front_matter, body, source_dir) in enumerate(sections):
        # Only the first part keeps its front matter — it heads the merged doc.
        if index == 0 and front_matter:
            chunks.append(front_matter)
        chunks.append(f"<!-- merged from: {label} -->")
        if body:
            chunks.append(rewrite_links(body, anchors, source_dir))
    return "\n\n".join(chunks) + "\n"


def main():
    children_ok = run_children()

    files, missing = collect()
    if missing:
        for part in missing:
            print(f"missing part: {part}")
        return 1

    sections, anchors = build_sections(files)

    reset_output()
    text = merge(sections, anchors)
    OUTPUT.write_text(text, encoding="utf-8")

    print(f"merged {len(sections)} part(s) into {OUTPUT.name}")
    for label, _, _, _ in sections:
        print(f"  - {label}")
    return 0 if children_ok and report_dangling(text) else 1


if __name__ == "__main__":
    sys.exit(main())
