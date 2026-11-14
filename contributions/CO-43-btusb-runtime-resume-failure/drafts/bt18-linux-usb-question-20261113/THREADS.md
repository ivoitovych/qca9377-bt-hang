# BT-18: the four list threads, read in full (2026-11-13)

Every message below was downloaded into `threads/` (file name = prefix + archive file) and read
as text with `scripts/html2txt.py` (`scripts/fetch.py --trim <prefix> <url>...` does both).
lore.kernel.org refuses this machine (403), so the mirrors are lkml.iu.edu, mail-archive.com and
ratatoskr.run. Quotes are short on purpose; the saved pages hold the full text.

---

## 1. The September 2026 "Intel" proposal: Sean Rhodes, "[PATCH v2 0/2] Bluetooth: restore powered-off Intel adapters"

**It is not from Intel.** The author is Sean Rhodes (Star Labs, `sean@starlabs.systems`); it is
*for* Intel combined adapters. Its v1 is "Bluetooth: btusb: clear remote wake on idle Intel ACPI
paths" (2026-08-04, the 940-line rewrite already in CO-43 prior art §4). So the two entries in our
records are one series.

| message | date | URL |
|---|---|---|
| 0/2 cover | 2026-09-17 | https://lkml.iu.edu/hypermail/linux/kernel/2609.2/05874.html |
| 1/2 "usb: core: check ACPI port power during registration" | 2026-09-17 | https://lkml.iu.edu/hypermail/linux/kernel/2609.2/05906.html |
| 2/2 "Bluetooth: btusb: restore powered-off Intel adapters" | 2026-09-17 | https://lkml.iu.edu/hypermail/linux/kernel/2609.2/05888.html |
| CI bot (linux-bluetooth) | 2026-09-17 | in the thread page below |
| Oliver Neukum on 2/2 | 2026-09-22 | https://lkml.iu.edu/hypermail/linux/kernel/2609.2/16641.html |
| whole thread (5 messages, 3 authors) | | https://ratatoskr.run/linux-bluetooth/2026/09/17600257/t (`threads/rat-intel-t.html`) |
| v1 replies (Paul Menzel, Luiz) | 2026-08-04 | https://lkml.iu.edu/hypermail/linux/kernel/2608.0/06813.html (Luiz) |

**What it does:**
- 1/2 (USB core): `usb_port_allow_power_off()` checked ACPI power manageability through the hub
  before `hdev->maxchild` was set, so it always failed; the patch checks the port's ACPI companion
  directly. `Fixes: 8020c41b39f5`.
