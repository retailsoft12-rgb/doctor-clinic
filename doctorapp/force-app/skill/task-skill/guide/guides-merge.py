"""Run every top-level merge script under private/, then merge the results into
one document: guides-TEMPORARY.md.

Each of the three guides loaded by the skills is produced by its own
`*-merge.py` living under `private/`, and keeps being written out beside this
script:

    private/handle-state/handle-state-merge.py        -> handle-state-TEMPORARY.md
    private/front-end/sequence/sequence-fe-merge.py   -> sequence-fe-desicion-TEMPORARY.md
    private/back-end/sequence/sequence-be-merge.py    -> sequence-be-TEMPORARY.md

Those three are then merged, under the index embedded below (INDEX_DOC), into
guides-TEMPORARY.md — the whole private tree as a single self-contained file.

Each child script owns its own behavior and is not duplicated here: it deletes
and re-creates its own output and refreshes its own nested children first —
handle-state-merge.py its data-state / communication-state / interaction-state
parts, sequence-fe-merge.py its imperative-flow / wire-flow parts. Those nested
`*-TEMPORARY.md` files stay under private/; they are intermediates, not guides.

Every script runs even when an earlier one fails, so a single pass reports every
problem rather than stopping at the first. The exit code is 0 only when all
three succeeded, all three outputs are on disk, and every link in the merged
document resolves.

Links are rewritten from external file references to internal anchors, so the
merged document never sends the reader to another file — except for links to
guides that live outside private/ (guard/, performance/, the guide/ root), which
are kept and reported.

Run it from anywhere — the target directory is the one holding this script:

    python guides-merge.py
"""

import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PRIVATE = HERE / "private"
OUTPUT = HERE / "guides-TEMPORARY.md"

# (merge script, the file it is expected to produce in HERE) — the load order
# the skills read them in: state study, then the front-end call decision it
# feeds, then the back-end sequence.
SCRIPTS = [
    (
        PRIVATE / "handle-state" / "handle-state-merge.py",
        HERE / "handle-state-TEMPORARY.md",
    ),
    (
        PRIVATE / "front-end" / "sequence" / "sequence-fe-merge.py",
        HERE / "sequence-fe-desicion-TEMPORARY.md",
    ),
    (
        PRIVATE / "back-end" / "sequence" / "sequence-be-merge.py",
        HERE / "sequence-be-TEMPORARY.md",
    ),
]

INDEX_NAME = "guides.md"

INDEX_DOC = """# Task-skill guide — the full private tree

The three guides the skills load, merged into one document. Read them in this
order: what state the component holds, how the front end calls Apex, then what
the back end does with the call.

1. **[LWC State Management Guide](#lwc-state-management-guide)** — the four state
   categories (data, control, communication, interaction), each with its own
   storage, scope and update rules.
2. **[Front-end sequence](#front-end-sequence--choosing-the-apex-call-flow)** —
   which Apex call flow a task belongs to, and every phase of the flow it picks.
3. **[Back-end sequence](#back-end-sequence--dooperation-request-lifecycle)** —
   the `doOperation()` request lifecycle, phase by phase.

---
"""

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


def run(script):
    """Run one merge script from its own directory. True when it succeeded."""
    if not script.exists():
        print(f"missing merge script: {script}")
        return False
    # Children inherit stdout and write to it directly; flush first so our own
    # buffered output does not land after theirs when stdout is a pipe.
    sys.stdout.flush()
    result = subprocess.run([sys.executable, str(script)], cwd=str(script.parent))
    if result.returncode != 0:
        print(f"{script.name} failed with exit code {result.returncode}")
        return False
    return True


def run_scripts():
    """Run every child script. Returns the names of the ones that failed."""
    failed = []
    for script, output in SCRIPTS:
        # ASCII only — the Windows console encodes stdout as cp1252.
        print(f"--- {script.relative_to(HERE).as_posix()} " + "-" * 20)
        # Keep going on failure so one pass surfaces every broken script.
        if not run(script):
            failed.append(script.name)
        elif not output.is_file():
            print(f"{script.name} reported success but {output.name} is missing")
            failed.append(script.name)
        print()
    return failed


def anchors_in(text, name):
    """Map every source file represented in `text` to its section anchor.

    A part that is itself a merge carries `<!-- merged from: x.md -->` markers,
    so each guide inside it stays an addressable link target — however deep the
    nesting, since the markers of every level survive into this document.
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
        # Not a failure: these point outside private/ by design.
        print(f"  . kept link outside the document: {link}")
    return not dangling


def reset_output():
    """Delete the TEMPORARY file when it already exists, so it is re-created."""
    if OUTPUT.exists():
        OUTPUT.unlink()
        print(f"removed existing {OUTPUT.name}")


def build_sections():
    """Return (sections, anchors) — the index first, then each child output."""
    index_front_matter, index_body = split_front_matter(INDEX_DOC)
    sections = [
        (f"{INDEX_NAME} (embedded in {Path(__file__).name})", index_front_matter, index_body, HERE)
    ]
    anchors = {INDEX_NAME: slug(H1_RE.search(index_body).group(1))}

    for _, output in SCRIPTS:
        front_matter, body = split_front_matter(output.read_text(encoding="utf-8"))
        anchors.update(anchors_in(body, output.name))
        sections.append((output.name, front_matter, body, output.parent))
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
    failed = run_scripts()
    if failed:
        print(f"{len(failed)} of {len(SCRIPTS)} merge script(s) failed:")
        for name in failed:
            print(f"  - {name}")
        return 1

    sections, anchors = build_sections()

    reset_output()
    text = merge(sections, anchors)
    OUTPUT.write_text(text, encoding="utf-8")

    print(f"merged {len(sections)} part(s) into {OUTPUT.name}")
    for label, _, _, _ in sections:
        print(f"  - {label}")
    print()
    print(f"all {len(SCRIPTS)} guide(s) also written to {HERE.name}/ on their own:")
    for _, output in SCRIPTS:
        print(f"  - {output.name}")
    return 0 if report_dangling(text) else 1


if __name__ == "__main__":
    sys.exit(main())
