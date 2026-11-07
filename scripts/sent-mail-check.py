#!/usr/bin/env python3
"""sent-mail-check.py — do the recorded files still equal the mails upstream received?

    python3 -I scripts/sent-mail-check.py             # compare with patchwork
    python3 -I scripts/sent-mail-check.py --hashes    # offline: SHA-256 only

The inventory is docs/sent-mails.tsv: one row per mail we sent, with the
repository path of the file as sent, its Message-ID, the patchwork id (if
the list's patchwork has one) and the SHA-256 the file had when it was
recorded. A record of what was sent must never change after the send.

Default mode: for each row with a patchwork id, fetch the mbox once from
patchwork.kernel.org into cache/sent-upstream/<message-id>.mbox (the API
JSON next to it as .json; a cached copy is not fetched again) and compare it
with the local file, ignoring transport headers: the subject (with its
"[PATCH ...]" prefix and whitespace normalised), the commit message, the
notes under the "---" line, and the diff (also by `git patch-id --stable`).
Verdict per row: IDENTICAL, DIFFERS (with a unified diff of each differing
part), or NO UPSTREAM COPY (no patchwork id; lore refuses this machine with
403, so it is not used). The SHA-256 of every file is checked too.

--inventory=FILE reads another table (a control: point a row at the wrong file).
A bare word restricts the run to rows whose contribution contains it.

--hashes: only recompute the SHA-256 of every inventory file and report any
that differs from the recorded one (a guard for a save step).

Read-only apart from the cache. Exit 1 on any DIFFERS or hash change, 2 when
patchwork cannot be reached.
"""
import difflib
import email
import email.header
import hashlib
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
INVENTORY = os.path.join(ROOT, "docs", "sent-mails.tsv")
CACHE = os.path.join(ROOT, "cache", "sent-upstream")
API = "https://patchwork.kernel.org/api/{}/{}/"
NOT_KEPT = "not kept in the repository"


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "curl/8"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def read_inventory(path=INVENTORY):
    rows = []
    with open(path, encoding="utf-8") as f:
        header = f.readline().rstrip("\n").split("\t")
        for line in f:
            if line.strip():
                rows.append(dict(zip(header, line.rstrip("\n").split("\t"))))
    return rows


