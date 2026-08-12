"""Run the three top-level merge scripts under private/ — and nothing else.

Same first half as guides-merge.py, without the merge: each of the three guides
the skills load is produced by its own `*-merge.py` living under `private/`, and
is written out beside this script:

    private/handle-state/handle-state-merge.py        -> handle-state-TEMPORARY.md
    private/front-end/sequence/sequence-fe-merge.py   -> sequence-fe-desicion-TEMPORARY.md
    private/back-end/sequence/sequence-be-merge.py    -> sequence-be-TEMPORARY.md

Use this when you want those three files fresh as three separate guides. Use
guides-merge.py instead when you also want them combined into the single
guides-TEMPORARY.md.

Each child script owns its own behavior and is not duplicated here: it deletes
and re-creates its own output and refreshes its own nested children first —
handle-state-merge.py its data-state / communication-state / interaction-state
parts, sequence-fe-merge.py its imperative-flow / wire-flow parts. Those nested
`*-TEMPORARY.md` files stay under private/; they are intermediates, not guides.

Every script runs even when an earlier one fails, so a single pass reports every
problem rather than stopping at the first. The exit code is 0 only when all
three succeeded and all three outputs are on disk.

Run it from anywhere — the target directory is the one holding this script:

    python guides-build.py
"""

import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PRIVATE = HERE / "private"

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


def main():
    failed = run_scripts()

    print(f"built {len(SCRIPTS) - len(failed)} of {len(SCRIPTS)} guide(s) in {HERE.name}/")
    for _, output in SCRIPTS:
        mark = "-" if output.is_file() else "!"
        print(f"  {mark} {output.name}")
    for name in failed:
        print(f"  ! {name} did not produce its guide")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
