# BT-17 source investigation — the third outside reviewer's answer

*Received 2026-11-13 in answer to `2026-11-13T0003Z-bt17-source-investigation-task.md`. The text
is kept as received; `scripts/review-text-clean.py` found no tooling marks to remove.*

*No finding was added or changed. What we checked on 2026-11-13, and what holds:*

- **The new finding holds: a queued xHCI fix matches the tail of our log line by line.**
  - **The patch.** "[PATCH] usb: xhci: Fix ep0 maxpacket update on enabled slots" (Michal
    Pecio, 2026-11-09 11:28 +0100, `<20261109112846.04bfeb0f.michal.pecio@gmail.com>`), read from
    lore's linux-usb archive with `scripts/lore-git-message.sh`.
  - **The maintainer's answer.** Mathias Nyman replied "Added to queue" at 16:57 +0200 the same
    day (`<70031d2d-e9c4-4efd-a4f8-9e60e9b66a52@linux.intel.com>`).
  - **What it describes:**
    - the harmless `WARN: invalid context state for evaluate context command`, "observed when core
      uses 'old scheme' on a full-speed device";
    - the more serious case: after a Transaction Error of Address Device, the slot is left
      Enabled, its input context is corrupted, and "some HCs reject the next Address Device with
      Parameter Error".
  - **The code it fixes is in the kernel that ran.** It patches `xhci_check_ep0_maxpacket()`
    (v7.0 `xhci.c:1549`). v7.0 calls that function from the endpoint-reset path for full-speed ep0
    with no slot-state check (`:3339`). Ubuntu's `7.0.0-42` delta does not touch it (its `xhci.c`
    hunks are at old lines 1009, 3285, 3782 and 3842).
  - **Our log, in order** (`excerpt-boot-1-kernel-failure-window.txt`), on this full-speed device:
    - `device not accepting address 2, error -71` at 18:03:15.653410;
    - the warning at 15.653967;
    - the next reset;
    - `unexpected setup address command completion code 0x11` twice (15.765808, 15.973397);
    - `error -22` at 16.181035.

    Completion code 0x11 is `COMP_PARAMETER_ERROR` (17, `xhci.h:849`).
  - **What it does not explain.** As the review says, it accounts for the recovery tail, not
    for the start:
    - the device had already failed a descriptor read (`-71`, 18:03:14.24) and addressing
      before the first warning;
    - the next boot, with a freshly started xHCI, still could not read its descriptor.
  - **To register:** a defect of its own, fixed upstream by another author, and a backport
    candidate.
- **The history commits exist with the subjects and dates given:**
  - `86c57edf60f5` (Alan Stern, 2008-06-30);
  - `fd865802c66b` (2017-07-08);
  - `61f5acea8737` (2018-01-08);
  - `24ff62ae383f` (2021-09-16);
  - `7c393421755d` and `f07d478090b0` (Hsin-chen Chuang, both 2025-01-08);
  - `161510ccf91c` (Luiz Augusto von Dentz, 2021-10-27).
- **The origin of the misleading MGMT status is settled.** `git show 161510ccf91c --
  net/bluetooth/mgmt.c` adds `mgmt_errno_status()` with `case -ETIMEDOUT: return
  MGMT_STATUS_AUTH_FAILED;`. This is the non-merge commit the second review could not name.
- **Two ordered work queues, as stated.** v7.0 `hci_core.c:2605` (`hdev->workqueue`) and `:2611`
  (`hdev->req_workqueue`) are both `alloc_ordered_workqueue()`. The sync commands' work is queued on
  the second (`hci_sync.c:727`). That is why the MGMT commands could time out every 2 s while the
  command pipeline itself waited behind the blocked timeout handler.
