# BT-17 source investigation — the second outside reviewer's answer

*Received 2026-11-13 in answer to `2026-11-13T0003Z-bt17-source-investigation-task.md`. The text
is kept as received, except for the reviewer's tooling marks, which
`scripts/review-text-clean.py` removes: tracking parameters in links, favicon lines with their
site labels, and HTML space entities.*

*No finding was added or changed. What we checked on 2026-11-13, and what holds:*

- **The mainline line numbers match.** `git grep -n` at `v7.0`:
  - `usb_resume_both()` `driver.c:1537`;
  - in `hub.c`: `check_port_resume_type()` 3285, `wait_for_connected()` 3738, `hub_port_init()` 4902,
    `port_event()` 5746 (its `disabled by hub (EMI?)` error at 5782),
    `usb_reset_and_verify_device()` 6170;
  - `xhci.h:849` `COMP_PARAMETER_ERROR 17` and `:851` `COMP_CONTEXT_STATE_ERROR 19`;
  - `xhci.c:2191-2193`, the `invalid context state for evaluate context command` warning;
  - `xhci-pci.c:342-343`, `XHCI_BROKEN_D3COLD_S2I` for `0x1639`.

  At `v7.3`: `platform_is_ryzen()` `btusb.c:3008`, `is_direct_child_of_root_hub()` 3017, the
  `set_bit` 3071-3072, the suspend test 4673.
- **The extra 40 ms in xHCI is real.** v7.0 `xhci-hub.c`, ClearPortFeature(SUSPEND) for a port in
  U3: `XDEV_RESUME`, `msleep(USB_RESUME_TIMEOUT)`, then `XDEV_U0`. With `usb_port_resume()`'s own
  40 ms and 10 ms, that makes 90 ms of fixed waits, which the brief did not count. That leaves
  about 0.20 s of the 5.291 s unexplained, not 0.24 s.
- **On the alternative branch.** In `check_port_resume_type()` a port found not enabled is retried
  as a reset-resume, and the GET_STATUS is skipped. Taken alone, that branch would put the first
  reset about 0.1 s after the resume began, not 5.29 s. It fits the timing only if some other
  operation waited about 5 s first:
  - `wait_for_connected()` gives up after 2,000 ms;
  - root-hub status requests run synchronously in the host controller driver (`rh_call_control()`)
    and do not use a 5 s control timeout.

  So the timing still favours H1's branch, but the review is right that only a trace can tell
  the two apart.
- **The Ubuntu delta, which the review could not retrieve, is in our cache.**
  `linux-hwe-7.0_7.0.0-42.42~24.04.1.diff.gz` (`cache/ubuntu-src/`).
  - **The resume path is unchanged.** The diff changes no line of `drivers/base/power/runtime.c`
    or `drivers/usb/host/xhci-hub.c`, and none of the resume path:
    - in `hub.c` its hunks are at old lines 753-766 (`usb_wakeup_notification()` under a lock),
      991 (a short hub-status read now an error) and 5603;
    - in `driver.c` they are dynamic-ID matching only;
    - in `xhci.c` they are the suspend-time pending-command warning and stream freeing;
    - in `xhci-pci.c` a VIA quirk.

    The mainline reading therefore holds for `7.0.0-42`.
  - **One hunk matters.** The 5603 hunk, in the enumeration retry loop's `attempt power cycle`
    step, also calls a new `usb_acpi_port_prr_reset()` (added in `usb-acpi.c`), which evaluates
    the port's ACPI `_PRR` and calls `_RST` on it. That is the step logged at 18:03:18.14.
  - **On this laptop it can have done nothing.** The port's ACPI node is
    `\_SB_.PCI0.GP17.XHC1.RHUB.PRT3`. The node has no power-resource attributes, and no `_PRR`
    object exists in any table (`grep -l -a _PRR` over DSDT and SSDT1-8: none; no dynamic
    tables). So the power cycle was the port's power switch only.
- **`c93922dd316b` is in the tree that ran.** "Bluetooth: btusb: Fix leaked runtime PM reference
  in btusb_reset" (2026-09-04): the `test_and_set_bit(BTUSB_RESET, …)` lines are in the brief's
  `7.0.0-42` quote of `btusb_reset()`. As the review says, it sits after the failed
  `usb_autopm_get_interface()` and cannot have run.
- **History commits.**
  - `6933568aec92` (2020-06-24) and `c9209b269afd` (2022-10-06) exist with the subjects given.
    The 2020 commit's message says only that ROME "sometimes gets into a state where it is
    unresponsive to commands" and so the port is reset. The statement that a USB reset did not
    bring the controller back without a power cycle is from the patch discussion, which we did
    not read.
  - `b32563b6ccba` is the 2021-11-17 bluetooth-next merge, as stated.
- **What the review checked that the brief did not give:** the USB version 1.10 and the missing
  `usb2_hardware_lpm` file are in the brief's sysfs output. The review uses them correctly to set
  aside Ubuntu bug 1757218's LPM fix.
