"""Merge every .md file in /private/back-end/sequence/ into
sequence-be-TEMPORARY.md.

The sources live under guide/private/back-end/sequence/; the merged output is
written one level outside that private tree, into guide/ itself — beside
lwc-css-design-guide.md and lwc-apex-call-implementation-guide.md.

The index that used to live in sequence.md is now embedded in this script
(INDEX_DOC below) — it heads the merged document, its YAML kept verbatim in a
```yaml block under a title, so the section has an anchor the phases can link
to. The phases follow in numeric order.

Because every phase ends up in a single document, links between them are
rewritten from external file references to internal anchors:

    [phase 2](phase-2-delegate-to-service.md)
    → [phase 2](#phase-2--delegate-to-service)

Links to guides outside this merge (guard/, performance/, the guide/ root) are
kept, but re-expressed relative to the folder OUTPUT is written to — otherwise
the `../../../` hops of the source file would no longer resolve from there.

A stale sequence-be-TEMPORARY.md is deleted before the merge runs, so the file
is always re-created from scratch rather than overwritten in place.

Run it from anywhere — the target directory is the one holding this script:

    python sequence-be-merge.py
"""

import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
# guide/ — three levels up from guide/private/back-end/sequence/. The merged
# output is published there, beside lwc-css-design-guide.md, so consumers never
# reach into private/; only the sources being merged live under it.
GUIDE_ROOT = HERE.parents[2]
OUTPUT = GUIDE_ROOT / "sequence-be-TEMPORARY.md"

# Where the index text used to live. Kept as a name only — the content below is
# the source of truth, and no such file is read.
INDEX_NAME = "sequence.md"

INDEX_DOC = """# Back-end sequence — doOperation() request lifecycle

```yaml
sequence:
  title: "doOperation() — request lifecycle"
  summary: "Controller → correctness check (via Dao) → Service → rule validation → persist"


  participants:
    - id: client
      name: Client
    - id: controller
      name: Controller
    - id: domainCorrectness
      name: Domain Correctness
    - id: service
      name: Service
    - id: validator
      name: DomainCompleteValidator
    - id: otherService
      name: OtherService
    - id: dao
      name: Dao
    - id: db
      name: DB
      type: datastore

  layout:
    controller: >-
      classes/controller/<feature>/<Name>Controller.cls — thin @AuraEnabled
      orchestration only, no SOQL/DML business logic; every controller ships with
      a <Name>ControllerTest.cls alongside it
    service: >-
      classes/domain/<Name>Service.cls — one Service per domain object; owns the
      DML of its object and reads only through its Dao
    correctness: >-
      classes/domain/DomainCorrectness.cls — input guards; holds no SOQL, it
      resolves input ids through the Dao of the object it guards
    dao: >-
      classes/dao/<Name>Dao.cls — one Dao per domain object; the ONLY layer that
      writes SOQL for that object, query-only.
    dto: >-
      classes/domain/<Name>Dto.cls — composite / nested RESPONSE shapes only;
    shared: >-
      classes/shared/ — APIResponse (the envelope), ServiceException (the only
      type services throw), plus enums / utils / constants; never duplicated per
      feature

  dbAccessRule: >-
    every SOQL statement in every phase is written inside classes/dao/<Name>Dao.cls
    — the controller, DomainCorrectness, the Service and DomainCompleteCorrectness
    all reach the database through a Dao and never carry a [SELECT] of their own.
    DML is the one exception: it stays in the Service that owns the object.

  legend:
    call: "solid arrow — synchronous call"
    return: "dashed arrow — return value"

  entry:
    phase: "1 — input correctness"
    doc: "phase-1-input-correctness.md"
    read_when: >-
      always — start here. Each phase carries its own steps and hands off to the
      next one at the end of its file.

  errorHandling:
    scope: "any layer"
    rule: "catch (ServiceException e) → return APIResponse(false, e.message)"
```

**Entry:** → [Phase 1 — Input correctness](#phase-1--input-correctness) — always start here.
Each phase carries its own steps and hands off to the next one at the end of its section.
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
