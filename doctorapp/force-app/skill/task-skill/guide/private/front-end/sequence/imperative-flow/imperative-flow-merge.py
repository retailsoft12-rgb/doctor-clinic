"""Merge every .md file in /front-end/sequence/imperative-flow/ into
sequence-imperative-flow-TEMPORARY.md.

The index that used to live in sequence-imperative-flow.md is now embedded in
this script (INDEX_DOC below) — it heads the merged document, front matter and
all, so the whole flow is produced from this one file plus the phase files.

Because every phase ends up in a single document, links between them are
rewritten from external file references to internal anchors:

    [phase-1-synchronous-validation.md](phase-1-synchronous-validation.md)
    → [phase-1-synchronous-validation.md](#phase-1--synchronous-validation)

A link that points outside this merge is kept, but re-expressed relative to the
folder OUTPUT is written to, so it still resolves from there.

A stale sequence-imperative-flow-TEMPORARY.md is deleted before the merge runs,
so the file is always re-created from scratch rather than overwritten in place.

Run it from anywhere — the target directory is the one holding this script:

    python imperative-flow-merge.py
"""

import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "sequence-imperative-flow-TEMPORARY.md"

# Where the index text used to live. Kept as a name only — the content below is
# the source of truth, and no such file is read.
INDEX_NAME = "sequence-imperative-flow.md"

INDEX_DOC = """---
flow: FLOW A — imperative Apex call (cacheable = No)
applies-to: every write-type task
chain: user action → validate → spinner up → Apex → branch → toast → spinner down
entry: phase-1-synchronous-validation.md
---

# FLOW A — imperative Apex call (cacheable = No)

## Participants

- **User** — clicks / fires a child event.
- **component.html** — renders, hosts the spinner overlay, re-renders on state change.
- **component.js** — validates, owns `isLoading`, calls Apex, branches on the response.
- **c-ao-spinner** — overlay at root template while `isLoading` is true.
- **ShowToastEvent** — surfaces `success` and `!success | rejection`.
- **Apex @AuraEnabled** — `apexMethod({ params })` → `APIResponse | rejection`.

## Legend

- solid arrow → call
- dashed arrow → return
- gold pill → phase
- cylinder → datastore

## Start

→ Go to [phase-1-synchronous-validation.md](#phase-1--synchronous-validation).
"""

# Guides that start without an H1 — the merge injects this title so the section
# has an anchor other guides can link to.
TITLES = {}

PHASE_RE = re.compile(r"^phase-(\d+)", re.IGNORECASE)
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
    """Non-phase files first, then phase-N ascending."""
    match = PHASE_RE.match(path.stem)
    if match:
        return (1, int(match.group(1)), path.stem)
    return (0, 0, path.stem)


def collect():
    return sorted(
        (
            p
            for p in HERE.glob("*.md")
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
        sections.append((path.name, front_matter, body, path.parent))
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


def reset_output():
    """Delete the TEMPORARY file when it already exists, so it is re-created."""
    if OUTPUT.exists():
        OUTPUT.unlink()
        print(f"removed existing {OUTPUT.name}")


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

    reset_output()
    text = merge(sections, anchors)
    OUTPUT.write_text(text, encoding="utf-8")

    print(f"merged {len(sections)} part(s) into {OUTPUT.name}")
    for label, _, _, _ in sections:
        print(f"  - {label}")
    return 0 if report_dangling(text) else 1


if __name__ == "__main__":
    sys.exit(main())
