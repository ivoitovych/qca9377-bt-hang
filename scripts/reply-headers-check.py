#!/usr/bin/env python3
"""Check a reply mail's threading and recipients against the original mail.

Usage: python3 -I scripts/reply-headers-check.py <reply.eml> <original.eml>

Checks, and prints PASS or FAIL for each:
  - In-Reply-To is exactly the original's Message-ID;
  - References contains the original's Message-ID;
  - Subject is "Re: " + the original's Subject;
  - the reply's To + Cc addresses equal the original's From + To + Cc
    (a reply-all: nobody dropped, nobody added), ignoring the reply's own
    From address;
  - From, To and Subject are present, and the body is plain text.
Addresses are compared case-insensitively, display names ignored.
Exits 0 when every check passes, else 1. scripts/mail-lint.sh checks the
form (line length, ASCII, whitespace); this checks the threading.
"""
import email
import email.policy
import email.utils
import sys


def addrs(msg, *fields):
    values = []
    for field in fields:
        values += msg.get_all(field, [])
    return {a.lower() for _, a in email.utils.getaddresses(values) if a}


def expected_subject(original):
    s = " ".join(original.split())
    return s if s.lower().startswith("re:") else "Re: " + s


def main():
    if len(sys.argv) != 3:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    with open(sys.argv[1], "rb") as f:
        reply = email.message_from_binary_file(f, policy=email.policy.default)
    with open(sys.argv[2], "rb") as f:
        orig = email.message_from_binary_file(f, policy=email.policy.default)

    mid = (orig.get("Message-ID") or "").strip()
    own = addrs(reply, "From")
    want = addrs(orig, "From", "To", "Cc") - own
    have = addrs(reply, "To", "Cc")

    checks = [
        ("original has a Message-ID", bool(mid)),
        ("In-Reply-To is the original's Message-ID",
         (reply.get("In-Reply-To") or "").strip() == mid),
        ("References contains the original's Message-ID",
         bool(mid) and mid in (reply.get("References") or "")),
        # Unfolded and whitespace-normalised; a reply to a reply keeps one "Re: "
        # (2026-10-29: the first reply to a reply, CO-25, was failed for not having "Re: Re:").
        ("Subject is Re: + the original's Subject",
         " ".join((reply.get("Subject") or "").split())
         == expected_subject(orig.get("Subject") or "")),
        ("From, To and Subject present",
         all(reply.get(h) for h in ("From", "To", "Subject"))),
        ("body is text/plain", reply.get_content_type() == "text/plain"),
        ("reply-all: To+Cc equal the original's From+To+Cc", have == want),
    ]
    ok = True
    for name, passed in checks:
        print("%s  %s" % ("PASS" if passed else "FAIL", name))
        ok = ok and passed
    if have != want:
        for a in sorted(want - have):
            print("  missing: %s" % a)
        for a in sorted(have - want):
            print("  added:   %s" % a)
    print("recipients: %d (original %d)" % (len(have), len(want)))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
