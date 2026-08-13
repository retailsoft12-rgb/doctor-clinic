"""Merge every .md file in /handle-state/data-state/local-data-state/ into
local-data-state-TEMPORARY.md.

The index that used to live in local-data-state.md is now embedded in this
script (INDEX_DOC below) — it heads the merged document, so the whole guide is
produced from this one file plus the sibling guides.

Because every guide ends up in a single document, links between them are
rewritten from external file references to internal anchors:

    [Principal Data State](principal-data-state-guide.md)
    → [Principal Data State](#principal-data-state--case-3-data-state)

A guide that starts without an H1 gets one injected (see TITLES) so it has an
anchor to link to. Front matter is kept only for the first part.

Run it from anywhere — the target directory is the one holding this script:

    python local-data-state-merge.py
"""

import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "local-data-state-TEMPORARY.md"

# Where the index text used to live. Kept as a name only — the content below is
# the source of truth, and no such file is read.
INDEX_NAME = "local-data-state.md"

INDEX_DOC = """# LWC Data State — Three Cases

Data in your LWC falls into exactly **three categories**. Each has its own rules for how to structure and organize it. Pick the right category for each piece of data and follow its pattern.

## The Three Cases at a Glance

| Case | Name | What It Is | Example |
|------|------|-----------|---------|
| **1** | Picklist & Static Options | Reference data that rarely changes | Status choices, team member list, item type options |
| **2** | Server Indicators | Pagination and sync metadata | `hasMore`, `offset`, `isStale` |
| **3** | Principal Data | Server-backed entities with CRUD | Items, buckets, topics |

---

## Entry Point: What Kind of Data Are You Adding?

Start with this question: **Is this data loaded from the server, or is it a reference?**

1. **Is it a picklist, dropdown list, or static reference set?**
   → **[READ Case 1: Picklist & Static Options](#case-1-picklist--static-options)**

2. **Is it pagination info, sync metadata, or a flag that describes other data?**
   → **[READ Case 2: Server Indicators](#case-2-server-indicators)**

3. **Is it an entity (like an item or bucket) that your component loads and can modify?**
   → **[READ Case 3: Principal Data](#case-3-principal-data)**

---

## Case 1: Picklist & Static Options

**READ WHEN:** Creating or editing any LWC component that uses picklists, dropdowns, comboboxes, or option sets.

**Key Rule:** Picklist options are **always isolated** in their own tracked fields. Never merge them with principal data or server indicators.

[→ Read full guide: Picklist & Static Options](#picklist--static-options--case-1-data-state)

---

## Case 2: Server Indicators

**READ WHEN:** Loading paginated or server-returning data with status flags, `hasMore`, offsets, or other metadata from the backend.

**Key Rule:** Server indicators **always live near their data**, not isolated or mixed with picklists.

[→ Read full guide: Server Indicators](#server-indicators--case-2-data-state)

---

## Case 3: Principal Data

**READ WHEN:** Loading server data into an LWC component — determining whether data is principal state or derived.

**Key Rule:** Each entity type loaded by the principal method is a principal state with full CRUD operations available on the frontend.

[→ Read full guide: Principal Data State](#principal-data-state--case-3-data-state)

---

## Also In This Document

- **[Derived / Computed State](#derived--computed-state-guide)** — read-only getters computed from principal state; never a parallel tracked field.
- **[LWC State Management Checklist](#lwc-state-management-checklist)** — walk it before presenting generated code.

---
"""

# Guides that lead the document, in reading order. Anything else found in the
# folder is appended after them, sorted by name.
ORDER = [
    "picklist-static-options-guide.md",
    "server-indicators-guide.md",
    "principal-data-state-guide.md",
    "derived-state.md",
    "pather-lwc-state-management-checklist-guide.md",
]

# Guides that start without an H1 — the merge injects this title so the section
# has an anchor other guides can link to.
TITLES = {
    "pather-lwc-state-management-checklist-guide.md": "LWC State Management Checklist",
}

FRONT_MATTER_RE = re.compile(r"\A---\r?\n.*?\r?\n---[ \t]*\r?\n?", re.DOTALL)
H1_RE = re.compile(r"^#[ \t]+(.+?)[ \t]*$", re.MULTILINE)
HEADING_RE = re.compile(r"^#{1,6}[ \t]+(.+?)[ \t]*#*$", re.MULTILINE)
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


def sort_key(path):
    """ORDER first in the order listed, then everything else by name."""
    name = path.name
    if name in ORDER:
        return (0, ORDER.index(name), "")
    return (1, 0, name)


def collect():
    return sorted(
        (
            p
            for p in HERE.rglob("*.md")
            # INDEX_NAME is skipped: its text lives in INDEX_DOC now, so an old
            # copy left behind must not be merged a second time.
            if not p.stem.endswith("-TEMPORARY") and p.name != INDEX_NAME
        ),
        key=sort_key,
    )


def title_for(path, body):
    """The section title: the body's own H1, else the injected fallback."""
    match = H1_RE.search(body)
    if match and body.lstrip().startswith("# "):
        return match.group(1), body
    title = TITLES.get(path.name) or path.stem.replace("-", " ").title()
    return title, f"# {title}\n\n{body}" if body else f"# {title}"


def build_sections(files):
    """Return (sections, anchors).

    sections is a list of (label, front_matter, body, source_dir); anchors maps
    a file name to the anchor of that file's top heading, so links can be
    rewritten. source_dir is what relative links in that body resolve against.
    """
    index_front_matter, index_body = split_front_matter(INDEX_DOC)
    sections = [
        (f"{INDEX_NAME} (embedded in {Path(__file__).name})", index_front_matter, index_body, HERE)
    ]
    anchors = {INDEX_NAME: slug(H1_RE.search(index_body).group(1))}

    for path in files:
        front_matter, body = split_front_matter(path.read_text(encoding="utf-8"))
        title, body = title_for(path, body)
        anchors[path.name] = slug(title)
        sections.append((path.relative_to(HERE).as_posix(), front_matter, body, path.parent))
    return sections, anchors


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
    files = collect()
    sections, anchors = build_sections(files)

    text = merge(sections, anchors)
    OUTPUT.write_text(text, encoding="utf-8")

    print(f"merged {len(sections)} part(s) into {OUTPUT.name}")
    for label, _, _, _ in sections:
        print(f"  - {label}")
    return 0 if report_dangling(text) else 1


if __name__ == "__main__":
    sys.exit(main())
