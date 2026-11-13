# BT-17 source investigation — the first outside reviewer's answer

*Received 2026-11-13 in answer to `2026-11-13T0003Z-bt17-source-investigation-task.md`. The text
is kept as received.*

*No finding was added or changed. What we checked on 2026-11-13, and what holds:*

- **The line numbers are mainline v7.0's, and they match.** `git grep -n` at the `v7.0` tag:
  - `btusb.c`: `btusb_reset()` 982, `btusb_qca_reset()` 1121, `submit_or_queue_tx_urb()` 2174,
    `btusb_waker()` 2420, `hdev->reset = btusb_qca_reset` 4277 (and 4292);
  - `hub.c`: `finish_port_resume()` 3631, `usb_port_resume()` 3793;
  - `hci_core.c`: `hci_cmd_timeout()` 1462;
  - `mgmt.c`: `mgmt_errno_status()` 286, its `case -ETIMEDOUT:` at 299.

  The brief quoted Ubuntu `7.0.0-42` line numbers for btusb, so the two sets differ by design.
  `BTUSB_WAKEUP_BROKEN` is not in v7.0 at all; it is in Ubuntu's `7.0.0-42` tree and in 7.2.y, as
  the brief said.
- **The timing constants are right.** `USB_RESUME_TIMEOUT` is 40 ms (`include/linux/usb.h:337`)
  and `USB_CTRL_GET_TIMEOUT` is 5000 (`:1934`). The 10 ms TRSMRCY is the literal `msleep(10)` in
  `usb_port_resume()`; v7.0 has no `USB_TRSMRCY` macro.
- **The cited history commit exists and says what the reviewer says.** `1fdb926974695`
  (2018-02-20, "Bluetooth: btusb: Use DMI matching for QCA reset_resume quirking") moved
  `USB_QUIRK_RESET_RESUME` from all QCA ROME IDs to a DMI list. Its message says the problem is
  the platform, likely cutting all power, and that "the USB_QUIRK_RESET_RESUME quirk also
  disables runtime suspend".
- **The 0.24 s is not explained by this answer.** The review calls it "ordinary overhead and xHCI
  port-status polling" but names no code. Reading v7.0's `usb_port_resume()` shows more steps
  before the GET_STATUS than the brief counted:
  - `pm_runtime_resume_and_get()` on the port device;
  - port-status reads before and after the 40 ms;
  - `wait_for_connected()` (persist is on);
  - `check_port_resume_type()`.

  Before any of these, the runtime-PM core resumes the parent chain: the root hub `usb3`, and if
  that was suspended, the xHCI PCI function. Our archived sysfs (`machine/usb3-port3.txt`, taken
  at 22:44 in the next boot) does not record the root hub's or the xHCI function's runtime state
  at 18:03, so that part stays open.
- **One misreading of the brief.** "One occurrence after 11 days of uptime": the 11.2 days are
  the total over E3 trial rows #1–#8, eight boots, not one boot's uptime. The failing boot had run
  about 3 minutes (monotonic 178.7 s) when the command was sent. That fits the review's point (one occurrence is thin)
  rather than weakening it.
