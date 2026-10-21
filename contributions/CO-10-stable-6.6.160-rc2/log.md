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

## 2026-10-21 02:xx UTC — three outside reviews of version 1; version 3
The reviews are in `reviews/2026-10-21-reviewer-{1,2,3}.md`. A fourth reviewer will answer
later. All three read version 1, with its [PENDING] line.

**Verdicts:**
- reviewer 1: send once the pending line is filled;
- reviewer 2: ready after minor fixes;
- reviewer 3: revise before sending; conditional approval.

**What each point led to:**

| point | who | done |
|---|---|---|
| Finish the other testers; check per-case verdicts, not script completion | 1, 2, 3 | done in version 2, by per-case comparison (`compare-tester-verdicts.py`); the one differing case was repeated 3 times per kernel |
| "No regressions in Bluetooth" is overbroad | 2, 3 | changed to "No new failures in those tests" |
| Put the exact rc2 commit in the mail | 2, 3 | added: `(c578c158a368)` |
| Show mgmt-tester's existing failures | 2, 3 | added: rc2 465/37/6, 6.6.159 464/38/6 |
| Confirm KASAN and lockdep in the generated configs; confirm the booted kernels | 2, 3 | done: 4 options on each config; every log names the intended kernel (results file) |
| A wider scan for kernel reports | 3 | `scripts/kernel-report-scan.py` (13 kinds): rc2 clean in all 18 logs; positive control found 6.6.159's crash. The mail now says "No kernel warnings or sanitizer reports on rc2 in these runs" |
| The comparator can hide duplicates and accept empty input | 3 | fixed: exit 2 on duplicate names or no verdicts |
| The build recipe and QEMU wrapper are not public | 3 | copied into `experiments/` with both configs; decisive lines in the results file |
| Link the rc2 run to the earlier isolated experiments | 3 | added to the results file |
| The comment in `all-testers.sh` names the wrong script | 2 | fixed |
| The QCA9377 entry: omit (1, 2) or one sentence (3) | split | middle course: "(emulated controllers, no Bluetooth hardware)" states the scope without singling out one patch |
| Check the threading headers against the announcement | 3 | the sendable copy's `In-Reply-To`/`References` match the saved announcement's Message-ID; To/Cc copied from its header |
| No reboot of the laptop into rc2 | 2, 3 | agreed; not done |

**The sendable copy:** version 3, `tmp/co10-20261021/send/reply-6.6.160-rc2-v3.eml`.
`mail-lint.sh` flags only the two quoted lines of the announcement (73 columns, kept as
written).