- 2/2 (btusb), 33 lines:
  - `btusb_intel_acpi_power_manageable()`: `BTUSB_INTEL_COMBINED`, `DEVICE_FIXED`, parent port ACPI
    power-manageable;
  - for those, `HCI_QUIRK_NON_PERSISTENT_SETUP` (setup is rerun at the next open);
  - **a new `btusb_reset_resume()`:** if the adapter is not such an Intel one, **or HCI is running**,
    it sets `intf->needs_binding = 1` and returns 0 (the core's own behaviour, copied); otherwise it
    calls `btusb_resume()`;
  - `btusb_suspend()` returns `-EBUSY` for an autosuspend of a `USB_QUIRK_RESET_RESUME` device that
    is not such an Intel one. That replaces the `autosuspend_check()` gate that a non-NULL
    `reset_resume` would otherwise open (the Dell DMI table relies on it).
- Tested on one machine (Star Labs Lite Mk IV, 8087:0aaa): *"Three Bluetooth off/on cycles reached
  ACPI D3cold"*; also S3 with Bluetooth off.

**State:** open, unmerged.
- Only reply from a person: Oliver Neukum, 2026-09-22: *"Have you tested this with a different
  device and S4?"* and, on the `.reset_resume` line, *"What happens to a connection if a lot of
  data has been lost?"*
- CI bot: SubjectPrefix FAIL (1/2 has a `usb:` prefix), mgmt-tester and mesh-tester FAIL
  (the details were not opened; not ours to judge).
- No maintainer reply (Luiz, Marcel, Greg, Alan) on any mirror; no v3 in the LKML indexes
  2026-09 to 2026-11 (`scripts/hm-search.py "powered-off Intel|ACPI port power during registration"
  2608.0 … 2611.1`).
- Not in bluetooth-next `c9644a9257d15` (2026-11-11) or `da3cc0258`
  (`git log --all --grep`, `git grep btusb_reset_resume`).
- On v1, Luiz: *"This looks way too big to be considered in a single change"*.

**What it means for BT-18:**
- It does **not** fix BT-18: for every non-Intel device, and for an Intel one with HCI running, its
  `reset_resume` sets `needs_binding` and returns, so a runtime reset-resume still leaves btusb
  unresumed. 13d3:3503 is unaffected.
- If it lands, btusb has a `reset_resume` callback. Our patch D (also a `reset_resume`) would
  conflict textually and in design; D already stays local.
- It is the newest instance of the btusb-side rule: Oliver again asks what a reset does to
  connections, as in 2014 and 2017.

---

## 2. The 2014 Loic Poulain thread (Intel, Android, btusb), every message found

Three threads on linux-usb, 2014-03-05 to 2014-04-02. All on mail-archive.com
(`https://www.mail-archive.com/linux-usb@vger.kernel.org/msgNNNNN.html`); index pages:
`search?l=linux-usb@vger.kernel.org&q=from:"Poulain, Loic"` (10 messages),
`q=subject:"Reset-Resume Mechanism does not work"` (15), `q=subject:"rebind mechanism"` (13),
`q=subject:"reset_resume() for btusb"` (11). Every listed message was read.

### 2a. "BUG: USB Reset-Resume Mechanism does not work for runtime resume" (2014-03-05..07)

**This is BT-18, reported with btusb, 12 years ago.** Poulain's log has our exact lines:
`retry with reset-resume`, then `btusb 2-3:1.0: no reset_resume for driver btusb?` and `…1.1…`.

| msg | who, when | key point |
|---|---|---|
| 38493 | Poulain, 03-05 | the mechanism step by step; `usb_resume_complete()` is *"never called in a runtime PM scenario"*; sysfs unbind/rebind recovers |
| 38556 | Oliver Neukum, 03-05 | *"If remote wakeup is needed, reset_resume() must not be used."*; *"the bug in this case is the fallback itself"*; rebinding risks *"a tight loop"* |
| 38571 | Alan Stern, 03-05 | fix the hardware; the alternative, logical disconnect, *"conflicts with the persist_enabled flag"*; workaround: `echo 0 > …/power/persist` |
| 38572 | Alan Stern, 03-05 | **"I suspect this is an oversight."** Lock *"may or may not already be held"* in `usb_runtime_resume`; a work queue *"seems like overkill (and it seems fragile)"* |
| 38597 | Peter Chen, 03-05 | `.reset_resume` *"is a must for class driver"* of autosuspending devices |
| 38626 | Oliver, 03-06 | persist is *"a declaration of a goal"*; without remote wakeup the device should persist |
| 38640 | Poulain, 03-06 | a single failed resume leaves the device *"suspended forever"*; fix the rebind or find another solution |
| 38689 | Alan, 03-06 | agrees with Peter: *"Now you just need to convince the btusb maintainer."* |
| 38697 | Oliver, 03-06 | after a reset the connection is lost; *"it would better be reenumerated anyway"* |
| 38700 | Alan, 03-06 | **sketch:** in `finish_port_resume()`, try the reset-resume only if `!udev->do_remote_wakeup` (else fail → logical disconnect). *"Are there any wakeup-enabled devices that this will mess up?"* |
| 38850 | Peter, 03-06 | *"a patch is welcome"* |
| 38887 | Oliver, 03-07 | *"Potentially HID."*; drivers *"need to be told about the error condition"*; for btusb it *"cannot be handled"* |
| 38907 | Alan, 03-07 | only a reset-resume callback can notify the driver; unbind+rebind suits mobile better than disabling PM |
| 38910 | Oliver, 03-07 | would accept `reset_resume()` with an error flag the core can handle; rebinding *"breaks opened fds"* |
| 38912 | Alan, 03-07 | so does logical disconnect; *"Then we need to add a reset-resume callback to btusb."* |

Alan's `do_remote_wakeup` sketch was never merged: `finish_port_resume()` at `da3cc0258`
(`hub.c:3694-3698`) still retries whenever `persist_enabled`.

### 2b. "[PATCH] rebind: Add rebind mechanism for runtime-resume", v1 to v4 (2014-03-10..04-02)

| msg | version / who, when | content |
|---|---|---|
| 39089 | v1, 03-10 | per-interface `rebind_ws` scheduled from `usb_runtime_resume()`; polls `usb_trylock_device()` for 1 s. Reason: the device lock *"may or may not already be held"* depending on remote wakeup vs local resume |
| 39099 | Greg KH, 03-10 | only: needs a real name in Signed-off-by |
| 39100 | Alan, 03-10 | *"Although the basic idea is okay, this patch has a couple of weak spots."* The loop doesn't sleep; use `usb_lock_device_for_reset()`; kerneldoc missing |
| 39123 | v2, 03-11 | per-interface work, `usb_lock_device_for_reset()` |
| 39141 | Alan, 03-11 | **"This patch looks okay now."** Asks for the btusb test result |
| 39145 | Poulain, 03-11 | works with a forced failure, but btusb's rebind fails: interface 1 is still claimed when interface 0 re-probes (sequential unbind/bind) |
| 39151 | Alan, 03-11 | *"it is a weakness in the USB core"*; posts the unbind-all-then-rebind patch |
| 39197 | Poulain, 03-12 | with Alan's patch and his reworked one, a real btusb runtime-resume failure *"is now handled correctly"* |
| 39214 | Alan, 03-12 | will submit his patch; Poulain's goes on top. Also: drop the confidentiality footer |
| 39215 | v3, 03-12 | **per-device** `udev->rebind_ws`, scheduled (system workqueue, `schedule_work`) from `usb_runtime_resume()` when any interface needs binding; the work takes `usb_lock_device()` and calls `usb_unbind_and_rebind_marked_interfaces()`; `cancel_work_sync()` in `usb_release_dev()`. No PM reference held. No reply |
| 40098 | v4, 04-02 | v3 rebased |
| 40114 | Alan, 04-02 | *"How does this differ from the v3 patch?"* (changelog below `---`) |
| 40126 | Poulain, 04-02 | *"Same content, It's just a rebase"* |

Nothing after 2014-04-02 was found. v3 and v4 still carry the corporate confidentiality footer
Alan had asked him to drop on 03-12; whether that or plain neglect stopped it is not on record
(not for public text). Landed from this work: `6aec044cc2f5` (Alan, 2014-03-12,
*"Reported-and-tested-by"* Poulain, Cc stable). `rebind_ws`/`usb_queue_rebind` are absent at
`da3cc0258` (`git grep`).

### 2c. "reset_resume() for btusb" (2014-03-12..17), the side thread

| msg | who | key point |
|---|---|---|
| 39199 | Oliver, 03-12 | *"it makes little sense to support reset_resume() in btusb"*; a patch: `-EIO` if HCI running, else rerun `hdev->setup` |
| 39218 | Poulain | prefers the core fix; a btusb `reset_resume` was reverted before (HID-mode devices, i.e. `b1a8014471b0`) |
| 39258 | Oliver | even with `reset_resume()` the core must deal with failure; suggests honouring `QUIRK_RESET` |
| 39261 | Peter Chen | that would reset every time |
| 39268 | Oliver | *"We cannot tell devices apart."*; a driver *"isn't told why"* reset_resume is called |
| 39293, 39294 | Alan | device errors → reset-resume or logical disconnect; driver errors → unbind/rebind |
| 39298, 39305 | Oliver, Alan | mode-switching devices: logical disconnect is cleaner (udev events) |
| 39471 | Alan, 03-17 | patch: with `USB_QUIRK_RESET`, skip the reset-resume, fail → logical disconnect |
| 39474 | Oliver | *"Looks perfect."* → merged as `1d10255c1c49` "USB: disable reset-resume when USB_QUIRK_RESET is set" (`hub.c:3672-3684` today) |

So the core already has one case where a needed reset-resume is turned into a logical disconnect
on purpose: question 3 of the mail asks for a second one.

---

## 3. The 2016 Johan Hovold thread: "[PATCH] Revert "USB / PM: Allow USB devices to remain runtime-suspended when sleeping""

| msg | who, when | URL |
|---|---|---|
| patch | Johan Hovold, 2016-05-02 09:37 | https://lkml.iu.edu/hypermail/linux/kernel/1605.0/00492.html |
| reply | Alan Stern, 11:13 | https://lkml.iu.edu/hypermail/linux/kernel/1605.0/00563.html (quoted in full in 00585) |
| reply | Greg KH, 11:22: is that an Ack? | …/00569.html (quoted in 00585) |
| reply | Alan, 11:26: *"Yes."* | https://lkml.iu.edu/hypermail/linux/kernel/1605.0/00585.html |
| reply | Greg, 11:54: *"now applied"* | …/00619.html |
| reply | Johan, 2016-05-03 | …/01437.html |
| stable | Greg, 4.5 73/88 | https://lkml.iu.edu/hypermail/linux/kernel/1605.1/00402.html (index only) |

- Johan: reverting `e3345db85068` (devices left runtime-suspended across system sleep) because
  USB-serial devices needing a rebind were never rebound; *"unlike system resume, run-time resume
  does not honour it."* Below `---`: *"We may be able to find a way around this"*.
- **Alan's doubt (00563):** *"would it help if usb_runtime_resume() did honor the needs_binding
  flag? I doubt it."* Reason: *"Things like the wakeup setting would still be lost"* before the
  runtime resume. He suspects the answer is *"always to resume a USB device if it needs a
  reset-resume"*.
- Johan (01437): he described how it broke, *"not necessarily to suggest how this should be
  fixed"*.
- **Why the doubt does not apply to BT-18:** it is about a device that stayed runtime-suspended
  through a *system* sleep, whose wakeup settings were already lost before any runtime resume. In
  BT-18 the reset-resume happens inside the runtime resume itself (`finish_port_resume()`
  fallback); there is no system transition. The commit message (`9be427efc764`) states the
  runtime gap as a fact; nobody contested that part.

---

## 4. Hongyu Xie, "[RFC PATCH] usb: core: defer leaf-device resume off the S3 critical path" (2026-08-05)

URL: https://ratatoskr.run/lkml/2026/08/17369900/t (`threads/xie-rat-t.html`). 5 messages, all on
2026-08-05; marked stale (no reply since).

- **What:** for *system* resume only (`!PMSG_IS_AUTO`), defer a leaf device's port resume to a
  per-device work item queued from `usb_resume_complete()` on `system_unbound_wq`; the work takes
  `device_lock()`, runs `usb_resume_both()`, then `unbind_marked_interfaces()` +
  `rebind_marked_interfaces()`. Gated by `usbcore.defer_resume`. Motive: a 2 s link-training wait
  on S3 resume.
- **Greg KH:** no module parameter for core functionality: *"This is not the 1990's"*; make it work
  for all systems, without `#ifdef`.
- **Marco Crivellari (SUSE):** `system_unbound_wq` is the old one; use `system_dfl_wq`.
- **Oliver Neukum:** drivers that don't do runtime PM would face effectively suspended devices;
  *"You cannot do this without checking whether remote_wakeup is correctly set."*; **"Furthermore
  you cannot just use the system work queue for this. You must not have any memory allocations
  with GFP_KERNEL on that queue."**
- **Alan Stern:** *"Overall this does not sound like a good idea."* Runtime and system suspend
  *"can have different wakeup settings"*; what about hubs and non-USB children; suggests
  `smart_suspend` / `may_skip_resume`.
- **Relevance to BT-18:** it is the only recent proposal that unbinds/rebinds marked interfaces
  from deferred work, and the reviewers' objections bound a core fix:
  - the queue: not the plain system workqueue for allocating work (Oliver). Note that
    `usb_queue_reset_device()` does rebind from `schedule_work()` today, inside `usb_reset_device()`
    under `memalloc_noio_save()` (`hub.c:6403`, `:6451`, `:6492`; `message.c:1969-1971`). The mail
    asks which applies;
  - remote-wakeup settings must be honoured (Oliver, Alan): in BT-18 the device was autosuspended
    with `do_remote_wakeup` 1, and a reset loses that state.
