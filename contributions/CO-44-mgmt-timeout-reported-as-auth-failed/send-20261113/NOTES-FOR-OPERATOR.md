# CO-44 send package: what is left to you

Nothing has been sent. Both mails are ready for your review; the commands are in
`send-commands.txt`, every check in `CHECKS.md`.

## 1. Your Signed-off-by

- **Kernel** (`kernel/0001-…patch`): add one line, `Signed-off-by: <your legal name> <address>`,
  as the last trailer, directly under the `Link:` line and above `---`. The bot's
  VerifySignedoff, CheckPatch and GitLint fail only for its absence (`CHECKS.md`).
- **BlueZ** (`bluez/0001-…patch`): **none.** BlueZ `doc/maintainer-guidelines.rst`: commit
  messages for bluez.git "shall not contain Signed-off-by".

## 2. Cc: stable (undecided)

The patch is packaged **without** it; `cc-stable-variant.txt` is the alternative (one trailer
line added, one below-`---` paragraph removed).

**For:**
- This maintainer took two MGMT status fixes with `Cc: stable` in the last two months:
  `86ef0f58bdec` "Bluetooth: MGMT: Fix status of pending commands flushed on power off" (ours,
  2026-09-29; user-visible 0x00 to 0x0f; it reached 6.12.y, 6.18.y and 7.2.y) and
  `4728474344793` "Bluetooth: MGMT: Fix runtime config status opcode" (2026-11-10). Older:
  `96570ffcca0b8` (2013), a new power-on failure status for user space, also with it.
- The wrong status misleads diagnosis in real reports (prior-art §3: six, two of them the same
  Write Class of Device timeout as ours), which fits "a real bug that bothers people".
- Reviewer 7 calls it a reasonable stable candidate after normal review.
- With `Fixes:` the stable team's automatic selection may pick it up anyway (reviewer 6).

**Against:**
- The two previous changes to this same function went in without it: `65683fbed5c8` RFKILLED
  (`Fixes:` only, into bluetooth.git) and `c0bb764fc0826` ECANCELED (neither tag).
- It changes a value user space sees; the consumer survey (BlueZ, Qt, python-btsocket, bleno,
  the Android HAL, paypal/gatt, the Rust btmgmt crate) is a sample, not a proof.
- Reviewers 2, 6 and 7 recommend no `Cc: stable` at first and asking the maintainer below the
  `---`, which is what the packaged form does.

## 3. The Link: tag (kept; you may drop it)

`Link:` points at Archie Pusaka's 2022 BlueZ patch on lore, whose message says Set Powered
"returns Authentication Failed because disconnection takes too long" — the one lore report that
names the timeout. lore's web answers 403 here; the message was verified in lore's own git
archive and on patchwork (`12951690`, accepted as BlueZ `ede7b9159`). Dropping it changes
nothing else, except that your Signed-off-by then goes directly under `Fixes:`.

## 4. Smaller wording choices

- **Subject:** kept as "Report a timed out command as MGMT_STATUS_TIMEOUT" (ours, reviewer 6).
  Reviewers 2 and 7 proposed "Report command timeouts as MGMT_STATUS_TIMEOUT"; both are accurate.
  If you change it, change the BlueZ message's quote of it too.
- **Below the `---`:** "161510ccf91c gives no reason for the old value; if it was deliberate,
  please say." (reviewer 6's question). Keep or drop.

## 5. The dry runs (2026-11-14): all OK

`dry-run-20261114/`: the kernel mail as packaged, with a Signed-off-by, and with Signed-off-by
plus `Cc: stable`; the BlueZ mail. Each ends `Result: OK`; the RCPT TO lines are the ones listed
in `send-commands.txt` (the stable form adds only `stable@vger.kernel.org`). Run the commands from
the project checkout, whose git config carries the SMTP server.

## 6. Order, on the day

1. Fetch both kernel trees and BlueZ master again; if a tip moved, the package must be
   regenerated and rechecked (`CHECKS.md` names the tips used).
2. Kernel mail first. Keep the Message-ID git send-email prints.
3. Put `https://lore.kernel.org/linux-bluetooth/<that Message-ID>/` in place of
   `@KERNEL_PATCH_LINK@` in the BlueZ mail, open it once lore shows the patch.
4. BlueZ mail the same day (the RFKILLED and EIR name length precedents; the maintainer applied
   the kernel fix minutes before the test). Until the kernel fix is in bluetooth-next, the new
   case would fail every other kernel patch's TestRunner_mgmt-tester, so it must not be applied
   first; its note says it needs the fix.
