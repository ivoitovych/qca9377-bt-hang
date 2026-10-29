#!/usr/bin/env python3
"""archive-budget-check.py: how full each raw-capture archive is against its budget.

Usage: archive-budget-check.py [--warn-only] [ARCHIVE_ROOT]

Each store under ARCHIVE_ROOT (default <project>/archive) that holds a MANIFEST.tsv is one
archive written by scripts/bt-trace-archive.py (archive/bt-trace, archive/hci-capture). Its
budget is the BUDGET_GB file the archiver writes on every run; a store without one is reported
as such, never assumed. Used space is the sum of its *.zst files, as the archiver counts it.

WHY (2026-10-29, the operator): the archiver warns at 80 % and stops at 100 %, but only in its
own run's output; a full archive means rotation deletes captures again, silently. This check
runs from the session-start hook, so the warning reaches every session.

Output, one line per store:  OK / WARNING (>= 80 %) / FULL (>= 100 %) / NO BUDGET.
--warn-only prints only WARNING, FULL and NO BUDGET lines (nothing when all is well).
Exit status: 0, or 1 when any store is FULL. Read-only.
"""
import os
import sys

WARN_AT = 0.8


def store_line(path):
    name = os.path.basename(path)
    used = sum(os.path.getsize(os.path.join(path, n)) for n in os.listdir(path) if n.endswith(".zst"))
    try:
        with open(os.path.join(path, "BUDGET_GB"), encoding="utf-8") as f:
            budget_gb = float(f.read().strip())
    except (OSError, ValueError):
        return "NO BUDGET", (f"archive {name}: NO BUDGET recorded ({used / 1024 ** 3:.2f} GB used); "
                             f"the next archiver run writes it")
    budget = budget_gb * 1024 ** 3
    share = used / budget if budget > 0 else 1.0
    text = f"archive {name}: {used / 1024 ** 3:.2f} GB of {budget_gb:g} GB ({share:.0%})"
    if share >= 1.0:
        return "FULL", (f"⚠️ {text}: FULL. The archiver stops; rotation deletes the oldest captures "
                        f"unarchived. Raising the budget is the operator's decision.")
    if share >= WARN_AT:
        return "WARNING", (f"⚠️ {text}: over {WARN_AT:.0%} of the budget; tell the operator before "
                           f"it fills (the budget is the operator's decision).")
    return "OK", text


def main(argv):
    warn_only = "--warn-only" in argv
    rest = [a for a in argv if a != "--warn-only"]
    here = os.path.dirname(os.path.abspath(__file__))
    root = rest[0] if rest else os.path.join(os.path.dirname(here), "archive")
    if not os.path.isdir(root):
        print(f"archive-budget-check: no archive directory at {root}")
        return 0
    full = False
    for name in sorted(os.listdir(root)):
        path = os.path.join(root, name)
        if not os.path.isfile(os.path.join(path, "MANIFEST.tsv")):
            continue
        state, line = store_line(path)
        full = full or state == "FULL"
        if not warn_only or state != "OK":
            print(line)
    return 1 if full else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
