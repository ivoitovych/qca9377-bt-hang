# CO-35 — BT-10: the L2CAP ECRED deferred-accept hang on the stable lines

**State:** investigating → **fix identified and confirmed on 7.2.13** (2026-10-28). Nothing
drafted; a stable request is the operator's decision.

**Target:** the stable kernel (7.2.y as it is; 6.18.y, 6.12.y and 6.6.y need a hand backport), and
through it Ubuntu.

**Comes from:** `BT-10` (`docs/STATUS.md`): l2cap-tester "L2CAP Ext-Flowctl Server - Accept 2
Close 1" never finishes on 7.2.12, 6.18.58, 6.12.114, 6.6.160 and Ubuntu 7.0.0-38's code, and
passes on bluetooth-next. The BlueZ test's commit (`e9b6ee380`, Pauli Virtanen) says "This
triggers deadlock on some kernel versions".

## The fix

Two commits by Pauli Virtanen, in bluetooth-next since 2026-08-29, in mainline since the 7.4
merge window (2026-10-27), with no `Cc: stable` and in no stable queue (2026-10-28):
1. `608e0b7a675b2` "Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and locking helpers", the
   helpers the second needs (`l2cap_chan_lock_conn()`, `l2cap_chan_unlock_conn()`);
2. `32d86e048d8ef` "Bluetooth: L2CAP: hold conn->lock for __l2cap_ecred_conn_rsp_defer"
   (`Fixes: ab4eedb790ca`, "Fix corrupted list in hci_chan_del", early 2025). That commit is on
   7.2.y and 6.18.y (through 6.14) and was backported to 6.12.y and 6.6.y, matching the lines that
   hang. 6.1.y, 5.15.y and 5.10.y do not carry it.

**Evidence** (`log.md`, `experiments/results-2026-10-28.md`):
- a bisect of bluetooth-next (v7.2 hangs, `47d4d9f67e92` passes), with the confound removed,
  ends at `32d86e048d8ef`;
- 7.2.13 + the two commits: the case passes (0.009 s; plain 7.2.12 hangs in the same run's
  control), the full l2cap-tester 111 of 111, the kernel log clean.

## Missing before a request

- **6.18.y:** the pair applies but does not build (`608e0b7a675b2` uses lock annotations 6.18
  lacks: `__must_not_hold`, two-argument `__cond_acquires`); a backport without the annotations,
  built and run the same way;
- **6.12.y and 6.6.y:** that, plus a reworked `l2cap_sock.c` hunk of `32d86e048d8ef`; or a request
  limited to 7.2.y, saying the older lines need a backport;
- whether 6.1.y, 5.15.y and 5.10.y hang at all (they lack `ab4eedb790ca`): one run each;
- the mail (to stable@, Cc the author and the Bluetooth maintainers, as the BT-9 backport
  requests of 2026-10-10 were) and the operator's decision.
