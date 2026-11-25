#!/usr/bin/python3 -I
"""lkml-practice.py: how Bluetooth kernel patches posted to linux-bluetooth use linux-kernel@.

Reads the local lore archive (cache/lore-linux-bluetooth-0.git, one mail per commit, file "m"),
read-only. A kernel patch mail is a non-reply whose subject is "[...PATCH...] Bluetooth: ..." and
not BlueZ; cover letters (0/N) are counted apart. For each posting: is linux-kernel@vger.kernel.org
(or netdev@) in To/Cc, who sent it. "Applied" means the subject (prefix stripped) is in the
bluetooth-next or mainline log since 2025-12-01; renamed resubmissions therefore count as not
applied, the same for both groups. Also lists every mail by the two maintainers whose own text
(quoted lines dropped) mentions LKML or linux-kernel@.
"""
import collections
import email
import email.policy
import re
import subprocess

ARCH = "/root/exp/qca9377-bt-hang/cache/lore-linux-bluetooth-0.git"
LINUX = "/root/exp/qca9377-bt-hang/cache/linux"
SUBJ = re.compile(r"^\[(?P<tag>[^\]]*PATCH[^\]]*)\]\s*(?P<rest>Bluetooth:.*)$", re.I | re.S)
MAINT = ("luiz.dentz@gmail.com", "luiz.von.dentz@intel.com", "marcel@holtmann.org")


def git(*a, cwd):
    return subprocess.run(["git", "-C", cwd, *a], capture_output=True, check=True).stdout


applied = set()
for ref in ("bluetooth-next/master", "origin/master"):
    out = git("log", "--since=2025-12-01", "--format=%s", ref, "--", "net/bluetooth",
              "drivers/bluetooth", "include/net/bluetooth", cwd=LINUX).decode()
    applied.update(s.strip().lower() for s in out.splitlines())

commits = git("log", "--format=%H", cwd=ARCH).decode().split()
proc = subprocess.Popen(["git", "-C", ARCH, "cat-file", "--batch"], stdin=subprocess.PIPE,
                        stdout=subprocess.PIPE)
rows, maint_mentions = [], []
for c in commits:
    proc.stdin.write(f"{c}:m\n".encode())
    proc.stdin.flush()
    head = proc.stdout.readline().split()
    if len(head) < 3 or head[1] != b"blob":
        continue
    raw = proc.stdout.read(int(head[2]))
    proc.stdout.read(1)
    msg = email.message_from_bytes(raw, policy=email.policy.compat32)
    subj = " ".join((msg.get("Subject") or "").split())
    frm = email.utils.parseaddr(msg.get("From") or "")[1].lower()
    date = msg.get("Date") or ""
    if frm in MAINT:
        body = msg.get_payload(decode=True) if not msg.is_multipart() else b""
        text = (body or b"").decode("utf-8", "replace")
        own = "\n".join(l for l in text.splitlines() if not l.startswith(">"))
        if re.search(r"\blkml\b|linux-kernel@", own, re.I):
            maint_mentions.append((date, frm, subj))
    if subj.lower().startswith("re:"):
        continue
    m = SUBJ.match(subj)
    if not m or "bluez" in m.group("tag").lower():
        continue
    rcpt = " ".join((msg.get_all("To") or []) + (msg.get_all("Cc") or [])).lower()
    tag = m.group("tag")
    cover = bool(re.search(r"\b0+/\d+", tag))
    rest = m.group("rest").strip()
    rows.append(dict(date=date, frm=frm, subj=rest, cover=cover,
                     lkml="linux-kernel@vger.kernel.org" in rcpt,
                     netdev="netdev@vger.kernel.org" in rcpt,
                     maint=frm in MAINT, mgmt="mgmt" in rest.lower(),
                     applied=rest.lower() in applied))

patches = [r for r in rows if not r["cover"]]
print(f"archive: {len(commits)} mails; kernel patch postings: {len(patches)} "
      f"(plus {len(rows) - len(patches)} cover letters)")


def share(sel, label):
    n = len(sel)
    k = sum(r["lkml"] for r in sel)
    print(f"  {label:<46} {k:>4} of {n:<4} copy linux-kernel ({100 * k / n if n else 0:.0f}%)")


print("Postings (every version counted):")
share(patches, "all kernel patches")
share([r for r in patches if r["maint"]], "sent by the two maintainers")
share([r for r in patches if not r["maint"]], "sent by others")
share([r for r in patches if r["mgmt"]], "subject names MGMT")
share([r for r in patches if r["mgmt"] and not r["maint"]], "MGMT, by others")
share([r for r in patches if r["netdev"]], "that also copy netdev")

print("Distinct subjects (one row per subject; LKML if any posting copied it):")
by = collections.defaultdict(list)
for r in patches:
    by[(r["subj"].lower())].append(r)
subj_rows = [dict(lkml=any(x["lkml"] for x in v), applied=v[0]["applied"],
                  maint=any(x["maint"] for x in v), mgmt=v[0]["mgmt"]) for v in by.values()]
for label, sel in (("all, by others", [s for s in subj_rows if not s["maint"]]),
                   ("MGMT, by others", [s for s in subj_rows if s["mgmt"] and not s["maint"]])):
    for flag in (True, False):
        g = [s for s in sel if s["lkml"] == flag]
        a = sum(s["applied"] for s in g)
        print(f"  {label:<16} {'with' if flag else 'without'} linux-kernel: {len(g):>4} subjects, "
              f"{a:>4} applied ({100 * a / len(g) if g else 0:.0f}%)")

print("Top senders by count, with their share copying linux-kernel:")
cnt = collections.Counter(r["frm"] for r in patches if not r["maint"])
for frm, n in cnt.most_common(15):
    k = sum(r["lkml"] for r in patches if r["frm"] == frm)
    print(f"  {n:>4} postings, {k:>4} with linux-kernel  {frm.split('@')[1]}")

print("Maintainers' own text mentioning LKML or linux-kernel@:")
for d, f, s in maint_mentions:
    print(f"  {d[:31]}  {f}  {s[:90]}")
if not maint_mentions:
    print("  none")
