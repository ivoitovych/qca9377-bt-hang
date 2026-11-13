# BT-17 patches — open work for outside reviewers, in parallel with ours (2026-11-13)

*Self-contained: every patch, the unpatched code it touches, our checks of seven earlier reviews,
the emulator, its source and its logs are below. Everything is on bluetooth-next
`da3cc02587c6` (2026-11-12), file `drivers/bluetooth/btusb_main.c`, unless a section says
otherwise. Nothing has been sent upstream.*

## 1. Where we are, in one page

**The incident (BT-17).** An idle QCA9377 USB Bluetooth controller (`13d3:3503`, AMD Ryzen
laptop) was runtime-suspended. The next HCI command started a resume that the device never
answered. The USB core's reset-resume failed, the device left the bus, and only a power cycle
brought it back. An emulated device under QEMU (usbip, the real btusb) reproduces the kernel's
side of this step by step. On the way, it found the defects below.

| id | defect | evidence | patch | state |
|---|---|---|---|---|
| BT-21 | `mgmt_errno_status()` reports a command timeout as `MGMT_STATUS_AUTH_FAILED` | laptop log; mgmt-tester case fails before and passes after | CO-44, one line, `Fixes: 161510ccf91c` | ready; five reviews agree |
| BT-23 | `submit_or_queue_tx_urb()` anchors on `deferred` outside `txlock`; a URB can miss the resume | source; emulation with a widened window | E, `Fixes: 7bee549e197c` (verified) | ready |
| BT-20 | `btusb_waker()` swallows a failed resume | source; emulation | A | ready after a rewording |
| BT-19 | `btusb_reset()` blocks the HCI workqueue behind a failing resume, and resets a reset-resumed device twice | laptop log; emulation | B | **wrong as written**: see task T1 |
| BT-18 | after a successful *runtime* reset-resume, btusb (no `reset_resume`) is never resumed or rebound: Bluetooth stays dead | emulation | D, a btusb-side `reset_resume` | **not as a fix**: see task T2 |
| BT-24 | `btusb_resume()`'s `failed:` path scuttles `deferred` outside `txlock` | source | none | see task T3 |
| (C) | QCA9377 on Ryzen: `BTUSB_WAKEUP_BROKEN`, as `dcaf83ead130` did for MT7922/MT7925 | one occurrence | C | RFC at most |

**New since the earlier reviews (all in section 4 below):**
- **B leaves Bluetooth dead in one case, shown in emulation.** A controller receives a command
  (the USB transfer completes), never answers it, and needs a USB reset to come back. The device
  autosuspends before the 2 s command timeout.
  - **Unpatched:** `btusb_reset()` resets it and Bluetooth works, 3 of 3.
  - **With B:** B skips the reset, 6 of 6, and nothing ever resets it again.
  - **Why nothing does:** the power cycle's HCI Resets fail with `-110`, and `hci_cmd_work()`
    does not arm the command timer while `HCI_RESET` is set (`hci_core.c:4351-4353`).
- **D's queued reset can be lost.** `usb_lock_device_for_reset()` refuses a suspended device,
  and D holds no PM reference. With the callback present, the core also stops setting
  `needs_binding` (reviewer 7, checked from the source).
- **`-EACCES` cannot be mapped to one MGMT status.** `bt_to_errno()` maps both HCI 0x05 and
  0x18 to it, and the HCI-status table maps them differently. CO-44 stays one line.

## 2. The tasks

Pick any. Each can be done from this document alone. The earlier findings are in section 4;
please don't redo them, unless you think one is wrong. Then say so.

### T1 — A correct replacement for patch B (BT-19)

Design a change to `btusb_reset()`, or to how `hci_cmd_timeout()` reaches it, that meets all
four requirements:
- **(a)** it does not block the ordered HCI workqueue behind a runtime resume that the device
  never answers (the BT-17 case: 5.3 s on the laptop);
- **(b)** it still resets a controller that **received** the timed-out command and needs a
  reset, even when the device autosuspended before the timeout (the `dropcmd-wedge` case, where
  B fails);
- **(c)** it does not reset a device twice when the core's reset-resume already reset it and the
  rebinding follows (the `recover` case);
