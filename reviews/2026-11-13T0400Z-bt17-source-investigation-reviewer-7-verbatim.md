# BT-17 source investigation — the seventh outside reviewer's answer

*Received 2026-11-13 in answer to `2026-11-13T0003Z-bt17-source-investigation-task.md`: a full
report and a covering message, both kept as received. Omitted, each marked in place:*
- *the covering message's link to the reviewer's working file;*
- *the reviewer's note on its environment's fetch limits;*
- *the tracking parameters in the covering message's links.*

*No finding was added or changed. What we checked on 2026-11-13, and what holds:*

- **The Ubuntu source the review reconstructed is the one that ran.**
  - Both input hashes match `linux-hwe-7.0_7.0.0-42.42~24.04.1.dsc` in our `cache/ubuntu-src/`
    (`sha256sum` of our `.diff.gz`: `ab5b2722…b076`).
  - The diff sets `SUBLEVEL = 14`, as the review says.
  - Four of the appendix's fingerprints match our own `-42` tree (`cache/ubuntu-7.0.0-42/`)
    exactly: `btusb.c`, `hci_core.c`, `hci_sync.c`, `mgmt.c`. The other files are outside that
    tree and were not compared.

  So the review's line numbers are the running source's.
- **The 5,200 ms count and the 91 ms remainder** agree with the sixth review and our check of
  `hub_port_init()`.
- **The two qualifications of the brief hold in the source:**
  - `hci_send_frame()` (`hci_core.c:3042-3080` in `-42`) copies the frame to the monitor before it
    tests `HCI_RUNNING` and before `hdev->send()`. The capture proves core send attempts, not
    driver entry.
  - In v7.0 `driver.c:1362-1372`, a reset-resume of a driver without `.reset_resume` only sets
    `needs_binding` (a `dev_dbg`). A missing `btusb_resume()` print alone therefore does not prove
    a failed device resume. The enumeration failures and the disconnect do.
- **The deferred-URB race candidate is real in the source, and not BT-17.** In `-42`:
  - `submit_or_queue_tx_urb()` (`btusb.c:2232-2252`) reads `BTUSB_SUSPENDING` under `txlock`,
    releases the lock, and only then anchors the URB on `deferred`;
  - `btusb_resume()` drains `deferred` and clears the flag under `txlock` (`:4774-4777`).

  A resume completing in that gap would leave the URB parked with the device active. As the
  review says, this is untested and does not fit BT-17, where no resume ran. It is to be
  registered as a candidate.
- **`b1f24c1ab523`** ("Bluetooth: hci_sync: don't drain cmd_sync backlog on unregister", Nguyen
  Ngoc Thang, 2026-09-27, first in v7.3-rc6):
  - absent from `-42`: `hci_cmd_sync_work()` at `hci_sync.c:304-339` loops with no unregister
    check;
  - **present in Ubuntu's `-43`**, which the laptop runs now (changelog line 490).
  - `eef1d74bf88f` (runtime PM `runtime_error`, 2026-07-06) is not in the `-43` changelog.
- **The cited commits exist with the subjects and dates given:**
  - `0983fb4799e7`, `1d10255c1c49`, `187f8b648cc1`, `f0e8c61110c2`;
  - `0c6e526646c0`, `596b07a9a226`, `939bc6c59e38`;
  - `e3d757dc9257`, `7e0ef4332ed9` (Mathias Nyman, 2026-08-06);
  - `008ee9eb8a11`, `ca69b7957bf2`.
- **`enable_autosuspend` is read once, at probe** (`btusb.c:4533-4534` in `-42`: `if
  (enable_autosuspend) usb_enable_autosuspend(data->udev);`). Writing the module parameter later
  changes nothing for a bound device, as the review says.
