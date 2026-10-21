# CO-10 — Tested-by on 6.6.160-rc2

**SENT 2026-10-21 03:05:42 UTC** (v6, server 250, 20 recipients; Message-ID
`<20261021030542.1434603-1-yaroslav.voytovych@gmail.com>`; `log.md`). Next: watch the thread
and the 6.6.160 release.

**State before the send:** all eleven BlueZ CI TestRunner suites run on both kernels, with l2cap-tester
stopped where it hangs on both (documented in the results). Draft **version 6** has taken up
four outside reviews and two rechecks, and its sendable copy
(`drafts/reply-6.6.160-rc2-v6.eml`) passes the form and threading checks. **It waits for the
operator's decision** and an app password, revoked after the send. **The deadline is
2026-10-22 07:53:04 UTC.**

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

**No other case that ran on both kernels passes on one and not on the other.** Every mesh
case now has a control verdict. One 6.6.159 run of "Send cancel - 1" failed where rc2 timed
out, which is why the wording is not "same verdict", nor "fail on both". l2cap-tester hangs
at the same case on both kernels.

**No kernel report on rc2,** by a 13-kind scan with a positive control. The QCA9377 entry was
not exercised: there is no hardware on this kernel. It builds.

The details are in `experiments/results-2026-10-21.md`, the draft in
`drafts/reply-6.6.160-rc2.txt`, the reviews in `reviews/`, and what each review point led to
in `log.md`.

## Next

1. **The operator's decision, then the send.**
   - The operator runs, in their own terminal, first with `--dry-run`, then without:

     ```
     git -C /root/exp/qca9377-bt-hang send-email --suppress-cc=self --suppress-cc=body contributions/CO-10-stable-6.6.160-rc2/drafts/reply-6.6.160-rc2-v6.eml
     ```

     git asks for the password there. **Not `--suppress-cc=all`:** it also drops the
     addresses on the file's own `Cc:` lines, and a dry run (2026-10-21 02:50 UTC) showed the
     reply going to Greg alone. With the options above the dry run lists all 20 recipients
     (`RCPT TO`), the `In-Reply-To` and `References` of the announcement, and nothing added
     from the body. It is never put into the conversation or
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