- **(d)** it is not racy: `pm_runtime_active()` is a snapshot that can only be trusted under the
  PM lock, and it is true while runtime PM is disabled.

Questions:
- **The test.** Is "the timed-out command is still on `data->deferred`"
  (`!usb_anchor_empty(&data->deferred)` under `txlock`) the right one for "it never reached
  the controller"? Can a URB be in flight, neither deferred nor completed, while the device
  suspends?
- **The mechanism.** Should the reset be handed to a work item outside `hdev->workqueue`, which
  may then wait for the resume? Or should B use `pm_runtime_get_if_active()`? Or
  `usb_autopm_get_interface_async()`?
- **The credit.** `hci_cmd_timeout()` restores the command credit only after `hdev->reset()`
  returns. Does your design change when the queued commands are sent, and is that acceptable?
- **The cost.** In the BT-17 case each queued command then times out on its own, three
  `tx timeout` lines instead of one blocked one. Is that acceptable to the Bluetooth
  maintainers, in your reading?

Please answer with a sketch of the code, and the failure cases you checked it against.

### T2 — The BT-18 question for the USB maintainers

The USB core reset-resumes a device whose runtime resume failed (persist). btusb has no
`reset_resume`, so `usb_resume_interface()` sets `needs_binding`. But only a system resume
(`usb_resume_complete()` → `rebind_marked_interfaces()`) or `usb_reset_device()` acts on it, not
a runtime resume. btusb stays bound, never resumed, with `BTUSB_SUSPENDING` set.

Questions:
- **Intent.** Is this asymmetry intended, and why? `autosuspend_check()` refuses autosuspend for
  `USB_QUIRK_RESET_RESUME` devices whose driver lacks `reset_resume`. Is that gate the core's
  answer, which a reset-resume that persist forces after a *failed* runtime resume bypasses?
- **The fix.** What should the core do after a runtime reset-resume of an interface marked
  `needs_binding`? A deferred unbind and rebind (a work item, as `usb_queue_reset_device()`
  uses), failing the resume, or something else? What are the locking constraints in the runtime
  resume path that rule out doing it inline?
- **Or btusb.** Should btusb instead get a real `reset_resume`? It would re-run the vendor setup
  (firmware download for QCA ROME) with HCI traffic held until then, and hold a PM reference
  until the work is done. Reviewer 7 lists why patch D is not that.
- **The mail.** Please draft the question as it should go to linux-usb (and linux-bluetooth?).
  Keep it short, with the facts a maintainer needs and nothing about our process. The emulation
  log excerpt for `close-recover` (section 6) is the reproduction.

### T3 — BT-24, and a suspected leak on the same paths

- **BT-24.** `btusb_resume()`'s `failed:` path calls `usb_scuttle_anchored_urbs(&data->deferred)`
  without `txlock`, then clears `BTUSB_SUSPENDING` under it. A sender in between still sees the
  flag and anchors a URB that nothing sends. Is that right? Can it happen in practice: what makes
  the interrupt or bulk URB submission fail at resume?
- **A suspected leak, ours, from the source; not yet checked by test.** Is it right?
  - A deferred URB owns:
    - its skb (`urb->context`), freed only in `btusb_tx_complete()`;
    - for a command, its setup packet (`dr` in `alloc_ctrl_urb()`), freed in
      `btusb_tx_complete()` and in `play_deferred()`'s cleanup loop.
  - `usb_scuttle_anchored_urbs()` only unanchors and drops the anchor's reference (`urb.c`). So
    the two scuttles of `deferred`, in `btusb_close()` and in `btusb_resume()`'s `failed:`, appear
    to free neither the skb nor the setup packet.
  - `play_deferred()`'s cleanup loop frees the setup packet but not the skb.
- **The fix.** If both hold, propose one fix for both: drain `deferred` under `txlock` with the
  same cleanup as `play_deferred()`, plus the skb. Mind the context: `kfree_skb()` with interrupts
  disabled, so `dev_kfree_skb_any()`. And should the commands be completed with an error rather
  than dropped silently?

### T4 — No USB-level recovery while an HCI Reset is pending

