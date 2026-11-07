# Sent-mail check — 2026-10-28

**Question (the operator's):** has any file that records a mail as sent been changed after the
send? **Answer: no.**

**Inventory:** [`docs/sent-mails.tsv`](../docs/sent-mails.tsv), 25 mails: send date, contribution,
repository path, Message-ID, patchwork id (cover letters as `cover:N`), list, SHA-256 of the file.
**Tool:** `python3 -I scripts/sent-mail-check.py` fetches each mail once from patchwork into
`cache/sent-upstream/<message-id>.mbox` (lore refuses this machine, 403), checks the fetched
Message-ID against the inventory, and compares the normalised subject, the commit message, the
notes under `---`, the diff, and `git patch-id --stable`; `--hashes` only re-hashes the recorded
files (offline, for a save-step guard). Exit 1 on any difference.

## Result
- **IDENTICAL: 22.** `git patch-id --stable` equal for every compared mail.
- **DIFFERS: 0.** `--hashes`: 24 of 24 files equal to their recorded hash.
- **No upstream copy reachable: 3** (no patchwork id): the `dc16388d45ec` stable request of
  2026-10-02 (its sendable file was never kept in the repository); the Tested-by reply on Hui
  Peng's mesh_tx patch (its last wording commit `b926833`, 15 minutes before the send; the later
  port `9588c99` carries the same blob `880b3e5cdeb5`); CO-10's 6.6.160-rc2 report (last commit
  `1eda14a`, 22 minutes before the send; blob `e8ab46352a3c`, as STATUS records).
- **Positive control:** a scratch inventory with one row pointing at the wrong file and one at a
  copy with a single code word changed gave DIFFERS for both, with diffs and a hash warning.

## What the comparison absorbs, and why (a first naive run reported 5 false differences)
- Patchwork files the text after the last hunk (the `-- 2.43.0` signature, `base-commit:`) with
  the notes, and keeps the signature on some mails only: the signature is ignored on both sides.
- `git send-email` adds an in-body `From: Jiajia Liu` to the three BT-9 stable mails (the sender
  is not the author): ignored.
- Those three files elide two `Signed-off-by` addresses and one device address, as their README
  says: a line is accepted only when it carries the placeholder and upstream's line has a
  well-formed address there; a note is printed; subject and diff are exact.

## Edits before a send (not after)
CO-02's BlueZ test file: commit `3195cdc` filled the lore link at 17:50:42, the send was at
17:50:59; the upstream copy has the link; no later commit touches the file. Commits after sends
(`1b3230d` creating `patches/bluez/sent/`, the ports `5939d04` and `9588c99`, `16d4b10` first
committing the shared/mgmt files) change no content.

## Not covered
The three mails without an upstream copy rest on commit order and recorded blobs. The 10-09 GitHub
comment on BlueZ #1554 is not a mail. Two fetches under a wrong id (cover/patch id overlap) were
moved to `cache/sent-upstream-wrong-id/`, nothing deleted.
