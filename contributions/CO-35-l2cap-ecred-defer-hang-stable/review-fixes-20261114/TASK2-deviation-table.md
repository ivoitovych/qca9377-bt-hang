# CO-35 deviations from mainline, per backport line (2026-11-14)

Method (measured): `diff` of the mainline commit as exported by `git format-patch` (`upstream/608e0b7a675b.patch`, `upstream/32d86e048d8e.patch`, from lane 5's kernel repository, read only) against each package patch `send-20261114/mail/<line>/000{1,2}-*.patch` (byte-identical to `send-20261102/`). Every line of the diff output is in the table; nothing else differs except the mail headers (new blob ids, `Subject: [PATCH <line> n/2]`), the added `[ Upstream commit <sha> ]` line, the added `[ backport: ... ]` note, and the added `Signed-off-by` of the submitter.

Marks: **code** = the resulting code differs from mainline's; **annotation** = a context-analysis annotation dropped (no code change); **context** = only hunk offsets, context lines or lines that do not exist in the tree.

## Patch 1: `608e0b7a675b` "add l2cap_chan_close_unlocked() and locking helpers" (mainline 149-line diff, 73 insertions, 5 deletions)

| difference | 6.18.y | 6.12.y | 6.6.y | mark |
|---|---|---|---|---|
| `l2cap.h`: `__must_not_hold(&chan->lock)` dropped from the prototype of `l2cap_chan_close_unlocked()` | yes | yes | yes | annotation |
| `l2cap.h`: `__cond_acquires(true, &chan->conn->lock)` dropped from `l2cap_chan_lock_conn()` (`__acquires(&chan->lock)` kept) | yes | yes | yes | annotation |
| `l2cap_core.c`: `__context_unsafe(/* conditional locking */)` line dropped | yes | yes | yes | annotation |
| `l2cap.h`: context line of `l2cap_chan_connect()` has no `u16 timeout` argument in this tree | no | no | yes | context |
| hunk offsets and blob ids (`l2cap.h`, `l2cap_core.c`) | yes | yes | yes | context |
| diffstat | 71 ins / 5 del (16 + 60 in the two files) | 71 / 5 | 71 / 5 | consequence of the three annotation lines |
| code of `__l2cap_chan_close()` split, `l2cap_chan_lock_conn()`, `l2cap_chan_unlock_conn()`, `l2cap_chan_close_unlocked()`, the six call-site replacements | identical to mainline | identical | identical | none |

## Patch 2: `32d86e048d8e` "hold conn->lock for __l2cap_ecred_conn_rsp_defer" (mainline 48 ins / 20 del)

| difference | 6.18.y | 6.12.y | 6.6.y | mark |
|---|---|---|---|---|
| `l2cap_sock.c`: the three `MSG_ERRQUEUE` lines (`if (unlikely(flags & MSG_ERRQUEUE)) return sock_recv_errqueue(...)`) that mainline removes before and re-adds after the new `l2cap_sock_defer()` call: this tree's `l2cap_sock_recvmsg()` has no such block, so neither the removal nor the re-addition is in the patch | no (block present, patch as mainline) | yes | yes | context (tree lacks the lines) |
| `l2cap_sock_defer()`, its body, and its call in `l2cap_sock_recvmsg()` | identical to mainline | identical | identical | none |
| hunk offsets and blob id | yes | yes | yes | context |
| diffstat | 48 ins / 20 del | 45 / 17 | 45 / 17 | consequence of the missing block |

## What is not a deviation

No code line of either commit is changed or reordered on any line. Patch 1 is requested whole; the three dropped lines are annotations that expand to nothing where they exist. The 6.6.y cover's wording ("the three MSG_ERRQUEUE lines ... are absent; l2cap_sock_defer() and its call are as upstream") and the `[ backport: ... ]` notes in the patches match this table. 7.3.y has no deviation: both mainline commits cherry-pick unchanged onto v7.3.4 (`logs/apply-v7.3.4.log` of the refresh).

Commands: `diff upstream/608e0b7a675b.patch send-20261114/mail/<line>/0001-*.patch` and `diff upstream/32d86e048d8e.patch send-20261114/mail/<line>/0002-*.patch` for the three lines (output inspected in full).
