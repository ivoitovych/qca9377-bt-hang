#!/usr/bin/env python3
"""bt-trace-archive.py: compress every closed HCI capture before rotation deletes it.

Usage: bt-trace-archive.py [--once-limit N]

bt-trace keeps the newest 400 btsnoop files in /var/log/bt-health/trace/ and deletes the
oldest at every rotation (and whenever free space drops under 15 GB). Until 2026-10-11 nothing
kept them: the oldest captures were being deleted while the investigation still read them.
This tool runs on a timer and, oldest first, for every closed capture not archived yet:

  1. compresses it with zstd -19 into the archive directory (a temporary name first);
  2. decompresses the result and compares its SHA-256 with the original's;
  3. only then renames it into place and appends a line to MANIFEST.tsv
     (name, original bytes, original sha256, compressed bytes, archived at, source).

It never deletes or changes a capture, and never deletes an archive. At 80 % of the budget
it warns; at 100 % it stops and exits 3, leaving the decision to the operator.

Sources:   $BT_TRACE_DIR       (default /var/log/bt-health/trace)
           $BT_TRACE_KEEP_DIR  (default /root/bt-trace-keep; copies kept by hand)
Archive:   $BT_ARCHIVE_DIR     (default <project>/archive/bt-trace, git-ignored)
Budget:    $BT_ARCHIVE_BUDGET_GB (default 10)
Names:     $BT_TRACE_PREFIX    (default "bt-"; the desktop capture's files are "hci-")
A capture counts as closed when it is not the newest file in its directory and has not
been modified for $BT_ARCHIVE_SETTLE_SEC seconds (default 120).
"""
import hashlib
import os
import subprocess
import sys
import time
from datetime import datetime

TRACE_DIR = os.environ.get("BT_TRACE_DIR", "/var/log/bt-health/trace")
KEEP_DIR = os.environ.get("BT_TRACE_KEEP_DIR", "/root/bt-trace-keep")
# Default: <project>/archive/bt-trace, git-ignored, so the archive is in sight of anyone
# working on the project (operator's choice, 2026-10-11). Derived from this file's place
# in scripts/; the timer passes BT_ARCHIVE_DIR explicitly while the tool runs from a worktree.
ARCHIVE_DIR = os.environ.get(
    "BT_ARCHIVE_DIR",
    os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "archive", "bt-trace"))
BUDGET = float(os.environ.get("BT_ARCHIVE_BUDGET_GB", "10")) * 1024 ** 3
SETTLE = int(os.environ.get("BT_ARCHIVE_SETTLE_SEC", "120"))
# The desktop capture (bt-capture, /var/log/bt-health/capture) names its files hci-*.btsnoop
# and prunes beyond 400 files too (2026-10-29: its August files, the sources of EX-055's
# survey, were gone); the same tool archives it with BT_TRACE_PREFIX=hci-.
PREFIX = os.environ.get("BT_TRACE_PREFIX", "bt-")
MANIFEST = os.path.join(ARCHIVE_DIR, "MANIFEST.tsv")
CHUNK = 1 << 20


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            b = f.read(CHUNK)
            if not b:
                return h.hexdigest()
            h.update(b)


def sha256_decompressed(path):
    h = hashlib.sha256()
    p = subprocess.Popen(["zstd", "-dcq", path], stdout=subprocess.PIPE)
    while True:
        b = p.stdout.read(CHUNK)
        if not b:
            break
        h.update(b)
    return h.hexdigest() if p.wait() == 0 else None


def closed_captures(directory, source):
    try:
        names = [n for n in os.listdir(directory) if n.startswith(PREFIX) and n.endswith(".btsnoop")]
    except FileNotFoundError:
        return []
    paths = [os.path.join(directory, n) for n in names]
    paths = [p for p in paths if os.path.isfile(p)]
    if not paths:
        return []
    newest = max(paths, key=os.path.getmtime) if source == "trace" else None
    now = time.time()
    return [(os.path.getmtime(p), p, source) for p in paths
            if p != newest and now - os.path.getmtime(p) >= SETTLE]


