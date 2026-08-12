"""Merge the data-state guides into data-state-TEMPORARY.md.

The index that used to live in data-state.md is now embedded in this script
(INDEX_DOC below) — it heads the merged document. Unlike the leaf folders,
data-state has a sub-folder that merges itself first, so the parts are listed
explicitly rather than globbed:

    data-state.md                                  (INDEX_DOC — heads the document)
    local-data-state/local-data-state-TEMPORARY.md (local-data-state-merge.py runs first)
    local-storage-state/local-storage-state.md

local-data-state/local-data-state-merge.py is run before the merge, so its
output is always fresh.

The result is one self-contained document: every link between the guides is
rewritten from an external file reference to an internal anchor, including
Obsidian wiki links:

    [READ: localStorage State Guide](local-storage-state/local-storage-state.md)
    → [READ: localStorage State Guide](#localstorage-state-guide)
    [[principal-data-state-guide]]
    → [principal-data-state-guide](#principal-data-state--case-3-data-state)

Guides that arrive inside a child TEMPORARY file are still link targets: their
`<!-- merged from: x.md -->` markers say which source each section came from, so
a link to x.md resolves to that section's heading.

A stale data-state-TEMPORARY.md is deleted before the merge runs, so the file is
always re-created from scratch rather than overwritten in place.

Run it from anywhere — the target directory is the one holding this script:

    python data-state-merge.py
"""

import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "data-state-TEMPORARY.md"

CHILD = HERE / "local-data-state" / "local-data-state-merge.py"

# Where the index text used to live. Kept as a name only — the content below is
# the source of truth, and no such file is read.
INDEX_NAME = "data-state.md"

INDEX_DOC = """# Data State Guide

Data in your LWC component falls into distinct categories, each with its own storage, scope, and update rules. This guide directs you to the pattern that fits your data.

---

## The Data State Decision Tree

**Start here:** What kind of data are you adding or modifying?

### 1. **Is it shared application context (workspace ID, workflow ID, user theme)?**
   → **[READ: localStorage State Guide](#localstorage-state-guide)**
   **READ WHEN:** Setting up persistent cross-component state, restoring app context on component load, or sharing context across multiple pages.

### 2. **Is it a reference picklist, dropdown list, or static options (status choices, team members, item types)?**
   → **[READ: Case 1 — Picklist & Static Options](#picklist--static-options--case-1-data-state)**
   **READ WHEN:** Adding or managing dropdown options, select lists, combobox choices, or any reference data that rarely changes.

### 3. **Is it pagination metadata, sync flags, or server indicators (`hasMore`, `offset`, `isLoading`, `isStale`)?**
   → **[READ: Case 2 — Server Indicators](#server-indicators--case-2-data-state)**
   **READ WHEN:** Loading paginated or server-returning data, handling async operations, or managing metadata about principal data.

### 4. **Is it canonical data (items, buckets, topics) that your component loads from the server and supports CRUD on?**
   → **[READ: Case 3 — Principal Data](#principal-data-state--case-3-data-state)**
   **READ WHEN:** Loading server entities, managing full create/read/update/delete lifecycle, or determining if data is principal state or derived.

### 5. **Is it a computed value derived from principal state or localStorage (UI existence checks, pagination labels, lookup names)?**
   → **[READ: Derived / Computed State Guide](#derived--computed-state-guide)**
   **READ WHEN:** Building getters instead of tracked fields, computing visibility flags, formatting display values, or avoiding manual state sync.

Cases 2–4 are indexed together in **[LWC Data State — Three Cases](#lwc-data-state--three-cases)**, and the
**[LWC State Management Checklist](#lwc-state-management-checklist)** closes the document — walk it before presenting generated code.

---
"""

PARTS = [
    "local-data-state/local-data-state-TEMPORARY.md",
    "local-storage-state/local-storage-state.md",
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


def run_child():
    """Refresh local-data-state-TEMPORARY.md. Returns True when it succeeded."""
    if not CHILD.exists():
        print(f"missing child merge script: {CHILD}")
        return False
    result = subprocess.run([sys.executable, str(CHILD)], cwd=str(CHILD.parent))
    if result.returncode != 0:
        print(f"{CHILD.name} failed with exit code {result.returncode}")
        return False
    return True


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
    child_ok = run_child()

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
    return 0 if child_ok and report_dangling(text) else 1


if __name__ == "__main__":
    sys.exit(main())
