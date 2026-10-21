# CO-10 log

Append-only. Newest last.

## 2026-10-20 — rc2 out
The rc1 boot panic on a two-socket Xeon server was bisected to a sysfs patch, which was
dropped. rc2 (07:57 UTC) lists our three patches, and responses are due Thu 22 Oct 07:53:04
UTC (STATUS).

## 2026-10-21 — dossier opened
No decision yet.

## 2026-10-21 00:5x UTC — the operator: start CO-10
"I would start work on that urgent one … I would try to contribute it if we can." There was
no draft, so this is the first work on it.
- **The release candidate:** linux-stable-rc `linux-6.6.y` fetched; tip `c578c158a368`,
  "Linux 6.6.160-rc2".
- **Our three commits in it:** `4124ec5afa39` (BT-9), `9e665c9f2123` (BT-8), `c1d19f19c937`
  (QCA9377).
- **The run:** `experiments/build-and-test.sh`. Both kernels built in about 2 minutes each,
  and every run finished by 01:04:46 UTC. Results: `experiments/results-2026-10-21.md`.
  - BT-9 race: 6.6.159 fails 3/3, rc2 passes 3/3.
  - BT-8 reproducer: 6.6.159 0x00 2/2, rc2 0x0f 2/2.
  - mgmt-tester: one verdict differs out of 508, the race case.
  - No kernel reports.
- **The operator asked for the homework to be complete.** Found: rc2 carries 41 Bluetooth
  commits, 38 of them by other authors. So `experiments/all-testers.sh` runs every BlueZ
  tester on both kernels, in parallel, from 01:02 UTC.
- **No follow-up fix** for `96d006ae6445`, `86ef0f58bdec` or `dc16388d45ec` in bluetooth-next
  (fetched 2026-10-21), bluetooth (fetched 2026-10-21) or the mainline mirror (to 2026-10-18).
  A fetch of today's mainline was still running.
- **Package for outside reviewers:** `REVIEW-REQUEST.md`. The draft reply is in `drafts/`.

## 2026-10-21 01:1x to 01:4x UTC — every tester compared; draft version 2
- **iso-, sco-, bnep-, rfcomm-, ioctl-, smp-, userchan- and 6lowpan-tester:** identical
  verdicts on both kernels.
- **l2cap-tester:** both kernels hang at the same case ("Ext-Flowctl Server - Accept 2
  Close 1"). The guests were stopped. Of the 96 cases before it, one differs: "Ext-Flowctl
  Client - Defer limit", which failed 3/3 on 6.6.159 and passed 3/3 on rc2 in repeats. That
  is rc2's `e2910b42115a` (Pauli Virtanen's ecred fix).
- **mesh-tester:** 6.6.159 crashes in "Mesh - Enable 2" (KASAN stack-out-of-bounds in
  `set_mesh_sync`, then a GPF in `mgmt_pending_remove`). rc2 runs clean, with "Send cancel 1/2"
  timing out. The crash is rc2's `78504bca42ab`.
- **A mistake of ours, fixed:** the first `repeat-case.sh` passed a multi-word `-p` filter.
  test-runner hands the guest its arguments in one string, split at spaces, so the whole
  l2cap-tester ran and hung. The script now takes one word with `-s`, and says why.
- **Identity:** the BT-9 and BT-8 commits in rc2 are the same as sent and as mainline (same
  patch-id). The QCA9377 entry adds the same two lines (different context). No follow-up fix
  in today's mainline (`14c897740388`).
- **The draft:** version 2 states all four fixes and the regression result. No pending lines.
