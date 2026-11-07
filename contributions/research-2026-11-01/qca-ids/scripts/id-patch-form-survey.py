#!/usr/bin/python3 -I
"""Survey the form of accepted btusb device-ID commits: for every commit
touching drivers/bluetooth/btusb.c or btusb_main.c since <since> that adds a
USB_DEVICE(...) line, record whether its message carries a
/sys/kernel/debug/usb/devices dump ("P:  Vendor=" line), a Tested-by or
Tested-on line, a Link:, and who committed it.

Usage: id-patch-form-survey.py <git-dir> <ref> <since> <out.tsv>
"""
import re
import subprocess
import sys

GIT_DIR, REF, SINCE, OUT = sys.argv[1:5]
PATHS = ["drivers/bluetooth/btusb.c", "drivers/bluetooth/btusb_main.c"]


def git(*a):
    return subprocess.run(["git", "-C", GIT_DIR, *a], capture_output=True,
                          text=True, check=True).stdout


hashes = git("log", "--format=%H", f"--since={SINCE}", "--no-merges", REF,
             "--", *PATHS).split()
rows = []
for h in hashes:
    diff = git("show", "--format=", "--unified=0", h, "--", *PATHS)
    added = re.findall(r"^\+.*USB_DEVICE\(\s*0x([0-9a-fA-F]{4}),\s*0x([0-9a-fA-F]{4})",
                       diff, re.M)
    removed = re.findall(r"^-.*USB_DEVICE\(\s*0x([0-9a-fA-F]{4}),\s*0x([0-9a-fA-F]{4})",
                         diff, re.M)
    new = sorted(set(added) - set(removed))
    if not new:
        continue
    body = git("show", "--no-patch", "--format=%B", h)
    meta = git("show", "--no-patch", "--format=%an%x09%aI%x09%cn%x09%s", h).strip()
    an, ad, cn, subj = meta.split("\t", 3)
    flags = re.findall(r"^\+.*\.driver_info\s*=\s*([A-Z0-9_ |]+)", diff, re.M)
    rows.append([
        h[:12], ad[:10], an, cn,
        ",".join(f"{v}:{p}".lower() for v, p in new),
        "yes" if re.search(r"^\s*P:\s+Vendor=", body, re.M) else "no",
        "yes" if re.search(r"^\s*T:\s+Bus=", body, re.M) else "no",
        "yes" if re.search(r"Tested-(by|on):", body) else "no",
        "yes" if re.search(r"^(Link|Closes):", body, re.M) else "no",
        " ".join(sorted({f.split("|")[0].strip() for f in flags})),
        subj,
    ])
with open(OUT, "w") as f:
    f.write("commit\tauthor_date\tauthor\tcommitter\tnew_ids\tusb_devices_P\t"
            "usb_devices_T\ttested\tlink\tfirst_flag\tsubject\n")
    for r in rows:
        f.write("\t".join(r) + "\n")
n = len(rows)
p = sum(r[5] == "yes" for r in rows)
print(f"{n} ID-adding commits since {SINCE}; with usb/devices dump: {p}",
      file=sys.stderr)
