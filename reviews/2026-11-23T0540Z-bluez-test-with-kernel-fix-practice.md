# When a BlueZ tester case for a kernel fix is posted: the practice (2026-11-23)

**Question** (the operator, 2026-11-23): when a kernel Bluetooth fix comes with a regression test
in BlueZ's testers, do contributors post the test with the kernel patch, or after the kernel fix
is applied?

**Method.**
- **Sources.** BlueZ `origin/master` and bluetooth-next history (`cache/bluez-upstream`,
  `cache/linux`); patchwork posting dates (UTC); the linux-bluetooth lore archive
  (`cache/lore-linux-bluetooth-0.git`).
- **Sample.** Tester commits since 2025-11, matched to their kernel commits: 11 pairs, 4 by
  contributors who are not maintainers, 4 by the maintainer, 3 of ours.
- **Limits.** A read-only survey. The lore archive was searched by subject, not full text.

## The pairs

| kernel fix (posted → applied) | BlueZ test (posted → applied) | order | how the test names the fix |
|---|---|---|---|
| "MGMT: Return RFKILLED for Set Powered on a blocked controller", T. Wilken (pw 14904618; 10-21 → 10-23) | "mgmt-tester: Add Set Powered test for rfkill block" (pw 14904693, `1445a64e6`; 10-21, 23 min later → 10-23, 9 min after the kernel) | same day, own thread | subject, and the culprit commit id |
| "hci_event: Find the owner of a terminated adv set" + 3, W. Guan (pw 14973063; 11-11 → 11-11) | "mgmt-tester: Add single advertising set tests" (pw 14974679, `923d95d0c`; 11-12 → 11-16) | after the kernel was applied (7 h) | the four commit ids |
| BT-9 stable backports of `96d006ae6445`, ours (10-10) | "mgmt-tester: Add simultaneous discovery stop tests", ours (pw 14878780–82; 10-10, 53 min later → 10-12) | same day, own thread | the commit id and subject |
| "hci_sync: scan unfiltered for host-resolved RPAs", K. Pepper (v2 pw 14887538; 10-14 → 10-14) | "mgmt-tester: Add host-resolved RPA scan checks" (pw 14887539, `dd9d5ba1f`; 10-14, 4 min later → applied 5 h **before** the kernel) | same day; "intentionally fail on an unfixed kernel" | below `---` only |
| "MGMT: Fix advertising instances with Global Advertising", the maintainer (pw 14868262) | "mgmt-tester: Add Global Advertising tests …", the maintainer (pw 14868264, `f8f352d13`; applied 9 days **before** the kernel) | the same minute | none |
| "MGMT: Add management security level changed event", F. Danis (v9 pw 14861280, 10-01) | "mgmt-tester: Add Security Level Changed event tests" (pw 14855132, `74334ac97`; applied 13 days before the kernel) | the test with the feature still in review | none |
| "L2CAP: fix out-of-bounds write in l2cap_ecred_connect", P. Virtanen (pw 14775028; 08-29 → 08-31) | "tools/l2cap-tester: add test for too many ECRED deferred sockets" (pw 14775027, `0b66bd533`; 1 min before → applied 55 min before the kernel) | the same minute | "on some kernels" |
| "L2CAP: hold conn->lock for __l2cap_ecred_conn_rsp_defer", P. Virtanen (pw 14774785; 08-29 → 10-14) | "tools/l2cap-tester: test closing sockets with ECRED defer" (`e9b6ee380`; 08-30/09-01 → applied 27 days before the kernel) | 1–3 days later | "on some kernels" |
| "L2CAP: fix chan mode for LE_CONN_REQ + EXT_FLOWCTL pchan", P. Virtanen (`4ef05db5b08b1`) | "tools/l2cap-server: add test for invalid Conn Req …" (`3a2d543c4`; applied 50 min before the kernel) | the same day (author dates) | "on some kernels" |
| Shorter Connection Interval, the maintainer (3 patches, committed 08-07) | "mgmt-tester: Add tests for SCI setting …" (`46f08703a` + 3; committed 07-30) | the tests first (commit order) | none |
| CO-02 "[PATCH 0/3] hci_conn: fix SCO connection reuse", ours (10-27, not applied) | "tools/sco-tester: Add SCO reconnect tests", ours (10-27, 50 s later; not applied) | same day, own thread | a lore link, "apply after the series is in bluetooth-next" |

