#!/usr/bin/env python3
"""Scan QEMU guest console logs for kernel reports and the booted kernel.

Usage: python3 -I scripts/kernel-report-scan.py <log>...

For each log, prints the "Linux version" the guest booted (or MISSING) and a
count per kind of kernel report: oops and panics, BUG, WARNING, KASAN, UBSAN,
KCSAN, lockdep, sleeping-in-atomic, RCU stalls, hung tasks, list and refcount
corruption, general protection faults, call traces. Exits 1 if any log has a
report or no "Linux version" line, else 0. ANSI colour codes are ignored.
"""
import re
import sys

KINDS = [
    ("oops", r"\bOops\b|Kernel panic|kernel BUG at"),
    ("BUG", r"\bBUG: "),
    ("WARNING", r"\bWARNING: |------------\[ cut here \]------------"),
    ("KASAN", r"KASAN"),
    ("UBSAN", r"UBSAN"),
    ("KCSAN", r"KCSAN"),
    ("lockdep", r"possible circular locking|possible recursive locking|"
                r"inconsistent lock state|lock held when returning|"
                r"suspicious RCU usage|INFO: lockdep"),
    ("atomic-sleep", r"sleeping function called from invalid context|"
                     r"scheduling while atomic"),
    ("rcu-stall", r"rcu: INFO|self-detected stall|rcu_sched detected stalls"),
    ("hung-task", r"blocked for more than \d+ seconds"),
    ("corruption", r"list_add corruption|list_del corruption|"
                   r"refcount_t: |double free|use-after-free"),
    ("gpf", r"general protection fault"),
    ("call-trace", r"Call Trace:"),
]
ANSI = re.compile(r"\x1b\[[0-9;]*m")


def main():
    if len(sys.argv) < 2:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    bad = 0
    for path in sys.argv[1:]:
        counts = {k: 0 for k, _ in KINDS}
        version = None
        with open(path, errors="replace") as f:
            for raw in f:
                line = ANSI.sub("", raw)
                if version is None and "Linux version " in line:
                    version = line.split("Linux version ", 1)[1].split(" ", 1)[0]
                for kind, pat in KINDS:
                    if re.search(pat, line):
                        counts[kind] += 1
        found = {k: v for k, v in counts.items() if v}
        if found or version is None:
            bad = 1
        print("%s  kernel=%s  %s" % (path, version or "MISSING",
              " ".join("%s=%d" % kv for kv in found.items()) or "clean"))
    return bad


if __name__ == "__main__":
    sys.exit(main())
