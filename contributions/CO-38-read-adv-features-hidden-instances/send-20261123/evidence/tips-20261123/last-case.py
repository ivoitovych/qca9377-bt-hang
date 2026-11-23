#!/usr/bin/env python3
"""last-case.py [--annotate] <log>... : for test-runner logs, the last case that started running ("<name> - run"),
reading through ANSI colour codes and the guest console's CRLF line ends. With --annotate, a log the run-tips
watchdog stopped (a hung-task report plus qemu's "terminating on signal 15 ... (timeout)") and that has no HUNG line
gets one appended: "HUNG in: <case> (guest stopped by the run-tips watchdog after a 60 s hung-task report)"."""
import re
import sys

ANSI = re.compile(r"\x1b\[[0-9;]*m")
args = sys.argv[1:]
annotate = args[:1] == ["--annotate"]
if annotate:
    args = args[1:]
for path in args:
    with open(path, encoding="utf-8", errors="replace", newline="") as f:
        text = f.read()
    lines = [ANSI.sub("", l).rstrip("\r") for l in text.split("\n")]
    runs = [l[:-len(" - run")] for l in lines if l.endswith(" - run")]
    last = runs[-1] if runs else "(none)"
    hung = any("blocked for more than" in l for l in lines)
    stopped = any("terminating on signal 15" in l and "(timeout)" in l for l in lines)
    labelled = any(l.startswith("HUNG in:") for l in lines)
    state = "HUNG, stopped" if hung and stopped else ("hung-task report" if hung else "normal")
    print(f"{path}: last case started: {last}; {state}{'; labelled' if labelled else ''}")
    if annotate and hung and stopped and not labelled:
        with open(path, "a", encoding="utf-8") as f:
            f.write(f"HUNG in: {last} (guest stopped by the run-tips watchdog after a 60 s hung-task report)\n")
        print(f"  labelled")