- **Where this review is behind the others:**
  - **The xHCI fix.** "I found no verified later patch that fixes this exact Address
    Device/Evaluate Context sequence". The third review found one, and we verified it: "usb:
    xhci: Fix ep0 maxpacket update on enabled slots", queued 2026-11-09. Our log matches its
    description step by step (third review's header).
  - **The MGMT mapping.** The exact introducing commit, which this review left open, is
    `161510ccf91c` (third review's header).
  - **`_PRR`.** This laptop's ACPI tables define no `_PRR` (second review's header), so the
    `-42` power-cycle step was a port power switch only.
- **Not checked here:** the external reports and list threads, and `driver.c:1958-1968`'s
  autosuspend rule for reset-resume devices.

---

# BT-17 — source investigation

Reviewed 2026-11-13. Incident evidence: the supplied E1–E9 brief. No commands were executed on the laptop and nothing was submitted upstream.

## Findings

| Question | Finding | Confidence and boundary |
|---|---|---|
| H1: the first reset was USB runtime-resume recovery | **Yes as the leading reconstruction; not established as a fact.** A failed post-resume GET_STATUS followed by USB-Persist reset-resume fits both the ordering and elapsed time. | Strong fit. Neither the failed request nor the reset caller was captured. A remote-wakeup-started resume or the disabled-port reset-resume branch remains possible. |
| H2: the HCI timeout callback blocked in runtime PM, then failed without issuing its USB reset | **Yes.** The callback is synchronous, the error precedes credit restoration, and its reset-queueing message never appears. | High for the callback/credit ordering and absence of a btusb-queued reset. The precise PM wait and the particular `-EBUSY` return site remain inferred. |
| H3: this is the same Ryzen remote-wakeup defect as MT7922/MT7925 | **Not demonstrated.** It is a reasonable mitigation hypothesis, not yet a device-family or host-controller diagnosis. | Low as a shared root cause; sufficient justification for a controlled autosuspend-off observation period. |
| Authentication Failed | A misleading kernel error conversion, not an authentication exchange. | Certain from `mgmt_class_complete()` and `mgmt_errno_status()`. |
| Frame #122 | A core send attempt during teardown, not proof of a USB transfer to a freed device. | Certain about the monitor placement; actual driver/URB disposition was not recorded. |

The review supports a failure **below the ordinary btusb interface-resume callback**, with the HCI timeout as a consequence. It does not distinguish controller firmware, its USB PHY/power domain, platform power handling, and xHCI resume signalling. The reset/re-enumeration errors describe failed recovery; they do not identify what originally broke the resume.

## Sources actually read and reproducibility

I cloned the Linux Git history and checked out mainline **v7.0**, commit `028ef9c96e96197026887c0f092424679298aae8`. I also downloaded the exact Ubuntu source package, reconstructed the relevant directories using its distribution patch with `patch --fuzz=0`, and read the resulting files. This closes the brief's unexamined Ubuntu USB/PM-delta gap.

The Ubuntu source package is `linux-hwe-7.0 7.0.0-42.42~24.04.1`, from the [Ubuntu package mirror](https://na.edge.kernel.org/ubuntu/pool/main/l/linux-hwe-7.0/):

| Input | SHA-256 |
|---|---|
| `linux-hwe-7.0_7.0.0.orig.tar.gz` | `c6343795c8c7e4feff55f5b309365c8e0eaf49cd6abcb412e32315313f149536` |
| `linux-hwe-7.0_7.0.0-42.42~24.04.1.diff.gz` | `ab5b2722d3d4bd00a97f4f048f1dc2d8a50cdbbc7ed868aac4ffc59bb516b076` |

Both match the package's `.dsc`. The patched Makefile reports a 7.0.14 sublevel; this package is not interchangeable with unmodified v7.0. Unless expressly marked otherwise, line references below mean **that reconstructed Ubuntu source**, before the user's separately stated one-entry btusb device-table addition. References to the supplied btusb function lines agree with it. I accept the stated one-entry-only module delta; I did not reproduce the module binary.

For later changes I inspected the fetched mainline snapshot **`7e1392a42ea288d70a266f6553fe06f57f8647ea`**, dated 2026-11-12. At that snapshot btusb has been split/renamed; relevant legacy code is in `drivers/bluetooth/btusb_main.c`. “Still present on mainline” in this report means that fixed snapshot, not an indefinitely moving branch.

History work included targeted `git log -S`, Git commit diffs, and attempted line blame. Two completed pickaxe checks identify `86c57edf60f5` for `retry with reset-resume` and `7c393421755d` for removal of `cmd_timeout_cnt`. Full older-file blame required additional lazy-fetched objects and did not complete; unresolved provenance is explicitly identified below rather than replaced with guessed commits.

I read upstream BlueZ **5.72** `src/adapter.c` and `src/shared/mgmt.c`. I did not reconstruct Ubuntu's complete BlueZ delta or the two unspecified local crash fixes, so those BlueZ line references are upstream 5.72 only. The supplied MGMT capture independently establishes the userspace trigger. I did not inspect or decode the exact compressed firmware payloads; a firmware-content diagnosis would require that additional work and documentation of the USB NVM format.

## 1. Origin of the first USB reset

### Code and ordering

| Code location | What it establishes |
|---|---|
| `drivers/bluetooth/btusb.c:2232`, `submit_or_queue_tx_urb()` | While `BTUSB_SUSPENDING` is set, anchors the URB on `deferred`, schedules `waker`, and returns success without submitting it. |
| `btusb.c:2478`, `btusb_waker()` | Calls synchronous `usb_autopm_get_interface()`; a negative result is silently returned. |
| `btusb.c:4622`, `btusb_suspend()` | With no connection/discovery and no applicable wakeup quirk, the open controller can autosuspend. Sets `BTUSB_SUSPENDING` and stops RX traffic. |
| `btusb.c:4726`, `btusb_resume()` | Debug print at 4732 precedes its conditional exits; successful ordinary resume eventually drains deferred URBs and clears `BTUSB_SUSPENDING` at 4774–4777. |
| `drivers/usb/core/driver.c:1541`, `usb_resume_both()` | Resumes the USB device before attempting interface resume. Failure of the former prevents the ordinary btusb resume callback. |
| `driver.c:1867`, `usb_autopm_get_interface()` | Synchronously obtains a runtime PM reference through `pm_runtime_resume_and_get()`. |
| `drivers/usb/core/hub.c:3798`, `usb_port_resume()` | Performs port resume, reads port status, checks resume type, calls `finish_port_resume()`, and logically disconnects on failure. |
| `hub.c:3636`, `finish_port_resume()` | On a normal resume, issues device GET_STATUS. On error, if persist is enabled, changes to reset-resume and calls `usb_reset_and_verify_device()`. |
| `hub.c:6189`, `usb_reset_and_verify_device()` | Reinitializes the device using `hub_port_init()` with retry attempts; failure leads to logical disconnection. |
| `hub.c:4907`, `hub_port_init()` | Performs the port reset at 4944; only afterward prints the familiar `reset full-speed ...` message at 5001–5004. |

The predicted sequence is: #121 consumes HCI command credit, its URB is deferred, the waker enters runtime resume, the USB device fails its post-resume check, USB-Persist tries reset-resume, enumeration fails, and logical disconnect wakes/terminates the parallel PM waiter in the HCI timeout callback. Nothing here requires an HCI command to have reached the controller.

**Important qualification:** no `btusb_resume()` print proves that this callback did not run, assuming complete enabled debug output. It does **not**, by itself, prove that every possible device-level resume failed. In `driver.c:1366–1375`, a successful reset-resume with a driver lacking `.reset_resume` marks the interface for rebinding instead. Ubuntu btusb has no `.reset_resume`, `.pre_reset`, or `.post_reset` callback. The enumeration failures and disconnect in E3, rather than the missing callback alone, establish failed recovery here.

The H1 interpretation also assumes that the failing boot had persist enabled. Its later-boot value is consistent with the normal policy, but is not a measurement of the earlier boot.

### The 5.291 seconds

There is more fixed delay before the printed reset than the brief counted. For the normal host-initiated USB2 path with the port initially in U3, the source gives:

| Stage | Nominal delay | Location |
|---|---:|---|
| xHCI ClearPortFeature(SUSPEND), signal resume then U0 | 40 ms | `drivers/usb/host/xhci-hub.c:1568–1585` |
| USB hub resume wait | 40 ms | `hub.c:3837`; `USB_RESUME_TIMEOUT` in `include/linux/usb.h` |
| Resume recovery | 10 ms | `hub.c:3860` |
| Unanswered GET_STATUS | 5000 ms | `finish_port_resume()` → `usb_get_std_status()` → control message, `USB_CTRL_GET_TIMEOUT` |
| Root-port reset polling interval | 60 ms initially | `hub_port_init():4931–4944`, `HUB_ROOT_RESET_TIME` |
| Reset recovery before enumeration/logging | normally 50 ms | `hub_port_reset()`: 10 ms plus the customary 40 ms, subject to its fast-enumeration/slow-reset conditions |
| **Nominal subtotal before the reset print** | **5200 ms** | |

The observed interval is 5291.467 ms. That leaves about **91 ms**, not an unexplained fixed 240 ms. Scheduling, timer rounding/slack, lock acquisition, host-controller commands and additional port polling can account for such a difference; these logs cannot apportion it. A timeout argument of 5000 ms does not promise a timestamp exactly 5.000 seconds later.

`wait_for_connected()` (`hub.c:3743–3761`) is a conditional loop in 20 ms increments, up to 2 seconds. If the connect bit is already set, it adds no sleep. There is no unconditional 240/250 ms wait there. A parent/root-hub runtime resume can add other time; its state was not captured. A remote-wakeup path need not take precisely the same waits as the host U3→resume path.

### Alternative paths and their logging

| Alternative | What the source/logs permit |
|---|---|
| GET_STATUS error → persist reset-resume | Best timing fit; `retry with reset-resume` is `dev_dbg`, so absent at the recorded debug settings. An error other than `-ETIMEDOUT` can also select this branch; duration alone cannot prove the errno. |
| Disabled port detected during resume | `check_port_resume_type()` (`hub.c:3290`, relevant branch 3321–3325) can select reset-resume when persist is enabled, before GET_STATUS. Also mostly debug-only. Would need another explanation for the five-second interval. |
| Remote wakeup initiated resume | `hub_handle_remote_wakeup()` / `usb_remote_wakeup()` around 3905/3887 can enter autoresume. No mandatory default-level notification identifies that initiator. A near-coincident remote wake could beat the waker into PM. |
| Hub port change / reconnect | Several change bits are handled without default messages. A plain disconnect/re-enumeration normally produces a disconnect and **new** device message; it does not by itself explain resetting the still-numbered device 2. The persist/suspended-device branch of connect-change handling can, however, enter resume recovery. |
| Classic EMI re-enable branch | `port_event()` prints `disabled by hub (EMI?), re-enabling...` at default error level near `hub.c:5801`. Its absence argues against that particular branch, not against every possible port-status event. |
| Another caller of `usb_reset_device()` | There is no universal caller-name/reset-reason print. It first calls `usb_autoresume_device()` at 6407: thus another reset requester can itself encounter a failing autoresume. If it proceeds to an ordinary explicit reset, btusb's missing pre/post-reset callbacks cause forced unbind at 6415–6423, normally producing btusb disconnect/unregister debug before `hub_port_init()`. Those prints are absent before the first reset. |
| SuperSpeed warm-reset recovery | Not the applicable port path for this full-speed USB2 child. |

Therefore, **“no `Resetting usb device.`” excludes btusb's own successful queueing path, not every possible source of a USB reset.**

### USB and xHCI errors

`-71` is `-EPROTO`. In this path it can represent a failed USB transaction; descriptor validation can also reject a returned descriptor with protocol error. The text `device descriptor read/64` is insufficient to tell whether the device was silent, returned malformed data, or suffered a link/host transaction error.

`xhci_setup_device()` (`drivers/usb/host/xhci.c`, relevant switch at 4420–4458) handles an Address Device USB-transaction-error completion by warning that the device did not respond, disabling/freeing the slot, trying to allocate a new one, and returning `-EPROTO`. This is materially below HCI and does not say the controller decoded Write Class of Device.

**Completion code `0x11` is xHCI Parameter Error (decimal 17), not Context State Error.** In this switch it reaches the unexpected-completion branch and returns `-EINVAL`, explaining the subsequent `error -22`. The separate Evaluate Context warning is generated for Context State Error, decimal 19 / hex `0x13`, by the context-command completion handling near `xhci.c:2174–2200`.

The latter two errors describe host-controller command/context state. They are not device firmware status bytes. They may be secondary to a failed transaction and slot replacement, or expose weak error recovery. There is insufficient command-ring/slot-context evidence to declare either a specific xHCI defect or harmless consequences. I found no verified later patch that fixes this exact Address Device/Evaluate Context sequence on `1022:1639`.

Later mainline `e3d757dc9257` and `7e0ef4332ed9` change endpoint recovery after root-port link loss/disconnection. They are not in this Ubuntu xHCI implementation and do not establish the initiating failure here. Their stated target is avoiding unnecessary endpoint state transitions and host hangs after link loss; the later family also attracted regression reports. Do not treat upgrading to that code as a proven BT-17 fix.

### Ubuntu delta and power recovery

`drivers/base/power/runtime.c` and the relevant `xhci-hub.c` resume path are unchanged from v7.0. Other USB files are **not** identical. Most importantly, Ubuntu adds **ACPI `_PRR` reset during enumeration-failure port power cycling**: `hub.c:5616` calls `usb_acpi_port_prr_reset()`, implemented in `drivers/usb/core/usb-acpi.c:163–211`.

That helper finds the port's ACPI object and `_PRR` reference, then invokes the referenced reset resource's `_RST`. If the ACPI objects are absent, it cannot do so. The default `attempt power cycle` line proves neither the presence of `_PRR` nor success of `_RST`, and proves nothing about the card's actual 3.3 V rail. This Ubuntu addition is relevant to the **later recovery attempt**, not to the first reset at 184.023. I verified the patch contents; I did not resolve a unique Ubuntu Git commit hash for this source-package hunk.

A root-port power operation need not remove power from a self-powered M.2 function. Warm reboot can likewise preserve its supply or a platform/PHY state. Consequently, “port reset and attempted port power cycle failed; power-off worked” is plausible. It does not prove that only the Bluetooth firmware was latched: host/platform power domains are also candidates. Wi-Fi working shows the PCIe function remained usable, not that Bluetooth's power/reset state was healthy.

### History, remedy, decisive observation

[`86c57edf60f5`](https://github.com/torvalds/linux/commit/86c57edf60f5c98adb496880f56cd0e5a3423153), Alan Stern, 2008, introduced fallback to reset-resume after normal resume failure, and the disabled-port persist fallback. Its reason was making USB-Persist recover where normal resume previously failed irrecoverably, citing kernel bug 10977. [`1d10255c1c49`](https://github.com/torvalds/linux/commit/1d10255c1c49) later prevented this fallback for devices carrying `USB_QUIRK_RESET`. The essential persist fallback remains in the inspected current mainline.

The USB core is executing an intentional recovery policy. Nothing observed proves that changing its timeout or eliminating reset-resume would repair the initiating failure. A narrow btusb autosuspend avoidance is a mitigation; a confirmed bad resume sequence belongs in xHCI/platform code, and a controller that mishandles correct signalling needs firmware/vendor action.

**Decisive observation:** one naturally occurring recurrence with USB core debug, bus-3 usbmon and xHCI port/command tracing. A GET_STATUS submission after resume, completion `-110`, `retry with reset-resume`, and the reset caller stack would establish the central H1 branch. A port-disabled fallback, early remote-wakeup event, different caller, or successful GET_STATUS would falsify or refine H1. Software tracing distinguishes these branches; only bus-level electrical evidence/vendor analysis can finally distinguish faulty signalling from a device ignoring correct signalling.

## 2. The blocking HCI timeout reset

`net/bluetooth/hci_core.c:1462–1482` calls `hci_cmd_sync_cancel_sync(hdev, ETIMEDOUT)` and then **calls `hdev->reset(hdev)` directly**. It restores `cmd_cnt` and queues `cmd_work` only after that call returns.

ROME probe (`btusb.c:4400–4407`) installs `btusb_qca_reset()`. With no reset GPIO and no active ramdump, that function (`1173–1207`) reaches `btusb_reset()` (`1032–1050`). The latter calls `usb_autopm_get_interface()` **before** its “Resetting usb device.” print and `usb_queue_reset_device()`. On error it emits the supplied failure message and returns immediately.

The core's runtime PM implementation supplies the matching wait:

- `drivers/base/power/runtime.c:825–864`: a synchronous resume waits while a transition is already in progress.
- `runtime.c:915–919`: it resumes an enabled, non-ignoring parent; if that parent is still not `RPM_ACTIVE`, the child returns `-EBUSY` rather than passing through the parent's precise failure code.
- Failed callback handling returns the device to `RPM_SUSPENDED` and wakes waiters.

This exactly explains the delayed `Failed usb_autopm_get_interface: -16`, followed 12 microseconds later by restored credit/command work. The 1 microsecond relation to the USB disconnect printk is not a lock-order proof: different CPUs/workers can run concurrently, and printk timestamps do not identify which PM waiter woke first.

The callback is allowed to sleep; it runs in process context. That does not make its latency inconsequential. `hdev->workqueue` is an ordered workqueue (`hci_core.c:2605`); `req_workqueue` is separate (`2611`). While the timeout worker blocks, other work on the former—including RX, TX and command work—cannot run. Request work can continue, expire waits and enqueue more commands, matching the intervening `Opcode ... failed` lines without additional TX-timeout messages.

The sync wait at `hci_sync.c:155–200` does not erase an already queued HCI command when its waiting caller times out. Thus there are two different notions of timeout here: the driver's outstanding-command watchdog and subsequent synchronous requests expiring while waiting behind it. They must not be counted as four independent on-wire HCI failures.

**Could PM block for another reason?** Yes: an ongoing suspend/resume, an ancestor/root-hub/HCD transition, a callback or port-lock wait. H2 does not uniquely identify the GET_STATUS wait. The precise parent-check attribution is strongly consistent with `-16` and the common completion time, but needs return/caller tracing. If the device and its ancestors were already active and uncontended, this path should pass PM acquisition promptly and print the reset-queueing message. The observed omission contradicts that simple active-device reset account.

### Reset-policy history

| Commit | Change and stated reason | Relevance |
|---|---|---|
| [`6933568aec92`](https://github.com/torvalds/linux/commit/6933568aec92dd6432207baaf59378d01f55a14f), 2020 | Added QCA ROME command-timeout USB-port reset when no reset GPIO existed; originally after five timeouts. | Its [submission discussion](https://lkml.rescloud.iu.edu/2006.3/01095.html) describes Chromebook suspend stress failures after hundreds of cycles. Reset removed the failed device from further suspend testing but did not reliably recover it; power cycling was still needed. No exact USB ID, host PCI ID or released kernel version is stated there. |
| [`c9209b269afd`](https://github.com/torvalds/linux/commit/c9209b269afd29c55b8be49916725ed469f8c5d9), 2022 | Factored a generic USB reset fallback and used it for controllers lacking a GPIO. | Introduced the present shared PM-get/queue helper shape. |
| [`7c393421755d`](https://github.com/torvalds/linux/commit/7c393421755daf35ae1e4e0016b99f308123751a), 2025 | Removed the five-timeout counter. Reason: only one command is allowed in flight, so reset after one timeout. | This is the specific first-timeout policy change. |
| [`f07d478090b0`](https://github.com/torvalds/linux/commit/f07d478090b0a03dda46fb45b5c6e089a8408351), 2025 | Replaced the `cmd_timeout` callback with `reset`, preparing a reusable/sysfs reset interface. | Renaming/restructuring was intended to preserve behavior. |
| [`0983fb4799e7`](https://github.com/torvalds/linux/commit/0983fb4799e7), 2025 | Fixed possible recursion in the reset helper following that conversion. | The old recursive form is absent from the running source. |
| [`c93922dd316b`](https://github.com/torvalds/linux/commit/c93922dd316b7273a8667d29084632066fa8a2d3), 2026 | Balanced the PM reference across reset/unbind using `BTUSB_RESET`. | Already backported in Ubuntu 42. H2 returns before this successful-PM-get path, so the leak cannot explain this occurrence. |

The synchronous call-before-credit ordering remains in current mainline `hci_core.c:1431–1450`; legacy QCA reset remains in `btusb_main.c`. The GPIO branch is a later addition, but its introducing hash was not independently established in this review.

The policy is defensible as a generic recovery attempt, but **a two-second HCI deadline can expire while a legitimate five-second USB resume check is still outstanding**. That is a timeout-domain mismatch worth measuring. The original QCA report and your controlled tests also undermine any assertion that USB reset is a reliable cure for a wedged ROME controller.

A more robust design would separate pending transport resume, command submission, command-response timeout and recovery. Recovery should not block unrelated HCI processing indefinitely, and stale requests should not be replayed merely because credit is restored. That requires coordination between btusb and the Bluetooth core; simply moving the reset to another workqueue while immediately restoring credit risks making ordering worse. No such design is proved necessary to fix this device's initiating failure.

**Decisive observation:** record entry/exit timestamps and return values for `btusb_reset()`, its PM acquisition, the parent's runtime-resume callback, and `hci_cmd_timeout()`. H2 is falsified if the long gap is outside this PM call, or if `usb_queue_reset_device()` is actually reached. The existing prints already make the latter very unlikely.

## 3. Ryzen remote-wakeup hypothesis and older ROME quirks

### What the MediaTek history actually establishes

[`e31d761628ad`](https://github.com/torvalds/linux/commit/e31d761628ad7e96490fc78105ed0a064ec1c1d9) describes **remote-wakeup-driven** failure: the trace contains a wakeup-resume event; the HCI device was open without active Bluetooth connections; USB requests subsequently stopped completing normally. The author reported failures in radio-busy environments and no cure from longer resume-recovery delay or forcing reset handling. This is stronger evidence of a remote trigger than BT-17 has.

[`dcaf83ead130`](https://github.com/torvalds/linux/commit/dcaf83ead130d3067862599089b0999b3da140a4) moves the workaround to btusb's runtime-suspend gate and restricts it to MT7922/MT7925 on Zen platforms directly attached to a root hub. It preserves requested **system** wakeup instead of globally revoking device wakeup capability. See the [v3 discussion](https://lists.infradead.org/pipermail/linux-mediatek/2026-September/112516.html).

The actual Ubuntu code is `btusb_mtk_setup():3022–3023` setting `BTUSB_WAKEUP_BROKEN`, consumed by `btusb_suspend():4645–4649`. It does not run for QCA ROME. The quirk is a workaround, not a demonstrated attribution of the defect to all AMD root hubs.

### Independent reports found

| Report | Device/platform/kernel stated | Observation and autosuspend result | Match to BT-17 |
|---|---|---|---|
| [2020 QCA reset submission](https://lkml.rescloud.iu.edu/2006.3/01095.html) | QCA ROME Chromebooks; exact ID/host/kernel unstated | Repeated suspend stress produced an unresponsive controller; port reset did not reliably restore it; power cycle needed. No autosuspend-off comparison. | Strong QCA recovery analogy; not evidence for Ryzen or this runtime path. |
| [Fedora bug 1514836](https://bugzilla.redhat.com/show_bug.cgi?id=1514836) | Lenovo Yoga 920, QCA ROME `0cf3:e300`, `4.15.0-0.rc0.git5.1.fc28`; later Dell XPS 13 9360 QCA6174/Killer 1535, `4.16.0-0.rc6.git0.2.fc28` | Yoga's original autosuspend regression improved with `btusb.enable_autosuspend=n`; later the blanket workaround was found unnecessary for Yoga. The Dell reporter described roughly 1.5 weeks without idle disappearance with autosuspend disabled, while system-suspend failures remained. | Useful runtime-vs-system distinction; Intel platforms, not `1022:1639`. |
| [QCA6174 firsthand investigation](https://billauer.se/blog/2019/07/qualcomm-atheros-qca6174-bluetooth/) | `0cf3:e300`, Intel X299 AORUS Gaming 7, Mint 19, `4.15.0-20` | Bluetooth absent after reboot while Wi-Fi worked; removal of power restored it. No controlled autosuspend comparison. | Similar retained failure; different platform and unproved trigger. |
| [MediaTek mailing-list follow-up](https://lkml.iu.edu/2607.3/08600.html), [topology](https://lkml.iu.edu/2607.3/08525.html) | MT7925/RZ717; AMD 800-series chipset xHCI `1022:43fc`; kernel version not established in these messages | Failure/recovery discussion corroborates AMD chipset relevance, not just SoC USB. [Another follow-up](https://lkml.iu.edu/2607.3/08144.html) reports non-reproduction even without the patch after BIOS changes. | Supports caution about platform/BIOS confounding; not an exact host match or clean quirk A/B. |
| [Arch report](https://bbs.archlinux.org/viewtopic.php?id=308169) | MT7922, ASUS TUF X670E-PLUS WIFI, Ryzen 9900X, `6.16.5-arch1-1` | USB Bluetooth disappears; unplugging power helps. Multiple xHCI IDs appear in topology; no unambiguous mapping of missing Bluetooth to a particular one and no controlled autosuspend result. | Symptom/platform analogy only. |
| [Beelink report](https://bbs.bee-link.com/d/7694-gtr9-pro-ai-max-395-usb-issues) | GTR9 Pro AI Max 395; MT7925 `13d3:3604`; reports include Arch/NixOS `6.16.8`, Fedora `6.17.0-63`, NixOS `6.17.0` | Power removal reported as recovery. No verified autosuspend A/B or xHCI PCI ID. | Another MediaTek/Ryzen comparator; mixed issues in thread should not be conflated. |

I did **not** find an independently verified Linux report matching QCA9377/ROME + Ryzen + `1022:1639` + failed idle runtime resume + power-off-only recovery. Search hits about ath10k Wi-Fi crashes and Windows Bluetooth disappearance do not establish that match. This negative search result is not proof that such reports do not exist.

### xHCI and USB quirks

The reported xHCI quirk mask `0x0000020000000010` decodes to `XHCI_BROKEN_D3COLD_S2I` (bit 41) and `XHCI_SPURIOUS_SUCCESS` (bit 4), using Ubuntu `xhci.h:1637` and `1589`. The `1022:1639` match in `xhci-pci.c` applies the former for system suspend-to-idle power handling. It is not an “all USB2 runtime remote wakeup is broken” flag.

Other AMD matches in `xhci-pci.c` include suspend delays, Synopsys-related suspend handling, Raven2 handling and Promontory U2-wakeup handling. They have different device-ID and power-state scopes. USB3 U2 policy and USB2 hardware LPM are not explanations for an ordinary USB 1.10 full-speed suspend/resume merely because the host supports USB3.

I found no existing USB-core quirk that establishes the broad H3 claim. `USB_QUIRK_RESET` means avoiding reset, not disabling runtime suspend; `USB_QUIRK_RESET_RESUME` requests reset on resume and can indirectly block autosuspend. They are not interchangeable with `BTUSB_WAKEUP_BROKEN`, and none should be applied experimentally here as a substitute for understanding the failure.

### Scope of a possible workaround

If repeated observations establish that avoiding autosuspend eliminates this failure, the narrow initial case would be **`13d3:3503` plus the measured platform/topology condition**. Evidence for one ID does not justify all `BTUSB_QCA_ROME`, still less all btusb devices on Ryzen. A DMI match cannot identify this laptop usefully with `Default string` values.

Direct-child-of-root-hub says nothing by itself about whether the USB controller is on the CPU, chipset or an add-in card. The HCD's backing PCI device can be examined with appropriate subsystem/type checks; CPU vendor alone does not establish its identity. Matching AMD `1022:1639` would be more specific than all Zen hosts, but whether btusb should traverse that hierarchy or USB/xHCI should expose the condition is a maintainer design decision. The MTK patch's “too intrusive” comment explains the author's chosen compromise, not an impossibility.

A credible quirk proposal needs recurrence traces, verified bus/PCI topology and firmware/build identification, exposure measured in suspend/resume cycles, and a sufficiently long controlled autosuspend-off comparison. It must distinguish an idle-runtime problem from system resume and document the power cost. A second affected machine/ID would justify broadening scope. These are evidence requirements I would seek, not a promise of maintainer acceptance.

### ROME reset-resume history

| Commit | Effect |
|---|---|
| [`fd865802c66b`](https://github.com/torvalds/linux/commit/fd865802c66b), 2017 | Added broad ROME reset-on-resume handling for firmware lost across suspend. |
| [`7d06d5895c15`](https://github.com/torvalds/linux/commit/7d06d5895c15), 2017 | Reverted the mechanism after reset during open/resume interfered with firmware loading. |
| [`61f5acea8737`](https://github.com/torvalds/linux/commit/61f5acea8737), 2018 | Reintroduced it through the USB core's `USB_QUIRK_RESET_RESUME`, avoiding btusb-specific duplicate machinery; also stopped runtime autosuspend through USB core policy. |
| [`1fdb92697469`](https://github.com/torvalds/linux/commit/1fdb92697469), 2018 | Replaced all-ROME coverage with DMI matching: loss of power appeared platform-specific, and broad coverage imposed unnecessary power cost on working systems. |
| [`f0e8c61110c2`](https://github.com/torvalds/linux/commit/f0e8c61110c2), 2018 | Removed Yoga 920 after it proved to work without that quirk. |
| [`0c6e526646c0`](https://github.com/torvalds/linux/commit/0c6e526646c0), [`596b07a9a226`](https://github.com/torvalds/linux/commit/596b07a9a226), [`939bc6c59e38`](https://github.com/torvalds/linux/commit/939bc6c59e38) | Added Dell OptiPlex 3060, XPS 13 9360 and Inspiron 5565 respectively. |
| [`fc54910280eb`](https://github.com/torvalds/linux/commit/fc54910280eb) | Restricted the DMI check to QCA ROME. |

The current table is at `btusb.c:900–927`; `btusb_check_needs_reset_resume()` is at 3958. The laptop does not match. This history concerns platform power loss across suspend, but it **also affects runtime behavior**: `driver.c:1958–1968` prevents autosuspend when reset-resume is required and an interface lacks reset-resume support or needs remote wake. Therefore older “disabling autosuspend fixed it” reports cannot automatically be read as evidence of the newer MTK remote-wakeup mechanism.

**First experiment for H3:** a long observation period with only this USB device's `power/control=on`, using the same kernel/firmware/workload and recording cycle exposure before and afterward. It tests dependence on runtime suspend. Even a strong result would not distinguish remote-wakeup arming from host-initiated resume or firmware sleep behavior. No safe single software experiment on this daily-use machine can prove the entire cross-vendor H3 claim.

## 4. Controller firmware and recovery

The USB ROME path is in **btusb**, not the UART IBS/sleep setup in btqca:

| Ubuntu code | Role |
|---|---|
| `btusb.c:3455` onward, QCA device/version table | ROM `0x302` selects the USB rampatch/NVM files and header sizes. |
| `btusb.c:3520`, vendor request helper | Reads target version and download status. |
| `btusb.c:3537`, `btusb_setup_qca_download_fw()` | Sends the download header through a vendor control request, then bulk payload chunks, including the inter-stage delay. |
| `btusb.c:3606`, rampatch loader | Checks target/file version information and downloads the patch when required. |
| `btusb.c:3707`, NVM loader | Loads and transmits the USB NVM blob; does not parse individual sleep/remote-wakeup tags. |
| `btusb.c:3745`, `btusb_setup_qca()` | Sequences version/status checks, patch download, re-read and NVM download. |
| `drivers/bluetooth/btqca.c`, NVM parsing near 380–460 | Contains sleep/in-band-signalling handling for the other QCA transport setup. It is not evidence that the USB ROME path edits those tags. |

The inspected USB path does not explicitly select a documented deep-sleep/USB-wakeup NVM tag. That is a statement about host source, **not** proof that the downloaded NVM contains no such setting. Opaque firmware can absolutely change suspend/resume behavior relative to ROM. Neither the successful SCO fix nor earlier ROM autosuspend proves equivalence of their low-power implementations.

The setup print compares file patch version with the target's version before patching; it is not itself a complete firmware readback or proof of every NVM setting. The subsequent successful initialization and command traffic strongly support successful setup overall.

If endpoint zero cannot answer descriptor/address requests, a vendor command over that same failed USB transport is not a credible recovery method. The source offers an out-of-band GPIO reset when the platform supplies one; this laptop does not. The USB shutdown HCI Reset path, introduced by [`187f8b648cc1`](https://github.com/torvalds/linux/commit/187f8b648cc16f07c66ab1d89d961bdcff779bf7), also needs a functioning transport. Later shutdown-helper refactoring does not create an out-of-band recovery mechanism.

There is no generic btusb→ath10k reset of the entire combo card in this path. Separate PCIe Wi-Fi reset operations do not demonstrate control of Bluetooth's reset/power domain. ACPI `_PRR` is a possible platform facility already attempted by the Ubuntu enumeration-recovery code if present; passive inspection of ACPI tables and the port's firmware-node association can establish whether it exists. Do not invoke undocumented ACPI methods or reset the Wi-Fi function as an experiment.

**Fix location:** firmware/vendor or platform power sequencing if correct USB signalling leaves the controller wedged; btusb for a narrowly evidenced avoidance quirk; xHCI for demonstrated incorrect host signalling/context handling. **First controller-side investigation:** preserve the exact uncompressed firmware hashes and inspect the USB NVM format with authoritative vendor documentation. A ROM-vs-patched destructive A/B is neither necessary nor suitable for this laptop.

## 5. Misleading status and the late command

### Authentication Failed

`remove_uuid_sync()` (`mgmt.c:2855`) updates Class of Device, then EIR. `mgmt_class_complete()` (`2768–2777`) converts its result through `mgmt_status(err)`. `mgmt_errno_status()` (`286–310`) maps `-ETIMEDOUT` to `MGMT_STATUS_AUTH_FAILED`. That fully accounts for the four misleading responses without any pairing attempt.

Upstream BlueZ 5.72 merely reports the returned status (`src/adapter.c:1146–1154`). `remove_uuid():1169–1190` queues MGMT Remove UUID; `src/shared/mgmt.c:227–260` serializes normal requests behind a pending request. This explains why the userspace requests advance approximately once per kernel timeout.

The mapping is still present in inspected mainline `mgmt.c:284–310`; later additions for cancellation/rfkill do not change `-ETIMEDOUT`. `MGMT_STATUS_TIMEOUT` already exists and is used for several positive HCI timeout status values. A host command timeout being labelled authentication failure is semantically wrong here. A command-specific `TIMEOUT` or generic `FAILED` response belongs in Bluetooth MGMT/core code, not bluetoothd; a global errno-map change needs an audit of pairing/security callers and the MGMT API's command-specific permitted statuses.

**History limitation:** `ca69b7957bf2` (2011) introduced the independent MGMT error hierarchy, but it did **not** introduce this later errno-conversion function. The supplied mapping is absent in the v5.15 source I read and present in the late-2021 HCI-sync conversion merge `b32563b6ccba`. I did not finish identifying and reading the exact introducing non-merge commit, so I cannot responsibly provide a specific rationale for choosing AUTH_FAILED. It should not be described as a documented authentication-timeout policy on the evidence reviewed here.

**Decisive experiment:** use a virtual HCI controller/test transport that deliberately never completes Write Class of Device and assert the returned MGMT status. This is a good VM test; it does not require physical USB failure.

### Frame #122

`hci_send_frame()` (`hci_core.c:3042`) sends to the monitor socket at 3053, **before** checking `HCI_RUNNING` at 3063 and calling the driver's `send` at 3077. Therefore the brief's statement “only two commands reach the driver” is stronger than the monitor evidence alone supports. It proves two core send attempts; it proves neither USB submission nor wire delivery.

At 186.083056 the timeout worker restores credit and enables a queued command. `hci_cmd_work()` near 4152 does not reject an skb merely because its original synchronous waiter has already expired. If this reaches btusb with `BTUSB_SUSPENDING` still set, it can simply be deferred again. The frame is also before the recorded `btusb_disconnect()`/`hci_unregister_dev()` entry at 186.083260. A USB disconnect print is not equivalent to having already freed `hdev` or `btusb_data`.

`hci_unregister_dev():2691–2742` sets `HCI_UNREGISTER`, removes the index, disables work/timers, clears sync work and closes the device before deferred final release. These lifetime measures make #122 insufficient evidence of a use-after-free. It is still worth fixing/validating stale-request behavior: after an unexpectedly successful resume, an expired request should not execute unnoticed or have its same-opcode completion attributed to a newer request.

A check of `HCI_UNREGISTER` in the timeout handler alone would not prevent this exact scheduling window: unregister had not yet entered. The transport-failure/recovery state and queue cancellation policy matter too.

**Decisive experiment:** in a virtual/test transport, hold command credit through several synchronous expiries, then release it and record which queued commands are submitted and which waiter consumes each completion. For the physical incident, usbmon plus send/deferred tracing determines #122's disposition without inducing a reset.

## 6. Additional findings

### A later unregister-backlog fix applies to adjacent behavior

Ubuntu 42's `hci_cmd_sync_work()` (`hci_sync.c:305–340`) drains its queued entries without checking `HCI_UNREGISTER`; `hci_cmd_sync_clear()` waits for it. Mainline [`b1f24c1ab523`](https://github.com/torvalds/linux/commit/b1f24c1ab52345e810c42a1a81286cb5a7c92252), September 2026, stops taking new entries during unregister and cancels the current wait with `ENODEV`. Its motivating report was a virtual-controller teardown blocked by a large backlog, each request taking a full HCI timeout. It fixes behavior introduced by `008ee9eb8a11`.

That fix is absent from the inspected Ubuntu 42 functions. It is relevant to the delayed index removal and is independently worth checking for Ubuntu 43/backport status. It cannot cause the preceding USB resume failure and does not prove a large backlog existed here. E3 is consistent with unregister waiting out the remaining fraction of the current two-second request. A virtual-controller regression test is appropriate; no laptop reset is needed.

### Runtime PM sticky failure changed later

Mainline [`eef1d74bf88f`](https://github.com/torvalds/linux/commit/eef1d74bf88f120f4f63a83a5201fcda67bf3b52), July 2026, moved sticky `runtime_error` assignment out of the general callback path and into suspend-failure handling. Its purpose was to allow retry after a failed runtime-resume callback instead of making future resumes immediately fail with `-EINVAL`. Ubuntu 42 retains the older implementation.

This can affect subsequent PM attempts, but it cannot explain a Bluetooth function that also fails fresh enumeration after reboot, and it does not establish the original failure. It must not be advertised as the BT-17 fix.

### A separate deferred-URB race candidate

There is an apparent synchronization gap between the suspend-state decision and deferred anchoring:

1. `submit_or_queue_tx_urb():2238–2242` observes `BTUSB_SUSPENDING` under `txlock`, then releases that lock.
2. A concurrent resume can drain the deferred anchor and clear the flag under `txlock` at 4774–4777.
3. The sender can then anchor its URB at 2247 and schedule the waker. If the interface is already active, that PM get need not call resume again, leaving the late URB deferred.

The same separation is present in current `btusb_main.c:2388–2407`. This is a source-level race candidate, not a reproduced defect in this review; it requires verifying the full reachable concurrency and a deterministic test. Crucially, it does **not** fit BT-17's missing resume callback if the debug record is complete. A fix, if reproduced, would make the suspend decision and deferred insertion atomic relative to resume's drain/clear operation, with the relevant USB-anchor lock ordering checked. Its introducing commit was not established here.

### The available knobs have different effects

The module parameter is writable, but `enable_autosuspend` is consulted when enabling autosuspend during probe/setup (`btusb.c:4533–4534`), not as a live veto in every suspend callback. Changing `/sys/module/btusb/parameters/enable_autosuspend` alone is not a reliable way to update the already-bound controller's current PM policy. Use this device's `power/control` for a live policy experiment, or the module/kernel option on a later normal boot. No reload is needed or proposed.

## 7. Experiments within the daily-use constraints

### First: one passive recurrence capture

Keep existing Bluetooth debug. Add the missing USB core debug without rebinding anything:

```sh
printf '%s\n' \
  'file drivers/usb/core/hub.c +p' \
  'file drivers/usb/core/driver.c +p' \
  'file drivers/usb/core/usb-acpi.c +p' |
  sudo tee /sys/kernel/debug/dynamic_debug/control >/dev/null
```

Use the actual dynamic-debug control mount on the machine if it differs. Record the previous settings so only the added flags are later reverted. Capture a bounded bus-3 usbmon ring during ordinary use; it records USB requests without issuing test transfers. Retain monotonic timestamps and the device address/generation because address numbers change during recovery.

In tracefs, first list available events and inspect their formats. Relevant events in the inspected source include `xhci-hcd:xhci_handle_port_status`, `xhci_get_port_status`, `xhci_portsc_writel`, `xhci_handle_command`, `xhci_handle_cmd_addr_dev`, `xhci_handle_cmd_reset_dev`, and USB URB enqueue/giveback events. Select only available events and filter by host/slot/port where their format permits. Use a bounded buffer or rotated capture rather than leaving all transfer events enabled indefinitely.

If supported, function/return tracing of `btusb_waker`, `usb_port_resume`, `finish_port_resume`, `usb_reset_and_verify_device`, `usb_reset_device`, `usb_remote_wakeup`, `btusb_reset`, and `hci_cmd_timeout` provides the missing caller and duration. Avoid assuming a static function is traceable on this build: inspect `available_filter_functions`. A short healthy natural cycle establishes the expected host-initiated trace and the measurement overhead.

The target evidence is: port U3/resume/U0 transitions; whether a port-status remote wake preceded the waker; the device GET_STATUS setup (`80 00 0000 0000 0002`) and completion; the reset-resume debug message/caller; PM return values; and Address Device/Evaluate Context completion codes and slot identities. Stop/preserve the trace when the device disappears; do not issue a diagnostic reset.

### Second: count exposure before an A/B

Reprocess the complete earlier kernel logs using monotonic timestamps and the full boot IDs. Count completed device-level cycles and distinguish pre-open, open-idle, SCO-interface-only and system-suspend activity. A suspend print is callback entry, so use paired interface ordering and rollback/error evidence rather than equating every isolated line with successful device suspension.

Report failures per relevant cycle and controller-open idle exposure, alongside uptime. The 970,343 seconds of prior uptime cannot itself give a failure probability per resume. With rare events, several failure-free weeks are useful but not definitive; zero events in N independent comparable opportunities gives only an approximate upper 95% bound of 3/N, and real cycles may not be independent.

### Third: avoid runtime suspend for this device

On a healthy, naturally active controller—or as policy on the next ordinary cold boot—set:

```sh
printf 'on\n' | sudo tee /sys/bus/usb/devices/3-3/power/control >/dev/null
```

Verify the path still belongs to `13d3:3503` before changing it. Writing `on` while it is already suspended can initiate a resume, so this is a policy intervention, not a passive read. Use a VID/PID-matched boot rule if persistence is desired. Keep kernel, firmware and normal workload stable; record power-policy state and natural resume exposure. Do not repeatedly flip auto/on to force cycles.

`btusb.enable_autosuspend=0` on a future normal boot is a broader alternative, affecting other btusb devices. Neither intervention proves that a remote-wakeup **event** was the trigger; both remove the open-idle runtime-suspend opportunity.

### What to avoid, and what can be virtualized

No driver unload/reload/rebind, deliberate USB reset, forced port cycle, PCI reset or speculative ACPI execution is required. Reproducing the real AMD root-port/controller power failure in QEMU is unlikely to resolve it. QEMU/vhci or a deterministic mocked transport **is** useful for MGMT error mapping, stale commands, unregister backlog and workqueue ordering. Another physical machine can establish quirk scope only if controller, firmware, host topology and power behavior are recorded; it is not a substitute for capturing this machine's first failed transition.

## Open evidence gaps

- No direct record of the initiating USB request, resume source, port status or first reset caller exists for BT-17.
- Failing-boot persist/wakeup/quirk sysfs values were not sampled; later-boot values must remain labelled as such.
- No exact independent QCA9377/Ryzen/`1022:1639` runtime-resume report was verified.
- Exact introducing commit/rationale for the MGMT errno timeout mapping, original deferred-URB synchronization layout, GPIO reset addition, and Ubuntu `_PRR` source-package hunk remain unresolved.
- Firmware USB NVM semantics and this platform's actual Bluetooth power/reset wiring remain unknown.
- Ubuntu 43 source/backport differences were not audited; equal device-table entries alone do not prove every recovery-path implementation is identical.

These gaps do not weaken the source-confirmed H2 ordering or the exclusion of btusb's successfully queued reset in this occurrence. They prevent promoting H1's exact GET_STATUS/host-trigger sequence, or H3's shared physical cause, from a strong/plausible hypothesis into a finding.

## Appendix: reconstructed source file fingerprints

These SHA-256 values identify the inspected Ubuntu 42 files before the separate device-table entry. They make line-number references independently checkable against the exact source-package reconstruction.

| File | SHA-256 |
|---|---|
| `drivers/bluetooth/btusb.c` | `98bfc190f0b22b8f27780ee476f36fef04ade2c82c196963a74f8d33850da52b` |
| `drivers/bluetooth/btqca.c` | `4b399fc600b36c43848c28be804cbdb766edcdf19acac2baaea08526dcfb2db9` |
| `drivers/usb/core/hub.c` | `797740d0ef750a0fd0ee0d6dc99f992bb65dd32b457c9442552edc57c13d2f38` |
| `drivers/usb/core/driver.c` | `aa96d087e2e2b9098b590e8fbc0b5e67892feb10327b5299fc30955585db3ef2` |
| `drivers/usb/core/usb-acpi.c` | `0783071bbb55c9cf1a493d89efb88cf521816b071a1a5074b104faa2fb398fe3` |
| `drivers/usb/host/xhci-hub.c` | `2917c7192d97211b541e24cd6fd93563111bf66bf54d1989a37a482d903fd76b` |
| `drivers/usb/host/xhci.c` | `21bae971b70325c9cfec507d954b83da961293f954c88d3a0864d97667469838` |
| `drivers/usb/host/xhci-pci.c` | `9f2cb32d3a0b8a1517bf72ed3ad53ed33cf74b44e9b604734cc4134b4e148507` |
| `drivers/base/power/runtime.c` | `86a4ab8982d610b0ff1a1eb998adaf99a5f914833a56e70fb62efda2764af566` |
| `net/bluetooth/hci_core.c` | `699c3926067e801094e70682e2529120a416685149a32ceb9a287bca42e8ca46` |
| `net/bluetooth/hci_sync.c` | `dab4cac3b954bfe805b3fb0bd29e1e2d27b10f19d487538073bebdf592efc34a` |
| `net/bluetooth/mgmt.c` | `030fe5f3915240d5a1efdc69ddebed9ec915b8c08fa79a9e3ba896b40378841a` |

---

## The reviewer's covering message

**H2 is strongly supported. H1 is the best-fitting reconstruction, but its exact GET_STATUS/host-initiated sequence remains unproved. H3 is plausible as a workaround hypothesis, not established as a shared Qualcomm/MediaTek defect.**

I checked out mainline v7.0, reconstructed the relevant files from Ubuntu’s exact `7.0.0-42.42~24.04.1` source package, and compared them with mainline snapshot `7e1392a42ea28`.

The detailed investigation, including line references, commit history, external reports, falsifiers and experiments, is here: *[link to the reviewer's working file omitted]*

The principal findings are:

1. **The first reset was almost certainly not queued by `btusb_reset()`.**

   In the Ubuntu source, `btusb_reset()` at `drivers/bluetooth/btusb.c:1032` obtains its runtime-PM reference before printing `Resetting usb device.` and calling `usb_queue_reset_device()`. Its observed error takes the early return.

   USB-Persist recovery in `drivers/usb/core/hub.c:3636`, `finish_port_resume()`, explains the reset without that message. However, GET_STATUS failure is not its only possible entry: a disabled port can select reset-resume earlier, and a remote wakeup can initiate the same resume machinery without a default-level notification.

   Thus **H1: yes as the leading reconstruction; no as a proven attribution of the exact branch and initiator.**

2. **The timing fits more closely than the brief suggests.**

   The normal host-initiated USB2 path contains these nominal waits:

   | Stage | Delay |
   |---|---:|
   | xHCI resume signalling | 40 ms |
   | USB core resume wait | 40 ms |
   | Resume recovery | 10 ms |
   | GET_STATUS timeout | 5000 ms |
   | Initial root-port reset polling | 60 ms |
   | Normal reset recovery | 50 ms |
   | **Total before the reset print** | **5200 ms** |

   Crucially, `hub_port_init()` prints `reset full-speed…` **after** performing the port reset and its recovery delay. Against the observed 5291.467 ms, this leaves approximately **91 ms**, plausibly scheduling, timer rounding, locking and host-controller work. The logs cannot assign that remainder exactly.

   `wait_for_connected()` adds conditional 20 ms waits; it does not impose an unconditional 240–250 ms delay.

3. **H2: yes—the source explains the blocked reset callback and delayed command credit.**

   `hci_cmd_timeout()` at `net/bluetooth/hci_core.c:1462–1482` calls `hdev->reset()` synchronously, then restores credit. Runtime PM waits for an existing transition; its parent-state check at `drivers/base/power/runtime.c:915–919` can return `-EBUSY` when the parent failed to become active.

   That matches the delayed `Failed usb_autopm_get_interface: -16`, immediately followed by restored credit. The exact PM wait/return site still needs tracing, but the callback ordering and failure before reset queueing are strong findings.

   Because `hdev->workqueue` is ordered, this wait also blocks RX, TX and command work there. The separate request workqueue can continue expiring requests, explaining the unsent commands’ timeouts.

4. **Two claims in the brief need qualification.**

   - Missing `btusb_resume()` proves that callback did not execute, assuming complete debug output. It does not alone prove every device-level resume failed: a successful **reset-resume** can cause rebinding because btusb lacks `.reset_resume`.
   - A monitor command record precedes both the `HCI_RUNNING` check and the driver call in `hci_send_frame()`. Frames #121/#122 prove core send attempts, not necessarily driver entry, USB submission or wire delivery.

   Frame #122 also precedes the recorded btusb disconnect/unregister entry. It is not evidence of sending through a freed `hdev`. Stale queued-command execution nevertheless deserves a separate correctness test.

5. **QCA reset history supports your concern about recovery policy.**

   `6933568aec92` introduced ROME timeout-triggered USB reset in 2020, originally after five timeouts. Its submission describes Chromebook suspend-stress failures and explicitly reports that resetting removed the troublesome device but did not reliably restore it; power cycling remained necessary. [lkml.rescloud.iu.edu](https://lkml.rescloud.iu.edu/2006.3/01095.html)

   `7c393421755d` removed the counter in 2025, reasoning that only one command is in flight and recovery should begin after its first timeout. `f07d478090b0` subsequently renamed/restructured the callback as `hdev->reset`. [git.zx2c4.com](https://git.zx2c4.com/laptop-kernel/commit/drivers/bluetooth?id=7c393421755daf35ae1e4e0016b99f308123751a)

   There is a real design tension here: the two-second HCI watchdog can expire while a five-second USB resume check is outstanding. That warrants investigation, but changing the timeout/reset policy would not by itself repair the underlying failed resume.

6. **H3 remains unconfirmed, and broadening the quirk would be premature.**

   The original MediaTek evidence includes an actual remote-wakeup-driven resume. BT-17 does not. The later quirk deliberately prevents open-controller runtime autosuspend while preserving system-wakeup functionality; its platform restriction is a cautious workaround, not proof of a universal AMD defect. [lists.infradead.org](https://lists.infradead.org/pipermail/linux-mediatek/2026-September/112516.html)

   I found Qualcomm autosuspend and power-off-recovery analogues, including Fedora’s QCA6174/XPS reports, but **no independently verified exact QCA9377 + Ryzen + `1022:1639` runtime-resume match**. The Intel-platform reports also show why runtime and system-suspend failures must be separated. [bugzilla.redhat.com](https://bugzilla.redhat.com/show_bug.cgi?id=1514836)

   If evidence supports a quirk, start with `13d3:3503` and the demonstrated platform/topology—not all ROME or all Ryzen Bluetooth devices.

7. **The Ubuntu USB delta matters.**

   Ubuntu adds an ACPI `_PRR` reset attempt during enumeration-failure port power cycling: `hub.c:5616` calls `usb_acpi_port_prr_reset()`.

   Therefore `attempt power cycle` may involve platform recovery beyond the mainline-v7.0 path. It still proves neither that `_PRR` exists nor that the Bluetooth supply was actually removed. This affects interpretation of the later recovery attempt, not the first reset.

   Also, xHCI completion **`0x11` means Parameter Error**. The separate Evaluate Context warning corresponds to Context State Error. These are host-controller context errors, not Bluetooth firmware status bytes; they could expose secondary recovery problems.

8. **There are adjacent software issues worth separating from the initiating failure.**

   - `-ETIMEDOUT → MGMT_STATUS_AUTH_FAILED` explains the misleading MGMT responses and remains in the inspected mainline.
   - Later commit `b1f24c1ab523` prevents unregister from draining an entire synchronous-command backlog through repeated timeouts. It is absent from Ubuntu 42’s inspected implementation and may bear on teardown delay.
   - The report identifies a separate possible deferred-URB anchoring race. It is untested and does **not** fit BT-17’s missing resume callback.

**The first experiment should be passive capture of one natural recurrence:** USB core debug, bounded bus-3 usbmon, and xHCI port/command tracing. Capture the resume initiator, GET_STATUS submission/completion, reset-resume branch, reset caller and PM return values. Then use a controlled observation period with this device’s `power/control=on`, preferably set while healthy and naturally active. No reload, rebind, deliberate reset or port cycle is needed.

The report explicitly marks remaining gaps: several exact introducing commits, the complete locally modified BlueZ source, firmware NVM semantics, and Ubuntu 43’s full delta.

Some older history checks remained unfinished *[the reviewer's note on its environment's fetch limits omitted]*. Those gaps are identified rather than filled with guessed provenance.
