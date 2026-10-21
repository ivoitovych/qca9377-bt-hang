# CO-10 — Tested-by on 6.6.160-rc2

**State:** tested in full. Draft **version 5** has taken up four outside reviews and their
recheck, and its sendable copy (`drafts/reply-6.6.160-rc2-v5.eml`) passes the form and
threading checks. **It waits for the operator's decision**
and a one-time app password. **The deadline is 2026-10-22 07:53:04 UTC.**

**Target:** the stable kernel review of "[PATCH 6.6 0000/1651] 6.6.160-rc2 review".

**Before sending, on the day:** the two mail checks, linux-stable-rc `linux-6.6.y` still at
`c578c158a368`, and no 6.6.160-rc3 announced.

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

**All other cases that ran on both kernels either pass on both or fail on both.** Every mesh
case now has a control verdict. One 6.6.159 run of "Send cancel - 1" failed where rc2 timed
out, which is why the wording is not "same verdict". l2cap-tester hangs at the same case on
both kernels.

**No kernel report on rc2,** by a 13-kind scan with a positive control. The QCA9377 entry was
not exercised: there is no hardware on this kernel. It builds.

The details are in `experiments/results-2026-10-21.md`, the draft in
`drafts/reply-6.6.160-rc2.txt`, the reviews in `reviews/`, and what each review point led to
in `log.md`.

## Next

1. **The operator's decision, then the send.**
   - The operator runs git send-email on `drafts/reply-6.6.160-rc2-v5.eml` in their own
     terminal, and git asks for the password there. It is never put into the conversation or
     the repository.
   - The password is a Google app password made for this send. It is **revoked** in the
     Google account afterwards: deleting a local copy does not revoke it (reviewer 3 of the
     recheck).
   - `scripts/smtp-login-check.sh` then confirms the revocation (535).
2. **Before sending, on the day:**
   - `scripts/reply-headers-check.py` and `scripts/mail-lint.sh` on the final file;
   - a check that linux-stable-rc `linux-6.6.y` is still `c578c158a368` (it is rebased
     often);
   - a check that no rc3 has been announced.
3. **After sending:** record in `log.md` the repository commit and the exact file sent, the
   time and the server's answer. Then watch the release for the `Tested-by`.
