# BT-17 open work — reviewer 3's answer, and our checks (2026-11-14)

Reviewer 3 answered the task document of 2026-11-13 17:40 UTC
(`2026-11-13T1740Z-bt17-open-work-for-outside-reviewers.md`) with the other reviewers. The answer
was not stored or checked on 11-13 with the answers of reviewers 1, 2, 6 and 7
(`2026-11-13T1750Z-bt17-open-work-answers-checks.md`). It is now stored as
`2026-11-13T1740Z-bt17-open-work-answer-reviewer-3-verbatim.md`. The other four stored answers were
compared with the operator's file of all answers on 11-14 and are complete; the only differences
are the tooling marks that `scripts/review-text-clean.py` removes.

Since the answer arrived, the 11-14 btusb series (`contributions/CO-43-…/send-series-20261114/`,
patches 1 to 5) was built from the other answers. Each point below is weighed against that
series as well as the 11-13 package.

## 1. A regression in patch 3 of the 11-14 series, found by following R3's T2 point

R3 recalls that `.reset_resume = btusb_resume` was added in 2013 (`502f76966297`, Shuah Khan)
and reverted (`b1a8014471b0`, Hans de Goede, 2013-09-28). Some devices come back from a USB reset
in another mode and need re-enumeration, so btusb is meant to have no `reset_resume` and be
rebound. Both commits are verified in `cache/linux`, and our BT-18 question draft already cites
the revert.

**What R3 did not say, and we checked:** patch 3, "Bluetooth: btusb: Recover after a runtime
reset-resume", adds exactly such a callback. Its message says the system-resume path "is meant to
stay as it is". In the source, it does not:
- `usb_resume_interface()` (`drivers/usb/core/driver.c` on `cache/linux` HEAD, lines 1361 to
  1371) calls `driver->reset_resume()` when the driver has one. Only when it has none does it set
  `intf->needs_binding`, which makes `usb_resume_complete()` unbind and rebind the interface after
  a system resume.
- With patch 3, a reset-resume during a **system** resume therefore runs `btusb_reset_resume()`.
  That calls `btusb_resume()` and queues nothing, because the check for an active runtime resume
  is false. There is no rebind and no new controller setup: this is the 2013 behaviour that was
  reverted.
- **Who is affected for certain:** btusb's own `btusb_needs_reset_resume_table` (`btusb.c:858`).
  It sets `USB_QUIRK_RESET_RESUME` for QCA ROME devices on three Dell models because "the
  platform (likely shutting off all power)". On those, every system resume is a reset-resume.
  Today the rebind reloads the rampatch and NVM. With patch 3 btusb would only resume, on a
  controller that has lost its firmware [inference from source; not run].