- **Not checked here:** the external reports (Ubuntu bugs 1757218 and 2166119, the 2020
  discussion, the MediaTek report's logs, the 2023 AMD `1022:1505` report).

---

# **BT-17 — Source-code investigation**

Technical review · 13 November 2026 · Linux Bluetooth / USB runtime PM / AMD xHCI

## **1. Executive findings**

The evidence points to a failure at the **USB runtime-resume boundary**, rather than a Bluetooth protocol failure. The first unresponsive HCI command exposed the problem; there is no evidence that the command itself caused it.

The central distinction is between three events:

1. A Bluetooth command was submitted while the USB device was suspended.
2. The USB device apparently failed to resume successfully.
3. USB recovery then failed at the enumeration level, leaving the controller inaccessible even after a warm reboot.

These events are related, but their causal order is not yet established completely.

| Hypothesis                                                         | Assessment                                                       | Confidence  |
| ------------------------------------------------------------------ | ---------------------------------------------------------------- | ----------- |
| **H1:** Failed USB resume, followed by USB-core reset-resume       | Most likely explanation of the first reset; not proved           | Medium–high |
| **H2:** HCI timeout recovery blocked behind the failing USB resume | Strongly supported by code and timing                            | High        |
| **H3:** Ryzen root-hub remote-wakeup problem also affects QCA9377  | Credible candidate for testing, not an established shared defect | Low–medium  |

I have independently retrieved the relevant mainline v7.0 source files, including `btusb.c`, `hci_core.c`, `mgmt.c`, `hub.c`, `driver.c`, and `runtime.c`. The investigation also identifies a closely matching 2026 MediaTek failure with an upstream fix.

**Source limitation:** I have not independently reproduced a checkout of Ubuntu's exact `7.0.0-42.42~24.04.1` source package. The release's source archive is published, but direct retrieval was unsuccessful. Thus, mainline findings below are source-verified; Ubuntu-specific differences quoted in the brief remain a separate verification requirement.

### **The most important distinction**

The first USB reset at monotonic time 184.022630 did **not necessarily originate in the Bluetooth timeout handler**.

In mainline v7.0:

- `hci_cmd_timeout()` calls `hdev->reset()`.
- For QCA ROME without an available reset GPIO, `btusb_qca_reset()` calls `btusb_reset()`.
- `btusb_reset()` first performs a synchronous `usb_autopm_get_interface()`.
- It prints `Resetting usb device.` and queues its own USB reset **only if that PM acquisition succeeds**.

The observed `Failed usb_autopm_get_interface: -16`, together with the absence of `Resetting usb device.`, is especially strong evidence that this Bluetooth reset request never reached `usb_queue_reset_device()`.

This is not merely an inference from USB timing: it follows from the actual error-return branch in `btusb_reset()`.

Source: [Linux v7.0 — btusb.c](https://github.com/torvalds/linux/blob/v7.0/drivers/bluetooth/btusb.c), `btusb_reset()`.

## **2. Item 1 — Where did the first USB reset come from?**

**H1: Yes, it is the best-supported reconstruction of the reset sequence. No, the available evidence does not prove that the five-second operation was specifically**`GET_STATUS`**.**

### **The source-level sequence**

Likely control flow

18:03:08.827 · HCI command #121

`hci_cmd_work()` → `btusb_send_frame()` → `submit_or_queue_tx_urb()`

Suspended controller: command deferred

`BTUSB_SUSPENDING` → `data->deferred` → `btusb_waker()`

USB runtime resume attempted

`usb_autopm_get_interface()` → runtime PM → `usb_resume_both()` → `usb_port_resume()`

Device-level resume fails

Likely control request timeout; alternate path is an unusable port state

18:03:14.120 · USB-core reset attempt

`usb_reset_and_verify_device()` → `hub_port_init()`

18:03:16.181 · Logical disconnect

Reset/enumeration failure; device cannot be rediscovered

The decisive source locations are:

| Tree          | File and lines                        | Relevant behavior                                                                           |
| ------------- | ------------------------------------- | ------------------------------------------------------------------------------------------- |
| Mainline v7.0 | `drivers/bluetooth/btusb.c:2174–2195` | Defers a TX URB when `BTUSB_SUSPENDING` is set                                              |
| Mainline v7.0 | `btusb.c:2420–2432`                   | `btusb_waker()` synchronously requests an interface autoresume; silently returns on failure |
| Mainline v7.0 | `drivers/usb/core/driver.c:1537–1598` | `usb_resume_both()` resumes the USB device **before** interface callbacks                   |
| Mainline v7.0 | `drivers/usb/core/hub.c:3793–3880`    | `usb_port_resume()` performs port signalling and resume checks                              |
| Mainline v7.0 | `hub.c:3631–3712`                     | `finish_port_resume()` may retry a failed normal resume as reset-resume                     |
| Mainline v7.0 | `hub.c:6160–6320`                     | `usb_reset_and_verify_device()` retries reset and device initialization                     |
| Mainline v7.0 | `hub.c:4902–5110`                     | `hub_port_init()` emits the observed `reset full-speed USB device` message                  |

The core ordering explains the missing `btusb_resume()` log: if `usb_resume_device()` fails, `usb_resume_both()` does not enter the interface-resume loop. That is stronger evidence than simply saying that the device did not wake up.

Sources: [USB driver PM callbacks](https://github.com/torvalds/linux/blob/v7.0/drivers/usb/core/driver.c); [USB hub resume and reset paths](https://github.com/torvalds/linux/blob/v7.0/drivers/usb/core/hub.c).

### **The 5.291-second gap**

I checked the actual xHCI USB2 port-resume implementation, not just the generic hub code.

In mainline v7.0, `xhci_hub_control()` handles `ClearPortFeature(USB_PORT_FEAT_SUSPEND)` at `drivers/usb/host/xhci-hub.c:1568–1595`. For a port in `XDEV_U3`, it:

1. Sets the port to `XDEV_RESUME`.
2. Sleeps for `USB_RESUME_TIMEOUT`, which is **40 ms**, not 20 ms.
3. Sets `XDEV_U0`, ends resume signalling and rings the device.

Then `usb_port_resume()` itself includes another 40 ms resume wait and a 10 ms recovery wait. Consequently, approximately **90 ms of programmed waits** can occur before the device status request. These are not necessarily the only delays: runtime-PM scheduling, root-port state transitions, locking and USB requests add time.

The observed elapsed time is:

\\[ 184.022630-178.731163=5.291467\ \text{s}. \\]

If a 5,000 ms `GET_STATUS` timed out, the remaining approximately 291 ms is plausible. The code accounts for part of it, but not enough to reconstruct every millisecond.

**Two competing USB-core routes remain:**

- `finish_port_resume()` detects failed `GET_STATUS` and uses the persistence retry (`retry with reset-resume`). This is H1's specific mechanism.
- `check_port_resume_type()` at `hub.c:3285–3346` finds that the port is no longer enabled, sets `udev->reset_resume` and proceeds to reset without the proposed five-second failing `GET_STATUS`.

The second route matters because it is a real alternative in the source. A timed-out hub or xHCI operation preceding it could also explain a long delay.

The first reset's source therefore remains **most likely USB core, through failed resume recovery**, but the precise decision branch requires tracing.

### **What the xHCI errors actually establish**

The later messages contain several different error classes.

`device descriptor read/64, error -71` means `-EPROTO`: enumeration-level USB communication failed. `Device not responding to setup address` means the host could not successfully establish the device address. Neither, by itself, distinguishes dead Bluetooth firmware from a defective USB link or host controller state.

More specifically, mainline `xhci.h:849` defines xHCI completion code `0x11` as **Parameter Error** (`COMP_PARAMETER_ERROR = 17`). It is not USB error `-71`, nor is it an HCI error.

The message `WARN: invalid context state for evaluate context command` comes from `drivers/usb/host/xhci.c:2191–2195` when the xHCI controller returns `COMP_CONTEXT_STATE_ERROR = 19`. That branch returns `-EINVAL` (`-22`).

These are evidence of **failed xHCI command processing during recovery**, not proof that the xHCI driver caused the initial problem. A host-side recovery defect is still possible, particularly if traces show unexpected slot/context transitions.

A persistent firmware or power-domain failure is entirely plausible. A USB port reset is primarily a protocol/link reset, not a guarantee that the internal Bluetooth chip loses power. Even a logical port power cycle need not remove power from an M.2 module's Bluetooth circuitry. USB's own documentation describes this distinction.


I also examined `hub.c:5746–5910`, particularly `port_event()`. It contains a recovery path for a port disabled because of possible electromagnetic interference, but that branch prints `disabled by hub (EMI?), re-enabling...` at error level. That message is absent from E3, making this particular alternative unlikely.

A USB hub event or remote wakeup could nevertheless have initiated the resume without a default-level message: relevant output is `dev_dbg`. An unrelated caller of `usb_reset_device()` could likewise reach `hub_port_init()` and print the same reset line, although the timing and lack of btusb's reset message make this less likely.

**H1 would be falsified in its specific form** by a future trace showing that no `GET_STATUS` timed out, that the first reset came from an independent hub event, or that `check_port_resume_type()` selected reset-resume before `finish_port_resume()` ran.

## **3. Item 2 — The HCI timeout blocked behind USB recovery**

**H2: Yes, with high confidence.** The evidence supports a synchronous wait inside the Bluetooth timeout handler. The exact origin of the final `-EBUSY` is strongly suggested by runtime-PM source, but is not uniquely identifiable from this log.

The key code is `net/bluetooth/hci_core.c:1462–1482`, `hci_cmd_timeout()`:

```
if (hdev->reset)
    hdev->reset(hdev);

atomic_set(&hdev->cmd_cnt, 1);
queue_work(hdev->workqueue, &hdev->cmd_work);
```

This means command credit is restored **after** the driver-specific reset callback returns.

At 180.772 the timeout handler entered that callback. The eventual `Failed usb_autopm_get_interface: -16` and restoration of command credit both occur at 186.083. The elapsed time is approximately **5.311 seconds**.

That is an unusually strong signature of the reset callback waiting for a USB runtime-PM operation to finish.

### **Why**`-16`**makes sense**

In `drivers/base/power/runtime.c`, `rpm_resume()` has two pertinent behaviors.

First, when another operation has already put a device into `RPM_RESUMING`, a synchronous caller waits for that transition to finish.

Second, when resuming a child, it attempts to resume the parent. If the parent still has not reached `RPM_ACTIVE`, it returns `-EBUSY`.

For this controller, the relevant ancestry is approximately:

`USB interface 3-3:1.0` → `USB device 3-3` → USB port/root-hub infrastructure.

A failed parent resume therefore provides a concrete route from the pending USB recovery to the exact `-16` returned to `btusb_reset()`.

The code also explains why command #122 appears only at the time of disconnection. The timeout handler was unable to restore command credit earlier.

The subsequent attempt to submit another command is an undesirable consequence of generic HCI timeout recovery assuming that restoring credit is useful. **I would not characterize this as a proven use-after-free or independently established race defect.** The USB and HCI teardown paths can overlap without an object necessarily having been freed prematurely. It is, however, a worthwhile state-validity and error-propagation review.

### **Is blocking intended?**

The blocking operation is not an accidental sleep in atomic context: `hci_cmd_timeout()` is delayed work, and `usb_autopm_get_interface()` is explicitly a process-context API.

The design nevertheless has a weakness: **USB recovery latency becomes HCI command-queue recovery latency.** A USB request can wait for seconds, while HCI synchronous callers have their own deadlines. That explains how multiple MGMT commands can fail even though only the first HCI command was submitted before the USB recovery completed.

A future improvement could separate requesting controller recovery from restoring command credits, with explicit device-presence and recovery-state checks. Such a change belongs in the Bluetooth core in coordination with btusb, not in BlueZ.

### **Why QCA ROME resets on a command timeout**

This policy has a particularly relevant history.

In commit [`6933568aec92`](https://github.com/torvalds/linux/commit/6933568aec92dd6432207baaf59378d01f55a14f), **“Bluetooth: btusb: Reset port on cmd timeout”**, Abhishek Pandit-Subedi added USB-port reset recovery for QCA ROME in June 2020.

The accompanying patch discussion describes Chromebooks whose QCA ROME controllers stopped answering commands after hundreds of suspend/resume stress cycles. The author explicitly said that the USB reset was sufficient to remove the failed device from service, but generally **did not restore a functioning Bluetooth controller without a power cycle**.

That is an important historical match to BT-17's recovery outcome.

There is also a change in policy to distinguish. The original QCA timeout code waited for five command timeouts before performing this recovery. The current design uses the generic `hdev->reset` callback on the first command timeout. The generic USB-reset infrastructure was subsequently consolidated in `c9209b269afd`.

In September 2026, commit [`c93922dd316b`](https://github.com/torvalds/linux/commit/c93922dd316b7273a8667d29084632066fa8a2d3) fixed a leaked runtime-PM reference in `btusb_reset()`. That fix is relevant to the reset path's correctness, but cannot explain the current incident if the PM acquisition failed before the reset was queued.

**Fix location:** improving the diagnostics for a failed `btusb_waker()` belongs in btusb. Preventing inappropriate command-credit restoration or improving command recovery belongs in the Bluetooth core. Neither solves the underlying failure of the USB device to resume.

## **4. Item 3 — Is the Ryzen remote-wakeup quirk applicable?**

The similarity is striking, but I would **not yet propose an upstream QCA9377 quirk on this single occurrence**.

### **What the MediaTek change actually addressed**

The original MediaTek commit, `e31d761628ad`, and the refined patch `dcaf83ead130` addressed MT7922/MT7925 USB Bluetooth controllers on Ryzen laptops.

The reported failure was not merely a generic HCI timeout. It involved a documented **remote wakeup** from USB runtime suspend, after which the USB Bluetooth device stopped responding and required a power cycle. The patch was specifically scoped to Bluetooth devices that are direct children of Ryzen root hubs.

Commit [`dcaf83ead130`](https://github.com/torvalds/linux/commit/dcaf83ead130d3067862599089b0999b3da140a4), merged in September 2026, adds `BTUSB_WAKEUP_BROKEN` and refuses runtime suspend while the HCI interface requires remote wakeup. It does not globally disable the controller's USB support or prevent ordinary Bluetooth use.

I verified the resulting implementation in mainline v7.3:

- `btusb.c:3008–3022`: Ryzen and root-hub-child predicates.
- `btusb.c:3072–3076`: setting `BTUSB_WAKEUP_BROKEN` for the affected MediaTek models.
- `btusb.c:4675–4678`: returning `-EBUSY` for automatic suspend with `needs_remote_wakeup` set.

The existing QCA ROME probe branch does not set that flag.

### **How closely does it match BT-17?**

BT-17 meets the hardware/topology preconditions used by the MediaTek workaround: a Ryzen processor and an internal USB Bluetooth controller attached directly to the root hub. It also matches the failure's severity and recovery behavior.

But one crucial distinction remains:

**The MediaTek evidence identifies remote wakeup as the event associated with failure. BT-17 identifies a host-initiated HCI command after a suspended interval.**

That does not exclude remote wakeup from BT-17: an earlier, unlogged remote-wakeup-related port event is possible. Nor does it establish that remote wakeup is required for the QCA failure. Host-initiated resume and remote wakeup can expose different hardware faults.

The MediaTek patch's own reasoning emphasizes caution about scope. It does not prove that AMD's xHCI implementation, rather than the particular Bluetooth firmware's USB-power handling, was responsible. The kernel discussion explicitly acknowledges that the root-hub test can also match a PCIe add-in USB controller, and deliberately avoids more intrusive PCI hierarchy inspection.

### **A separate AMD xHCI quirk on this exact host**

There is a further source finding.

Mainline v7.0 `drivers/usb/host/xhci-pci.c:341–343` explicitly recognizes **AMD Renoir xHCI**`0x1639` and sets `XHCI_BROKEN_D3COLD_S2I`.

This is the USB host PCI ID in BT-17. However, that quirk concerns the host controller's **D3cold behavior during suspend-to-idle**, not ordinary runtime suspend/resume of an individual USB Bluetooth device. It is evidence that this AMD host family has required power-management exceptions, but it is not an explanation for this event.

Other AMD xHCI workarounds, including `XHCI_RESET_ON_RESUME` for certain older AMD PCI IDs, likewise have different match conditions and failure contexts. One 2023 kernel report concerned AMD `1022:1505` and a host controller that became unresponsive to a Stop Endpoint command. It should not be conflated with `1022:1639`, where the xHCI host continued enumerating devices and reporting errors.

The initial implementation of a QCA workaround should therefore be **device-specific**, preferably conditioned on `13d3:3503`, Ryzen and direct-root-hub topology, with evidence that preventing the suspended-with-remote-wakeup-armed state actually prevents the failure.

A quirk for every QCA ROME controller, or every btusb controller on Ryzen, would have much more extensive power and compatibility consequences without corresponding evidence.

## **5. Item 4 — QCA ROME firmware, NVM and controller-side recovery**

### **Firmware loading does not explain the initial timeout directly**

In mainline v7.0, the relevant USB QCA implementation is primarily in `drivers/bluetooth/btusb.c`, rather than the UART-oriented portions of `btqca.c`.

`btusb_setup_qca()` at lines 3600 onward queries the ROM version and firmware state. `btusb_setup_qca_load_rampatch()` at lines 3467 onward obtains the patch image, and `btusb_setup_qca_load_nvm()` at lines 3562–3585 downloads the NVM image through the QCA USB firmware-download mechanism.

I found no code in that USB ROME setup path which independently establishes whether the controller will reliably honor USB runtime suspend, resume signalling, or remote wakeup. The firmware and NVM are supplied as binary images.

There is an important distinction in `btqca.c`: its TLV processing contains `EDL_TAG_ID_HCI` and `EDL_TAG_ID_DEEP_SLEEP` handling. The former includes controller-side in-band sleep settings. However, that generic TLV processing is not evidence that the **USB ROME binary NVM** is processed through the same code path or uses the same settings.

Thus, a conclusion such as “the QCA NVM enables a broken deep-sleep mode” would be premature.

The fact that the firmware loads successfully and answers startup commands establishes that the initial download and initialization worked. It does not validate the firmware's later USB suspend behavior.

Relevant source: [Linux v7.0 btusb QCA firmware implementation](https://github.com/torvalds/linux/blob/v7.0/drivers/bluetooth/btusb.c).

### **Could the patched firmware behave differently from ROM firmware?**

Yes. The rampatch changes the controller's executable firmware, and the NVM can configure controller behavior. It is entirely plausible that USB suspend handling differs between patched and ROM firmware.

But the earlier ROM-firmware SCO defect and BT-17 are different failure classes. There is no SCO, ACL or discovery activity in BT-17, and the device had already completed a normal firmware-loaded startup.

I would retain firmware handling as a **candidate root cause**, particularly if subsequent USB traces show that the host performed a standards-compliant resume while the controller failed to respond.

A firmware comparison would require either decoding the actual image formats and relevant configuration fields or obtaining controller-specific documentation. The provided compressed-file hashes identify the files but do not disclose their power-management settings.

### **Can software recover the controller?**

No reliable software-only recovery path is established by this investigation.

`btusb_qca_reset()` can use a reset GPIO where the platform exposes one, but this machine does not. Its fallback is USB-level reset, which historically has not guaranteed recovery of wedged ROME hardware.

The Wi-Fi function operating through `ath10k_pci` is a separate interface. Nothing in the examined btusb path establishes a Wi-Fi-mediated reset of the Bluetooth function. Resetting the Wi-Fi side also risks interrupting an otherwise functioning device.

An ACPI reset method or platform-specific Bluetooth power gate would be worth investigating **read-only**, but none has been identified here. The machine's uninformative DMI fields further limit existing platform matching.

**Fix location:** firmware or platform power sequencing if the controller itself becomes unresponsive despite correct USB resume; USB core or xHCI if traces instead show a host-side sequencing failure.

## **6. The older QCA ROME resume history**

There is a useful warning in the historical commits: applying reset-related workarounds to every ROME device has already proved too broad.

In 2017, commit `61f5acea8737`, *“Bluetooth: btusb: Restore QCA Rome suspend/resume fix with a 'rewritten' version”*, applied `USB_QUIRK_RESET_RESUME` broadly to QCA ROME USB Bluetooth devices.

The motivation was that some systems lost the controller's updated firmware during a system suspend, while the USB layer failed to detect the need for reinitialization.

In February 2018, Hans de Goede's commit [`1fdb92697469`](https://github.com/torvalds/linux/commit/1fdb926974695d3dbc05a429bafa266fdd16510e), *“Bluetooth: btusb: Use DMI matching for QCA reset_resume quirking”*, narrowed that workaround to affected systems.

The commit message explicitly explains that most ROME devices resume correctly and that the problem was platform-specific. The broad USB-ID match had disabled runtime suspend unnecessarily, increasing power consumption. The change was associated with Red Hat bug **1514836** and included user confirmation.

Development tree for the kernel CSPRNG+1



That history supports two conclusions for BT-17.

First, there is a long-standing precedent for **ROME resume behavior depending on the host platform**.

Second, it argues against treating a single incident as evidence that all ROME devices need a global workaround.

The historical `USB_QUIRK_RESET_RESUME` addresses a different situation from the MediaTek-inspired `BTUSB_WAKEUP_BROKEN` approach. A reset-resume quirk changes USB resume recovery policy; the wakeup-broken approach prevents the problematic runtime-suspended state while the HCI device is open.

For BT-17, I would investigate the second strategy before considering the first.

## **7. Item 5 — Two Bluetooth-core problems exposed by the failure**

### **7.1.**`MGMT_STATUS_AUTH_FAILED`**is misleading**

This one is source-confirmed.

Mainline v7.0 `net/bluetooth/mgmt.c:286–310` contains:

```
case -ETIMEDOUT:
    return MGMT_STATUS_AUTH_FAILED;
```

The same mapping remains in the current mainline source I checked.

For BT-17, the MGMT `Remove UUID` command waited for an HCI Write Class of Device operation to finish. It returned `-ETIMEDOUT`, which the generic mapping converted to `MGMT_STATUS_AUTH_FAILED` (`0x05`).

**No authentication procedure failed.** The status is the result of an errno conversion, not a controller-generated authentication rejection.

A better generic mapping would appear to be:

```
case -ETIMEDOUT:
    return MGMT_STATUS_TIMEOUT;
```

`MGMT_STATUS_TIMEOUT` is a defined management status. `MGMT_STATUS_FAILED` would be less specific but still more accurate than authentication failure.

The choice needs compatibility review because the errno mapper is shared by different MGMT operations. Some historical callers may have implicitly depended on the existing conversion.

For history, I traced the mapping to at least the November 2021 integration of the HCI synchronous-command rework: merge `b32563b6ccba`, which introduced the errno-based management conversion. The merge's stated purpose was HCI command-execution serialization, not an explicitly documented decision that a timeout represents authentication failure.

I could not independently identify the precise non-merge introducing commit or its original justification through blame. That remains an outstanding history item rather than something I would assign a guessed commit ID.

This deserves an **independent Bluetooth MGMT fix and regression test**. It is a diagnostic/API correctness issue, not the cause of the USB controller disappearing.

### **7.2. Command #122 after the failed recovery**

In `hci_cmd_timeout()`, restoring command credit and queuing `cmd_work` is unconditional after `hdev->reset()` returns.

That policy means the command queue can restart even when the driver reset failed and the USB device is disappearing.

BT-17 demonstrates this behavior: `cmd_cnt 1 cmd queued 3` appears around the USB disconnect, and the HCI monitor captures another Write Class of Device.

The monitor capture does not prove that the USB control transfer reached the device. It proves that the command progressed through the HCI send path.

I would inspect the interaction between:

- `hci_cmd_timeout()` and `hci_cmd_work()` in `hci_core.c`;
- `btusb_send_frame()` and `submit_or_queue_tx_urb()` in `btusb.c`;
- `btusb_disconnect()` and `hci_unregister_dev()`;
- URB anchoring, cancellation and error completion.

My initial judgment is that this is **an observable recovery-policy weakness**, not yet a demonstrated unsafe memory-access defect. A test should check that outstanding commands receive appropriate errors, the HCI queue drains or stops cleanly, and no command is submitted against a controller already marked unregistering.

A Bluetooth emulator, fault-injected transport or QEMU-based test is useful for this **software ordering problem**. It is not useful for proving that the physical QCA9377 or AMD USB port can resume correctly.

## **8. Other people's reports**

I found several useful reports. They must not all be treated as reproductions of the same defect.

**Closest QCA9377 recovery match — Ubuntu bug 1757218, 2018–2019**

Lenovo IdeaPad 310-14ISK, Ubuntu 18.04, kernel `4.15.0-12-generic`.

The QCA9377 sometimes failed USB enumeration with `-71`, followed by SET_ADDRESS failures and inability to enumerate. A warm reboot, including into Windows, could leave the failure in place; power-off restored operation.

This is an unusually close match to BT-17's **USB-level failure and cold-power recovery**. Its identified problem, however, was USB2 LPM state persisting through shutdown. Ubuntu's corrective action was to disable USB2 LPM at shutdown. On BT-17, the device reports USB 1.10 and no `usb2_hardware_lpm` attribute, so that specific fix should not be transferred without evidence.

**QCA9377 missing after upgrade — Ubuntu bug 2166119, September 2026**

ASUS VivoBook X512FB, Ubuntu 26.04, kernel `7.0.0-30-generic`.

The reporter's QCA9377 Wi-Fi function worked, but Bluetooth never appeared. USB port `1-10` produced `-110` and `-71`, xHCI SET_ADDRESS failures and inability to enumerate.

This is a strong comparison for the **post-failure USB state** and the fact that Wi-Fi can remain functional. The host appears to be Intel xHCI (`0000:00:14.0`), not the AMD Renoir host in BT-17. The report does not establish a runtime-autosuspend trigger or power-off-only recovery.

**QCA ROME timeout after suspend stress — 2020 upstream discussion**

Chromebooks with QCA ROME, exact USB IDs and kernel versions not specified in the cited patch discussion.

Repeated suspend/resume stress led to controllers ceasing to answer commands. USB reset did not reliably restore Bluetooth; full power cycling remained necessary.

This is a strong precedent for the **controller becoming unrecoverable through USB reset**, but it does not identify the same runtime-resume mechanism as BT-17.

**MediaTek MT7922/MT7925 on Ryzen — 2026 upstream fixes**

Ryzen laptops, USB Bluetooth attached to xHCI; the published sample logs identify `usb 3-5` on xHCI `0000:67:00.0`, at **high speed**. The cited report does not identify the exact host PCI vendor/device ID or an exact distribution kernel release.

Crucially, the report records `usb wakeup-resume`, followed by a nonresponsive device, `retry with reset-resume`, failed enumeration and logical disconnect. That is the closest demonstrated **USB-core resume-to-reset sequence**, but the identified initiating condition is remote wakeup, unlike the presently reconstructed BT-17 host-command path.

I did **not** find a verified independent report combining all of the following: QCA9377 or `BTUSB_QCA_ROME`, AMD `1022:1639`, idle runtime suspend, a failed host-initiated resume, and recovery only after complete power-off.

Likewise, I found no externally verified report showing that `btusb enable_autosuspend=0` or `power/control=on` cured precisely this combination.

That absence is an important constraint on H3, not evidence against it.

## **9. Experiments — ranked for this laptop**

The single most decisive next experiment is **passive tracing of the USB runtime-resume path**, not another reset attempt.

### **Experiment A — Capture the next resume failure**

Enable debug output on the current kernel:

```
echo 'file drivers/usb/core/hub.c +p' |
    sudo tee /sys/kernel/debug/dynamic_debug/control

echo 'file drivers/usb/core/driver.c +p' |
    sudo tee /sys/kernel/debug/dynamic_debug/control
```

These commands enable logging; they do not reload or reset the controller.

If the relevant files were compiled with dynamic-debug support, a recurrence should reveal messages such as `usb wakeup-resume`, `finish resume`, `retry with reset-resume`, `gone after usb resume`, or hub-port recovery events.

Also inspect available xHCI and USB tracepoints before enabling a bounded trace:

```
find /sys/kernel/tracing/events/xhci-hcd \
     /sys/kernel/tracing/events/usb \
     /sys/kernel/tracing/events/power \
     -maxdepth 1 -mindepth 1 -type d 2>/dev/null
```

The exact available events depend on the built kernel. A trace of xHCI port status, USB control URB submission/completion, and runtime-PM transitions is more informative than additional Bluetooth packet logging.

The essential facts to record, on a common monotonic clock, are:

1. Which event began the resume: `btusb_waker`, remote wakeup, hub event, or another PM consumer?
2. Did the xHCI root port complete resume signalling?
3. Was `GET_STATUS` submitted to device `3-3`, and what was its completion status and elapsed time?
4. Did `check_port_resume_type()` or `finish_port_resume()` set `reset_resume`?
5. Which caller initiated the first `usb_reset_and_verify_device()`?
6. Did the runtime-PM parent return `-EBUSY` after the failed device resume?

**Interpretation:** a recorded five-second `GET_STATUS` timeout followed by `retry with reset-resume` would substantially confirm H1. A trace showing the hub initiating the reset independently would refute its proposed control flow.

### **Experiment B — Quantify how exceptional the failure is**

Use the already available suspend-cycle extraction script across all retained patched-driver boots, preserving complete and incomplete cycles separately.

I would record, for each boot, the number of completed suspend/resume cycles, total suspended time, longest suspended interval, number of runtime resumes, number of resume errors and whether the boot ended normally.

The eight successful boots total about 11.2 days. But days of uptime are not the best denominator for this failure class: **number of resume attempts is**.

The eight successful cycles in boot #8 alone, including suspends of approximately 49 and 71 minutes, already show that long idle duration is not sufficient to cause failure.

A per-cycle failure rate remains uncertain with only one event, even if many successful cycles are counted.

### **Experiment C — Prevent runtime autosuspend**

A carefully bounded comparison using:

```
echo on | sudo tee /sys/bus/usb/devices/3-3/power/control
```

would prevent that USB device from entering runtime autosuspend. Unlike a reset or driver rebind, it requests normal runtime-PM activation. Nevertheless, **the act of switching to**`on`**can autoresume an already suspended device**, so it should only be done while Bluetooth is healthy and the risk is acceptable.

The setting is temporary unless managed persistently, and it does not disable system-level suspend.

If the device remains healthy over a substantial period with `power/control=on`, that would support a runtime-suspend-related mechanism. One successful week alone would not prove it, because the baseline failure is exceptionally rare.

If another BT-17-like incident occurs while runtime-PM records confirm that the device **never entered runtime suspend**, that would strongly weaken the runtime-autosuspend explanation.

The USB documentation confirms the semantics of `on` and `auto`.

I prefer this per-device control over changing module-wide `enable_autosuspend` parameters, because it minimizes effects on other Bluetooth hardware and avoids manipulating the running driver.

### **Experiment D — Examine platform reset facilities read-only**

Investigate the ACPI namespace, available GPIO descriptors and PCI/USB power ancestry to determine whether Bluetooth has a separately controllable power domain.

The goal is to establish why an xHCI port reset and warm reboot fail to restore the USB function while a full shutdown succeeds.

This examination should remain read-only. There is no justification to exercise an unknown ACPI reset method, reset the Wi-Fi side or power-cycle a USB port on the daily-use machine.

## **10. Where fixes should go**

| Finding or condition                                               | Appropriate subsystem           | Proposed change                                                                                            |
| ------------------------------------------------------------------ | ------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `btusb_waker()` silently loses a failed autoresume                 | **btusb**                       | Improve debug/error reporting and document the deferred-command failure state                              |
| QCA9377 cannot survive runtime suspend with remote wakeup armed    | **btusb**, narrowly scoped      | Consider `BTUSB_WAKEUP_BROKEN` for the proven device/platform combination                                  |
| Normal USB resume signalling is mishandled by AMD `1022:1639`      | **xHCI / USB core**             | Fix the identified port-state or command-ordering defect; avoid a generic Bluetooth workaround if possible |
| Correct USB resume produces a permanently nonresponsive controller | **QCA firmware / platform**     | Firmware fix or reliable controller power/reset sequencing                                                 |
| HCI command credit resumes during a failed/disconnecting transport | **Bluetooth core + btusb**      | Review recovery-state synchronization and queue cancellation                                               |
| `-ETIMEDOUT` appears as Authentication Failed                      | **Bluetooth MGMT**              | Correct errno mapping, with MGMT regression tests                                                          |
| QCA firmware state lost over system suspend on particular laptops  | **Platform-specific USB quirk** | Use targeted reset-resume matching, as historical fixes do                                                 |

For a maintainable H3 quirk, I would expect a patch submission eventually to include a reproducible or well-observed failure trace, exact host/device IDs, firmware identifiers, unambiguous exposure to runtime suspend, and an A/B result showing that the targeted condition avoids failures. It should explain why applying the quirk only to `13d3:3503` on a Ryzen root-hub child is sufficient, what functionality and power savings are sacrificed, and why broader QCA ROME matching is unjustified.

The MediaTek patch provides an implementation pattern, not sufficient evidence on its own.

## **11. Outstanding verification and final judgment**

The source review establishes a coherent causal chain but leaves several limits.

The exact Ubuntu source delta for `7.0.0-42.42~24.04.1` has not been independently checked against `drivers/usb/` and `drivers/base/power/`. Nor have I completed exact blame attribution for every legacy USB-PM function or the original `mgmt_errno_status()` mapping. The mainline code establishes what these paths can do, but the next recurrence must identify which ones actually executed.

The most significant **positive** findings are:

- The HCI reset callback almost certainly waited behind USB runtime-PM failure rather than issuing the first reset itself.
- The xHCI errors include identifiable host-controller command failures during recovery; they should not be reduced to a generic “Bluetooth firmware froze” explanation.
- The 2020 ROME reset history explicitly anticipates power-cycle-only recovery.
- The 2026 MediaTek report independently demonstrates nearly the same USB resume → five-second timeout → reset-resume → disappearance pattern, but with a known remote-wakeup trigger.
- Two independent Ubuntu QCA9377 reports demonstrate related USB enumeration failures, including one in which warm reboot could not restore the device.

The most significant **negative** findings are:

- No evidence makes SCO, ACL traffic, discovery or the `13d3:3503` table entry the cause of BT-17.
- The old QCA DMI reset-resume workaround does not match this machine and should not be generalized to it.
- The AMD `1022:1639` xHCI D3cold quirk is not a direct explanation of an ordinary per-device runtime resume.
- The MGMT Authentication Failed messages are error-conversion artifacts, not evidence of a failed authentication protocol.
- Nothing yet proves that the MediaTek and QCA failures share the same root cause.

**My recommended sequence is therefore: retain the working QCA firmware and device-table fix unchanged; add passive USB-core/xHCI/runtime-PM tracing; count the historical resume cycles; and only then evaluate a targeted no-autosuspend comparison.**

There is no reason to risk a deliberate reset, rebind, module reload or firmware alteration on this laptop to answer the most important open question.

The immediate objective is to capture **who initiated the failed resume and which USB operation consumed the five seconds before the first reset**. That is the evidence which will separate a btusb policy workaround from a genuine USB/xHCI or controller-firmware defect.
