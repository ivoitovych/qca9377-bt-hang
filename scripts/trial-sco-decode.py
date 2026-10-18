#!/usr/bin/env python3
"""trial-sco-decode.py — a trial window's SCO requests, decoded at full width.

    python3 -I scripts/trial-sco-decode.py <start-epoch> [<end-epoch>]

Read-only: btmon -r only reads a file, nothing is sent to the controller.

The setups come from the kernel journal: `opcode 0x0428` (Setup Synchronous
Connection) and `opcode 0x043d` (the Enhanced form), between start and end
(default: now). For each setup, in each capture directory, the first btsnoop
file last written after it holds it (each directory is written in order), so
only those files are decoded, once each: `btmon -T --columns=200 -r <file>`.

WHY --columns. Written to a pipe, btmon fits each header line into 80 columns
and shortens the name (`< HCI Comman.. (0x01|0x0028) plen 17`); it ignores
COLUMNS. bt-trial's close decoded with COLUMNS=200 and so never kept a record
(2026-10-18; comms/2026-10-18T0615Z-from-main-branch-maintainer-to-test-suite-maintainer.md).

Kept, inside the window by their decoded time, each block whole and labelled
by source: every Setup Synchronous Connection and Enhanced Setup Synchronous
Connection command, every Command Status naming one, and every Synchronous
Connect Complete. Addresses are replaced by <addr>. The summary at the end
matches each kernel setup against the decoded commands of each path (within
2 s): a setup missing from one path is an instrumentation finding, not
evidence about the controller.
"""
import datetime
import os
import re
import subprocess
import sys

DIRS = [os.environ.get("BT_CAPTURE_DIR", "/var/log/bt-health/capture"),
        os.environ.get("BT_TRACE_DIR", "/var/log/bt-health/trace")]
HEADER = re.compile(r"^[<>@=!] ")
STAMP = re.compile(r"(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d+)\s*$")
ADDR = re.compile(r"\b(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\b")
NAME_STAMP = re.compile(r"(\d{8})-(\d{6})\.btsnoop$")
SETUP_CMDS = ("HCI Command: Setup Synchronous Connection",
              "HCI Command: Enhanced Setup Synchronous Connection")


def redact(line):
    line = ADDR.sub("<addr>", line)
    return re.sub(r"(Address: <addr>).*", r"\1", line)


def kernel_setups(start, end):
    since = datetime.datetime.fromtimestamp(start).strftime("%Y-%m-%d %H:%M:%S")
    until = datetime.datetime.fromtimestamp(end).strftime("%Y-%m-%d %H:%M:%S")
    r = subprocess.run(["journalctl", "-k", "--since", since, "--until", until,
                        "--grep=opcode 0x04(28|3d)", "-o", "short-iso-precise",
                        "--no-pager"], capture_output=True, text=True)
    if r.returncode not in (0, 1) or (r.returncode == 1 and r.stderr.strip()):
        sys.exit(f"journalctl failed (rc {r.returncode}): {r.stderr.strip()}")
    out = []
    for line in r.stdout.splitlines():
        m = re.search(r"opcode (0x04(?:28|3d))", line)
        if not m:
            continue
        ts = datetime.datetime.fromisoformat(line.split()[0]).timestamp()
        out.append((ts, m.group(1)))
    return out, since, until


def captures(d):
    files = []
    for f in os.listdir(d):
        if f.endswith(".btsnoop"):
            p = os.path.join(d, f)
            files.append((os.path.getmtime(p), p))
    return sorted(files)


def name_start(p):
    m = NAME_STAMP.search(p)
    if not m:
        return "?"
    return datetime.datetime.strptime(m.group(1) + m.group(2), "%Y%m%d%H%M%S").isoformat(sep=" ")


def decode(path, lo, hi):
    """Yield (time, header, block lines) for the kept blocks of one file."""
    p = subprocess.Popen(["btmon", "-T", "--columns=200", "-r", path],
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                         text=True, errors="replace")
    block, t = [], None

    def flush():
        if not block or t is None or not (lo <= t <= hi):
            return None
        head = block[0]
        if any(c in head for c in SETUP_CMDS) or "Synchronous Connect Complete" in head:
            return (t, head, list(block))
        if "HCI Event: Command Status" in head and any("Setup Synchronous Connection" in l for l in block[1:]):
            return (t, head, list(block))
        return None

    for line in p.stdout:
        line = line.rstrip("\n")
        if HEADER.match(line):
            kept = flush()
            if kept:
                yield kept
            m = STAMP.search(line)
            t = datetime.datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S.%f").timestamp() if m else None
            block = [line]
        elif block:
            block.append(line)
    kept = flush()
    if kept:
        yield kept
    err = p.stderr.read()
    rc = p.wait()
    if rc != 0:
        print(f"# btmon rc={rc} on {path}: {err.strip()[-200:]}")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    start = int(sys.argv[1])
    end = int(sys.argv[2]) if len(sys.argv) > 2 else int(datetime.datetime.now().timestamp())
    setups, since, until = kernel_setups(start, end)
    print(f"# trial window: {since} .. {until} (local time)")
    print(f"# kernel setups in the window: {len(setups)} "
          f"(journalctl -k --grep='opcode 0x04(28|3d)')")
    print("# decoded with: btmon -T --columns=200 -r <file>; addresses replaced by <addr>")
    print("# both capture paths are shown; a request present in only one")
    print("# is an instrumentation finding, not evidence about the controller.\n")

    found = {}
    for d in DIRS:
        files = captures(d)
        print(f"===== source: {d} =====")
        if not files:
            print("(no captures)\n")
            found[d] = []
            continue
        print(f"# {len(files)} captures retained; the oldest, {os.path.basename(files[0][1])}, "
              f"starts {name_start(files[0][1])}")
        chosen = []
        for ts, _ in setups:
            after = [p for mt, p in files if mt >= ts]
            if after and after[0] not in chosen:
                chosen.append(after[0])
        print(f"# files decoded: {', '.join(os.path.basename(p) for p in chosen) or 'none'}\n")
        times = []
        for path in chosen:
            for t, head, block in decode(path, start, end):
                if any(c in head for c in SETUP_CMDS):
                    times.append(t)
                print(f"--- {os.path.basename(path)}")
                for line in block:
                    print(redact(line))
        found[d] = times
        print()

    print("===== summary: each kernel setup against each path (within 2 s) =====")
    for ts, op in setups:
        when = datetime.datetime.fromtimestamp(ts).isoformat(sep=" ", timespec="microseconds")
        marks = []
        for d in DIRS:
            hit = any(abs(t - ts) <= 2 for t in found.get(d, []))
            marks.append(f"{os.path.basename(d)}: {'decoded' if hit else 'NOT FOUND'}")
        print(f"{when}  {op}  " + "  ".join(marks))
    for d in DIRS:
        print(f"# {os.path.basename(d)}: {len(found.get(d, []))} setup command(s) decoded in the window")


if __name__ == "__main__":
    main()
