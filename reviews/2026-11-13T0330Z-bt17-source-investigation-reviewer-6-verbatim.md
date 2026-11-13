# BT-17 source investigation — the sixth outside reviewer's answer

*Received 2026-11-13 in answer to `2026-11-13T0003Z-bt17-source-investigation-task.md`. The
review is kept as received, with three omissions:*
- *the byline under the date (a mention of the operator);*
- *the reviewer's three progress notes, one of which links to its working document;*
- *that link.*

*The closing summary is kept, under its own heading. No finding was added or changed.*

*What we checked on 2026-11-13, and what holds:*

- **Correction 1 holds: the unexplained 0.24 s mostly goes away.** In v7.0's `hub_port_init()`,
  `hub_port_reset()` runs before the `new`/`reset … USB device number` line is printed (`hub.c`
  around 4939 and 4997). Two waits come first:
  - the root-hub reset wait, `HUB_ROOT_RESET_TIME` 60 ms (`:2901`, applied at `:4927`);
  - the reset recovery `msleep(10 + 40)` (`:3158-3165`).

  Our brief, and reviews 1–3, counted the waits only up to the GET_STATUS. With these two:
  40 + 40 + 10 + 5,000 + 60 + 50 = 5,200 ms. That leaves about 91 ms of the 5,291 ms for
  scheduling and polling.

  The root hub's own resume probably adds nothing. The other device on bus 3, a FocalTech
  fingerprint reader at `3-4`, has `power/control` `on` and is active, so the root hub cannot
  autosuspend. The reader logged no error in the failing boot (`grep "usb 3-4"`: enumeration lines only).
- **The xHCI host never runtime-suspends.** This rules out Item 3's host-side alternative for
  the current boot. Read now, `7.0.0-43`:
  - `0000:03:00.4` `power/control` is `on`, `runtime_status` `active`, `runtime_suspended_time` 0;
  - `usb3` is `auto` and `active`.

  No TLP, powertop or laptop-mode-tools is installed (`dpkg-selected.txt` in the incident
  archive). Nothing on this laptop sets the xHCI to `auto`, but the failing boot's value itself
  was not recorded.
- **The quirk decode is right.** The failing boot logs `hci version 0x110 quirks
  0x0000020000000010` for `0000:03:00.4`. In v7.0 `xhci.h`, bit 41 is `XHCI_BROKEN_D3COLD_S2I`
  and bit 4 is `XHCI_SPURIOUS_SUCCESS`. Bit 33, `XHCI_DEFAULT_PM_RUNTIME_ALLOW`, is clear.
  `quirk_ryzen_xhci_d3hot` is declared for `0x1639` at `drivers/pci/quirks.c:2101`.
- **The H2 proof from our own log holds.** The full archived kernel log has exactly two
  `cmd_cnt` lines between the send and the disconnect: 18:03:08.827502 (`queued 1`) and
  18:03:16.181879 (`queued 3`). Also:
  - `rpm_resume()` has one `-EBUSY` return in v7.0;
  - `__hci_cmd_sync_sk()` returns `-ETIMEDOUT` without taking the command off the queue.
- **Correction 4 holds by the code.** `BTUSB_SUSPENDING` is set at `btusb.c:4493` and cleared
  only in `btusb_resume()` (`:4614`, `:4624`), which never ran. So #122 went back onto the
  deferred queue. Our brief's "went to a device that was already gone" is withdrawn; it reached
  no hardware.
- **Parameter Error 0x11 only on the reset of the known device.** Our logs agree:
  - the two `completion code 0x11` lines fall inside the reset-resume of device number 2;
  - the fresh enumerations after the disconnect (device numbers 4–7) and the next boot show the
    `invalid context state` warning but no 0x11.

  That matches the third review's xHCI patch, which names exactly the case where "core resets a
  device and doesn't reallocate udev".
