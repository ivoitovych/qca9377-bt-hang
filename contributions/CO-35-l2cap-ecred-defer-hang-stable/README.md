# CO-35 — BT-10: the L2CAP ECRED deferred-accept hang on the stable lines

**State (2026-10-28, evening):** **send package ready for an outside review; nothing sent.**
`send/` holds four mails (`send/README.md`): an option-2 request for 7.3.y and 7.2.y
(`request-v2.eml`) and one option-3 series per older line (`[PATCH 6.18.y 0/2]`, `6.12.y`,
`6.6.y`), generated from the reviewed backports (code identical, same patch-ids). Next: an
outside review of those mails; then the operator's word; then the main session's dry run.
`send/request-v1.txt` (7.2.y only) is superseded and kept.

What the evening round established (`experiments/results-7.3-and-older-2026-10-28.md`):
- no stable line has a newer tag than the tested bases (7.2.13, 6.18.59, 6.12.114, 6.6.160);
  7.3.y has no release yet (branch at v7.3); neither commit is in any stable queue;
- **7.3.y:** v7.3 hangs on the case alone and passes with the pair; the whole l2cap-tester on
  v7.3 stalls earlier, in its SCI cases, with or without the pair: v7.3 has the SCI feature
  `2f8784cfe8a9` without its fix `5874f8d03268` (proposed BT-15). With `5874f8d03268` applied as
  well, the pair still decides the case (hang without, pass with) and the whole l2cap-tester
  passes 111 of 111. All logs clean;
- **6.1.y, 5.15.y, 5.10.y:** they lack `ab4eedb790ca`, and ECRED is off there by default
  (before v6.2 it is the module parameter `enable_ecred`), so the case fails at once ("Can't set
  mode"). With `enable_ecred=1` set in the guest the case never finishes on v6.1.190, v5.15.223
  and v5.10.272 either (positive control: the other Ext-Flowctl cases pass). The pair does not
  apply there. The request names them as affected and not covered; a fix for them is open;
- **What the hang is** (diagnostic, results §5): with the hung-task detector on, plain v7.3
  shows the tester's task holding its socket's lock from `l2cap_sock_recvmsg()` and waiting
  for the same lock in `l2cap_sock_teardown_cb()`; by the source, `__l2cap_ecred_conn_rsp_defer()`
  is called under that lock and can reach the socket's own teardown. That path dates from v5.7
  (`15f02b9105625`), which is why the older lines hang too; `32d86e048d8ef` releases the lock
  first;
- **Corrections to earlier records:** the first bisect's "second, SCI-caused hang on the same
  case" was a stall in an earlier case, "L2CAP LE Client - SCI Fast Mode", which the split
  case filter ran; the l2cap-tester images are built without `CONFIG_DETECT_HUNG_TASK`, so "no
  hung-task report" (request-v1, STATUS) claimed a check that could not fire.

**Target:** the stable kernel (7.3.y and 7.2.y take the pair as it is; 6.18.y, 6.12.y and 6.6.y
take the hand backports), and through it Ubuntu.

**Comes from:** `BT-10` (`docs/STATUS.md`): l2cap-tester "L2CAP Ext-Flowctl Server - Accept 2
Close 1" never finishes on 7.2.12, 6.18.58, 6.12.114, 6.6.160 and Ubuntu 7.0.0-38's code, and
passes on bluetooth-next. The BlueZ test's commit (`e9b6ee380`, Pauli Virtanen) says "This
triggers deadlock on some kernel versions".

## The fix

Two commits by Pauli Virtanen (authored 2026-08-29; committed in their present form
2026-10-14, `git log --format=%cd`), in mainline since the 7.4 merge window, with no
`Cc: stable` and in no stable queue (re-checked 2026-10-28 20:34 UTC):
1. `608e0b7a675b2` "Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and locking helpers", the
   helpers the second needs (`l2cap_chan_lock_conn()`, `l2cap_chan_unlock_conn()`);
2. `32d86e048d8ef` "Bluetooth: L2CAP: hold conn->lock for __l2cap_ecred_conn_rsp_defer"
   (`Fixes: ab4eedb790ca`, "Fix corrupted list in hci_chan_del", early 2025). That commit is on
   7.3.y, 7.2.y and 6.18.y and was backported to 6.12.y (`f87271d21dd4e`) and 6.6.y
   (`efc30877bd4bc`), matching the lines that hang. 6.1.y, 5.15.y and 5.10.y do not carry it.

The two are patches 2 and 7 of Pauli Virtanen's 16-patch series "[PATCH 00/16] Bluetooth:
L2CAP: fix and annotate l2cap_conn::chan_l locking" (2026-08-29, linux-bluetooth); all 16 are in
mainline, none on a stable line, eight carry a `Fixes:` tag (`tmp/co35/series16.sh`, results
file §4). The pair alone cherry-picks, builds and fixes the case; the other 14 were not tested
here.

**Evidence** (`log.md`, `experiments/`):
- a bisect of bluetooth-next (v7.2 hangs, `47d4d9f67e92` passes), with the confound removed,
  ends at `32d86e048d8ef` (`results-2026-10-28.md`);
- 7.2.13 + the two commits: the case passes, the full l2cap-tester 111 of 111, the kernel log
  clean (`results-2026-10-28.md`);
- v6.18.59, v6.12.114, v6.6.160 + the hand backports: the case passes, every failing case of
  the full suite also fails on the plain base (`results-backports-2026-10-28.md`);
- v7.3 + the two commits, and the older lines (`results-7.3-and-older-2026-10-28.md`).

## History

The sections "Missing before a request" of the earlier README (6.18 build failure, the
6.12/6.6 hunk, the older lines, the mail) are all done; their record is in `log.md`.
