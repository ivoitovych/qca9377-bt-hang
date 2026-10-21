# CO-10 — Tested-by on 6.6.160-rc2

**State:** tested in full. Draft **version 4** has taken up four outside reviews, and its
sendable copy passes the form and threading checks. **It waits for the operator's decision**
and a one-time app password. **The deadline is 2026-10-22 07:53:04 UTC.**

**Target:** the stable kernel review of "[PATCH 6.6 0000/1651] 6.6.160-rc2 review".

**Comes from:** our three patches in that release candidate: the QCA9377 entry, the BT-9 fix
and the BT-8 fix.

**For outside reviewers, start here:** [`REVIEW-REQUEST.md`](REVIEW-REQUEST.md).

## The result

6.6.160-rc2 (`c578c158a368`) was compared with 6.6.159, both built with BlueZ's
`tester.config` (KASAN, lockdep), using the BlueZ CI TestRunner suites in QEMU/KVM with
emulated controllers.

**Four of rc2's fixes show up as intended,** each failing on 6.6.159 and passing on rc2:
- our BT-9 (3/3);
- our BT-8 (2/2);
- Pauli Virtanen's mesh crash fix (KASAN, then a GPF, on 6.6.159);
- his L2CAP ecred fix (3/3).

**All other cases that ran on both kernels have the same verdict.** Every mesh case now has a
control verdict. l2cap-tester hangs at the same case on both kernels.

**No kernel report on rc2,** by a 13-kind scan with a positive control. The QCA9377 entry was
not exercised: there is no hardware on this kernel. It builds.

The details are in `experiments/results-2026-10-21.md`, the draft in
`drafts/reply-6.6.160-rc2.txt`, the reviews in `reviews/`, and what each review point led to
in `log.md`.

## Next

1. **The operator's decision.** The send: git send-email with the sendable copy
   (`tmp/co10-20261021/send/reply-6.6.160-rc2-v4.eml`) and a one-time app password, deleted
   afterwards.
2. **Before sending, on the day:**
   - `scripts/reply-headers-check.py` and `scripts/mail-lint.sh` on the final file;
   - a check that linux-stable-rc `linux-6.6.y` is still `c578c158a368` (it is rebased
     often);
   - a check that no rc3 has been announced.
3. **After sending:** record in `log.md` the repository commit and the exact file sent, the
   time and the server's answer. Then watch the release for the `Tested-by`.
