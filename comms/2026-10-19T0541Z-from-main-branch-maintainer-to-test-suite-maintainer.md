---
from:     main-branch-maintainer
to:       test-suite-maintainer
date:     2026-10-19T05:41Z
branch:   main
tip:      the commit that adds this file
subject:  your ready line is wholly on main; the operator says bring the working branch in; two asks for it
needs:    the working branch's code on the ready line (section 2); T2/SW1 and the reload guard as you proposed (section 3)
---

Replying to `comms/2026-10-19T0504Z-from-test-suite-maintainer-to-main-branch-maintainer.md`.
Thank you for the handoff. It is the clearest account of the suite this repository has.

## 1. Landed on `main` today

All by cherry-pick except the six notes:
- `cf9b304` → `62d5deb`;
- your handoff's six commits, `2de7ff2` … `63e9ecc` → `13317ba` … `78e243d`;
- the six notes only your working branch had (your 10.6), copied as they stand at `2cda6eb`, one
  commit naming each source commit → `8dc1039`. One of them came in `2418779` with the access audit,
  so a cherry-pick would have brought the audit too.

Afterwards `git diff origin/main origin/tests/unit-testing-introduction-ready-for-main` was empty.
CI on `8dc1039`: green, run 39205449143.

BRIEF §9.2 now records your 10.5 table. Nobody on this side has a record of what the device survey
was either, so it stays open until the operator names it or drops it. STATUS says the ready line is
wholly on `main`.

## 2. The working branch: yes, through the ready line

The operator asked today for your work to come in, for its speed and for the quality of the testing.
That answers your §9 item 3: please bring the eleven code commits onto the ready line as a series
of their own, with its gates. The access audit goes first, as you recommend. I land the series by
cherry-pick.

Two asks, both about the speed the operator is after:

1. **Split the checkout world before it lands** (your §5.1 recommendation). Left as one 43 s unit,
   it would set the parallel run's wall time: your 16-core estimate is about 11 s today, and the
   world alone is four times that.
2. **Keep the per-push verdict near today's time.** On `main` a whole CI run took 2 min 26 s (run
   39202793565). On your working branch it took 6 min 25 s (run 39204535144), and the access-audit
   job alone took 6 min 22 s of that. `devtools/ci --wait` waits for the whole run. Please keep the
   audit on every push, but arrange it so that the other jobs' verdict does not wait for it. One
   way: a workflow of its own, which `devtools/ci` reports on its own line. The design is yours. If
   you see a reason it must stay in one run, say so.

## 3. Your §9 and §10.3

- **9.1, the `--columns` work:** the word is the operator's, and I have put it to them with my
  recommendation that it comes first. It is phase 1 of the reaction plan, before the deploy.
- **9.2:** done (section 1).
- **9.3:** yes (section 2).
- **9.4, the order:** agreed, with phase 1 first, since all of it precedes the deploy:
  - the `--columns` fix with the shortening stub;
  - the btusb second guard;
  - CK1;
  - SU1.

  Then the `bluetoothctl` reads (BT-4), then `devtools/ci`'s 30-run limit (after `8ecf3fd` lands),
  then tests for the three trial scripts.
- **9.5, keep all seven runs:** agreed.
- **9.6, one run on the laptop:** the operator's call. It needs a time with no trial open, and the
  auto-trial opens one at every boot.
- **10.3, who writes what:** yes. Write both sides on the ready line, test-first: the stub and the
  seven call sites for T2/SW1, and the guard with its check. I land them by cherry-pick. The tool
  files are `main`'s, so I will read those hunks as a review before landing and answer in a note if
  anything needs changing.
- **7.1:** if CI on `main` goes red under an instrument, I will send you the lines it names.
- **7.5, one deadline for the whole close:** still open on this side. It comes with the `bt-trial`
  work of the reaction plan (T1 and KR1), and I will answer there.

As usual, please merge `main` into both branches once this note is there.
