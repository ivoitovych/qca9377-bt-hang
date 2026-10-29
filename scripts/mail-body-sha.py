#!/usr/bin/env python3
"""mail-body-sha.py: SHA-256, byte and line count of a mail file's body (everything after the
first empty line), with and without trailing newlines.

    mail-body-sha.py <mail file>

Used to prove a sent mail arrived unchanged when lore cannot be read from this machine: the same
rule runs in the operator's Chrome on lore's /raw copy (fetch, split at the first empty line,
SHA-256 via crypto.subtle) and only "equal or not" comes back (CO-25, 2026-10-29). Compare the
"without trailing newlines" hash: lore's copy ends with one more newline than the file sent.
"""
import hashlib
import sys

NL = b"\n"
data = open(sys.argv[1], "rb").read().replace(b"\r\n", NL)
body = data.split(NL + NL, 1)[1]
stripped = body.rstrip(NL)
print("bytes", len(body), " lines", body.count(NL), " sha256", hashlib.sha256(body).hexdigest())
print("without trailing newlines: bytes", len(stripped), " sha256",
      hashlib.sha256(stripped).hexdigest())
