# E — what is left to you

**Patch:** `0001-Bluetooth-btusb-Anchor-a-deferred-URB-under-txlock.patch`, on bluetooth-next
`da3cc02587c6` (today's tip; bluetooth's tip `3b069de8a5d6` has the same `btusb_main.c`). It is sent
alone: it applies and builds without A, and with A before or after it, on both tips (`CHECKS.md`).
The code is unchanged from the reviewed version; the message is the reviewers' scope (the
successful-resume race only; the failed-resume path, BT-24, is not mentioned).

**Nothing has been sent.** The send is yours, with your own Signed-off-by.

## Your Signed-off-by

On its own line directly after the `Fixes:` line, before the `---`:

```
Fixes: 7bee549e197c ("Bluetooth: Add USB autosuspend support to btusb driver")
Signed-off-by: <your legal name> <yaroslav.voytovych@gmail.com>
---
Tested with an emulated device ...
```

Something must follow `Fixes:` there: the bot's VerifyFixes flags a `Fixes:` that is the
body's last line ("empty lines surround the Fixes tag"), and passes once the Signed-off-by follows
it (`CHECKS.md`, "VerifyFixes with full history").

If you take `Cc: stable`, it goes between the two: `Fixes:`, then
`Cc: stable@vger.kernel.org`, then your Signed-off-by.

## Decisions

1. **`Cc: stable@vger.kernel.org`, yes or no.**
   - **For:** one outside reviewer sees a plausible stable case once the stress test has passed,
     because E prevents a command hang that was reproduced. The stress test has now passed
     (`CHECKS.md`, "Stress"). The change is 6 lines, and the bug is present since 2009
     (`7bee549e197c`), so every stable line has it.
   - **Against:** the hang was reproduced only with the window widened by a debug-only delay. Without it,
     the unpatched kernel parked nothing in the stress test's 950 normal cycles (about 40,000
     packets) either. Nobody has reported it in the field, and it is not
     BT-17. `stable-kernel-rules.rst` asks for a bug that "bothers people". With `Fixes:` alone,
     the stable team's automatic selection may pick it anyway.
   - **Our reading:** no `Cc: stable`; leave it to the maintainer, who can add it. Either is
     defensible.
2. **The note below the `---`** (how it was tested, two sentences). Optional; `git am` drops it.
   It describes the emulation in words only, with no link, as the precedents do.
3. **Oliver Neukum's address.** `get_maintainer.pl` gives `oliver@neukum.org` (the Fixes: commit's
   author address); MAINTAINERS lists it on two entries today and `oneukum@suse.com` on others.
   Kept as the script prints it.
4. **Order:** the reviews' priority was CO-44, then E, then A. E and A are independent and touch
   different functions.

## What the stress test showed and did not show

- **Showed:** no deadlock, lockdep, KASAN or hung-task report, and no parked packet, over 10 runs
  of 100 cycles on each of the unpatched and the E kernel; with the debug delay, the harness finds
  parked packets on the unpatched kernel and none with E (`CHECKS.md` has the tables).
- **Did not show:** anything about real hardware. kmemleak reports the same small leaks on both
  kernels after the power-offs and disconnects with deferred data: that is BT-25 (registered,
  not E's).

## The dry run

Done 2026-11-14 (`../dry-run-20261114/dry-run-co43-E.txt`): `Result: OK`, the six `RCPT TO`
lines listed in `send-commands.txt`. Run it once more after adding your Signed-off-by, from the
project checkout (its git config carries the SMTP server).
