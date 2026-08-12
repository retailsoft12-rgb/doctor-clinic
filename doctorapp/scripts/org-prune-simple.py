#!/usr/bin/env python3
"""
org-prune-simple.py

Deletes CustomTab, LightningComponentBundle, ApexClass, and CustomObject
metadata that exists in the org but not in the local source.

Queries the org for each of the four metadata types, compares against
what's on disk, and deletes anything found only in the org (an "orphan").
Anything found only locally is left alone (not deployed yet, not a reason
to touch the org).

Works in any SFDX project. The script finds sfdx-project.json by walking
up from wherever it lives (then from the current directory), and reads the
package directories and API version out of it - so a project using
"force-app", "src", or several package directories at once all work with
no edit. Pass --project-dir to point it somewhere else.

Managed-package components, standard tabs (standard-*), and anything with
a namespace prefix are never touched - Salesforce won't let you delete
them this way regardless. For objects, only plain custom objects (Foo__c)
are in scope: standard objects, system-generated children (__History,
__Share, __Feed, __ChangeEvent), custom metadata types (__mdt), platform
events (__e), big objects (__b), and external objects (__x) are all left
alone.

Deleting a custom object deletes every record stored in it. That is
irreversible and is by far the most destructive thing this script does.

Deletes run in this order to respect references: CustomTab first, then
LightningComponentBundle, then ApexClass, then CustomObject last - tabs
and classes point at objects, so the objects have to go last. If a step
fails, later steps are skipped.

Usage:
    python org-prune-simple.py myOrgAlias
    python org-prune-simple.py myOrgAlias --project-dir ../other-project
"""

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path
from xml.sax.saxutils import escape

# --------------------------------------------------------------------- color
RED = "\033[91m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
GRAY = "\033[90m"
RESET = "\033[0m"


def cprint(text: str, color: str = "") -> None:
    print(f"{color}{text}{RESET}" if color else text)


# ---------------------------------------------------------------- ordering
ORDERED_TYPES = ["CustomTab", "LightningComponentBundle", "ApexClass", "CustomObject"]

PROJECT_FILE_NAME = "sfdx-project.json"
DEFAULT_API_VERSION = "62.0"

# On Windows, the Salesforce CLI is installed as sf.cmd. subprocess.run()
# with an argument list does not resolve .cmd shims the way a real shell
# does, so "sf" alone raises FileNotFoundError even though it works fine
# when typed directly into a terminal. Resolve the actual executable once,
# up front, so every subprocess.run() call below works on Windows, macOS,
# and Linux alike.
SF_CLI = shutil.which("sf")
if SF_CLI is None:
    cprint("Could not find the 'sf' CLI on PATH. Install the Salesforce CLI "
           "(npm install -g @salesforce/cli) or check your PATH.", RED)
    sys.exit(1)


# ---------------------------------------------------------------- project
def find_project_root(start: Path) -> Path | None:
    """Nearest ancestor of `start` (inclusive) holding sfdx-project.json."""
    start = start.resolve()
    for candidate in [start, *start.parents]:
        if (candidate / PROJECT_FILE_NAME).is_file():
            return candidate
    return None


def resolve_project_root(explicit: str | None) -> Path:
    """
    Locate the SFDX project.

    With --project-dir, that directory (or its nearest project ancestor) wins.
    Otherwise look upward from the script's own location first, so running it
    from an unrelated working directory still targets the project it is
    checked into, then fall back to the current directory for the case where
    the script is kept somewhere shared and pointed at a project by cwd.
    """
    if explicit:
        given = Path(explicit).expanduser()
        if not given.is_dir():
            cprint(f"--project-dir is not a directory: {given}", RED)
            sys.exit(1)
        root = find_project_root(given)
        if root is None:
            cprint(f"No {PROJECT_FILE_NAME} found in {given} or its parents.", RED)
            sys.exit(1)
        return root

    for start in (Path(__file__).parent, Path.cwd()):
        root = find_project_root(start)
        if root is not None:
            return root

    cprint(f"No {PROJECT_FILE_NAME} found near {Path(__file__).parent} or "
           f"{Path.cwd()}. Run this from inside an SFDX project, or pass "
           "--project-dir.", RED)
    sys.exit(1)