- **Not checked here:**
  - the review's search for public reports;
  - the power-rail remark (the card's Bluetooth supply not following the root-hub port power):
    that is an inference, and nothing in the logs or in the source reads it.

---

**Yes on H1 and H2; H3 is a plausible but weakly supported candidate.** The code paths in mainline v7.0 (and the Ubuntu 7.0.0-42 delta for the Bluetooth/USB core pieces that matter here) match the logs closely. The first reset came from the USB core’s reset-resume path after a host-initiated runtime resume failed a GET_STATUS; btusb’s own reset was blocked behind it and never ran. The Ryzen/root-hub remote-wakeup pattern is similar in symptom and platform but the trigger observed here is different, and the failure is intermittent after long successful suspends.

All line numbers below are from mainline v7.0 sources (`drivers/bluetooth/btusb.c`, `drivers/usb/core/hub.c`, `net/bluetooth/hci_core.c`, `drivers/base/power/runtime.c`). Ubuntu’s `7.0.0-42` tree was the one that ran for `btusb`/`hci_*`; the brief already notes the USB core and power paths were read against mainline v7.0. The extra device-table line (`dc16388d45ec`) is irrelevant to this incident.

### 1. Origin of the first USB reset (H1) — yes

**Participating code**

- `drivers/bluetooth/btusb.c` ~2174 `submit_or_queue_tx_urb()`: when `BTUSB_SUSPENDING` is set the URB is anchored on `data->deferred` and `schedule_work(&data->waker)` is called. The waker is the only host-initiated resume path that the HCI command can take while the device is runtime-suspended.
- `btusb.c` ~2420 `btusb_waker()`: `usb_autopm_get_interface()` (error is silent; it just returns).
- No `btusb_resume()` `BT_DBG("intf %p")` appears after the 18:00:28 suspend (E1). The driver’s resume callback was never invoked, so the device-level resume failed before the USB core handed the interfaces back to the driver.
- `drivers/usb/core/hub.c` ~3793 `usb_port_resume()`: ClearPortFeature(SUSPEND), `msleep(USB_RESUME_TIMEOUT)` (40 ms), then `finish_port_resume()`.
- `hub.c` ~3631 `finish_port_resume()`: after the resume signalling it calls `usb_get_std_status()` → `usb_control_msg(..., USB_CTRL_GET_TIMEOUT)`. `USB_CTRL_GET_TIMEOUT` is 5000 ms. On failure and `persist_enabled` it sets `reset_resume = 1` and jumps to `usb_reset_and_verify_device()`, which prints the exact “reset full-speed USB device number 2 using xhci_hcd” line. All intermediate messages on this path are `dev_dbg` (off).

**Reading**

Frame #121 at monotonic 178.731 was parked on the deferred anchor. The waker started a host-initiated runtime resume. The controller did not answer the GET_STATUS after resume signalling; the request timed out after 5 s. Because `persist` is 1 the core retried as a reset-resume. That is the first reset at 184.023 (5.291 s after the send). The arithmetic is 5000 ms timeout + 40 ms resume signalling + 10 ms TRSMRCY + scheduling, which accounts for the observed interval (the residual ~0.24 s is ordinary overhead and xHCI port-status polling). No other default-level caller produces that exact message without additional prints. A remote-wakeup-initiated resume would have produced different timing and, typically, a resume print; none was observed.

The later `-71` (“device descriptor read/64”), “Device not responding to setup address”, xHCI completion code 0x11 and “invalid context state for evaluate context command” are the normal USB-core/xHCI symptoms of a device that is not answering on the wire. They are consequences, not an independent xHCI error-handling defect.

It is plausible that the controller remains wedged through port resets and a port power cycle if the M.2 card’s Bluetooth power rail does not follow the root-hub port power, while a full platform power-off does cut it. That matches the recovery behaviour.

**Certainty**: high.  
**Falsifier**: USB-core `dev_dbg` on a recurrence that does *not* show “retry with reset-resume” / “gone after usb resume? status …”, or a different caller of `usb_reset_device` that somehow produces no other default-level messages.  
**History**: the reset-resume-on-failed-GET_STATUS path is long-standing USB-core behaviour.  
**Fix location**: none required in this path if the hypothesis is only the explanation; the failure is the controller not answering after resume signalling.  
**First experiment**: enable `dev_dbg` for `drivers/usb/core/hub.c` and `driver.c` (and xHCI trace events if practical). A recurrence should print the exact “retry with reset-resume” and status lines.

### 2. HCI timeout reset behind the failing resume (H2) — yes

**Participating code**

- `net/bluetooth/hci_core.c` ~1462 `hci_cmd_timeout()`: if `hdev->reset` is set it is called *before* `cmd_cnt` is restored. The work item runs on `hdev->workqueue`.
- For `BTUSB_QCA_ROME` the probe sets `hdev->reset = btusb_qca_reset` (`btusb.c` ~4277).
- `btusb_qca_reset()` ~1121: no reset GPIO on this platform, so it falls through to `btusb_reset()`.
- `btusb_reset()` ~980: `usb_autopm_get_interface()`; on any error it prints “Failed usb_autopm_get_interface: %d” and returns *without* printing “Resetting usb device.”.
- `drivers/base/power/runtime.c` `rpm_resume()`: a caller that finds the device (or its parent) still `RPM_RESUMING` waits; if the parent does not become `RPM_ACTIVE` the return is `-EBUSY` (-16).

**Reading**

At 180.772 the HCI timeout called `btusb_qca_reset` → `btusb_reset` → `usb_autopm_get_interface`. That call found the H1 resume already in progress and blocked. When the resume failed and the device was logically disconnected the wait ended with `-EBUSY`. The “Failed usb_autopm_get_interface: -16” line appears within 1 µs of the “USB disconnect” line (E3 monotonic). Consequently `hci_cmd_timeout` stayed blocked for ~5.3 s, the command credit was restored only then, and frame #122 was submitted to a device that had already disappeared. The two later 0x0c24 commands timed out unsent because they were queued behind the blocked work item.

Blocking inside `hdev->reset` on the command workqueue is existing design (other vendor reset paths also sleep). For a QCA ROME without a reset GPIO the first-timeout USB reset is the policy that has been in place since the GPIO-preferring rewrite; on this hardware a USB reset issued to an already-unresponsive controller has previously driven it off the bus (the 2026-08 ROM-firmware tests).

**Certainty**: high.  
**Falsifier**: the Failed line appearing with a different error code, or appearing without a concurrent disconnect, or a “Resetting usb device.” line at the timeout instant.  
**History**: `btusb_qca_reset` prefers a platform GPIO (`BT_EN`) when present and falls back to the USB reset; the USB path is the one that ran.  
**Fix location**: if a change is wanted it belongs in btusb (do not issue a USB reset from the timeout path while a resume is already failing, or make the timeout path non-blocking). That is a policy decision, not required to explain the logs.

### 3. Ryzen remote-wakeup quirk applicability (H3) — candidate only

**Participating code / history**

- Mainline `dcaf83ead130` (“Bluetooth: Properly disable remote wakeup for MT7922/MT7925 on Ryzen platform”) and its predecessor `e31d761628ad`. The quirk is set only in `btusb_mtk_setup` for MT7922/MT7925 when `platform_is_ryzen()` (Zen) and the device is a direct child of the root hub. It makes `btusb_suspend` return `-EBUSY` for runtime suspend while HCI is open (`needs_remote_wakeup == 1`).
- The commit message and discussion describe exactly the symptom “completely unresponsive, xHCI root-hub reset does not help, only a power cycle recovers” and note that all reports were on Ryzen laptops. The limitation to direct children of the root hub is deliberate; the authors considered a PCI-vendor check “too intrusive”.
- The older QCA ROME `USB_QUIRK_RESET_RESUME` path (`btusb_check_needs_reset_resume`, DMI table) was for system resume on platforms that cut power. It was narrowed from “all ROME” to DMI matches because the quirk also disables runtime suspend and most platforms resume fine (`1fdb9269` etc.). This laptop’s DMI is “Default string”, so it does not match.

**Reading**

Platform match is exact (Ryzen 7 5825U / Cezanne, Bluetooth is a direct child of the SoC xHCI `1022:1639` root hub, HCI open so remote wakeup was armed). Symptom match is exact (unresponsive after runtime suspend, resets and warm reboot fail, only full power-off recovers). Trigger match is imperfect: the resume that failed was host-initiated by the waker, not a remote-wakeup event, and the previous boot of the same setup successfully resumed from 49- and 71-minute suspends. One occurrence after 11 days of uptime is not enough to establish the condition.

No public reports of QCA9377 / `13d3:3503` / other `BTUSB_QCA_ROME` IDs disappearing after idle or resume on Ryzen laptops that only a power-off fixes were found beyond this project’s own logs. Historical QCA ROME problems (Launchpad/Bugzilla ~2017-2018) were system-suspend/resume and were addressed by the DMI quirk. Similar `-71` enumeration failures appear for QCA9377 in other power-state contexts, but not this exact runtime-suspend pattern.

**Judgment**: worth an A/B test (`power/control=on` or `btusb.enable_autosuspend=0`), not yet a finding. A quirk patch acceptable to maintainers would need either multiple independent reports or a reproducible case on QCA ROME (or this specific ID) on Ryzen root hubs, preferably with USB-core debug confirming the failure on a remote-wakeup-armed runtime suspend. The scope should stay narrow (per-ID or ROME + the existing platform/root-hub check). Applying it to all btusb devices on Ryzen root hubs would be broader than the MTK precedent.

**First experiment**: the same USB-core `dev_dbg` run already recommended for H1; if a recurrence shows a remote-wakeup path rather than the waker, the case for H3 strengthens.

### 4. Controller side

`btusb_setup_qca()` loads the rampatch and NVM normally (the log shows the expected “patch rome 0x302 build 0x3e8”). Whether any NVM tag configures deep-sleep or remote-wakeup behaviour is inside the binary firmware files, not the kernel source. The patched firmware already differs from the ROM firmware in SCO behaviour; a difference in USB-suspend handling is possible but not visible in the driver. No software path (vendor command, ath10k-side reset of the combo card, ACPI method) that recovers a controller in this state without a power cycle appears in the drivers. The Wi-Fi half stayed up throughout, so there is no shared recovery that helped.

### 5. Smaller items

- `net/bluetooth/mgmt.c` `mgmt_errno_status()` maps `-ETIMEDOUT` to `MGMT_STATUS_AUTH_FAILED` (0x05). The mapping is present in v7.0 and remains on mainline. It is misleading for a command timeout; `MGMT_STATUS_TIMEOUT` or `MGMT_STATUS_FAILED` would be more accurate. Harmless to the failure itself.
- Frame #122 after the credit restore is harmless (the URB fails because the device is gone). The delayed restore is simply the consequence of the blocking reset in H2.

### Anything else the code shows

The silent failure of `btusb_waker` (no print on `usb_autopm_get_interface` error) is what makes the missing resume print the key observation. The combination of `persist=1`, no `USB_QUIRK_RESET`/`RESET_RESUME`, and a 2 s autosuspend delay with HCI open is exactly the configuration that exercises the path that failed.

**Recommended first experiment** (within the constraints): turn on `dev_dbg` for `drivers/usb/core/hub.c` and `driver.c` (and xHCI trace events if practical) on the running system. A recurrence should confirm or refute the “retry with reset-resume” sequence. Counting suspend/resume cycles across the earlier boots would give a failure rate; an A/B with runtime PM disabled for the device is the cleanest long-term test of H3. Reproducing on QEMU or another machine is unlikely to help.
