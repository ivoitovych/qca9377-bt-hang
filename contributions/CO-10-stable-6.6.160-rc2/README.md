# CO-10 — Tested-by on 6.6.160-rc2

**State:** tested in full. Draft version 3 has taken up three outside reviews
(`reviews/`, `log.md`); a fourth is expected. Sending is the operator's decision. **The
deadline is 2026-10-22 07:53:04 UTC.**

**The result, 2026-10-21 01:4x UTC:** every BlueZ tester was compared on rc2 and 6.6.159.
There are no regressions, and four of rc2's fixes show up as intended:
- our BT-9 and BT-8;
- Pauli Virtanen's mesh crash fix: 6.6.159 hits KASAN, then a GPF, in mesh-tester;
- his L2CAP ecred fix: "Defer limit" fails 3/3 on 6.6.159 and passes 3/3 on rc2.

Details: `experiments/results-2026-10-21.md`.

**Target:** the stable kernel review of "[PATCH 6.6 0000/1651] 6.6.160-rc2 review".

**Comes from:** our three patches in that release candidate: the QCA9377 entry, the BT-9 fix
and the BT-8 fix.

**For outside reviewers, start here:** [`REVIEW-REQUEST.md`](REVIEW-REQUEST.md).

## Where it stands (2026-10-21 01:2x UTC)

- **Both kernels built** with BlueZ's tester config: 6.6.160-rc2 (`c578c158a368`) and the
  control 6.6.159.
- **The two fixes,** tested in QEMU (results in `experiments/results-2026-10-21.md`):
  - BT-9's race case fails on 6.6.159 (3 of 3 runs) and passes on rc2 (3 of 3);
  - BT-8's reproducer shows the bug on 6.6.159 (2 of 2) and the fix on rc2 (2 of 2).
- **No regression in mgmt-tester:** 508 cases with one difference, the race case.
- **No kernel reports.**
- **Running:** every other BlueZ tester on both kernels, because rc2 carries 41 Bluetooth
  commits, 38 of them by other authors.
- **Follow-ups:** none in mainline, bluetooth or bluetooth-next for the three commits
  (`git log --grep` on each upstream id, 2026-10-21).
- **The draft:** `drafts/reply-6.6.160-rc2.txt`. The sendable copy with its headers stays on
  the development host.

## Next

1. Fill in the other testers' result. Update the draft's [PENDING] line, or report a
   difference.
2. Outside reviews (`REVIEW-REQUEST.md`).
3. The operator's decision, then the send: git send-email with `--in-reply-to` and a one-time
   app password, deleted afterwards.