- **The wider group: Realtek.** `btusb_suspend()` (`btusb.c:4515` to `4528`) sets
  `udev->reset_resume = 1` on a system suspend with wakeup disabled for `BTUSB_WAKEUP_AUTOSUSPEND`
  devices. Its comment explains why: "For global suspend, Realtek devices lose the loaded fw".
  Today the missing callback makes the core rebind them, and the rebind downloads the firmware
  again. With patch 3 they would only be resumed, without firmware, after every such suspend
  [inference from source; not run]. `contributions/CO-43-…/README.md` "Open before any send"
  item 1 already lists both groups for D v1. It assumed they keep their rebinding ("one USB reset
  more, before a rebinding they already got"); with a callback they lose it.
- Any device whose ordinary system resume fails and falls back to reset-resume under persist is
  affected the same way.
- **A second change:** `autosuspend_check()` (`driver.c:1958` to `1965`) refuses runtime suspend
  for a `USB_QUIRK_RESET_RESUME` device whose driver lacks `reset_resume`. With patch 3 those Dell
  devices may autosuspend when no remote wakeup is needed. Each runtime resume is then a
  reset-resume, and patch 3 queues a reset and a rebind every time [source].

**Consequence:** patch 3 must not go out as it is. Item 11 of the review document is marked
accordingly. Two ways forward, which are for the operator to choose:
- (a) R3's advice and reviewer 7's: send the BT-18 question to linux-usb first, and hold patch 3.
- (b) Keep the callback and mirror the core's path on a system resume: set `needs_binding`
  there and return 0. That touches USB-core state from a driver, and the emulated device cannot
  test a system sleep.

Patch 2 says it depends on patch 3, so it is held with it.

## 2. T1: a send gate, against patch 2's "each command times out on its own"

- **Patch 2 (B2) accepts it:** while the device resumes, each queued command times out on its
  own, about two seconds apart.
- **R3 rejects it** ("I would not deliberately accept three successive two-second timeouts").
  They propose a recovery-pending bit: `btusb_send_frame()` fails fast while it is set, and the
  recovery work clears it. The precedent cited is `btintel_pcie`'s recovery-in-progress state,
  not checked here.
- Not weighed before; added to CO-43's open points.

## 3. T1: a timed-out command may be sent late

R3 points out that a command still on the deferred anchor when its HCI timeout fires is replayed
when the resume eventually succeeds. The HCI core has given up on it by then.
- Not checked in the emulator.
- The mechanism follows from patch 2: `btusb_reset()` returns at once for a deferred command, and
  `play_deferred()` later submits it.
- Recorded as a research item for CO-43: an emulator mode that resumes late, and a check for an
  unexpected Command Complete in the log.

## 4. T4: R2's unverified claim is verified

Reviewer 2 said older HCI-core code documents that recovery is avoided during initialization.
The 11-13 checks marked that "unverified, not used". R3 gives the source:
- `net/bluetooth/hci_core.c:1492` to `1494` on `cache/linux`: "During HCI_INIT phase no events can
  be injected if the ncmd timer triggers since the procedure has its own timeout handling."
- Verified.
- The commit that added it was not found, because the clone is shallow.

R3's question for the maintainers matches R2's proposal: whether a failed `hci_dev_open_sync()`
Reset should call `hdev->reset` after it fails, rather than arming the command timer during
`HCI_RESET`.

## 5. Facts checked, and hashes that are not what they seem

- `7bee549e197c` (Oliver Neukum, 2009) added `btusb_waker()` with its silent return on a failed
  `usb_autopm_get_interface()` (verified in `git show`). E already carries it as `Fixes:`. R3
  suggests it for A (patch 1) too, which has none. A choice for the operator.
- **These hashes in R3's links are tree revisions of the web pages linked, not the commits
  described:** `53492a668e3b`, `5d144c294ae2`, `7bcf809b1e78`, `55cee73e2af5`. Locally they are an
  unrelated btintel commit, a sound merge, a CXL commit and an L2CAP commit.
  - So R3's account of 2018 is not verified: QCA reset-resume handling moved to the USB core,
    later narrowed by DMI. Only the DMI table itself is confirmed (`btusb.c:858`).
- `65683fbed5c8` (CO-44's precedent) and `c93922dd316b` (the PM reference in `btusb_reset()`) were
  already in CO-44's and CO-43's prior art.

## 6. Points already taken up, from R3 or from others

- **T3:**
  - one free helper used at every discard site;
  - drain and clear under one `txlock` section;
  - `dev_kfree_skb_any()`;
  - no error completion in the same patch.
  
  All of these are in patches 4 and 5 of the 11-14 series. kmemleak was run as validation.
- **CO-44:**
  - the one-line form and no `-EACCES` are kept;
  - R3's test refinement (that the Write Class of Device hook fired) is in CO-44's `CHECKS.md`
    ("the hook fired once in the whole run").
- **CO-44 `Cc: stable`:** R3 is for it and reviewer 1 against. The package's NOTES list the
  arguments, and the decision stays the operator's. Added to the NOTES' "For" list: R3 cites the
  stable rules, which say a `Fixes:` tag does not replace the stable Cc.
- **T7, the emulator:**
  - "saw post-reset reconfiguration" rather than "saw a reset" (reviewer 1 suggests pairing it
    with the descriptor read);
  - firmware-loaded state cleared at reset (reviewer 7 too);
  - fault injection in btusb for BT-24.
  
  All three are open emulator items for CO-43.
- **C:** R3's subject, "Avoid QCA9377 runtime suspend on Ryzen while wakeup is needed", and an
  RFC-only body. That is the same position as the package.
