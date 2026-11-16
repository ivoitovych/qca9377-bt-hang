# CO-21 (SCO alternate setting) - what is left to you

**Patches** (a series of two, on bluetooth-next `da3cc02587c6`, today's tip):
1. `0001-Bluetooth-Keep-the-air-mode-of-SCO-links-that-came-u.patch` (core: `conn->air_mode`, `hci_conn_sco_up_num()`)
2. `0002-Bluetooth-btusb-Pick-the-SCO-alt-setting-from-links-.patch` (btusb: the worker picks the setting from the links that are up; `Fixes: baac6276c0a9`)

Patch 2 needs patch 1 (it calls `hci_conn_sco_up_num()`); send them together, in this order.
Both are the 2026-11-01 patches reviewed and tested on 11-11, rebased from `42b8c2d72926` to the tip
without a conflict; patch 2's subject is shortened (75 to 65 characters, see below); the old
Signed-off-by lines are removed, as for every package here.
**Nothing has been sent.** The send is yours, with your own Signed-off-by (and `git send-email`'s own
dry run from the project checkout, whose git config carries the SMTP server).

## Your Signed-off-by

On its own line directly after the last body line of each patch, before the `---`. For patch 2 that is
right after the `Fixes:` line:

```
Fixes: baac6276c0a9 ("Bluetooth: btusb: handle mSBC audio over USB Endpoints")
Signed-off-by: <your legal name> <yaroslav.voytovych@gmail.com>
---
```

Something must follow `Fixes:` there: the bot's VerifyFixes flags a `Fixes:` that is the last line of the
body ("empty lines surround the Fixes tag") and passes once the Signed-off-by follows it (CO-43 E's
CHECKS.md has the control run).

## Decisions

1. **`Cc: stable@vger.kernel.org`, yes or no.** Patch 1 adds a field to `struct hci_conn` (one byte, in
   the core's header), and patch 2 cannot be built without patch 1. `Fixes:` alone lets the stable team's
   automatic selection pick patch 2, which then does not apply or build without its predecessor, so a
   plain `Cc: stable` on patch 2 alone would be wrong; the form that works is the dependency note,
   `Cc: stable@vger.kernel.org # needs "Bluetooth: Keep the air mode of SCO links that came up"`, and the
   maintainers may prefer to decide that themselves.
   - **For:** the two-link hang-up case is reproducible in emulation and by source reading (the
     remaining link is moved to alternate setting 0, which has no isochronous bandwidth), and the bug is
     present since 2020.
   - **Against:** no field report; on the laptop, 281 pending setups over 68 boots never ran on alt 0
     (README, evidence); the two-link case needs two headsets in a call; the change touches a core struct.
   - **Our reading:** no `Cc: stable`; keep `Fixes:` (it is true and VerifyFixes needs a valid one) and
     let the maintainer add it; say in the cover letter that patch 2 needs patch 1. Either is
     defensible.
2. **Patch 2's subject.** "Bluetooth: btusb: Pick the SCO alt setting from links that are up" (65
   characters). The old one was 75 characters here, and the README's "81 characters" could not be
   reproduced (I could not find the GitLint run it came from; the bot's GitLint on this package is in
   `CHECKS.md`). "alt" is the driver's own word (`alts[]`, `new_alts`). Change it back if you prefer
   the longer title.
3. **A cover letter.** None is in the package; two patches that depend on each other are usually sent
   with one. `cover-letter.txt` is a short draft (facts only, no review history).
4. **Recipients.** `recipients.txt`: the script's output, with the four `blamed_fixes` authors of patch 2
   as Cc (Johan Hedberg, Hsin-Yu Chao, Chethan T N, Amit K Bag). Drop any you do not want to Cc.
5. **Hitalo Souza's series (patchwork 14875454, "6/6").** Pending and `new` on 2026-11-11 (the CO-21
   README; not re-read today). It fixes one of the scenarios the redesign covers, so the redesign does
   not need it; if it is applied first, patch 2's `btusb_notify()` hunk will need a rebase.
6. **Laptop test (optional, your word).** The new field changes the layout of the connection struct, so
   `bluetooth.ko` and `btusb.ko` must be built and installed together (`updates/` + `depmod` + a cold
   boot). Not done.

## What the tests showed and did not show

- **Showed** (`CHECKS.md`): on the rebased tree the five usbip scenarios fail on the unpatched kernel
  (10 of 10 runs) and pass with the series (10 of 10); checkpatch `--strict` clean except the missing
  Signed-off-by; the bot's build checks pass on both sides.
- **Did not show:** anything on real hardware; the emulator is a userspace controller attached over
  usbip, so it exercises btusb and the core's SCO bookkeeping, not the radio or the firmware.
  "Any transparent link wins" when CVSD and transparent links are both up is a chosen rule, not a
  measured fact.