def read_manifest():
    done = {}
    try:
        with open(MANIFEST, encoding="utf-8") as f:
            for line in f:
                cells = line.rstrip("\n").split("\t")
                if len(cells) >= 6 and cells[0] != "name":
                    done.setdefault(cells[0], set()).add(cells[2])
    except FileNotFoundError:
        pass
    return done


def archive_bytes():
    total = 0
    for n in os.listdir(ARCHIVE_DIR):
        if n.endswith(".zst"):
            total += os.path.getsize(os.path.join(ARCHIVE_DIR, n))
    return total


def main(argv):
    limit = int(argv[argv.index("--once-limit") + 1]) if "--once-limit" in argv else None
    os.makedirs(ARCHIVE_DIR, mode=0o700, exist_ok=True)
    # The budget this store runs under, for scripts/archive-budget-check.py (which the
    # session-start hook runs): a warning has to reach someone between runs too.
    with open(os.path.join(ARCHIVE_DIR, "BUDGET_GB"), "w", encoding="utf-8") as f:
        f.write(f"{BUDGET / 1024 ** 3:g}\n")
    if not os.path.exists(MANIFEST):
        with open(MANIFEST, "w", encoding="utf-8") as f:
            f.write("name\toriginal_bytes\tsha256\tcompressed_bytes\tarchived_at\tsource\n")
    done = read_manifest()
    todo = sorted(closed_captures(TRACE_DIR, "trace") + closed_captures(KEEP_DIR, "keep"))
    archived = skipped = failed = 0
    raw_in = zst_out = 0
    for _mtime, path, source in todo:
        if limit is not None and archived >= limit:
            break
        name = os.path.basename(path)
        if name in done and source == "keep":
            skipped += 1  # same name already archived; the keep copies duplicate trace files
            continue
        if name in done:
            skipped += 1
            continue
        used = archive_bytes()
        if used >= BUDGET:
            print(f"bt-trace-archive: BUDGET REACHED ({used / 1024 ** 3:.2f} GB of {BUDGET / 1024 ** 3:.0f} GB);"
                  f" stopped with {len(todo) - archived - skipped} capture(s) not archived. Operator's decision.")
            return 3
        try:
            size = os.path.getsize(path)
            digest = sha256_file(path)
        except FileNotFoundError:
            continue  # rotated away between listing and reading
        final = os.path.join(ARCHIVE_DIR, name + ".zst")
        if os.path.exists(final):
            final = os.path.join(ARCHIVE_DIR, f"{source}-{digest[:12]}-{name}.zst")
        partial = final + ".partial"
        r = subprocess.run(["zstd", "-19", "-T0", "-q", "-f", "-o", partial, path])
        if r.returncode != 0 or sha256_decompressed(partial) != digest:
            failed += 1
            print(f"bt-trace-archive: FAILED {path}: compression or verification; left as {partial}")
            continue
        if sha256_file(path) != digest:
            failed += 1
            print(f"bt-trace-archive: {path} changed while archiving; left as {partial}, retried next run")
            continue
        os.rename(partial, final)
        csize = os.path.getsize(final)
        with open(MANIFEST, "a", encoding="utf-8") as f:
            f.write(f"{name}\t{size}\t{digest}\t{csize}\t{datetime.now().isoformat(timespec='seconds')}\t{source}\n")
        done.setdefault(name, set()).add(digest)
        archived += 1
        raw_in += size
        zst_out += csize
    used = archive_bytes()
    pending = sum(1 for _m, p, _s in todo if os.path.basename(p) not in done)
    msg = (f"bt-trace-archive: archived {archived} ({raw_in / 1024 ** 2:.0f} MB -> {zst_out / 1024 ** 2:.1f} MB),"
           f" skipped {skipped}, failed {failed}, pending {pending};"
           f" archive {used / 1024 ** 3:.2f} GB of {BUDGET / 1024 ** 3:.0f} GB")
    if used >= 0.8 * BUDGET:
        msg += " -- WARNING: over 80 % of the budget"
    print(msg)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