## What it shows

- **Timing.** The test is posted the same day as the kernel patch, minutes to a day later, in its
  own BlueZ thread, never as a reply or in the same series. That is 7 of 11 pairs, and in 2 more
  the test follows a kernel fix already applied.
- **Order of application.** BlueZ often applies the test **before** the kernel fix: in 7 pairs, by
  5 hours to 27 days. A test that fails on unfixed kernels is common. One contributor said so
  outright ("intentionally fail on an unfixed kernel"), and nobody objected.
- **The maintainer.** In one kernel thread (Kyle Pepper's v1, 2026-10-13) he asked the
  contributor for an mgmt-tester case to confirm the fix. No objection by a maintainer to a test
  that fails on current kernels was found.
- **Naming the fix.** Three pairs give the kernel commit id or subject. Three say "on some
  kernels". Four say nothing, and one names it below `---` only.
- **Guidelines.** BlueZ's `doc/maintainer-guidelines.rst` and `HACKING` say nothing about test
  ordering or kernel dependencies.

One cost noted in our own records, not in the guidelines: the kernel patches' CI runs
mgmt-tester from BlueZ master. So a new case that needs an unapplied kernel fix fails on other
people's kernel CI runs until the fix lands. The practice above accepts that.

## For our packages

CO-44 and CO-38 follow the practice:
- the kernel patch is mailed first;
- the BlueZ test goes the same day as its own BlueZ mail;
- it names the kernel patch by subject and lore link, and by commit id once it is applied.

CO-44's prepared form (`send-20261113/send-commands.txt`, STEP 2a/2b) already does this, and
CO-38's will do the same. Waiting for the kernel fix to be applied is also within practice, but
it is the less common choice.

## Addendum 2026-11-26 (an outside reviewer's research, checked here)

- **The maintainer does it himself.** On 2026-11-25 Luiz Augusto von Dentz posted "[PATCH BlueZ v4 0/6] Add tests
  for security of deferred setup" (linux-bluetooth, 2026-11-25 21:12 UTC). It is a BlueZ test series
  for his own kernel series, which is still in review. The cover letter lists five tests that "depend on the kernel
  series … and fail without it" (read in `cache/lore-linux-bluetooth-0.git`).
- **Posting a tester case does not gate BlueZ.** BlueZ `bed6e3602` (Luiz Augusto von Dentz, 2026-09-08), "test:
  functional: exclude kernel testers from make check": "they exercise the kernel rather than BlueZ userspace and
  should not gate a userspace release".
- **Where a failing case does show:** only in the kernel CI's mgmt-tester run, which uses BlueZ master. So it shows
  only once the test is applied, and only until the fix is in the tree that CI tests.
  - Wilken's pair: the kernel fix was applied to bluetooth-next first and the test about 10 minutes later.
  - Kyle Pepper's pair: the test was applied the same day as the kernel fix, `dd9d5ba1f`. The reviewer's "remained
    unapplied" is wrong; its CI pull request was closed, which is not a rejection.
- **Kernel-tree rules.** In-tree tests go in the same series (`5.Posting.rst`; netdev's "Co-posting selftests"),
  and netdev asks that a test not land in a tree before its fix. A BlueZ tester case is a separate repository, so
  the netdev model is separate threads that point at each other.
- **Conclusion for CO-38's test.** Posting it now, as its own BlueZ mail that names the kernel patch and asks for
  application after the fix, matches what the maintainer himself does. When to apply it is the maintainer's call,
  and the note tells him when it will pass.