def read_project(project_root: Path) -> tuple[list[Path], str, str]:
    """
    Returns (source_dirs, api_version, namespace) from sfdx-project.json.

    Package directory paths are relative to the project root. Ones that do
    not exist on disk are dropped rather than fatal - a project can list a
    directory that has not been created yet, and that is not this script's
    problem to complain about.
    """
    project_file = project_root / PROJECT_FILE_NAME
    try:
        project = json.loads(project_file.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as exc:
        cprint(f"Could not read {project_file}: {exc}", RED)
        sys.exit(1)

    source_dirs = []
    for entry in project.get("packageDirectories") or []:
        path = entry.get("path")
        if not path:
            continue
        resolved = (project_root / path).resolve()
        if resolved.is_dir() and resolved not in source_dirs:
            source_dirs.append(resolved)

    if not source_dirs:
        cprint(f"No usable packageDirectories in {project_file}. Nothing to "
               "compare the org against - refusing to treat the whole org as "
               "orphaned.", RED)
        sys.exit(1)

    api_version = project.get("sourceApiVersion") or DEFAULT_API_VERSION
    namespace = project.get("namespace") or ""
    return source_dirs, str(api_version), namespace


# ------------------------------------------------------------------- org side
def is_plain_custom_object(name: str) -> bool:
    """
    True only for objects you created yourself, e.g. Ticket__c.

    Listing CustomObject in an org returns far more than that: standard
    objects (Account, Contact), the system-generated children Salesforce
    creates for you (Ticket__History, Ticket__Share, Ticket__Feed,
    Ticket__ChangeEvent), custom metadata types (Foo__mdt), platform
    events (Foo__e), big objects (Foo__b) and external objects (Foo__x).
    None of those belong in a source-vs-org diff, and requiring a __c
    suffix rules out every one of them in a single check.

    A namespaced object (ns__Foo__c) also ends in __c, so require exactly
    one __ separator - two means the name is packaged, not ours. Salesforce
    does not allow a double underscore inside an API name, so a legitimate
    unmanaged custom object always has exactly one.
    """
    return name.endswith("__c") and name.count("__") == 1


def test_deletable(mtype: str, item: dict) -> bool:
    name = item.get("fullName")
    if not name:
        return False

    if item.get("namespacePrefix"):
        return False

    manageable_state = item.get("manageableState")
    if manageable_state and manageable_state != "unmanaged":
        return False

    if mtype == "CustomTab" and name.startswith("standard-"):
        return False

    if mtype == "CustomObject" and not is_plain_custom_object(name):
        return False

    return True


def get_org_members(mtype: str, target_org: str) -> list[str]:
    result = subprocess.run(
        [SF_CLI, "org", "list", "metadata",
         "--metadata-type", mtype,
         "--target-org", target_org,
         "--json"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"sf org list metadata failed for {mtype} "
            f"(exit {result.returncode}): {result.stdout or result.stderr}"
        )

    parsed = json.loads(result.stdout)
    items = parsed.get("result") or []
    if isinstance(items, dict):
        items = [items]

    members = {
        item["fullName"]
        for item in items
        if test_deletable(mtype, item)
    }
    return sorted(members)


# ----------------------------------------------------------------- local side
def get_by_extension(source_dirs: list[Path], suffix: str) -> list[str]:
    names = []
    for source_dir in source_dirs:
        for f in source_dir.rglob(f"*{suffix}"):
            if f.is_file() and f.name.endswith(suffix):
                names.append(f.name[: -len(suffix)])
    return names


def get_bundle_names(source_dirs: list[Path], folder: str) -> list[str]:
    names = []
    for source_dir in source_dirs:
        for root in source_dir.rglob(folder):
            if not root.is_dir():
                continue
            for child in root.iterdir():
                if child.is_dir() and any(child.iterdir()):
                    names.append(child.name)
    return names


def get_object_names(source_dirs: list[Path]) -> list[str]:
    """
    An object counts as local if the source shows any trace of it: the object
    file itself (objects/Foo__c/Foo__c.object-meta.xml) or merely a folder
    named for it. The folder-only case matters - it is normal to track an
    object's fields without tracking the object file - and an object folder
    on disk is intent to keep the object either way.
    """
    names = get_by_extension(source_dirs, ".object-meta.xml")
    for source_dir in source_dirs:
        for root in source_dir.rglob("objects"):
            if not root.is_dir():
                continue
            for child in root.iterdir():
                if child.is_dir():
                    names.append(child.name)
    return names


def get_local_members(source_dirs: list[Path], mtype: str) -> list[str]:
    if mtype == "ApexClass":
        members = get_by_extension(source_dirs, ".cls")
    elif mtype == "CustomTab":
        members = get_by_extension(source_dirs, ".tab-meta.xml")
    elif mtype == "LightningComponentBundle":
        members = get_bundle_names(source_dirs, "lwc")
    elif mtype == "CustomObject":
        members = get_object_names(source_dirs)
    else:
        members = []

    return sorted(set(members))


# --------------------------------------------------------------- manifest xml
def build_destructive_manifest(mtype: str, members: list[str], api_version: str) -> str:
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<Package xmlns="http://soap.sforce.com/2006/04/metadata">',
        "    <types>",
    ]
    for member in members:
        lines.append(f"        <members>{escape(member)}</members>")
    lines.append(f"        <name>{mtype}</name>")
    lines.append("    </types>")
    lines.append(f"    <version>{api_version}</version>")
    lines.append("</Package>")
    return "\n".join(lines) + "\n"


def build_empty_package(api_version: str) -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<Package xmlns="http://soap.sforce.com/2006/04/metadata">\n'
        f"    <version>{api_version}</version>\n"
        "</Package>\n"
    )


