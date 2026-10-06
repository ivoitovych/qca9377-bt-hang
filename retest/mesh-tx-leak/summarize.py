#!/usr/bin/env python3
"""Compare RESULT lines and tester summaries between kernel builds.

Rows are paired by what they measure (scenario step, handle, tag, scan
round), not by line position, so an extra line in one log does not shift
the rest.

Usage: summarize.py <logs-dir> <build-a> <build-b>
Prints a Markdown report to stdout.
"""
import os
import re
import sys

SPLAT = re.compile(r"BUG: KASAN|WARNING:|possible circular locking|"
                   r"BUG: |Oops|kmemleak: .*new suspected")
ANSI = re.compile(r"\x1b\[[0-9;]*m")


# Values that identify a row rather than being the measured result.
KEY_FIELDS = {"handle", "tag", "round", "stack_scan", "slab_shrink", "scan"}


def row_key(line, seen):
    """Key used to pair the same observation across two logs."""
    if line.startswith("dmesg: "):
        base = "dmesg: " + re.sub(r"-?\d+$", "", line[7:])
    elif line.startswith("Mesh Send tag"):
        base = line.split(" -> ")[0]
    else:
        base = re.sub(r"(\w+)=(\S*)",
                      lambda m: m.group(0) if m.group(1) in KEY_FIELDS
                      else m.group(1) + "=", line)
    seen[base] = seen.get(base, 0) + 1
    return f"{base}#{seen[base]}"


def results(path):
    out = []
    seen = {}
    with open(path, errors="replace") as f:
        for line in f:
            line = ANSI.sub("", line.rstrip())
            if line.startswith("RESULT "):
                line = line[7:]
            elif "Send Mesh Failed" in line:
                line = "dmesg: " + line.split("] ", 1)[-1]
            elif "Mesh Send tag" in line:
                line = line.split(": ", 1)[-1]
            else:
                continue
            out.append((row_key(line, seen), line))
    return out


def merge_keys(a, b):
    """Union of row keys, keeping the order of both logs."""
    keys = [k for k, _ in a]
    pos = -1
    for k, _ in b:
        if k in keys:
            pos = keys.index(k)
        else:
            pos += 1
            keys.insert(pos, k)
    return keys


def splats(path):
    with open(path, errors="replace") as f:
        return [l.rstrip() for l in f if SPLAT.search(l)]


def tester_cases(path):
    cases = {}
    total = None
    in_summary = False
    with open(path, errors="replace") as f:
        for line in f:
            line = ANSI.sub("", line.rstrip())
            if line.startswith("Test Summary"):
                in_summary = True
                continue
            if not in_summary:
                continue
            if line.startswith("Total:"):
                total = line
                break
            # Long case names leave a single space before the status.
            m = re.match(r"(.+?) +(Passed|Failed|Timed out|Not Run) +"
                         r"[0-9.]+ seconds$", line)
            if m:
                cases[m.group(1).strip()] = m.group(2)
    return cases, total


def main():
    logs, a, b = sys.argv[1:4]
    names = sorted(set(os.listdir(os.path.join(logs, a))) |
                   set(os.listdir(os.path.join(logs, b))))
    print(f"# Results: `{a}` vs `{b}`\n")
    for name in names:
        pa = os.path.join(logs, a, name)
        pb = os.path.join(logs, b, name)
        title = name[:-4]
        if "tester" in name:
            ca, ta = tester_cases(pa) if os.path.exists(pa) else ({}, None)
            cb, tb = tester_cases(pb) if os.path.exists(pb) else ({}, None)
            print(f"## {title}\n")
            print(f"- {a}: {ta}\n- {b}: {tb}")
            diff = [c for c in sorted(set(ca) | set(cb))
                    if ca.get(c) != cb.get(c)]
            notpass = sorted(c for c in set(ca) | set(cb)
                             if ca.get(c) != "Passed" or cb.get(c) != "Passed")
            for k, c, t in ((a, ca, ta), (b, cb, tb)):
                n = int(re.match(r"Total: (\d+)", t).group(1)) if t else None
                if n is None or n != len(c):
                    print(f"- INCOMPLETE: {k} summary parsed {len(c)} cases, "
                          f"total {n}")
            print(f"- per-case differences: {len(diff)}"
                  f" (over {len(set(ca) | set(cb))} cases)")
            for c in diff:
                print(f"  - {c}: {a}={ca.get(c)} {b}={cb.get(c)}")
            for c in notpass:
                print(f"- not passing: {c}: {a}={ca.get(c)} {b}={cb.get(c)}")
        else:
            ra = results(pa) if os.path.exists(pa) else []
            rb = results(pb) if os.path.exists(pb) else []
            da, db = dict(ra), dict(rb)
            print(f"## {title}\n")
            if not ra or not rb:
                print(f"(missing in {a if not ra else b})\n")
            print(f"| {a} | {b} |\n|---|---|")
            for k in merge_keys(ra, rb):
                x, y = da.get(k, ""), db.get(k, "")
                mark = "" if x == y else " **≠**"
                print(f"| `{x}` | `{y}`{mark} |")
        for k, p in ((a, pa), (b, pb)):
            if os.path.exists(p):
                s = splats(p)
                print(f"\n{k} kernel reports: {len(s)}" +
                      "".join(f"\n    {l}" for l in s[:10]))
        print()


if __name__ == "__main__":
    main()