`hci_cmd_work()` does not arm `cmd_timer` while `HCI_RESET` is set (`hci_core.c:4351-4353`).
So when a controller stops answering and the next command is an HCI Reset (power-on,
`hci_dev_open`), `hci_cmd_timeout()` and `hdev->reset()` are never called. The sync request
fails `-110`, and Bluetooth stays dead until the device is unplugged or the machine rebooted.
Even the unpatched kernel does not recover such a controller.

Questions:
- Is that intended? Why is the timer not armed for HCI Reset?
- Should a failed HCI Reset at power-on reach `hdev->reset` (the driver's recovery)?
- Is there a precedent or a discussion on linux-bluetooth?

This is a question, not a defect claim yet.

### T5 — Prior art and history (independent of our own search)

We are searching too. Independent results catch what one search misses.
- **CO-44:**
  - the review thread of `161510ccf91c` ("Bluetooth: hci_sync: Make use of
    hci_cmd_sync_queue set 1", 2021-10), and any reason given for `-ETIMEDOUT →
    MGMT_STATUS_AUTH_FAILED`;
  - later or pending patches to `mgmt_errno_status()`;
  - user reports of "Authentication Failed (0x05)" for power, mode, UUID or class operations;
  - MGMT socket users outside bluetoothd that branch on 0x05 or 0x08.
- **CO-43:**
  - why btusb has no `reset_resume`, and the intent of Realtek's `udev->reset_resume = 1`
    (rebind after a system resume) and of `btusb_needs_reset_resume_table`;
  - linux-usb discussions of rebinding after a runtime reset-resume;
  - reports of btusb devices dead after an autosuspend or runtime resume (QCA, others);
  - pending patches touching `btusb_reset`, `btusb_waker`, `play_deferred`,
    `submit_or_queue_tx_urb` or `BTUSB_SUSPENDING`.
- **Rules:** linux-usb's expectations for a question or RFC versus a patch, and for a question
  spanning two subsystems.

For each, give a URL or commit id. When nothing is found, say where and what you searched.

### T6 — Final wording

Propose the final commit message text for:
- **A:** the `-EACCES` comment must not claim system sleep only, nor that `btusb_resume()`
  always drains the data. The message's "nothing that said the resume had failed" overstates:
  there is `Failed usb_autopm_get_interface: -16` at the disconnect.
- **E:** its message, scoped to the successful-resume race; BT-24 is separate.
- **CO-44:** the message, and a short note below the `---`. The note says that the patch makes
  the errno path agree with the HCI-status table (0x08, 0x10 and no answer are all `TIMEOUT`
  there), and that the MGMT status of a timed-out command changes from 0x05 to 0x08.
  `Cc: stable` or not: give your reasoning.
- **C, if it is ever posted:** the GET_STATUS failure is inferred from the source and
  reproduced in emulation, not logged on the laptop. The subject "Disable runtime suspend"
  overstates what `BTUSB_WAKEUP_BROKEN` does.

Kernel style: plain, factual, no review history, no process.

### T7 — The emulator: what it can prove, and the tests still missing

The emulator and harness are in section 5, in full.
- **The reset signal.** `--wedge-until-reset` takes a SET_CONFIGURATION, seen while the
  emulator is wedged, as the sign of a USB reset. vhci handles the port reset and SET_ADDRESS
  itself, and a plain resume sends only GET_STATUS and CLEAR_FEATURE. Is that a sound signal?
  What could fake it, or hide it?
- **The missing modes.** Design, or better write, these modes:
  - **(a)** the reset work delayed past an autosuspend (D's lost reset);
  - **(b)** a reset that clears the controller's patch and NVM state, with `QCA_CHECK_STATUS`
    reporting not loaded, so that the rebind must download again (D's early traffic);
  - **(c)** a deferred send racing a failed interrupt or bulk URB submission at resume (BT-24);
  - **(d)** a kmemleak run for T3's suspected leak.
- **System suspend.** vhci refuses system suspend with a device attached, and a raw-gadget
  emulator cannot take part in a system resume. Is there any other way to test D's
  system-resume path, short of real hardware?

## 3. How to answer

- **Findings:** give each one a severity (blocker, should-fix, nit or question), a file and
  line on `da3cc0258`, and a short reason. Say whether it is from the source or from a run.
- **Code:** give it as a diff against `da3cc0258` or against the patch it replaces.
- **Uncertain points:** say "not sure" where you are. That is more useful to us than a
  confident guess.