# -------------------------------------------------------------------- main
def main() -> int:
    parser = argparse.ArgumentParser(
        description="Delete org-only CustomTab, LightningComponentBundle, "
                     "ApexClass, and CustomObject metadata not present in "
                     "the local SFDX source."
    )
    parser.add_argument("target_org", help="Org alias or username")
    parser.add_argument("--project-dir", default=None,
                        help="SFDX project to compare against. Defaults to the "
                             "project containing this script, then the current "
                             "directory.")
    args = parser.parse_args()
    target_org = args.target_org

    project_root = resolve_project_root(args.project_dir)
    source_dirs, api_version, namespace = read_project(project_root)
    out_dir = project_root / "manifest" / "destructive" / "prune-simple"

    print()
    print(f"Org     : {target_org}")
    print(f"Project : {project_root}")
    for source_dir in source_dirs:
        print(f"Source  : {source_dir}")
    print(f"API     : {api_version}")
    print(f"Types   : {', '.join(ORDERED_TYPES)}")
    print()

    if namespace:
        # In a namespaced org every component you own comes back carrying the
        # namespace prefix, and test_deletable drops those - so the diff would
        # find nothing at all. Say so rather than printing a reassuring zero.
        cprint(f"This project declares the namespace '{namespace}'. Namespaced "
               "components are skipped, so this", YELLOW)
        cprint("comparison will likely report nothing to delete.", YELLOW)
        print()

    plan = []

    for mtype in ORDERED_TYPES:
        cprint(f"== {mtype}", CYAN)
        cprint("   querying org ...", GRAY)

        try:
            org_members = get_org_members(mtype, target_org)
        except RuntimeError as exc:
            cprint(f"   ERROR: {exc}", RED)
            return 1

        local_members = get_local_members(source_dirs, mtype)
        local_set = set(local_members)
        orphans = [m for m in org_members if m not in local_set]

        print(f"   org: {len(org_members):<4} local: {len(local_members):<4} to delete: {len(orphans)}")

        orphan_set = set(orphans)
        for m in org_members:
            if m in orphan_set:
                cprint(f"   DELETE  {m}", RED)
            else:
                cprint(f"   keep    {m}", GRAY)

        if orphans:
            plan.append({"type": mtype, "members": orphans})
        print()

    if not plan:
        cprint("Org matches local source. Nothing to delete.", GREEN)
        return 0

    total = sum(len(p["members"]) for p in plan)

    print("---------------------------------------------------------------")
    cprint(f"{total} org-only member(s) across {len(plan)} type(s).", CYAN)
    for p in plan:
        print(f"   {p['type']:<26} {len(p['members'])}")
    print()

    # ------------------------------------------------------- build manifests
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True)

    package_path = out_dir / "package.xml"
    package_path.write_text(build_empty_package(api_version), encoding="utf-8")

    steps = []
    for idx, p in enumerate(plan, start=1):
        manifest_text = build_destructive_manifest(p["type"], p["members"], api_version)
        manifest_path = out_dir / f"{idx:02d}-{p['type']}.xml"
        manifest_path.write_text(manifest_text, encoding="utf-8")
        steps.append({"type": p["type"], "members": p["members"], "manifest": manifest_path})

    cprint(f"Wrote {len(steps)} manifest(s) to {out_dir}", CYAN)
    print()

    # ------------------------------------------------------------ confirmation
    cprint(f"About to PERMANENTLY DELETE {total} item(s) from '{target_org}'.", RED)
    cprint("Anything that exists only in the org has no other copy.", RED)

    object_step = next((p for p in plan if p["type"] == "CustomObject"), None)
    if object_step:
        count = len(object_step["members"])
        cprint(f"{count} of those are custom OBJECTS. Deleting an object also "
               "deletes every record in it,", RED)
        cprint("along with its fields, layouts, and list views. There is no "
               "undo and no export is taken here.", RED)

    confirm = input(f"Type the org alias '{target_org}' to confirm: ")
    if confirm != target_org:
        cprint(f"Aborted. Manifests left in {out_dir} - nothing was deleted.", YELLOW)
        return 1
    print()

    # -------------------------------------------------------------- run steps
    for step_no, s in enumerate(steps, start=1):
        cprint(f"===== Step {step_no}/{len(steps)}: {s['type']} ({len(s['members'])} member(s))", CYAN)

        deploy_args = [
            SF_CLI, "project", "deploy", "start",
            "--manifest", str(package_path),
            "--post-destructive-changes", str(s["manifest"]),
            "--target-org", target_org,
            "--ignore-warnings",
            "--wait", "33",
        ]

        result = subprocess.run(deploy_args)
        code = result.returncode

        if code != 0:
            print()
            cprint(f"Step {step_no} ({s['type']}) FAILED with exit code {code}.", RED)
            cprint("Nothing from this step was deleted. Earlier steps already applied.", YELLOW)

            if step_no < len(steps):
                cprint("Sequence halted - remaining step(s) did not run:", RED)
                for r in steps[step_no:]:
                    cprint(f"   skipped  {r['type']}", GRAY)
            return code

        cprint(f"Step {step_no} ({s['type']}) OK.", GREEN)
        print()

    cprint(f"All {len(steps)} step(s) applied. {total} item(s) deleted from '{target_org}'.", GREEN)

    # Clean up - the manifests were only scratch files for this run.
    # Keep the folder itself, just empty it out.
    try:
        for item in out_dir.iterdir():
            if item.is_dir():
                shutil.rmtree(item)
            else:
                item.unlink()
        cprint(f"Cleared contents of {out_dir}", GRAY)
    except OSError as exc:
        cprint(f"Could not clear {out_dir}: {exc}", YELLOW)

    return 0


if __name__ == "__main__":
    sys.exit(main())