- **Commit dates and contents:**
  - `dcaf83ead130` is first in `v7.3-rc3` (`git tag --contains`);
  - `e2bef3847e3d`, `582ee9c5ad26`, `fc54910280eb`, `7d06d5895c15`, `7bee549e197c`,
    `4baf12181509`, `24be0b3c4059`, `be58267a34ae` (Zijun Hu, 2026-09-13, "Build the driver from
    multiple source files") and `e31d761628ad` exist with the subjects and dates given.
- **Point 7, the README question, answered.**
  - The repository README does not describe the mitigation; the reviewer probably read
    `docs/install.md`. Its "What it installs" lists `enable_autosuspend=0` and the udev rule,
    which is what `install.sh --apply` puts in place, not this laptop's state.
  - On the laptop the files are disabled (`machine/btusb-modprobe-udev-disabled.txt` in the
    incident archive). HISTORY records the dates:
    - the mitigation was installed on the first night;
    - it was lifted for the August "experiment mode" boots (Phase 24);
    - the laptop went back to stock on 2026-09-18/19 (Phase 36).
  - So there are ROM-firmware boots with autosuspend at the stock `auto` and btusb's debug on:
    the August experiment-mode boots and about one week from 09-19 to the first patched-firmware
    boot (E1, boot `226965f1`, 2026-09-26, `EX-055`). The archived journals of those boots can supply the baseline the review
    asks for. Not counted yet.
- **Recovery routes, read now (all reads only):**
  - `/sys/class/rfkill` has only `hci0` (bluetooth) and `phy0` (wlan): no platform Bluetooth
    switch;
  - the port's ACPI node `\_SB_.PCI0.GP17.XHC1.RHUB.PRT3` has no power resources, and no ACPI
    table defines `_PRR` (the second review's header).

  Neither route in Item 4 exists on this laptop.
- **Step 6 (an HCI command every 6 s to provoke the fault) sends commands to the laptop's
  controller.** It may cost a power-off. It is listed as the operator's decision, not as a step
  for us.
- **Not checked here:**
  - the external reports and list threads;
  - the claim that the MediaTek log's failing resume lasted 69 s;
  - the Ubuntu SAUCE question for `config.c`, `hcd.c`, `port.c` and `quirks.c`. Our `-42` delta
    (second review's header) does touch `hcd.c` (the root-hub descriptor), `port.c` and
    `quirks.c`, besides `hub.c`; none of those hunks is on the resume path.

---

# BT-17 source review: QCA9377 runtime-resume failure (2026-11-12)

Nov 13, 2026

## Bottom line

**H1: yes.** The first reset is the USB core's reset-resume retry inside `finish_port_resume()`, after a 5 s `GET_STATUS` timeout on a resume that started at the send of frame #121. Confidence: high.

**H2: yes.** `btusb_reset()` sat in `usb_autopm_get_interface()` behind that resume and got `-EBUSY` from `rpm_resume()`'s parent check. btusb's own reset never ran. Confidence: high. Your own log proves the block independently of the code (see Item 2).

**H3: half.** The failure *signature* is the MT7922/MT7925 one, step for step. The claimed *condition* (Ryzen root hub) is not established for QCA. ROME has an older record of the same end state on Intel platforms. One occurrence does not carry a quirk patch.

### Where this review contradicts or corrects the brief

1. **The "unexplained 0.24 s" is explained.** You counted 5.000 s plus 50 ms. The code path has 5.200 s of fixed waits before the `reset full-speed` line is printed. The line is printed *after* the port reset, not before it.
2. **The device was not giving transaction errors before the reset.** A dead device fails `GET_STATUS` in milliseconds with `-71`. This one took the full 5 s timeout, so the request was NAKed or never completed. After the first bus reset every transfer fails fast with `-71`. The reset changed the controller's state. That matches your two August tests.
3. **`BTUSB_WAKEUP_BROKEN` is not in mainline v7.0, nor in stable 7.0.14** (the last 7.0.y). It entered mainline in v7.3-rc3. Ubuntu carries it as its own backport, so "Ubuntu 7.0.0-42 = v7.0 plus delta" hides a larger btusb delta than the brief implies.
4. **Frame #122 did not go "to a device that is gone".** It never left btusb. `BTUSB_SUSPENDING` was still set, so the URB was parked on `data->deferred` again.
5. **Mainline has split `btusb.c`** into `btusb_main.c` and `btusb_qcom.c` (`be58267a34ae`, 2026-09-13). Any patch targets those files now.
6. **Not in the brief at all:** the xHCI host's own runtime-PM state, and the fact that all four port resets *succeeded at the port level*. Both bear on where the wedge lives (Item 1).
7. **A question, not a finding:** the public README of `qca9377-bt-hang` still describes `enable_autosuspend=0` plus a udev rule pinning `power/control=on` as installed. The brief says neither exists. If that mitigation was removed around the time the device-table entry went in, the controller's exposure to remote-wakeup-armed autosuspend is only as old as rows #1 to #9, and the ROM-firmware era gives no baseline.

## What was read

| Tree | Version | Used for |
| --- | --- | --- |
| `torvalds/linux` | tag `v7.0` (`028ef9c96e96`), checked out | every file and line number cited below |
| `torvalds/linux` | full history to `7e1392a42ea2` (v7.4-rc2+) | `git log -S`, commit messages, what mainline changed later |
| `gregkh/linux` | `linux-7.0.y` tip, `458c6079f` (7.0.14) | diff against v7.0 for the USB core, xHCI, runtime PM, btusb |

**Not obtained: Ubuntu's `7.0.0-42.42~24.04.1` tree.** `git.launchpad.net` is blocked from this session. Three consequences:

- All line numbers here are mainline v7.0. Your btusb lines sit 50 to 147 lines lower (`btusb_reset` 982 vs your 1032, `submit_or_queue_tx_urb` 2174 vs 2232, `btusb_waker` 2420 vs 2478, `btusb_suspend` 4475 vs 4622).
- The functions you quoted from the Ubuntu btusb match mainline v7.0 except two backports: `dcaf83ead130` (the quirk) and `c93922dd316b` (the `BTUSB_RESET` flag in `btusb_reset()`, mainline v7.3-rc3).
- For `drivers/usb/` and `drivers/base/power/`: between v7.0 and 7.0.14 nothing touches `hub.c`, `driver.c`, `runtime.c` or `xhci-hub.c`. The only USB-core changes are in `config.c`, `hcd.c` (a root-hub descriptor), `port.c` (the `disable` attribute) and `quirks.c` (two Lenovo dock IDs). Ubuntu SAUCE patches to those files remain unchecked. One command settles it on the laptop's source package: `diff` those four files against v7.0.

No USB-core debug, xHCI trace or usbmon exists for the incident, so every statement about what happened on the wire is inference from timing and from default-level messages.

## Item 1: where the first USB reset came from (H1)

**H1 holds: a host-initiated runtime resume, a `GET_STATUS` that timed out, and the core's reset-resume retry.** All lines are mainline v7.0.

### The code path

1. `submit_or_queue_tx_urb()` (`btusb.c:2174`) finds `BTUSB_SUSPENDING`, parks the URB on `data->deferred` and schedules `btusb_waker()` (`:2420`).
2. The waker calls `usb_autopm_get_interface()`. USB interfaces have no runtime-PM callbacks (`message.c:2200`), so `rpm_resume()` goes to the parent (`runtime.c:915`) and runs `usb_runtime_resume()` (`driver.c:2017`) → `usb_resume_both()` → `usb_port_resume()` (`hub.c:3793`).
3. `finish_port_resume()` (`hub.c:3631`) sends `GET_STATUS` (`:3674`) with `USB_CTRL_GET_TIMEOUT` = 5000 ms (`usb.h:1934`). On failure with `persist_enabled` it sets `reset_resume` and calls `usb_reset_and_verify_device()` (`:3677-3680`, `:3665`).
4. That routine loops `PORT_INIT_TRIES` = 4 times over `hub_port_init()` (`hub.c:6206-6217`, `:2896`), switching enumeration scheme halfway.
5. On failure it goes to `re_enumerate` (`:6316`), returns `-ENODEV`, and `usb_port_resume()` calls `hub_port_logical_disconnect()` (`:3868`).

### Why it cannot be anything else

- **The log shows exactly one call of `usb_reset_and_verify_device()`.** Four `reset full-speed` lines: the first two fail at `device descriptor read/64` (new scheme), the last two at SET\_ADDRESS (old scheme). That 2+2 pattern is the loop in step 4.
- **The word "reset" narrows the callers to two.** `hub_port_init()` prints `reset` instead of `new` only when it is given a descriptor (`hub.c:4997`). Only `usb_reset_and_verify_device()` does that, and it has two callers: `finish_port_resume()` (`:3665`) and `usb_reset_device()` (`:6410`).
- **`usb_reset_device()` needs an actor, and none is visible.** btusb would have printed `Resetting usb device.`. usbfs `USBDEVFS_RESET` needs a userspace process. Either would also call `usb_autoresume_device()` first, which for a suspended device runs the same `finish_port_resume()`.
- **The other `hub_wq` paths print at default level or print something else.** The EMI re-enable prints `disabled by hub (EMI?)` at `dev_err` (`hub.c:5782`). A connect change prints `USB disconnect` or `new`, never `reset`.
- **A remote wakeup takes the same path.** `usb_remote_wakeup()` (`hub.c:3882`) calls `usb_autoresume_device()`. It would be silent at default level too.

### The 5.291 s, accounted for

| Step | Code | Wait |
| --- | --- | --- |
| xHCI drives resume: PLS=Resume, sleep, PLS=U0 | `xhci-hub.c:1574-1587` | 40 ms |
| USB core waits again after ClearPortFeature(SUSPEND) | `hub.c:3832` | 40 ms |
| TRSMRCY | `hub.c:3854` | 10 ms |
| `GET_STATUS` times out | `hub.c:3674` | 5000 ms |
| Port reset, root-hub reset time | `hub.c:2901`, `:2965` | 60 ms |
| Reset recovery (TRSTRCY plus extra) | `hub.c:3158-3165` | 50 ms |
| `reset full-speed ...` is printed here | `hub.c:4997` |  |
| **Fixed waits** |  | **5200 ms** |

Observed: 5291 ms. The remaining 91 ms covers the waker's scheduling, the root hub's own resume if `usb3` was autosuspended (`hcd_bus_resume()`, `xhci_bus_resume()`), cancelling the timed-out URB, and `msleep()` rounding. I cannot split it further without a trace.

A measured reference exists. The log in `e31d761628ad` (MT7925, another AMD host, USB debug on) shows `finish resume` → `retry with reset-resume` in 5.120 s and → `reset high-speed` in 5.240 s. Your stretch from `finish resume` would be about 5.2 s. There is no second wait to look for.

### Host resume or remote wakeup?

**Host-initiated, by coincidence argument only.** A remote wakeup skips the first two 40 ms waits (`hub.c:3812-3818`), so the totals differ by less than the timing resolves. But a wakeup would have had to land within about 0.1 s of frame #121 in a 160 s window.

What the logs cannot exclude: the controller wedged at some earlier moment in those 160 s, and the command only discovered it. A wakeup that the host *serviced* is excluded, because `btusb_resume()` would have printed.

### What the error lines say about the device

- **Before the reset the device, or the port, was not producing transaction errors.** `-71` (`EPROTO`) comes back in milliseconds. A 5 s timeout means the control transfer stayed pending: NAK, or a port that was not passing traffic.
- **Every port reset completed with a full-speed device attached.** `hub_port_wait_reset()` (`hub.c:2953`) only succeeds with RESET clear and CONNECTION set. Otherwise you get `Cannot enable. Maybe the USB cable is bad?` (`:3151`) or no `reset` line at all. So the D+ pull-up stayed asserted through four resets, the port "power cycle", and the warm reboot. The chip was powered and electrically present, with a dead USB function.
- **`Device not responding to setup address`** is an Address Device command ending in USB Transaction Error (`xhci.c:4420`). The driver then frees the slot and allocates a new one.
- **`WARN: invalid context state for evaluate context command`** is a consequence. `usb_ep0_reinit()` (`hub.c:6214`) → `xhci_endpoint_reset()` (`xhci.c:3307`) → `xhci_check_ep0_maxpacket()` (`:1549`) issues Evaluate Context on the freshly re-allocated slot, which is not addressed yet.
- **`completion code 0x11`** is `COMP_PARAMETER_ERROR` (`xhci.h:849`), reported by the default branch at `xhci.c:4443`. It appears only when an already-known device is reset, not on the next boot's fresh enumeration. I did not trace which input-context field the controller rejects. It is a wart in xHCI error handling on a path only a dead device reaches, not a cause.

### Why only a power-off helps

**Plausible, and documented for this chip family.**

- An M.2 module's Bluetooth runs from the slot's 3.3 V rail, not from VBUS. `attempt power cycle` (`hub.c:5606`) toggles the root port's PORT\_POWER bit and switches nothing on the module. A warm reboot keeps the rail up. The persistent pull-up and the working Wi-Fi half both say the rail never dropped.
- `582ee9c5ad26` ("USB: Disable USB2 LPM at shutdown", 2019) records that ROME left in a USB low-power link state cannot be enumerated even after a reboot. Its bug link, [LP #1757218](https://bugs.launchpad.net/bugs/1757218), is a QCA9377 on a Lenovo IdeaPad with your exact `-71` lines and a power-off as the only cure.
- Your device is full speed with bcdUSB 1.10, so LPM L1 itself is not in play. The parallel is the end state: a ROME USB function stuck after a low-power bus state.

### History, confidence, falsifiers

- **History:** the reset-resume retry is `86c57edf60f5` (Alan Stern, 2008, "USB: use reset\_resume when normal resume fails"). Unchanged in substance since. The USB core behaved as designed; nothing to fix there.
- **Confidence:** high on the path. Medium on "the reset changed the device's state".
- **Falsifiers:** with `hub.c` debug on, a recurrence that shows no `retry with reset-resume`; or usbmon showing the first `GET_STATUS` ending in `-71` rather than `-110`.
- **First experiment:** dynamic debug for `hub.c` and `driver.c`, plus usbmon on bus 3 (see Experiments).

## Item 2: the HCI timeout's reset behind the failing resume (H2)

**H2 holds: `hci_cmd_timeout()` was blocked for 5.311 s inside `hdev->reset`, and btusb's reset never ran.**

### The code path

1. `hci_cmd_timeout()` (`hci_core.c:1462`) calls `hdev->reset(hdev)` (`:1478`) *before* it restores the command credit.
2. Probe sets `hdev->reset = btusb_qca_reset` for ROME (`btusb.c:4277`). With no GPIO that falls through to `btusb_reset()` (`:982`), whose first act is `usb_autopm_get_interface()`.
3. `rpm_resume()` on the interface goes to the parent device, finds it `RPM_RESUMING` (the waker's resume from Item 1), and sleeps on its wait queue (`runtime.c:825-865`).
4. When the resume callback fails, `rpm_callback()` stores `runtime_error` (`:473`) and the status drops back to suspended. The woken waiter retries, gets `-EINVAL` for the parent (`:797`), and the interface gets `-EBUSY` because the parent is not `RPM_ACTIVE` (`:919`).
5. `btusb_reset()` prints `Failed usb_autopm_get_interface: -16` and returns without queueing a reset.

### Your log proves the block without the code

- `hci_cmd_work()` prints `cmd_cnt ... cmd queued ...` every time it runs (`hci_core.c:4144`). It printed at 178.731 and next at 186.083, with `queued 3`. Three sync commands were queued in between (180.772, 182.820, 184.867) and none triggered that line.
- `hdev->workqueue` is an ordered workqueue (`hci_core.c:2605`) and the command timer runs on it (`:4162`). One work item at a time.
- Had `hdev->reset` returned at once, the credit would be 1 at 180.772 and the second Write Class of Device would have been sent and logged then.

So something held that workqueue from 180.772 to 186.083. Only `hci_cmd_timeout()` was running on it.

### What else is stuck behind it

Everything on `hdev->workqueue`: `cmd_work`, `rx_work`, `tx_work` and the ncmd timer. Sync requests run on `hdev->req_workqueue` and keep going. Each waits its own 2 s (`HCI_CMD_TIMEOUT`) for a command that cannot be sent, then fails with `-110`. That is the source of the three extra `Opcode 0x0c24 failed: -110` lines and of the four misleading MGMT replies (Item 5).

### Is a blocking reset here intended?

**Nothing says so; it looks inherited.** The history:

| Commit | Date | What and why |
| --- | --- | --- |
| `e2bef3847e3d` | 2019-01 | Adds the driver `cmd_timeout` hook. |
| `6933568aec92` | 2020-06 | ROME gets a USB reset after 5 timeouts. Stated reason: ROME sometimes stops answering commands and has no reset GPIO. This commit puts `usb_autopm_get_interface()` into the timeout path. |
| `c9209b269afd` | 2022-10 | Factors that into the generic `btusb_reset()`. |
| `7c393421755d` | 2025-01 | Removes the count of 5. Stated reason: only one command is in flight, so reset on the first timeout. |
| `f07d478090b0` | 2025-01 | Renames `cmd_timeout` to `reset`; `hci_cmd_timeout()` takes today's form. |
| `c93922dd316b` | 2026-09 | Adds the `BTUSB_RESET` flag to fix a leaked PM reference. In your Ubuntu tree, not in v7.0. |

Every other step in the reset hooks is short. The resume wait is the only unbounded one, and it is not small: in the `e31d761628ad` log the failing resume lasted 69 s.

### Reset on the first timeout for ROME without a GPIO

**BT-17 gives no evidence either way, because that reset never ran.** Two structural points stand:

- For a controller that stopped answering *because it would not resume*, `btusb_reset()` can never work. It must resume the device before it may reset it.
- Your two August tests say a USB reset of a non-answering ROME on this laptop ends in loss until power-off. Item 1 adds a third data point of the same kind, issued by the USB core. The Chromium authors of `6933568aec92` evidently saw resets recover the chip on their hardware. That is two tests against an unknown fleet; I would record it, not patch on it.

### Could `usb_autopm_get_interface()` block for another reason?

Only if the device, the root hub or the xHCI PCI device were mid-transition. And `-16` pins the cause: `rpm_resume()` returns `-EBUSY` at exactly one place, the parent check, when the parent failed to become active. If H1 were wrong and the device had been active, you would have `Resetting usb device.` at 180.772.

### Fix, and where

**btusb, low priority.** `btusb_reset()` should not wait for a runtime resume on the HCI workqueue. `usb_reset_device()` already resumes the device itself from the reset work (`hub.c`, `usb_autoresume_device()` at the top). Taking the PM reference with `usb_autopm_get_interface_async()` would keep the reference without the wait. The symptom to cite is the one above: a stalled HCI workqueue and commands timing out unsent.

- **Confidence:** high.
- **Falsifier:** an ftrace of `rpm_resume`/`rpm_return_int` at a recurrence showing the interface's get returning before the device resume ends.
- **Experiment:** none needed for the verdict. The `cmd_cnt` gap is the measurement.

## Item 3: does the Ryzen remote-wakeup quirk apply? (H3)

**The symptom match is stronger than the brief claims; the platform claim is weaker.** The mitigation the quirk implements is the right thing to test here. The reasoning "it is the Ryzen root hub" is not something `dcaf83ead130` established, and QCA's own history points at the chip as much as the platform.

### What was actually observed on MT7922/MT7925

The first commit, `e31d761628ad` (v7.2-rc1), carries a log taken with USB debug and usbmon on. It answers your question directly:

- **Trigger: a remote wakeup during runtime suspend.** The log opens with `usb wakeup-resume`, then `Waited 0ms for CONNECT` and `finish resume`. The port-level resume completed.
- **Then the device ignored every URB** (the author's usbmon note). 5.12 s later: `retry with reset-resume`. Four resets, logical disconnect, failed re-enumeration, `attempt power cycle`, `unable to enumerate`.
- **Topology:** `usb 3-5` on `xhci_hcd 0000:67:00.0`, a direct child of the root hub. No PCI ID is given.
- **Stated reproduction conditions:** a noisy radio environment, no connection, and the interface open so that remote wakeup is armed. Reproduced within several hours each time.
- **What did not help:** a longer TRSMRCY, and `USB_QUIRK_RESET`.

From the discussion of the second patch:

- Machines named by the author: a ThinkBook 14 G7+ ASP (Ryzen AI 9 H 365, Bluetooth `0489:e111`) and a Beelink GTR9 Pro (Ryzen AI Max+ 395, Bluetooth `13d3:3604`) ([lkml](https://lkml.iu.edu/2607.3/01067.html)).
- Removing the xHCI controller from the PCI bus and re-probing it did not recover the device ([lkml](https://lkml.iu.edu/2606.3/04802.html)).
- A reboot without a power cycle always ends in an enumeration failure ([lkml](https://lkml.iu.edu/2607.0/11619.html)).
- **Nothing was found on the xHCI side.** MediaTek attributes the problem to the platform's hub and, as of 2026-07-24, had not reproduced it on an AMD machine ([lkml](https://lkml.iu.edu/2607.3/00574.html)).
- **The Ryzen condition is a scoping compromise, not a diagnosis.** The author notes these NICs do not ship on Intel platforms, so he cannot say whether it reproduces there. v1 applied to every Zen system; the maintainer objected that this would catch dongles on external ports ([linux-mediatek](https://lists.infradead.org/pipermail/linux-mediatek/2026-June/108931.html)); v2 added the direct-child test.

### BT-17 against that record

|  | MT7922/MT7925 (commit log) | BT-17 |
| --- | --- | --- |
| HCI open, no link, suspended with remote wakeup armed | yes | yes |
| Resume initiated by | device (remote wakeup) | host (by timing) |
| After resume | no answer; 5 s `GET_STATUS` timeout; reset-resume | 5 s gap; reset-resume (inferred) |
| Resets | four, all fail | four, all fail |
| Errors after reset | `-110`, `-62` (transfers hang) | `-71` (transaction errors) |
| Port "power cycle" | no effect | no effect |
| Reboot without power-off | enumeration fails | enumeration fails |
| Power-off | recovers | recovers |
| Device | high speed, MediaTek | full speed, QCA ROME |

Your brief says the match is "with the symptom and the platform, not with the trigger". Agreed on the trigger. The symptom match is closer than you could know without the commit's log: the same core sequence, including the 5 s.

### QCA ROME's own history points elsewhere

| Commit | Date | What it did and why |
| --- | --- | --- |
| `fd865802c66b` | 2017-07 | Reset on resume for all ROME. Reason: controllers stop working after resume and seem to lose power. |
| `7d06d5895c15` | 2017-12 | Reverts it. The reset landed in `btusb_open()` and interrupted firmware loading. |
| `61f5acea8737` | 2018-01 | `USB_QUIRK_RESET_RESUME` for all ROME. Notes that this also disables autosuspend, which it calls similarly broken on these devices. |
| `1fdb92697469` | 2018-02 | Narrows to a DMI table. Reason: most platforms resume fine; it is a platform problem, probably power being cut; the quirk costs power everywhere. |
| `fc54910280eb` | 2018-04 | Checks the table only for ROME. Quotes about 0.4 W for a disabled runtime PM. |
| `582ee9c5ad26` | 2019-08 | Disables USB2 LPM at shutdown, because ROME left in L1 cannot be enumerated after a reboot. |

What this bears on:

- **Runtime resume was part of it.** [RHBZ 1514836](https://bugzilla.redhat.com/show_bug.cgi?id=1514836) includes a Dell XPS 13 9360 (QCA6174) losing Bluetooth after idle periods, cured by `btusb.enable_autosuspend=n`. Those are Intel machines.
- **But it was a different failure.** In 2017-18 the controller needed a reset and a reset *cured* it. In BT-17 the reset is what finished it off. The DMI table would not have helped you even if your DMI strings were real.
- **A stuck USB function that only a power-off clears is on record for QCA9377 on Intel** (`582ee9c5ad26`, [LP #1757218](https://bugs.launchpad.net/bugs/1757218)).

So for QCA the evidence for "the chip does this" is at least as good as for "Ryzen root hubs do this".

### Other reports

**None found of QCA ROME on a Ryzen SoC root hub with this signature.** That is a weak negative: lore.kernel.org and bugzilla.kernel.org were not reachable or not searched, and the search covered a handful of queries. What did turn up is the same end state on other vendors and hosts:

- Intel AX211 lost after suspend/resume on an Intel xHCI, `-71` on re-enumeration ([linux-bluetooth, 2026-03](https://ratatoskr.run/linux-bluetooth/2026/03/9704999/t)).
- A Framework 11th-gen laptop: full-speed device, your exact `-71` sequence, worked around with `enable_autosuspend=0` ([Framework forum](https://community.frame.work/t/responded-bluetooth-restarts-on-ubuntu-kernel-6-5-0-14-11th-gen/42081)).
- MT7925/MT7927 boards that need a full power cycle after a warm reboot ([bluefin #4728](https://github.com/ublue-os/bluefin/issues/4728), [mt7927 #110](https://github.com/jetm/mediatek-mt7927-dkms/issues/110)).

### AMD-side quirks that exist

- **Your host carries `XHCI_BROKEN_D3COLD_S2I`.** The log's `quirks 0x0000020000000010` decodes to bit 41 (that quirk, set for `1022:1639` at `xhci-pci.c:341`) plus bit 4 (`XHCI_SPURIOUS_SUCCESS`).
- **`1022:1639` has a PCI quirk for an unreliable D3hot-to-D0 transition** (`quirk_ryzen_xhci_d3hot`, `drivers/pci/quirks.c:2101`, 20 ms delay).
- **Runtime PM by default for AMD xHC 1.1 was tried and reverted** (`4baf12181509`, 2023-10; revert `24be0b3c4059`, 2023-12, for regressions). Your controller reports `hci version 0x110` and bit 33 is clear, so it stays in D0 unless userspace sets `power/control` to `auto`.
- **`XHCI_U2_DISABLE_WAKE`** exists for AMD Promontory chipset controllers (`xhci-pci.c:339`). Not your controller.
- Nothing in `usb_quirk_list` or xhci-pci addresses "remote wakeup in runtime suspend breaks the device on AMD root hubs". `BTUSB_WAKEUP_BROKEN` is the only such quirk, and on mainline tip its only user is still the MediaTek setup path.

The third point matters. If something on this laptop set the xHCI to `auto`, the host was probably in D3 during the idle, and the resume in Item 1 began by waking a controller with a documented fragile wake. One sysfs read decides it (Experiments, step 1).

### What a quirk patch would have to show

1. **More than one event**, at least one with `hub.c` debug on, showing the sequence of Item 1.
2. **That not suspending prevents it.** Note the quirk is exactly "never autosuspend while HCI is open". `power/control=on` tests the same thing with no patch.
3. **Scope by device ID.** That is what was accepted for MediaTek (two chip IDs), and what the maintainer pushed v1 toward. All-ROME was tried in 2018 and backed out over power cost. All-btusb-on-Ryzen has no evidence behind it.
4. **The platform condition is optional for a per-ID quirk.** Telling an SoC root hub apart is a short check of the host controller's PCI vendor through `udev->bus->sysdev`; the commit declined it as too intrusive, and a per-ID quirk does not need it.
5. **A cross-vendor data point has value of its own.** A QCA device showing the MediaTek signature on a Ryzen SoC root hub is the first evidence in that thread for "platform" over "MediaTek firmware". It is worth reporting there once it has happened twice.

- **Confidence:** high that the signatures match; low that the cause is shared.
- **Falsifier for H3:** the wedge recurring with autosuspend off, or with the xHCI found in D3 at the time.
- **Where a fix belongs:** unknown until the cause is. As a mitigation, btusb (`btusb_qcom.c` on mainline tip).

## Item 4: the controller side

**The driver configures nothing about sleep or USB suspend. Whatever the patched firmware does in suspend comes from the two blobs.**

### What the QCA setup does

- `btusb_setup_qca()` (`btusb.c:3600`) issues three vendor control requests: `QCA_GET_TARGET_VERSION`, `QCA_CHECK_STATUS`, and the version again.
- It downloads the rampatch if the status lacks `QCA_PATCH_UPDATED`, and the NVM if it lacks `QCA_SYSCFG_UPDATED`. Both go down raw through `btusb_setup_qca_download_fw()` (`:3398`): header over the control pipe, body over bulk.
- No NVM tag is read or edited on the USB path. The tag handling that knows about deep sleep (`EDL_TAG_ID_DEEP_SLEEP`, `btqca.c:453`) is `qca_tlv_check_data()`, called only from the UART download (`btqca.c:615`).
- The last step sets `HCI_QUIRK_BROKEN_ENHANCED_SETUP_SYNC_CONN`. Nothing else.

So yes: the patched firmware's handling of USB suspend and remote wakeup can differ from the ROM's, and `nvm_usb_00000302.bin` is where such configuration would live. I could not inspect the blobs.

### The comparison you may not have

The question "did the device-table entry make suspend worse" needs suspend/resume cycles with HCI open under ROM firmware. If the earlier mitigation pinned autosuspend off through that period (see Bottom line, point 7), there are none, and the two firmware states cannot be compared from history.

Two cheap checks:

- Count device suspend/resume cycles in any pre-October journal you still have.
- Check whether linux-firmware has changed `qca/rampatch_usb_00000302.bin` or `qca/nvm_usb_00000302.bin` since your `20240318` package. A newer pair is a legitimate variable.

### Recovery without a power cycle

**None exists in btusb or btqca.** Every tool they have goes through endpoint 0 or HCI, and both were dead.

- `btusb_qca_reset()` has only the GPIO and the USB reset (`btusb.c:1121`). You have no GPIO.
- `btusb_shutdown_qca()` (`:3836`) sends HCI Reset. No use here.
- ath10k has no control over the Bluetooth core of the combo chip.

Two platform-level routes are worth one passive look, because either would be a real `BT_EN`:

- **A platform rfkill for Bluetooth.** On M.2 cards W\_DISABLE2# normally gates the Bluetooth core. If `rfkill list` shows a Bluetooth switch that is not `hci0`, a hard block and unblock is a cold start of the core.
- **An ACPI reset on the port's firmware node.** btintel uses a `_PRR` power resource with `_RST` for exactly this. Look at `/sys/bus/usb/devices/3-3/firmware_node/path` and search the DSDT under that node for `_RST`, `_PRR` or `_PS3`.

Both are things to try only when the controller is already dead, before the power-off.

- **Confidence:** high on what the driver does; none on what the firmware does.
- **Where a fix belongs:** if the cause is the controller's suspend handling, in Qualcomm's rampatch or NVM. The kernel can only avoid the state.

## Item 5: smaller items

### The MGMT status

**`-ETIMEDOUT` has mapped to `MGMT_STATUS_AUTH_FAILED` since the function was written, with no stated reason, and it still does on mainline.**

- **Code:** `mgmt_errno_status()`, `net/bluetooth/mgmt.c:299` in v7.0, `:297` on mainline tip.
- **Introduced by:** `161510ccf91c` (Luiz Augusto von Dentz, 2021-10-27, v5.17-rc1), "Bluetooth: hci\_sync: Make use of hci\_cmd\_sync\_queue set 1". That commit converts Set Device Class, Set Device ID, Add UUID and Remove UUID to the sync queue and adds the errno table in passing. The message does not mention the mapping.
- **What exists instead:** `MGMT_STATUS_TIMEOUT` (0x08). The HCI-status table in the same file uses it for Connection Timeout, Host Timeout and LMP Response Timeout (`mgmt.c:228-260`).
- **Reading:** an oversight, or pairing semantics carried into a table that now serves every sync command. Medium confidence; I found no discussion.
- **Fix:** one line in `net/bluetooth/mgmt.c`. Before sending, check which pairing paths reach this function with `-ETIMEDOUT` and what bluetoothd does with 0x08 there, since the D-Bus error would change.
- **Experiment:** mgmt-tester with an emulated controller that withholds one Command Complete. You already have that harness.

### The queued command

**Harmless here, and not a matter for `hci_cmd_timeout()`.** Two things happened:

- A sync command that times out is not removed from `hdev->cmd_q`. `__hci_cmd_sync_sk()` (`hci_sync.c:157-213`) returns `-ETIMEDOUT` and leaves the skb queued. Three stale Write Class of Device commands accumulated; `queued 3` at 186.083 is that count.
- When the credit came back, the first of them was handed to btusb as #122 and parked on `data->deferred`, because `BTUSB_SUSPENDING` was still set. It reached no hardware.

In a case where the controller recovers, such commands go out late with nobody waiting. For Write Class of Device that is benign. A general fix means dequeuing on sync timeout, which is a larger change than this incident justifies.

## Item 6: what else the code shows

None of these caused BT-17. Each made it harder to see or slower to end.

1. **`btusb_waker()` swallows a failed resume** (`btusb.c:2420-2430`). It returns on error without a message, and the deferred URB stays parked. The HCI core learns of the failure only through its own 2 s timer. This dates from `7bee549e197c` (Oliver Neukum, 2009), the commit that added autosuspend to btusb. A `bt_dev_err()` there, plus scuttling `data->deferred`, would have put the resume failure and its errno in your default-level log.
2. **`BTUSB_SUSPENDING` stays set after a failed resume.** Only `btusb_resume()` clears it (`:4614`, `:4624`). From then on every send is parked without an error until disconnect. Same root as point 1.
3. **`hci_cmd_timeout()` can stall the ordered HCI workqueue for the length of a failing USB resume** (Item 2). 5.3 s here, 69 s in the MediaTek log.
4. **The USB core resets and removes a device with no explanation at default log level.** `retry with reset-resume` and `gone after usb resume?` are `dev_dbg` (`hub.c:3678`, `:3685`). That is the maintainers' choice; the practical answer is to leave those two files' debug on.
5. **xHCI reports `completion code 0x11` as an unexpected error** on the fourth attempt (Item 1). Cosmetic, on a dead-device path.
6. **A timed-out sync command stays on `cmd_q`** (Item 5).

Points 1 and 3 are the two I would consider sending, in that order. Both are small, both have a concrete symptom in this log, and neither depends on knowing why the controller wedged.

## Experiments, in order

**The one that decides it: arm USB-core debug and usbmon now (step 3), and wait for a recurrence.** Everything below respects your constraints except step 6, which is optional and yours to weigh.

### 1. Five reads, now, passive

```
grep . /sys/bus/pci/devices/0000:03:00.4/power/{control,runtime_status,runtime_suspended_time}
grep . /sys/bus/usb/devices/usb3/power/{control,runtime_status}
lsusb -t
cat /sys/bus/usb/devices/3-3/firmware_node/path
rfkill list
```

- The first line says whether the xHCI itself runtime-suspends. If `control` is `auto` and `runtime_suspended_time` is large, the host was probably in D3 during the idle and Item 3's host-side alternative is live.
- `lsusb -t` says what else hangs off bus 3. A second device there that survived the incident argues against a host-side fault.
- The last two feed Item 4's recovery routes.

### 2. Count the cycles you already have

Run `suspend-cycles.py` over rows #1 to #9. Split resumes into host-initiated (an HCI command print within milliseconds before the resume) and device-initiated (an HCI event with no command). That gives a per-cycle failure rate and the mix of triggers. It also tells you whether 160 s at the greeter is typical or rare.

### 3. Arm passive logging

```
echo 'file drivers/usb/core/hub.c +p'    > /sys/kernel/debug/dynamic_debug/control
echo 'file drivers/usb/core/driver.c +p' > /sys/kernel/debug/dynamic_debug/control
echo 1 > /sys/kernel/tracing/events/xhci-hcd/xhci_handle_port_status/enable
echo 1 > /sys/kernel/tracing/events/xhci-hcd/xhci_get_port_status/enable
echo 1 > /sys/kernel/tracing/events/xhci-hcd/xhci_portsc_writel/enable
echo 1 > /sys/kernel/tracing/events/rpm/enable
cat /sys/kernel/debug/usb/usbmon/3u > /var/log/usbmon-bus3.log &
```

usbmon needs `modprobe usbmon` if it is not built in; that touches neither btusb nor bluetooth.ko. The trace buffer needs saving before the power-off.

At a recurrence this answers, in one event:

- `usb auto-resume` or `usb wakeup-resume`: host or device initiated.
- `status xxxx.xxxx after resume`: printed only if the port itself came back wrong. Otherwise the Waited-for-CONNECT and finish-resume lines show how far the port-level resume got.
- `retry with reset-resume`: H1, directly.
- usbmon: whether the `GET_STATUS` setup was answered at all, and with what status.

### 4. At the next failure, before powering off

Two minutes, nothing to lose, no resets:

- Read `/sys/kernel/debug/usb/xhci/0000:03:00.4/ports/port*/portsc` for the port that held 3-3. CCS set with the device absent confirms the stuck pull-up.
- If step 1 found a platform Bluetooth rfkill, block and unblock it and watch the kernel log.

### 5. The A/B, with a caveat

`power/control=on` for `13d3:3503` by udev rule. This is functionally the quirk.

**The "on" arm cannot fail by this mechanism, by construction.** It only tells you whether anything else wedges the controller. And the arithmetic is unkind: one failure in 11.2 days needs about 34 failure-free days before the difference means much at the usual 95 % (the rule of three). "Several weeks" is the minimum, not a comfortable margin.

### 6. Optional: accelerate the control arm

I disagree mildly with staying purely passive. The rate is the thing you lack, and passively it arrives at one event per 11 days.

A script that sends one harmless HCI command every 6 s lets the controller autosuspend 2 s later and be host-resumed on the next command: about 600 cycles an hour, with step 3 armed. If the per-cycle rate is 0.5 % or more, an hour reproduces it with 95 % probability. It issues no reset. It costs a power-off if it hits, and it is short. An hour with no failure is also a result: it says host-initiated resumes alone are not enough, which points back at remote wakeups, as in the MediaTek reproduction.

### 7. QEMU or another machine

Agreed, no. The fault needs this chip on a real bus with real suspend signalling.

## Sources

### Code and commits (read from git)

| Commit | Mainline | Subject |
| --- | --- | --- |
| `86c57edf60f5` | 2008 | USB: use reset\_resume when normal resume fails |
| `7bee549e197c` | 2009 | Bluetooth: Add USB autosuspend support to btusb driver |
| `fd865802c66b` | 2017 | Bluetooth: btusb: fix QCA Rome suspend/resume |
| `7d06d5895c15` | 2017 | Revert of the above |
| `61f5acea8737` | v4.16-rc1 | Bluetooth: btusb: Restore QCA Rome suspend/resume fix with a "rewritten" version |
| `1fdb92697469` | v4.16-rc5 | Bluetooth: btusb: Use DMI matching for QCA reset\_resume quirking |
| `fc54910280eb` | v4.17-rc5 | Bluetooth: btusb: Only check needs\_reset\_resume DMI table for QCA rome chipsets |
| `e2bef3847e3d` | 2019 | Bluetooth: Allow driver specific cmd timeout handling |
| `582ee9c5ad26` | 2019 | USB: Disable USB2 LPM at shutdown |
| `6933568aec92` | 2020 | Bluetooth: btusb: Reset port on cmd timeout |
| `161510ccf91c` | v5.17-rc1 | Bluetooth: hci\_sync: Make use of hci\_cmd\_sync\_queue set 1 |
| `c9209b269afd` | 2022 | Bluetooth: btusb: Introduce generic USB reset |
| `4baf12181509`, `24be0b3c4059` | 2023 | xhci: Loosen RPM as default policy to cover for AMD xHC 1.1, and its revert |
| `7c393421755d` | 2025 | Bluetooth: Remove the cmd timeout count in btusb |
| `f07d478090b0` | 2025 | Bluetooth: Get rid of cmd\_timeout and use the reset callback |
| `e31d761628ad` | v7.2-rc1 | Bluetooth: btmtk: Disable remote wakeup for MT7922/MT7925 |
| `dc16388d45ec` | v7.3-rc1 | Bluetooth: btusb: Add IMC Networks QCA9377 to quirks table |
| `dcaf83ead130` | v7.3-rc3 | Bluetooth: Properly disable remote wakeup for MT7922/MT7925 on Ryzen platform |
| `c93922dd316b` | v7.3-rc3 | Bluetooth: btusb: Fix leaked runtime PM reference in btusb\_reset |
| `be58267a34ae` | 2026-09 | Bluetooth: btusb: Build the driver from multiple source files |

### Mailing lists and bug trackers (pages opened)

- [PATCH: btmtk: Disable remote wakeup for MT7922/MT7925](https://lkml.rescloud.iu.edu/hypermail/linux/kernel/2606.0/04311.html)
- [Re: the same, author's reply to MediaTek's revert request](https://lkml.iu.edu/2606.3/04802.html)
- [Re: PATCH v2, Properly disable remote wakeup ..., reboot without power cycle](https://lkml.iu.edu/2607.0/11619.html)
- [Re: PATCH v2, affected machines](https://lkml.iu.edu/2607.3/01067.html)
- [Launchpad #1757218, QCA9377 isn't being recognized sometimes](https://bugs.launchpad.net/bugs/1757218)
- [Red Hat Bugzilla 1514836, QCA ROME and autosuspend](https://bugzilla.redhat.com/show_bug.cgi?id=1514836)

### Seen in search results only, not opened

- [Re: PATCH v1, maintainer's scope objection](https://lists.infradead.org/pipermail/linux-mediatek/2026-June/108931.html)
- [Re: PATCH v2, MediaTek's reply](https://lkml.iu.edu/2607.3/00574.html)
- [linux-bluetooth, Intel AX211 lost after suspend/resume](https://ratatoskr.run/linux-bluetooth/2026/03/9704999/t)
- [Framework forum, Bluetooth restarts on 11th gen](https://community.frame.work/t/responded-bluetooth-restarts-on-ubuntu-kernel-6-5-0-14-11th-gen/42081)
- [ublue-os/bluefin #4728](https://github.com/ublue-os/bluefin/issues/4728) and [mediatek-mt7927-dkms #110](https://github.com/jetm/mediatek-mt7927-dkms/issues/110)

Treat the last group as leads. Each needs reading before it is cited anywhere.

---

## The reviewer's closing summary

The review is written up in the BT-17 source review doc linked above: H1 yes, H2 yes, H3 only half.

* H1: the first reset is the USB core's reset-resume retry after a 5 s `GET_STATUS` timeout. Your "unexplained 0.24 s" is the xHCI's own 40 ms resume drive plus the 110 ms port reset that precedes the log line.
* H2: your own log proves the block: no `cmd_cnt … cmd queued` line appears between 178.731 and 186.083, although three commands were queued on that ordered workqueue.
* H3: the MediaTek commit's debug log shows the same sequence as yours, including the 5 s. But its Ryzen condition was a scoping compromise, not a diagnosis, and ROME has its own record of this end state on Intel machines.

Two limits on what I read:

* Ubuntu tree not read. `git.launchpad.net` is blocked from here, so every line number is mainline v7.0. Stable 7.0.14 leaves `hub.c`, `driver.c`, `runtime.c` and `xhci-hub.c` untouched; Ubuntu's own patches to them are unchecked.
* Outside reports are thin. lore and the kernel bugzilla were not searched, and several links in the doc are marked as seen in search results only.

One thing to check on your side: the public README of `qca9377-bt-hang` still describes autosuspend as pinned off, which the brief says is not the case. If that mitigation was removed around when the device-table entry went in, there is no ROM-firmware baseline for suspend cycles.
The next step I'd take is arming `hub.c`/`driver.c` dynamic debug and usbmon on bus 3 now, so a recurrence is decisive. The doc has the commands.
