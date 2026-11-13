# BT-17 patches — outside reviewer 7's review of the intermediate document

*Received 2026-11-13 in answer to `2026-11-13T1100Z-bt17-patches-intermediate-review.md`. The text
is kept as received, except for the reviewer's tooling marks, which `scripts/review-text-clean.py`
removes. What we checked, finding by finding, and the plan that follows are in
`2026-11-13T1600Z-bt17-patches-reviews-checks-and-plan.md`.*

---

**I would send patch E and CO-44 independently, send A after a wording correction, and hold B and D for revision.** C is suitable only as a clearly qualified RFC.

I checked the patches against the actual sources at bluetooth-next `da3cc02587c629420603df4395179ec82955c941` and BlueZ `20ffd285b58facfd1f2478d159a5f941b09d5be1`, including USB core, runtime PM, the emulator and test harness. **I did not rerun QEMU or CI.** The counterexamples below are source-derived unless stated otherwise.

| Patch | Assessment |
|---|---|
| **1 — A: resume-error logging** | Ready after a comment/message correction |
| **2 — B: skip reset while suspended** | **Blocker:** can suppress recovery of a command that reached the controller |
| **3 — D: reset-resume recovery** | **Blocker:** recovery depends on queued work that can abandon the reset |
| **4 — E: anchor under `txlock`** | Correct for the demonstrated normal-resume race; send independently |
| **5 — C: Ryzen/QCA workaround** | RFC only; hardware cause remains unconfirmed |
| **CO-44 kernel mapping** | Correct; proposed `Fixes:` verified |
| **CO-44 BlueZ test** | Appropriate regression test; no blocker found |

**1. Patch B — blocker: `BTUSB_SUSPENDING` does not prove that the timed-out command was deferred.**

There is a concrete counterexample:

1. btusb submits a command while active.
2. Its USB transfer completes successfully, but the controller never produces the HCI response.
3. With a sufficiently short autosuspend delay, the device autosuspends before the HCI command timeout.
4. The timeout calls `btusb_reset()`.
5. B sees `BTUSB_SUSPENDING` and a non-active interface, and returns without recovery.

The critical distinction is that `btusb_tx_complete()` decrements `tx_in_flight` when the **USB transfer** completes. It does not wait for the corresponding HCI response. `btusb_suspend()` therefore has no outstanding-transfer reason to reject autosuspend in this case.

There need not be any deferred URB or scheduled waker. The existing reset path would resume the device and request recovery; B suppresses that action.