def sha256(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def check_hash(row):
    """Return (status, detail) for one row: ok, CHANGED, MISSING or skipped."""
    path = row["path"]
    if path == NOT_KEPT or not row.get("sha256"):
        return "skipped", "no file in the repository"
    full = os.path.join(ROOT, path)
    if not os.path.exists(full):
        return "MISSING", path
    now = sha256(full)
    if now != row["sha256"]:
        return "CHANGED", f"recorded {row['sha256']} now {now}"
    return "ok", ""


def fetch(row):
    """Cache and return the upstream mbox bytes for a row with a patchwork id."""
    name = row["message_id"].strip("<>")
    mbox = os.path.join(CACHE, name + ".mbox")
    if os.path.exists(mbox):
        with open(mbox, "rb") as f:
            return f.read()
    os.makedirs(CACHE, exist_ok=True)
    # patches and covers have separate id spaces: "cover:N" marks a cover letter
    kind, _, pid = row["patchwork_id"].rpartition(":")
    kind = "covers" if kind == "cover" else "patches"
    meta = json.loads(get(API.format(kind, pid)))
    if meta["msgid"] != row["message_id"]:
        raise RuntimeError(f"patchwork {kind}/{pid} is {meta['msgid']}, the inventory says {row['message_id']}")
    data = get(meta["mbox"])
    with open(os.path.join(CACHE, name + ".json"), "w") as f:
        json.dump(meta, f, indent=1)
    with open(mbox, "wb") as f:
        f.write(data)
    return data


def decode_header(value):
    return str(email.header.make_header(email.header.decode_header(value or "")))


def norm_subject(value):
    s = re.sub(r"\s+", " ", decode_header(value)).strip()
    return re.sub(r"^(\[[^\]]*\]\s*)+", "", s).strip()


def parse(raw):
    """Split a mail (mbox "From " line allowed) into subject, message, notes, diff, msgid."""
    if raw.startswith(b"From "):
        raw = raw.split(b"\n", 1)[1]
    msg = email.message_from_bytes(raw)
    part = msg
    if msg.is_multipart():
        part = msg.get_payload(0)
    charset = part.get_content_charset() or "utf-8"
    body = part.get_payload(decode=True).decode(charset, "replace")
    lines = [l.rstrip() for l in body.replace("\r\n", "\n").split("\n")]
    out = {"subject": norm_subject(msg["Subject"]),
           "msgid": (msg["Message-ID"] or "").strip()}
    start = next((i for i, l in enumerate(lines) if l.startswith("diff --git ")), None)
    sep = next((i for i, l in enumerate(lines) if l == "---"), None)
    if start is None:  # a cover letter: everything is message
        lines = strip_blank_edges(lines)
        if len(lines) > 1 and lines[-2] == "--" and re.fullmatch(r"\d+\.\d+[\w.\-]*", lines[-1]):
            lines = strip_blank_edges(lines[:-2])  # git's signature, see below
        out.update(message=lines, notes=[], diff=[])
        return out
    end = hunks_end(lines, start)
    out["message"] = lines[:sep] if sep is not None and sep < start else lines[:start]
    # Patchwork stores whatever follows the last hunk (the "-- " signature, a
    # base-commit line) with the text before the diff, so the tail joins the
    # notes on both sides; blank lines are not compared.
    notes = (lines[sep + 1:start] if sep is not None and sep < start else []) + lines[end:]
    notes = [l for l in notes if l.strip()]
    # git's "-- " + version signature: patchwork keeps it on some mails and
    # drops it on others, so it is a format artefact, not content.
    for i in range(len(notes) - 1):
        if notes[i] == "--" and re.fullmatch(r"\d+\.\d+[\w.\-]*", notes[i + 1]):
            del notes[i:i + 2]
            break
    out["notes"] = notes
    out["diff"] = lines[start:end]
    return out


def hunks_end(lines, start):
    """Index after the last line that belongs to a hunk of the diff starting at `start`."""
    i = start
    end = start
    while i < len(lines):
        m = re.match(r"@@ -\d+(?:,(\d+))? \+\d+(?:,(\d+))? @@", lines[i])
        if m:
            old = int(m.group(1) if m.group(1) is not None else 1)
            new = int(m.group(2) if m.group(2) is not None else 1)
            i += 1
            while (old > 0 or new > 0) and i < len(lines):
                c = lines[i][:1]
                if c == "-":
                    old -= 1
                elif c == "+":
                    new -= 1
                elif c in (" ", ""):
                    old -= 1
                    new -= 1
                i += 1
            while i < len(lines) and lines[i].startswith("\\"):
                i += 1
            end = i
        elif lines[i].startswith(("diff --git ", "index ", "--- ", "+++ ", "new file", "deleted file",
                                  "old mode", "new mode", "similarity", "rename ", "Binary files")):
            i += 1
            end = i
        else:
            break
    return end


ELISION = re.compile(r"(<<address elided>>|AA:BB:CC:00:00:[0-9A-Fa-f]{2})")
ELISION_RE = {"<<address elided>>": r"<[^<>\s]+@[^<>\s]+>",
              "AA:BB:CC:00:00:": r"(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}"}


def elided_equal(local_line, up_line):
    """True when the repository copy's line differs from upstream's only where it
    carries an address placeholder (public copies elide addresses on purpose)."""
    parts = ELISION.split(local_line)
    if len(parts) == 1:
        return False
    pat = ""
    for p in parts:
        if ELISION.fullmatch(p):
            pat += ELISION_RE["<<address elided>>" if p.startswith("<<") else "AA:BB:CC:00:00:"]
        else:
            pat += re.escape(p)
    return re.fullmatch(pat, up_line) is not None


def reconcile(a, b):
    """Lines of `a` (local) and `b` (upstream) after allowing the declared
    artefacts: the in-body "From:" git send-email adds when the sender is not the
    author, and elided addresses. Returns (a, b, number of elided lines)."""
    if b[:1] and b[0].startswith("From: ") and not (a[:1] and a[0].startswith("From: ")):
        b = strip_blank_edges(b[1:])
    n = 0
    if len(a) == len(b):
        b = list(b)
        for i, (x, y) in enumerate(zip(a, b)):
            if x != y and elided_equal(x, y):
                b[i] = x
                n += 1
    return a, b, n


def strip_blank_edges(lines):
    while lines and not lines[0]:
        lines = lines[1:]
    while lines and not lines[-1]:
        lines = lines[:-1]
    return lines


def patch_id(diff):
    if not diff:
        return "-"
    p = subprocess.run(["git", "patch-id", "--stable"], input="\n".join(diff) + "\n",
                       capture_output=True, text=True)
    return p.stdout.split()[0] if p.stdout.split() else "-"


def compare(row):
    """Return (verdict, report lines)."""
    with open(os.path.join(ROOT, row["path"]), "rb") as f:
        local = parse(f.read())
    up = parse(fetch(row))
    report = []
    if up["msgid"] != row["message_id"]:
        report.append(f"  Message-ID: inventory {row['message_id']} upstream {up['msgid']}")
    parts = [("subject", [local["subject"]], [up["subject"]])]
    for key in ("message", "notes", "diff"):
        parts.append((key, strip_blank_edges(local[key]), strip_blank_edges(up[key])))
    elided = 0
    for key, a, b in parts:
        if key in ("message", "notes"):
            a, b, n = reconcile(a, b)
            elided += n
        if a != b:
            report.append(f"  {key} differs (--- local, +++ upstream):")
            report.extend("    " + l for l in difflib.unified_diff(a, b, "local", "upstream", lineterm="", n=2))
    pa, pb = patch_id(local["diff"]), patch_id(up["diff"])
    if pa != pb:
        report.append(f"  patch-id: local {pa} upstream {pb}")
    if elided and not report:
        report.append(f"  note: {elided} line(s) differ only where the repository copy elides an address")
    return ("DIFFERS" if [l for l in report if not l.startswith("  note:")] else "IDENTICAL"), report, pa, pb


def main(args):
    hashes_only = "--hashes" in args
    only = [a for a in args if not a.startswith("--")]  # optional: rows whose contribution contains this
    inv = next((a.split("=", 1)[1] for a in args if a.startswith("--inventory=")), INVENTORY)
    rows = [r for r in read_inventory(inv) if not only or any(o in r["contribution"] for o in only)]
    bad = 0
    counts = {}
    for row in rows:
        tag = f"{row['contribution']}  {row['message_id']}"
        hstat, hdetail = check_hash(row)
        if hstat in ("CHANGED", "MISSING"):
            bad += 1
        if hashes_only:
            if hstat != "ok":
                print(f"{hstat.upper() if hstat != 'skipped' else 'SKIPPED'}  {tag}  {row['path']}  {hdetail}")
            counts[hstat] = counts.get(hstat, 0) + 1
            continue
        if not row["patchwork_id"] or row["path"] == NOT_KEPT:
            verdict, report, pa, pb = "NO UPSTREAM COPY", [], "-", "-"
        else:
            try:
                verdict, report, pa, pb = compare(row)
            except OSError as e:
                print(f"{tag}  unreachable: {e}", file=sys.stderr)
                return 2
        if verdict == "DIFFERS":
            bad += 1
        counts[verdict] = counts.get(verdict, 0) + 1
        print(f"{verdict:<16} hash={hstat:<7} patch-id={pa[:12]:<12} {tag}  {row['path']}")
        if hstat in ("CHANGED", "MISSING"):
            print(f"  hash {hstat}: {hdetail}")
        for line in report:
            print(line)
    print("summary:", ", ".join(f"{k}={v}" for k, v in sorted(counts.items())), f"of {len(rows)}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
