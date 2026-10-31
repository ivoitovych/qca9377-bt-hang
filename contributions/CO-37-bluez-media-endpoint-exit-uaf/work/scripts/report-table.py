#!/usr/bin/env python3
"""
report-table.py <run dir> <label>

For every <label>-<i>.debug.log (guest output at log level 1), one row
per sanitizer report of a bluetoothd: run, test, host, SUMMARY location,
and the path the use was reached by: "exit" if path_free() or
adapter_remove() is in the use stack (bluetoothd exiting), "main loop"
if service_filter() is (a D-Bus watch while running), "other" otherwise.
Then the count per (test, location, path).
"""
import collections
import re
import sys
from pathlib import Path

stage_re = re.compile(r"^==== functional/\S+::(\S+): (setup|call|teardown)")
start_re = re.compile(r"(host\.\d+\.\d+)\.bluetoothd\s*:\s+==\d+==ERROR: AddressSanitizer")
line_re = re.compile(r"(host\.\d+\.\d+)\.bluetoothd\s*:\s+(.*)$")
frame_re = re.compile(r"^\s*#\d+ 0x[0-9a-f]+ in (\S+)")


def main():
    run_dir, label = Path(sys.argv[1]), sys.argv[2]
    rows = []
    for p in sorted(run_dir.glob(f"{label}-*.debug.log"),
                    key=lambda q: int(re.search(r"-(\d+)\.debug\.log$", q.name).group(1))):
        run = int(re.search(r"-(\d+)\.debug\.log$", p.name).group(1))
        test = "?"
        lines = p.read_text(errors="replace").splitlines()
        i = 0
        while i < len(lines):
            m = stage_re.match(lines[i])
            if m:
                test = m.group(1)
            m = start_re.search(lines[i])
            if not m:
                i += 1
                continue
            host = m.group(1)
            frames = []
            in_use = True
            summary = "?"
            i += 1
            while i < len(lines):
                m2 = line_re.search(lines[i])
                i += 1
                if not m2 or m2.group(1) != host:
                    continue
                text = m2.group(2)
                if "freed by thread" in text:
                    in_use = False
                fm = frame_re.match(text)
                if fm and in_use:
                    frames.append(fm.group(1))
                if text.startswith("SUMMARY:"):
                    summary = text.split(" ", 3)[-1]
                    break
            if "path_free" in frames or "adapter_remove" in frames:
                path = "exit"
            elif "service_filter" in frames:
                path = "main loop"
            else:
                path = "other"
            rows.append((run, test, host, summary, path))

    for r in rows:
        print(f"run {r[0]}: {r[1]} {r[2]}: {r[3]} [{r[4]}]")
    counts = collections.Counter((r[1], r[3], r[4]) for r in rows)
    print(f"{label}: {len(rows)} reports")
    for (test, summary, path), n in sorted(counts.items()):
        print(f"  {n} x {test}: {summary} [{path}]")


if __name__ == "__main__":
    main()
