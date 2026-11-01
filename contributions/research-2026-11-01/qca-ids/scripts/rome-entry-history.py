#!/usr/bin/python3 -I
"""For every USB_DEVICE entry carrying BTUSB_QCA_ROME at a given ref, find the
first commit (in first-parent-agnostic topo order, oldest first) where that
VID:PID appears with BTUSB_QCA_ROME in drivers/bluetooth/btusb.c or
btusb_main.c.

Usage: rome-entry-history.py <git-dir> <ref> <out.tsv>

Missing blobs (partial clone) are fetched in one batch from the promisor
remote 'origin' first.
"""
import re
import subprocess
import sys

GIT_DIR, REF, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
PATHS = ["drivers/bluetooth/btusb.c", "drivers/bluetooth/btusb_main.c"]
ENTRY = re.compile(
    r"USB_DEVICE\(\s*0x([0-9a-fA-F]{4})\s*,\s*0x([0-9a-fA-F]{4})\s*\)\s*,"
    r"\s*\.driver_info\s*=\s*([A-Z0-9_|\s]+?)\s*\}",
    re.S,
)


def git(*args, inp=None, env=None):
    return subprocess.run(
        ["git", "-C", GIT_DIR, *args], input=inp, capture_output=True,
        text=True, check=True, env=env,
    ).stdout


# commit -> blob id of the btusb file after that commit
log = git("log", "--reverse", "--format=C %H %cI", "--raw", "--no-abbrev",
          "--no-renames", REF, "--", *PATHS)
versions = []  # (commit, date, path, blob)
cur = None
for line in log.splitlines():
    if line.startswith("C "):
        _, h, d = line.split(" ", 2)
        cur = (h, d)
    elif line.startswith(":"):
        meta, path = line.split("\t", 1)
        parts = meta.split()
        new_blob, status = parts[3], parts[4]
        if status.startswith("D"):
            continue
        versions.append((cur[0], cur[1], path, new_blob))

blobs = sorted({v[3] for v in versions})
import os
env = dict(os.environ, GIT_NO_LAZY_FETCH="1")
check = subprocess.run(
    ["git", "-C", GIT_DIR, "cat-file", "--batch-check"],
    input="\n".join(blobs) + "\n", capture_output=True, text=True, env=env,
).stdout
missing = [l.split()[0] for l in check.splitlines() if l.endswith(" missing")]
print(f"versions {len(versions)}, blobs {len(blobs)}, missing {len(missing)}",
      file=sys.stderr)
if missing:
    subprocess.run(
        ["git", "-C", GIT_DIR, "-c", "fetch.negotiationAlgorithm=noop",
         "fetch", "origin", "--no-tags", "--no-write-fetch-head",
         "--recurse-submodules=no", "--filter=blob:none", "--stdin"],
        input="\n".join(missing) + "\n", text=True, check=True,
    )

first_rome = {}   # id -> (commit, date, path, flags)
first_any = {}    # id -> (commit, date, path, flags)  any entry form
for commit, date, path, blob in versions:
    text = git("cat-file", "blob", blob)
    for m in ENTRY.finditer(text):
        vid, pid = m.group(1).lower(), m.group(2).lower()
        flags = " ".join(m.group(3).split())
        key = f"{vid}:{pid}"
        if key not in first_any:
            first_any[key] = (commit, date, path, flags)
        if "BTUSB_QCA_ROME" in flags and key not in first_rome:
            first_rome[key] = (commit, date, path, flags)

final = git("show", f"{REF}:drivers/bluetooth/btusb_main.c")
now = []
for m in ENTRY.finditer(final):
    flags = " ".join(m.group(3).split())
    if "BTUSB_QCA_ROME" in flags:
        now.append((f"{m.group(1).lower()}:{m.group(2).lower()}", flags))

with open(OUT, "w") as f:
    f.write("id\tflags_now\tfirst_rome_commit\tauthor\tauthor_date\t"
            "commit_date\tsubject\tfirst_any_commit\tfirst_any_flags\n")
    for key, flags_now in now:
        c, d, p, fl = first_rome[key]
        subj, an, ad_ = git("log", "-1", "--format=%s%n%an%n%aI", c).splitlines()[:3]
        ac, ad, ap, afl = first_any[key]
        f.write(f"{key}\t{flags_now}\t{c[:12]}\t{an}\t{ad_}\t{d}\t{subj}\t"
                f"{ac[:12]}\t{afl}\n")
    gone = sorted(set(first_rome) - {k for k, _ in now})
    for key in gone:
        c, d, p, fl = first_rome[key]
        f.write(f"# ever ROME but not at {REF}: {key} first {c[:12]} {d}\n")
print(f"wrote {len(now)} rows to {OUT}", file=sys.stderr)
