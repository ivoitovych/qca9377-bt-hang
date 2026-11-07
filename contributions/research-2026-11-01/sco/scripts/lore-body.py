#!/usr/bin/env python3
"""Print one lore message (by archive commit) without its transport headers.

Usage: lore-body.py <bare lore repo> <commit> [--noquote]
Addresses are removed from From/To/Cc; with --noquote, lines starting
with '>' are folded into a count.
"""
import email
import email.policy
import re
import subprocess
import sys


def main(repo, commit, noquote):
    raw = subprocess.run(["git", "-C", repo, "show", f"{commit}:m"], check=True,
                         capture_output=True).stdout
    msg = email.message_from_bytes(raw, policy=email.policy.default)
    for h in ("From", "Date", "Subject", "Message-ID", "In-Reply-To"):
        v = " ".join(str(msg.get(h, "")).split())
        if h == "From":
            v = re.sub(r"<[^>]*>", "", v).strip()
        print(f"{h}: {v}")
    print()
    part = msg.get_body(preferencelist=("plain",))
    body = part.get_content() if part else ""
    body = re.sub(r"[\w.+-]+@[\w-]+(\.[\w-]+)+", "<addr>", body)
    quoted = 0
    for line in body.splitlines():
        if noquote and line.startswith(">"):
            quoted += 1
            continue
        if quoted:
            print(f"   [{quoted} quoted lines]")
            quoted = 0
        print(line)
    if quoted:
        print(f"   [{quoted} quoted lines]")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], "--noquote" in sys.argv[3:])