This invalidates the patch’s central explanation that the timed-out command necessarily never reached the controller. It is more substantial than the acknowledged last-line wording issue. [Source: TX completion and suspend logic](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/drivers/bluetooth/btusb_main.c#L2072).

**Required test:** accept and complete the command’s USB transfer, suppress only its HCI response, and use an autosuspend delay shorter than the HCI timeout. The existing `--hold-hci` behavior, which holds the USB transfer itself, does not reproduce this case.

**2. Patch B — should-fix: the PM predicate is neither a reliable snapshot nor a nonblocking guarantee.**

At this exact revision, `pm_runtime_active()` means:

```c
runtime_status == RPM_ACTIVE || disable_depth
```

Its documentation explicitly says the result can only be trusted under the device’s runtime-PM lock or equivalent conditions preventing state changes. B has neither. [Source](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/include/linux/pm_runtime.h#L156).

Consequences:

- Runtime PM being disabled can satisfy the predicate even when the interface is not actually active.
- An active observation does not prevent a subsequent suspend before `usb_autopm_get_interface()`.
- `BTUSB_SUSPENDING` can already be cleared by the driver’s resume callback while the surrounding PM resume is still finishing. The guard then permits a synchronous PM call.

The subsequent call can wait for an ongoing suspend/resume or resume the parent device. Therefore, “does not block the HCI workqueue” is too strong; B avoids the particular observed wait, not all such waits. [Source: `rpm_resume()`](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/drivers/base/power/runtime.c#L787).

Merely locking around the predicate would not solve the check/use race after unlocking. Nor should the PM spinlock be held across the synchronous call. Recovery needs an explicit ownership and scheduling design, together with a distinction between deferred and already-transmitted commands.

**3. Patch D — blocker: queueing a reset does not guarantee that recovery happens.**

`usb_queue_reset_device()` retains an **interface object reference**, but it does not acquire a runtime-PM usage reference.

The worker calls `usb_lock_device_for_reset()`, which can reject the reset because:

- the device has become suspended;
- the device lock could not be acquired within approximately one second;
- the interface is unbinding/unbound or the device disconnected.

On failure, the worker simply drops its reference. There is no retry or recovery notification. [Reset worker](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/drivers/usb/core/message.c#L1962), [locking helper](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/drivers/usb/core/usb.c#L895).

For D, the problematic case is **a still-present device that autosuspends before the worker runs**. Unlike the existing `btusb_reset()`, D does not retain a PM reference until disconnect.

Furthermore, supplying `.reset_resume` prevents the USB core’s missing-callback path from setting `needs_binding`. Consequently, D replaces the previous system-resume rebind mechanism with a reset request that can disappear without performing that rebind.

Queueing from the callback is not inherently an object-lifetime error: the interface reference and disconnect checks address that aspect. **The unresolved issue is recovery completion.** D needs to prevent premature autosuspend and define what happens when the queued reset cannot acquire the device lock.

**4. Patch D — should-fix: ordinary traffic resumes before reset recovery is complete.**

`btusb_resume()` can restart receive URBs, invoke vendor resume handling, replay deferred transmissions and clear `BTUSB_SUSPENDING`. D does this before the queued reset has unbound and reinitialized the controller.

That assumes enough controller state survived to permit ordinary operation. Yet loss of that state is the patch’s reason for requesting a rebind. The USB documentation specifically requires reset-resume handling to redo necessary initialization. [Source](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/Documentation/driver-api/usb/power-management.rst#L315).

The emulator cannot validate this assumption: it always reports patch/NVM already loaded and does not model loss of meaningful controller configuration.

I would keep normal HCI traffic quiescent until the chosen recovery mechanism has restored state.

Also, **do not “fix” the unconditional reset queue simply by returning when `btusb_resume()` fails**. In this tree, `usb_resume_both()` ignores individual interface-resume return values; the error is logged, but it does not automatically trigger rebinding. Removing the queued recovery could leave the device stranded. [Source](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/drivers/usb/core/driver.c#L1544).

I favor investigating deferred rebinding in USB core, where the runtime/system PM message is available. That needs careful implementation outside the problematic callback context; simply adding synchronous rebinding inside `usb_runtime_resume()` is not a safe prescription.

**5. Patch E — no blocker found; its guarantee should remain scoped to successful resume.**

Moving `usb_anchor_urb()` inside `txlock` is sound:

- anchoring takes a spinlock and an URB reference; it does not sleep;
- the lock order matches the existing `play_deferred()` path;
- the enqueue decision and normal resume’s drain/flag-clear become mutually exclusive.

The original URB reference also keeps the object alive if resume drains it before the submitting thread reaches `usb_free_urb()`. [Anchor implementation](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/drivers/usb/core/urb.c#L126).

There is a separate, pre-existing error-path gap worth testing: `btusb_resume()`’s `failed:` path scuttles deferred URBs **outside** `txlock`, then acquires the lock to clear `BTUSB_SUSPENDING`. A concurrent sender can anchor between those operations.

That does not invalidate E’s fix for normal resume. It means “every URB exactly once” should not be presented as a guarantee covering all failure paths. Add an enqueue race with failed interrupt/bulk receive-URB submission.

**6. Emulation and harness — should-fix: strengthen the recovery assertions before using the matrix as acceptance evidence.**

Three specific limitations matter:

- **`--recover` recovers on cancellation, not reset.** `Emu.unlink()` changes the controller to healthy when a held request is unlinked. It does not observe a USB reset. This exercises the host’s reset-resume path, but cannot establish reset-dependent hardware recovery.
- **The command-triggered recovery scenario does not verify usable Bluetooth afterwards.** It checks for `hci0` returning, but does not require successful power-on and a subsequent command. Its `RESULT` line does not even include the `back` result.
- **Failures need not produce failing process status.** Scenario exceptions are logged and swallowed; false results do not cause failure exits. `run-guest.sh` records the runner’s status but finishes with `grep`, and the matrix continues without enforcing scenario success.

These do not negate the recorded traces. They weaken claims that the matrix automatically establishes successful recovery. [Emulator and harness](https://github.com/ivoitovych/qca9377-bt-hang/tree/0a17a7b785cb525b2cbea753826d58079b0f0095/results/bt17-emulation-2026-11-13/harness).

The highest-value additions are:

| Test | What it resolves |
|---|---|
| USB-completed command, missing HCI response, early autosuspend | B’s false classification |
| Delay reset work until after autosuspend | D’s lost recovery |
| Reset with firmware/configuration state lost | D’s premature traffic restart |
| Receive-URB submission failure racing deferred enqueue | Remaining resume error-path race |
| System reset-resume, including a device already runtime-suspended before sleep | D’s wider regression risk |
| Successful power-on **and** answered command after every recovery | Functional recovery, beyond index appearance |

The vhci tests remain useful evidence for kernel control flow. They do not establish AMD xHCI behavior, actual remote-wakeup signaling, firmware retention, or the physical cause of BT-17.

**7. Patches A and C — wording and evidence.**

**A — nit:** ignoring `-EACCES` is reasonable for expected runtime-PM-disabled transitions, but the comment should say it **can occur during** system sleep. `-EACCES` means runtime PM is disabled in the relevant PM path; it does not uniquely identify system sleep or guarantee that `btusb_resume()` will later drain the data. The error log level is reasonable for this exceptional failure.

**C — should-fix before any merge:** the condition implements the intended workaround while the HCI device requires remote wakeup; it does not disable every possible runtime suspend. One incident plus similar MediaTek symptoms does not establish a shared hardware cause.

An RFC is reasonable now if its purpose is to ask maintainers for corroboration and discuss the workaround. Describe the GET_STATUS/reset-resume explanation as strongly supported by source and emulation, but not directly captured on the laptop. Keep C separate from the demonstrated software fixes.

**8. CO-44 — no blocker found; the `Fixes:` tag is correct.**

I checked commit [`161510ccf91c`](https://github.com/bluez/bluetooth-next/commit/161510ccf91c961638940b03abb1ee804be53a97): it introduced `mgmt_errno_status()` with precisely the incorrect `-ETIMEDOUT → MGMT_STATUS_AUTH_FAILED` mapping. The replacement with `MGMT_STATUS_TIMEOUT` is appropriate.

The BlueZ test installs its command-drop hook after setup and checks the externally visible MGMT result. Its five-second timeout accommodates the observed approximately two-second command timeout. I found no correctness problem in that test.

There **are** BlueZ consumers that distinguish authentication failure from timeout:

- `bonding_attempt_complete()` has an authentication-failure-specific PIN retry path.
- `device_bonding_complete()` has an authentication-failure-specific disconnect.
- `new_authentication_return()` maps timeout to `AuthenticationTimeout`.

However, the normal kernel pairing callbacks inspected take an unsigned HCI status and use the positive-status mapping, which this patch leaves unchanged. Thus these consumers are not evidence of a regression from this change. They do mean that a blanket claim that the two statuses are interchangeable in userspace would be wrong. [Adapter handling](https://github.com/bluez/bluez/blob/20ffd285b58facfd1f2478d159a5f941b09d5be1/src/adapter.c#L8924), [device handling](https://github.com/bluez/bluez/blob/20ffd285b58facfd1f2478d159a5f941b09d5be1/src/device.c#L3518).

I consider CO-44 a reasonable stable candidate after normal review; I cannot establish that no third-party MGMT client depends on the historical value.

**Recommended submission order:** CO-44 kernel fix and its separately targeted BlueZ test; E; A. Revise and test B before submission. Keep D under design review with USB maintainers, and C as a separate RFC.