- **The timing arithmetic is ours too.** 40 + 40 + 10 + 5,000 ms leaves about 0.20 s of the 5.291 s
  (the second review's header says the same).
- **On "ROME".** The review suggests writing "QCA9377 using btusb's QCA_ROME path". Qualcomm's
  reply to CO-25 is the reason. The project's evidence (the boot line
  `QCA: patch rome 0x302 build 0x3e8`, linux-firmware's files) is in CO-25's log. The wording is
  accurate either way.
- **Not checked here:**
  - the external reports (Fedora 1514836's `enable_autosuspend=n` result, the Acer Nitro 5 forum
    thread, Ubuntu 1757218 and 2166119, the MediaTek threads);
  - the statement that the ROM-firmware setup also autosuspended.

---

I read the v7.0 source for the participating Bluetooth, USB, xHCI, and runtime-PM paths, followed the relevant commits and later mainline changes, and searched for matching reports. I also tried to make a local sparse `v7.0` checkout as a reproducibility check, but the execution container has no external DNS; the source reading therefore used the exact `v7.0` blobs and commit objects through the GitHub repository interface rather than a filesystem clone. One scope limitation remains from your brief: I could not mechanically apply Ubuntu's `7.0.0-42.42~24.04.1` HWE delta to `drivers/usb/` and `drivers/base/power/`, so those parts below are specifically **mainline v7.0**. The Bluetooth paths match the tree you described.

## Conclusions first

| Question | Conclusion | Confidence |
|---|---|---:|
| **H1: did #121 trigger/join a runtime resume which failed, with USB-Persist then producing the first reset?** | **Yes, very likely.** The missing `btusb_resume()` is decisive that USB-device resume never got far enough to resume the interface. The 5.291 s interval is an excellent match for failed resume → 5 s device GET_STATUS → reset-resume. The only part not proven is whether #121 initiated the resume or joined a device-originated remote wake already in progress, and whether GET_STATUS was specifically the transfer that hung. | **~85–90%** |
| **H2: did the HCI timeout's QCA reset block in `usb_autopm_get_interface()` behind that resume, then return `-EBUSY`?** | **Yes.** The runtime-PM state machine, 5.31 s stall, `-16`, absence of `Resetting usb device.`, and immediate command-credit restoration after the failed PM get fit almost uniquely. | **~95%** |
| **H3: is this the same Ryzen/root-hub defect as MT7922/MT7925?** | **Plausible, but not established.** The terminal symptom/platform/topology are strikingly similar, but the MediaTek case was specifically demonstrated to be **device-initiated remote wake**. BT-17 has not demonstrated that trigger. | **~40%** |
| **Are the xHCI `invalid context state` / `0x11` messages merely consequences?** | There is now a **known xHCI software bug** explaining that portion of the recovery tail. It cannot explain the initial controller death, but it can make a failed reset/re-enumeration attempt worse. | **High** |

There is also a useful distinction around naming. `13d3:3503` is unquestionably routed through the kernel's `BTUSB_QCA_ROME` **software path**, because that is what `dc16388d45ec` explicitly does. [OpenWall Lists](https://lists.openwall.net/linux-kernel/2026/06/27/457) However, a Qualcomm reviewer subsequently stated that QCA9377 is not ROME/QCA6174A. [Lore Kernel](https://lore-kernel.gnuweeb.org/linux-bluetooth/bf27c4e0-31ac-4ee6-b7ba-afc6744e5c0a%40oss.qualcomm.com/T/) I would therefore write future reports as **“QCA9377 using btusb's QCA_ROME path”**, rather than relying on ROME as a silicon-family identification.

---

# 1. The first USB reset — H1

## The code path

The decisive beginning is exactly the path you identified.

In Ubuntu's `btusb.c`, `submit_or_queue_tx_urb()` observes `BTUSB_SUSPENDING`. That flag was set by the successful autosuspend at 17.899 and is normally cleared by `btusb_resume()`. Therefore #121 cannot have been submitted normally: it is anchored on `data->deferred` and `btusb_waker()` is scheduled.

`btusb_waker()` then synchronously does:

```c
usb_autopm_get_interface(data->intf);
```

That leads through runtime PM of interface 0 to its parent `usb_device`, and eventually `usb_resume_both()` → `usb_resume_device()` → `usb_port_resume()`.

The important ordering in `drivers/usb/core/driver.c` is:

1. resume the **USB device**;
2. only if that succeeds, iterate its interfaces;
3. call the interface driver's `.resume`, i.e. `btusb_resume()`.

Current USB-core code retains this device-before-interface ordering. [GitHub](https://github.com/torvalds/linux/blob/master/drivers/usb/core/driver.c)

So this observation is stronger than merely “we didn't see a resume print”:

> **No `btusb_resume()` means the USB device did not successfully complete its own resume.**

The deferred HCI command therefore was never replayed by `play_deferred()`.

### One correction to my earlier progress update

I initially called `USB_RESUME_TIMEOUT` 20 ms. In v7.0 it is **40 ms**.

For a **host-initiated USB2 resume on xHCI**, there are actually two 40 ms waits in this stack:

- xHCI's root-hub `ClearPortFeature(SUSPEND)` handler itself changes U3 → RESUME, sleeps `USB_RESUME_TIMEOUT` = **40 ms**, then changes to U0;
- after that synchronous root-hub request returns, generic `usb_port_resume()` sleeps another **40 ms**;
- then USB core gives the device the required **10 ms TRSMRCY**;
- with `persist=1`, `wait_for_connected()` can additionally wait in 20 ms increments up to 2 s, but normally exits at once when CONNECTION is still set;
- then `finish_port_resume()` issues GET_STATUS, whose timeout is **5000 ms**.

So the minimum interesting timing is roughly:

**40 + 40 + 10 + 5000 = 5090 ms**

against your measured:

**5291 ms**

leaving approximately **201 ms**, not 240 ms, for workqueue dispatch, root-hub operations, USB control scheduling, and possibly a few `wait_for_connected()` iterations.

That is an unusually good match.

## Why the first reset fits `finish_port_resume()`

Mainline v7.0 `drivers/usb/core/hub.c::finish_port_resume()` is the important code:

```c
status = usb_get_std_status(...);

if (status && !udev->reset_resume && udev->persist_enabled) {
        dev_dbg(&udev->dev, "retry with reset-resume\n");
        udev->reset_resume = 1;
        goto retry_reset_resume;
}
```

and the retry calls:

```c
usb_reset_and_verify_device(udev);
```

That eventually enters `hub_port_init()`, which emits the default-level line:

> `reset full-speed USB device number 2 using xhci_hcd`

The intermediate diagnostics — `finish resume`, `retry with reset-resume`, `gone after usb resume?` — are `dev_dbg`, exactly the messages you did not have enabled.

This normal-resume→reset-resume fallback was deliberately introduced by commit `86c57edf60f5`, **“USB: use reset_resume when normal resume fails”**, as part of making USB-Persist survive a failed normal resume. [86c57edf60f5 in Linux git history](https://github.com/torvalds/linux/commit/86c57edf60f5c98adb496880f56cd0e5a3423153) The mechanism remains in modern USB core.

### Is GET_STATUS proven?

Not quite.

The 5-second signature strongly points to the `usb_get_std_status()` control transfer because `USB_CTRL_GET_TIMEOUT` is exactly 5000 ms. But without usbmon or those `dev_dbg` lines, the evidence is circumstantial rather than a wire-level proof.

So I would phrase the finding:

> **The first reset was very probably USB-Persist's reset-resume fallback following a failed runtime resume; the failure was probably the post-resume GET_STATUS timing out.**

not:

> “We proved GET_STATUS timed out.”

That distinction is worth preserving upstream.

## Could a remote wake have started the resume instead?

**Yes.**

This is the main surviving ambiguity in H1.

For USB2, when a remote wake already took the port out of suspend, `usb_port_resume()` detects that state and takes the `SuspendCleared` route rather than initiating the normal Clear-Suspend sequence. `hub_handle_remote_wakeup()` then calls `usb_remote_wakeup()` → autoresume.

Those paths can be essentially invisible with USB-core debug disabled.

Therefore this sequence remains possible:

1. QCA asserts remote wake just before or around 178.731;
2. USB runtime resume starts;
3. #121 arrives while that same resume is already underway;
4. its `btusb_waker()` joins/waits for the existing PM transition;
5. the post-wakeup resume fails.

That would falsify only the words **“host-initiated”** in H1. It would not falsify the important part:

**failed runtime resume → 5 s failure → persist reset-resume → device disappears.**

And it would make H3 considerably stronger.

## What else can produce that same reset printk?

`reset full-speed USB device ... using xhci_hcd` identifies `hub_port_init()` performing a reset of an existing USB device; it does not encode the caller.

Other `usb_reset_device()` callers can ultimately produce the same line.

However, several alternatives leave evidence BT-17 does not have:

- **btusb's HCI-timeout reset:** excluded for the first reset. A successful `btusb_reset()` must print `Resetting usb device.` *before* `usb_queue_reset_device()`. It never did.
- **hub EMI/re-enable path:** normally produces the default-level `disabled by hub (EMI?), re-enabling...` message. Not present.
- **fresh reconnect/enumeration:** normally gives `new full-speed USB device...`, whereas 184.023 is specifically a reset of device #2.
- **overcurrent/connect-change paths:** tend to leave other port/hub diagnostics.
- **remote wake:** can be silent, but by itself does not explain the reset; a subsequent failed resume/reset-resume does.

So another caller is possible in principle, but I did not find one whose timing and log footprint fit better than the persist fallback.

## What the USB/xHCI errors say

`device descriptor read/64, error -71` is `-EPROTO`. It says the control transaction failed at the USB protocol/host-controller level. It does **not** by itself distinguish:

- controller firmware not answering correctly,
- electrical/link trouble,
- host-controller state trouble.

`Device not responding to setup address` is stronger: the Address Device / SET_ADDRESS recovery sequence isn't completing.

The later:

> `WARN: invalid context state for evaluate context command`

and

> `unexpected setup address command completion code 0x11`

have a newly discovered software component.

On November 9, Michal Pecio posted **“usb: xhci: Fix ep0 maxpacket update on enabled slots.”** It explains that after an Address Device Transaction Error, the slot can remain in Enabled state; current xHCI code can then use an uninitialized ep0 output context and issue an invalid Evaluate Context. The warning is specifically described as harmless in one branch; in the more serious branch the corrupted input context can make the next Address Device fail with **Parameter Error**. [Lore Kernel](https://lore-kernel.gnuweeb.org/linux-usb/20261109112846.04bfeb0f.michal.pecio%40gmail.com/)

`0x11` is decimal 17, the xHCI **Parameter Error** completion code; the xHCI specification explicitly uses Parameter Error for an invalid referenced context. [Intel](https://cdrdv2-public.intel.com/625472/625472_xHCI_Rev1_2b.pdf)

Mathias Nyman replied **“Added to queue”** on November 9. As of this investigation I do not find it in Linus's tree yet, so I would treat it as queued rather than merged. [Lore Kernel](https://lore-kernel.gnuweeb.org/linux-usb/70031d2d-e9c4-4efd-a4f8-9e60e9b66a52%40linux.intel.com/)

### This is an important new BT-17 finding

It gives us two failures in the tail:

**A. Original failure:** controller/port cannot successfully resume/respond.

**B. Recovery-path xHCI defect:** once Address Device has already failed, Linux can mishandle the Enabled-slot ep0 context and make later recovery attempts fail with the exact warning/Parameter Error family you saw.

B cannot cause A, because the first HCI silence and the first reset occur before the erroneous re-enumeration sequence. But B may explain part of why the later reset attempts became progressively ugly.

That fix belongs in **xHCI**, independently of whatever fixes BT-17 itself.

## Could a device remain wedged through port power cycle and warm reboot?

Absolutely plausible.

`usb usb3-port3: attempt power cycle` means USB core attempted the hub's port-power mechanism. It does **not** prove that the physical 3.3-V supply to the Bluetooth function on the M.2 module was removed.

On an integrated root hub there may be no independently switched VBUS equivalent for that internal M.2 function. The module's Bluetooth rail, BT_EN/reset signal, or platform power resource can remain asserted while xHCI logically removes/resets the port.

Your empirical distinction is unusually informative:

- xHCI resets: no recovery;
- USB-core “power cycle”: no recovery;
- warm platform reboot: no recovery;
- true machine power-off: recovery;
- PCIe Wi-Fi half remains functional.

That strongly points to a persistent state below the level Linux can currently reset, although determining exactly which M.2 rail or reset signal survives requires ACPI/board information rather than kernel source.

### H1 falsifier

The best falsifier is a recurrence with USB-core dynamic debug/usbmon showing one of these instead:

- GET_STATUS completes successfully;
- no `retry with reset-resume`;
- another `usb_reset_device()` caller initiates the 184.023 reset;
- the reset occurs before the failed resume path reaches `finish_port_resume()`.

---

# 2. The HCI timeout reset — H2

This part is even stronger.

## The exact blocking sequence

`net/bluetooth/hci_core.c::hci_cmd_timeout()` does:

```c
if (hdev->reset)
        hdev->reset(hdev);

atomic_set(&hdev->cmd_cnt, 1);
queue_work(hdev->workqueue, &hdev->cmd_work);
```

The reset callback is therefore **synchronous** with respect to command-timeout recovery. Command credit remains zero until it returns.

For the QCA_ROME software path:

```text
hci_cmd_timeout()
  -> btusb_qca_reset()
     -> btusb_reset()
        -> usb_autopm_get_interface(data->intf)
```

and `btusb_reset()` has a particularly useful diagnostic invariant:

```c
err = usb_autopm_get_interface(...);
if (err) {
        bt_dev_err(..., "Failed usb_autopm_get_interface: %d", err);
        return;
}

bt_dev_err(..., "Resetting usb device.");
usb_queue_reset_device(...);
```

Therefore:

> Had the PM get succeeded, **`Resetting usb device.` must have appeared.**

It didn't.

Instead, 5.31 s later:

> `Failed usb_autopm_get_interface: -16`

appears and then command credit is restored.

That establishes that **btusb never queued its reset**.

## Why `-16` fits `rpm_resume()` specifically

`-16` is `-EBUSY`.

Mainline v7.0 `drivers/base/power/runtime.c::rpm_resume()` has two relevant pieces.

First, a synchronous caller finding a device in `RPM_RESUMING` or `RPM_SUSPENDING` waits on its PM waitqueue until the transition changes state.

Second, while resuming a child it synchronously resumes the parent:

```c
rpm_resume(parent, 0);

if (parent->power.runtime_status != RPM_ACTIVE)
        retval = -EBUSY;
```

That fits this nested sequence especially well:

```text
btusb_waker
  usb_autopm_get_interface(intf0)
    resume intf0
      resume parent USB device 3-3
        RPM_RESUMING
          usb_port_resume()
             ... hangs/fails for ~5 s ...

2.04 s later:

hci_cmd_timeout
  btusb_qca_reset
    usb_autopm_get_interface(intf0)
      tries to resume parent 3-3
        finds parent RPM_RESUMING
        waits
        original resume eventually fails
        parent != RPM_ACTIVE
      returns -EBUSY
```

Then, essentially immediately:

```text
Failed usb_autopm_get_interface: -16
cmd_cnt = 1
cmd_work queued
```

which is precisely the log.

I do not see another generic explanation for a **5.31-second** synchronous PM get followed by exactly `-EBUSY` that fits this chronology as well.

The 1 µs ordering between the PM error and `USB disconnect` isn't meaningful enough to infer which CPU printed first. They are effectively the same transition.

## What is blocked while `hdev->reset` blocks?

`hdev->workqueue` is created with:

```c
alloc_ordered_workqueue(...)
```

and `cmd_timer` itself runs there. So while `hci_cmd_timeout()` is sleeping inside the reset callback, later work on that same ordered workqueue cannot run.

Most importantly:

- command credit remains zero;
- `cmd_work` does not run;
- commands do not leave through the ordinary command pipeline.

The sync-request machinery has a separate `req_workqueue`, which explains why the subsequent MGMT operations can be accepted, queue work and themselves reach their ~2 s timeout while the physical command pipeline is stalled.

This is exactly what E3/E6 show.

## Was synchronous reset intended?

Yes.

This is not an accidental side effect newly introduced by QCA.

The timeout reset policy for this family begins with commit `6933568aec92`, **“Bluetooth: btusb: Reset port on cmd timeout.”** Its stated reason is succinct: QCA_ROME sometimes becomes unresponsive to commands and, without a reset GPIO, the driver should reset the USB port. [6933568aec92 — btusb Reset port on cmd timeout](https://github.com/torvalds/linux/commit/6933568aec92dd6432207baaf59378d01f55a14f)

Later changes made the policy more explicit:

- `24ff62ae383f` added use of a real BT_EN reset mechanism where the platform exposes one, retaining USB reset as fallback. [24ff62ae383f](https://github.com/torvalds/linux/commit/24ff62ae383f776ab0285f2996de6bd9bb2d2e4b)
- `7c393421755d`, **“Remove the cmd timeout count in btusb”**, moved toward resetting after the first timeout because only one command is in flight.
- `f07d478090b0`, **“Get rid of cmd_timeout and use the reset callback”**, changed the callback plumbing while explicitly saying it was not intended to change behavior.

So on current policy, **first command timeout → QCA reset callback** is intentional.

Whether USB port reset is actually a sensible recovery action for a controller that is already physically wedged is another question. Your August controlled tests and the history behind this callback both suggest that for some QCA failures the USB reset can fail to recover it.

In BT-17, however, it never got that far.

## Frame #122 after disconnect

This is real, but secondary.

`hci_cmd_timeout()` doesn't know whether the `void hdev->reset()` actually reset anything. After it returns it unconditionally:

```c
atomic_set(&hdev->cmd_cnt, 1);
queue_work(...cmd_work);
```

So a reset implementation that bails because the USB device is disappearing still causes command credit to be restored.

That is exactly how #122 can be handed to the driver at 186.083.

I would classify this as a **Bluetooth-core recovery robustness issue**, not a cause of BT-17.

It is worth auditing separately because the reset callback has no return value with which to tell `hci_cmd_timeout()`:

> “the transport is dead; don't restart the command queue.”

A fix may need either transport-state gating before restarting commands, or a reset API capable of reporting failure. I would not propose a one-line `HCI_RUNNING` test without first checking unregister/close locking, because this crosses exactly the timeout/disconnect race your trace exposed.

### H2 falsifier

PM tracepoints would have to show the timeout's `usb_autopm_get_interface()` was **not** waiting behind the parent `3-3` resume, or that its `-EBUSY` came from a different transition. Given the timestamps and source, that would surprise me.

---

# 3. H3 — the Ryzen remote-wakeup quirk

This is the most interesting hypothesis, but it needs one more occurrence with the right tracing before I would turn it into a patch.

## What actually happened with MT7922/MT7925

The MediaTek report is considerably more specific than merely “resume breaks Bluetooth.”

The reported sequence was a **remote wakeup while the device was runtime suspended**. After that remote wake the btusb interface became completely unresponsive; resetting the xHCI root hub did not recover it, and recovery required a power cycle. [OpenWall Lists](https://lists.openwall.net/linux-kernel/2026/07/01/1946)

The follow-up deliberately limited the workaround to:

- Ryzen (`X86_FEATURE_ZEN`);
- MT7922/MT7925;
- devices directly attached to a root hub.

The author explicitly said all reports seen were Ryzen based and that determining whether the root hub was the actual SoC/PCH controller through PCI hierarchy inspection was considered too intrusive. [OpenWall Lists](https://lists.openwall.net/linux-kernel/2026/07/01/1946)

MediaTek themselves did not have a reproducing AMD environment when reviewing it. [lists.infradead.org](https://lists.infradead.org/pipermail/linux-mediatek/2026-July/110750.html)

So nothing in that work established an xHCI silicon bug. It established a narrow empirical combination where suppressing the dangerous runtime-suspended/remote-wakeup state was effective.

## Similarity to BT-17

The similarities are unusually strong:

- Ryzen;
- direct root-hub child;
- btusb device;
- HCI open;
- runtime autosuspend;
- remote wake armed;
- completely nonresponsive afterward;
- xHCI reset cannot fix it;
- power cycle required.

But there is one important missing link:

> **BT-17 has not shown a remote-wakeup event.**

The command at 178.731 is itself sufficient to request a host autoresume.

That gives us two possible versions of BT-17:

**A. Host-resume version**

```text
#121 -> btusb waker -> host runtime resume -> controller dies/fails resume
```

This is **not** the demonstrated MediaTek trigger.

**B. Remote-wake version**

```text
controller remote wake -> USB autoresume starts
#121 arrives during it -> joins same transition
resume fails
```

This is almost eerily close to the MediaTek failure.

Your next trace can distinguish them.

## Other Qualcomm evidence

There is substantial evidence that Qualcomm USB Bluetooth has its own resume/autosuspend problems without Ryzen.

The strongest is Fedora bug 1514836. On a Dell XPS 13 9360 with QCA6174/USB `0cf3:e300`, the reporter said that adding:

```text
btusb.enable_autosuspend=n
```

made Bluetooth dramatically more reliable over roughly a week and a half; idle-time disappearance largely went away, leaving only occasional whole-system suspend failures. The reported kernel at that point was Fedora 28's `4.16.0-0.rc6.git0.2`. [Red Hat Bugzilla](https://bugzilla.redhat.com/show_bug.cgi?format=multiple\&id=1514836)

That bug is precisely what produced much of the old QCA reset-resume history.

So runtime PM can be pathological for this broad software family **even on non-Ryzen systems**.

There is also an AMD/QCA report from an Acer Nitro 5 with Raven/Raven2 and QCA6174: the controller appears immediately after boot and disappears about half a minute later. It lacks the tracing necessary to call it the same bug, but it is an interesting weak match. [Arch Linux Forums](https://bbs.archlinux.org/viewtopic.php?id=251103)

And there are two particularly close QCA9377 “persistent bad power state” reports:

- older Ubuntu QCA9377 failures produced the same full-speed `descriptor read/64, error -71` / failed enumeration pattern and could persist across reboot; that case was tied to USB2 LPM lingering in L1 across shutdown and was fixed by disabling USB2 LPM at shutdown. [OpenWall Lists](https://lists.openwall.net/linux-kernel/2018/11/06/820)
- Ubuntu bug 2166119, September 2026, QCA9377 on `7.0.0-30-generic` / upstream 7.0.12, reports Bluetooth USB enumeration failing with `-110/-71` while Wi-Fi on the combo adapter still works. The reporter recovered it by a genuine cold power drain. [Mail Archive](https://www.mail-archive.com/ubuntu-bugs%40lists.ubuntu.com/msg6305931.html)

Neither proves BT-17, but they demonstrate that **“QCA9377 Bluetooth half enters a state warm reboot cannot clear while Wi-Fi remains alive” is not unique to this laptop.**

I did **not** find a published report that simultaneously establishes:

**QCA9377/QCA6174 + Renoir/Cezanne/Barcelo 1022:1639 + runtime suspend/remote wake + power-off-only recovery + A/B confirmation with `power/control=on`.**

That exact report is still missing.

## The old QCA reset-resume history matters here

The sequence is instructive:

1. `fd865802c66b`, **“btusb: fix QCA Rome suspend/resume”**: numerous QCA devices stopped functioning after resume; the interpretation was that some platforms removed device power.
2. The original btusb-local reset-resume approach was reverted because it had problems.
3. `61f5acea8737`, **“Restore QCA Rome suspend/resume fix with a rewritten version”**, moved it to the USB core's `USB_QUIRK_RESET_RESUME`. The commit explicitly noted that this also disables autosuspend for those devices.
4. `1fdb92697469`, **“Use DMI matching for QCA reset_resume quirking”**, narrowed it again because **most platforms resumed QCA perfectly well**, while the broad quirk increased power consumption for everyone. The conclusion was that the failure was platform dependent, probably power removal. The DMI-scoped table remains in current mainline. [GitHub](https://github.com/torvalds/linux/blob/master/drivers/bluetooth/btusb.c)

This history argues strongly against an upstream proposal like:

> “all `BTUSB_QCA_ROME` devices on Ryzen are broken.”

The kernel already learned the hard way that overly broad QCA PM quirks cost power unnecessarily.

## What I would submit if BT-17 is reproduced

Initially, **the narrowest possible quirk**:

```text
13d3:3503
+
Ryzen
+
direct child of root hub
```

not all QCA_ROME and certainly not all btusb devices on Ryzen.

If recurrence proves **remote wake** is the transition, reusing `BTUSB_WAKEUP_BROKEN` is conceptually defensible.

If recurrence proves a purely **host-initiated runtime resume** wedges it, I would be less comfortable calling it `WAKEUP_BROKEN`. The workaround is still effective — preventing runtime suspend while HCI is open prevents either kind of runtime resume — but the actual defect would be “runtime suspend/resume broken”, not specifically remote wake. Maintainers might reasonably prefer a differently named/generalized btusb runtime-PM quirk.

The patch would need evidence showing:

1. exact USB-PM trace of the failure;
2. preferably one more occurrence;
3. A/B demonstrating that preventing autosuspend removes the failure over comparable exposure;
4. no need for the quirk when HCI is closed;
5. narrow hardware/platform scope;
6. ideally another affected Ryzen/QCA9377 machine.

Until then, H3 is a **candidate workaround hypothesis**, not a finding.

---

# 4. QCA controller side

`btusb_setup_qca()` does **not** contain an obvious command that says “enable USB deep sleep” or “configure USB remote wake.”

For this USB path it:

- queries target/version/status;
- loads the rampatch;
- downloads the NVM file;
- completes normal HCI setup.

The NVM blob itself is opaque from this code's perspective.

There are Qualcomm Bluetooth paths elsewhere with explicit TLV/NVM tags relating to sleep/deep sleep, but those are not evidence that this USB QCA9377 setup is programming an equivalent setting.

So:

> **I found no Linux-side btusb/btqca line that directly configures the USB suspend state involved in BT-17.**

That does **not** mean firmware is irrelevant. The rampatch completely changes executing controller firmware, and NVM can alter controller configuration invisible to the host source. Patched firmware could therefore behave differently during USB suspend.

But your earlier ROM-firmware system also autosuspended, so merely enabling runtime PM is not a new effect introduced by `dc16388d45ec`.

## Recovery once ep0 is dead

Once the device cannot complete USB enumeration/control transfers:

- HCI vendor commands are impossible; no HCI transport exists.
- Wi-Fi-side `ath10k` reset is not a generic documented reset mechanism for the Bluetooth USB half.
- btusb has no BT_EN GPIO on this platform.
- a useful ACPI power-cycle method could exist only if firmware exposes the module's power/reset resource.

So there is no generic software recovery path in these drivers that I would trust once BT-17 reaches the state seen after 184 s.

The meaningful source-level fix is therefore probably **preventive**, unless the platform can expose a real BT_EN/module reset.

---

# 5. The misleading MGMT `Authentication Failed`

You found a genuine semantic wart.

`mgmt_errno_status()` still contains this on current mainline:

```c
case -ETIMEDOUT:
        return MGMT_STATUS_AUTH_FAILED;
```

while real HCI status values such as Connection Timeout and Host Timeout map to `MGMT_STATUS_TIMEOUT`. [GitHub](https://github.com/torvalds/linux/blob/master/net/bluetooth/mgmt.c)

I traced the errno conversion to commit:

`161510ccf91c961638940b03abb1ee804be53a97`
**“Bluetooth: hci_sync: Make use of hci_cmd_sync_queue set 1”**

That commit converted exactly the operations relevant here — Set Device Class, Add UUID, Remove UUID, etc. — to the sync command machinery and introduced `mgmt_errno_status()` with `-ETIMEDOUT → AUTH_FAILED`.

Its commit message gives no rationale for that particular mapping.

So the four BlueZ messages:

> `Failed to remove UUID: Authentication Failed`

do **not** mean authentication took place or failed. They are simply the kernel translating a local synchronous HCI timeout through this generic errno table.

I think **`MGMT_STATUS_TIMEOUT` is semantically correct** for this situation. Changing the generic mapping deserves a caller audit because `-ETIMEDOUT` can arise from several operations, but `AUTH_FAILED` is demonstrably misleading for Remove UUID.

This remains unchanged today. [GitHub](https://github.com/torvalds/linux/blob/master/net/bluetooth/mgmt.c)

---

# 6. The reset-resume / QCA reports, summarized

| Device / platform | Kernel | Observation | Relevance |
|---|---|---|---|
| **QCA6174 `0cf3:e300`, Dell XPS 13 9360** | Fedora 4.16-rc6 era | Bluetooth disappeared during idle; `btusb.enable_autosuspend=n` made reliability dramatically better over ~1.5 weeks. | **Strong evidence QCA btusb runtime PM can be problematic independently of Ryzen.** [Red Hat Bugzilla](https://bugzilla.redhat.com/show_bug.cgi?format=multiple\&id=1514836) |
| **QCA6174, Acer Nitro 5 AN515-42, AMD Raven/Raven2** | not well specified | Controller appears after boot and disappears ~30 s later. | Weak but interesting AMD+QCA analogue. [Arch Linux Forums](https://bbs.archlinux.org/viewtopic.php?id=251103) |
| **QCA9377, Ubuntu bug 1757218** | Bionic-era kernels | `descriptor read/64, error -71`, warm-boot disappearance; traced to USB2 LPM L1 surviving shutdown; fixed by disabling USB2 LPM on shutdown. | Same persistence/enumeration phenotype, **different PM mechanism**. [OpenWall Lists](https://lists.openwall.net/linux-kernel/2018/11/06/820) |
| **QCA9377, ASUS VivoBook X512FB** | Ubuntu `7.0.0-30`, upstream 7.0.12 | `-110/-71`, BT not enumerated while Wi-Fi works; cold power drain recovered it. | Very close final state; initiating cause unknown. [Mail Archive](https://www.mail-archive.com/ubuntu-bugs%40lists.ubuntu.com/msg6305931.html) |
| **MT7922/MT7925, Ryzen direct root hubs** | 2026 kernels | runtime-suspend remote wake → completely unresponsive; xHCI reset ineffective; power cycle required. | Closest known causal analogue; vendor differs. [OpenWall Lists](https://lists.openwall.net/linux-kernel/2026/07/01/1946) |

The Ubuntu 1757218 mechanism specifically involved USB2 hardware LPM L1. BT-17's device is USB 1.10 and has no `usb2_hardware_lpm` sysfs attribute, so I would **not** reuse that explanation for BT-17. It matters as evidence of persistent QCA power-state failures, not as the same bug. Linux documentation confirms USB2 hardware LPM is a separate xHCI facility from ordinary USB selective/runtime suspend. [Linux Kernel Archives](https://cdn.kernel.org/doc/html/latest/driver-api/usb/power-management.html)

---

# 7. Where the fix belongs

For the **initiating BT-17 defect**, the evidence is not yet sufficient to pick one root-cause subsystem.

If passive tracing proves:

**remote wake specifically causes it on Ryzen:**  
preventive workaround in **btusb**, initially 13d3:3503 + Ryzen + direct root hub, analogous to MTK.

**any runtime resume causes the QCA9377 to wedge regardless of remote wake:**  
still probably a **btusb device/platform runtime-PM quirk** as the practical fix; ultimate root cause could be QCA firmware or platform power/reset sequencing.

**the xHCI port itself fails to return correctly from USB2 suspend before the device is touched:**  
then **xhci/AMD platform** becomes more likely.

**the same QCA9377 fails on unrelated host controllers:**  
controller firmware/NVM moves to the front.

The separate post-failure Enabled-slot/ep0 problem belongs unequivocally in **xhci**, and a fix is already queued. [Lore Kernel](https://lore-kernel.gnuweeb.org/linux-usb/20261109112846.04bfeb0f.michal.pecio%40gmail.com/)

I see no reason from this incident to put an initiating fix into Bluetooth core. Bluetooth core has a **secondary recovery/API issue** around restoring `cmd_cnt` after a failed reset.

---

# 8. The experiment that decides the most

I agree with your first candidate, with one addition: **make the next natural occurrence observable rather than intentionally provoking it.**

On 7.0.0-43, keep normal daily use and enable:

- dynamic debug for `drivers/usb/core/hub.c` and `drivers/usb/core/driver.c`;
- xHCI trace events around port status/resume and commands;
- preferably a passive usbmon capture for bus 3, if its logging volume is acceptable;
- runtime-PM tracepoints if convenient.

The crucial lines/events are:

```text
usb auto-resume
        versus
usb wakeup-resume

Waited Nms for CONNECT
finish resume
<GET_STATUS submission/completion in usbmon>
retry with reset-resume
gone after usb resume? status ...
```

Then correlate the second `usb_autopm_get_interface()` with the runtime-PM state.

A **single recurrence** with that data can simultaneously answer:

- Did #121 initiate the resume, or did a remote wake precede it?
- Did the first resume signalling reach U0?
- Did GET_STATUS really sit for 5 s?
- Was `retry with reset-resume` exactly the 184.023 reset?
- Did the HCI timeout's PM get block behind `RPM_RESUMING`?
- Which failed Address Device transition precedes the xHCI ep0-state bug?

That is much more discriminating than intentionally resetting anything.

## What I would do after that

Counting all historical device-level suspend/resume cycles is worthwhile now. Your present denominator of 11.2 days is useful, but **1 failure / N runtime resumes** is much better for judging a PM quirk.

Then an A/B test is valuable:

**A:** ordinary `control=auto`.  
**B:** set `/sys/bus/usb/devices/3-3/power/control=on` early after boot, or boot with btusb autosuspend disabled.

Do not reload/rebind anything.

Because the failure rate appears low, this will take exposure rather than a handful of cycles. But if the controller remains reliable through a comparable number of days and activity transitions with runtime suspend prohibited, that establishes runtime suspend as a necessary condition.

It still would not distinguish QCA firmware from Ryzen/xHCI; the passive trace does that better.

I agree that QEMU has almost no value for the principal bug. It can test Bluetooth-core bookkeeping such as #122, but it cannot reproduce the physical combination that matters here: QCA controller firmware, AMD xHCI USB2 resume signaling, and the laptop's actual M.2 power/reset domain.

---

# My reconstructed BT-17 sequence

The most probable code-level reconstruction is therefore:

```text
17.899
usb runtime autosuspend succeeds
  btusb_suspend(if1)
  btusb_suspend(if0)
  BTUSB_SUSPENDING remains set
  USB port suspended
  remote wake enabled because HCI remains open

178.731
HCI Write Class of Device handed to btusb

submit_or_queue_tx_urb()
  sees BTUSB_SUSPENDING
  anchors URB in data->deferred
  schedules btusb_waker()

btusb_waker()
  usb_autopm_get_interface(intf0)
    PM core starts resume of parent USB device 3-3
      usb_port_resume()
        USB2/xHCI resume
        device does not recover sufficiently
        finish_port_resume()
          likely GET_STATUS waits 5000 ms
          fails
          persist == 1
          "retry with reset-resume"
          usb_reset_and_verify_device()

180.772, while that is still happening
hci_cmd_timeout()
  hci_cmd_sync_cancel_sync()
  btusb_qca_reset()
    btusb_reset()
      usb_autopm_get_interface(intf0)
        waits behind parent 3-3's RPM_RESUMING state

184.023
USB-Persist reset-resume reaches hub_port_init()
  "reset full-speed USB device number 2 ..."

reset/re-enumeration fails
  -EPROTO / address failure
  later xHCI ep0 Enabled-slot bug can contribute
  invalid-context warning / Parameter Error 0x11

186.083
USB device logically disconnected
original PM transition completes unsuccessfully

second usb_autopm_get_interface()
  sees parent did not become RPM_ACTIVE
  returns -EBUSY

btusb_reset()
  prints Failed usb_autopm_get_interface: -16
  never prints Resetting usb device.
  never queues its own reset

hci_cmd_timeout()
  finally resumes
  cmd_cnt = 1
  queues cmd_work

#122 is handed down while transport is disappearing

hci_unregister_dev follows
```

There is one fork at the beginning:

```text
possible device remote wake
        ↓
resume already underway
        ↓
#121's waker joins it
```

instead of #121 itself starting the resume.

**That fork is now the single most important unanswered question.**

If the next natural occurrence says `wakeup-resume`, H3 moves from an interesting analogy to a very serious patch candidate. If it says cleanly `auto-resume` initiated by #121 with no preceding remote wake, I would stop calling this “the MediaTek remote-wakeup bug” and treat it as a QCA9377/runtime-resume failure on this platform whose safest initial workaround happens to resemble the MTK one.

The other finding I would immediately add to BT-17's project record is the November 9 xHCI patch: **the `invalid context state` and subsequent `0x11` sequence is no longer safe to interpret as evidence that AMD xHCI hardware itself malfunctioned. There is now a specific Linux xHCI recovery bug capable of producing that tail after an Address Device failure.** [Lore Kernel](https://lore-kernel.gnuweeb.org/linux-usb/20261109112846.04bfeb0f.michal.pecio%40gmail.com/)
