#!/usr/bin/env python3
"""
asan-blocks.py <pytest -rA log> <debug log> [--full]

Prints the verdict lines of the pytest log, then each AddressSanitizer
report of the debug log: the ERROR line, the access line, the stack frames
of the use, free and allocation (up to the first frame outside BlueZ when
not --full), and the SUMMARY line, with the host that printed it.
"""
import re
import sys

verdict_re = re.compile(r"^(PASSED|FAILED|ERROR|SKIPPED) ")
start_re = re.compile(r"(host\.\d+\.\d+)\.bluetoothd\s*:\s+(==\d+==ERROR: AddressSanitizer.*)")
line_re = re.compile(r"(host\.\d+\.\d+)\.bluetoothd\s*:\s+(.*)$")
frame_re = re.compile(r"^\s*#\d+ 0x[0-9a-f]+ in (\S+) (\S+)")


def main():
    pytest_log, debug_log = sys.argv[1], sys.argv[2]
    full = "--full" in sys.argv[3:]

    with open(pytest_log, errors="replace") as f:
        for line in f:
            if verdict_re.match(line):
                print(line.rstrip())

    with open(debug_log, errors="replace") as f:
        lines = f.readlines()

    i = 0
    count = 0
    while i < len(lines):
        m = start_re.search(lines[i])
        if not m:
            i += 1
            continue

        host = m.group(1)
        count += 1
        print(f"--- report {count}, {host}")
        print(lines[i].split(" OUT ", 1)[0], m.group(2))
        i += 1
        while i < len(lines):
            m2 = line_re.search(lines[i])
            i += 1
            if not m2 or m2.group(1) != host:
                continue
            text = m2.group(2)
            fm = frame_re.match(text)
            if fm:
                if full or not fm.group(2).startswith("("):
                    print("   ", text.strip())
                continue
            if (
                text.startswith("READ")
                or text.startswith("WRITE")
                or "is located" in text
                or text.startswith("freed by")
                or text.startswith("previously allocated")
            ):
                print(" ", text.strip())
            if text.startswith("SUMMARY:"):
                print(" ", text.strip())
                break

    print(f"reports: {count}")


if __name__ == "__main__":
    main()
