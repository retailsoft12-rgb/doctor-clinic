"""Merge the front-end sequence guide into sequence-fe-desicion-TEMPORARY.md.

The sources live under guide/private/front-end/sequence/; the merged output is
written one level outside that private tree, into guide/ itself — beside
lwc-css-design-guide.md and lwc-apex-call-implementation-guide.md. Only the child
TEMPORARY files stay private, since they are intermediates of this merge.

The index that used to live in sequence-fe-desicion.md is now embedded in this
script (INDEX_DOC below) — it heads the merged document. Two steps:

1. Run the child merge scripts, so their outputs are always fresh:
       imperative-flow/imperative-flow-merge.py -> sequence-imperative-flow-TEMPORARY.md
       wire-flow/wire-flow-merge.py             -> sequence-wire-flow-TEMPORARY.md
2. Merge INDEX_DOC, this directory's other .md files, then those two outputs.

A child output keeps its own front matter — it names the flow (FLOW A / FLOW B),
which is what the decision index selects between — but as a ```yaml block, so
the document has a single front matter at the top.

The result is one self-contained document: links between the flows and their
phases are rewritten from external file references to internal anchors. A link
that points outside this merge is kept, but re-expressed relative to the folder
OUTPUT is written to, so it still resolves from there.

Guides that arrive inside a child TEMPORARY file are still link targets: their
`<!-- merged from: x.md -->` markers say which source each section came from, so
a link to x.md resolves to that section's heading.

A stale sequence-fe-desicion-TEMPORARY.md is deleted before the merge runs, so
the file is always re-created from scratch rather than overwritten in place —
each child script does the same for its own output.

Run it from anywhere — the target directory is the one holding this script:

    python sequence-fe-merge.py
"""

import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
# guide/ — three levels up from guide/private/front-end/sequence/. The merged
# output is published there, beside lwc-css-design-guide.md, so consumers never
# reach into private/; only the sources being merged live under it.
GUIDE_ROOT = HERE.parents[2]
OUTPUT = GUIDE_ROOT / "sequence-fe-desicion-TEMPORARY.md"

# Where the index text used to live. Kept as a name only — the content below is
# the source of truth, and no such file is read.
INDEX_NAME = "sequence-fe-desicion.md"

INDEX_DOC = """# Front-end sequence — choosing the Apex call flow

**First — read the object data you are about to work on.** Open
`force-app/main/default/objects/<Object>__c/fields/` and take each field's type,
required flag, picklist values and lookup target before deciding anything.

<!-- TODO  -->
<!-- ANALYSE THE SCRATCHPAD TAB ANSWER :
IF METHOD IS OF TYPE READ SO  USE THE WIRE-FLOW ELSE IMPERATIVE-FLOW  -->

Then pick the flow the task belongs to:

- Read-type method (`cacheable = true`) → **[FLOW B — @wire with function handler](#flow-b--wire-with-function-handler-cacheable--yes)**
- Write-type method (`cacheable = false`) → **[FLOW A — imperative Apex call](#flow-a--imperative-apex-call-cacheable--no)**

Each flow carries its own phases; a phase hands off to the next one at the end of its section.
"""

# (merge script, the file it produces) — merged in this order, after the index.
CHILDREN = [
    (
        HERE / "imperative-flow" / "imperative-flow-merge.py",
        HERE / "imperative-flow" / "sequence-imperative-flow-TEMPORARY.md",
    ),
    (
        HERE / "wire-flow" / "wire-flow-merge.py",
        HERE / "wire-flow" / "sequence-wire-flow-TEMPORARY.md",
    ),
]

# Guides that start without an H1 — the merge injects this title so the section
# has an anchor other guides can link to.
TITLES = {}

PHASE_RE = re.compile(r"^phase-(\d+)", re.IGNORECASE)
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


def front_matter_payload(front_matter):
    """Strip the `---` fences, leaving the YAML body."""
    return "\n".join(front_matter.splitlines()[1:-1]).strip()


def slug(heading):
    """GitHub-style anchor: lowercase, punctuation dropped, spaces to hyphens."""
    return SLUG_STRIP_RE.sub("", heading.strip().lower()).replace(" ", "-")


def sort_key(path):
    """Non-phase files first, then phase-N ascending."""
    match = PHASE_RE.match(path.stem)
    if match:
        return (1, int(match.group(1)), path.stem)
    return (0, 0, path.stem)


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
    """This directory's own .md files first, then the child outputs."""
    local = sorted(
        (
            p
            for p in HERE.glob("*.md")
            # INDEX_NAME is skipped: its text lives in INDEX_DOC now, so an old
            # copy left behind must not be merged a second time.
            if not p.stem.endswith("-TEMPORARY") and p.name != INDEX_NAME
        ),
        key=sort_key,
    )
    children, missing = [], []
    for _, output in CHILDREN:
        (children if output.is_file() else missing).append(output)
    return local + children, missing


def title_for(path, body):
    """The section title: the body's own H1, else the injected fallback."""
    match = H1_RE.search(body)
    if match and body.lstrip().startswith("# "):
        return match.group(1), body
    title = TITLES.get(path.name) or path.stem.replace("-", " ").title()
    return title, f"# {title}\n\n{body}" if body else f"# {title}"


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
        if MARKER_RE.search(body):  # a part that is itself a merge
            anchors.update(anchors_in(body, path.name))
        else:
            title, body = title_for(path, body)
            anchors[path.name] = slug(title)
        sections.append((path.relative_to(HERE).as_posix(), front_matter, body, path.parent))
    return sections, anchors


def merge(sections, anchors):
    chunks = []
    for index, (label, front_matter, body, source_dir) in enumerate(sections):
        # Only the first part keeps its front matter — it heads the merged doc.
        if index == 0 and front_matter:
            chunks.append(front_matter)
        chunks.append(f"<!-- merged from: {label} -->")
        # A later part's front matter names its flow: keep it, as a yaml block.
        if index > 0 and front_matter:
            chunks.append(f"```yaml\n{front_matter_payload(front_matter)}\n```")
        if body:
            chunks.append(rewrite_links(body, anchors, source_dir))
    return "\n\n".join(chunks) + "\n"


def main():
    children_ok = run_children()

    files, missing = collect()
    if missing:
        for path in missing:
            print(f"missing part: {path.relative_to(HERE).as_posix()}")
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
