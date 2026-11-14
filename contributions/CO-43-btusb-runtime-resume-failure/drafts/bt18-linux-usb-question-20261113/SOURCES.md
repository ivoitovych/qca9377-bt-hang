# Sources for `question-linux-usb.txt` (2026-11-13)

Code: bluetooth-next `da3cc02587c629420603df4395179ec82955c941`, read with
`git -C /root/exp/agent-work/bt17-emu-20261113/linux show da3cc0258:<path>` and
`git … grep -n <pattern> da3cc0258 -- <path>`. History: `/root/exp/qca9377-bt-hang/cache/linux`
(`git show -s`, `git log --full-history -S`). Threads: `THREADS.md` (saved pages in `threads/`).

## 1. The mechanism (mail paragraph 2)

| claim in the mail | source at `da3cc0258` |
|---|---|
| a failed runtime resume's GET_STATUS, with persist, is retried as a reset-resume in `finish_port_resume()` | `drivers/usb/core/hub.c:3690-3699`: `usb_get_std_status()`; `if (status && !udev->reset_resume && udev->persist_enabled)` → `"retry with reset-resume"`, `udev->reset_resume = 1; goto retry_reset_resume;` (`:3679-3684` does the reset). Added by `86c57edf60f5c` (Alan Stern, 2008, "USB: use reset_resume when normal resume fails") |
| `usb_resume_interface()` sets `needs_binding` and skips a driver with no `reset_resume` | `driver.c:1367-1377`: `if (reset_resume) { if (driver->reset_resume) … else { intf->needs_binding = 1; dev_dbg(… "no reset_resume for driver %s?\n" …` |
| called with the reset-resume flag from `usb_resume_both()` | `driver.c:1558-1583` (`usb_resume_interface(udev, intf, msg, udev->reset_resume)`) |
| system path: `usb_resume()` unbinds, `usb_resume_complete()` rebinds | `driver.c:1660-1686` (`unbind_marked_interfaces(udev)` at `:1677`; comment `:1669-1670`: *"This can't be done in usb_resume_interface() above because it doesn't own the right set of locks."*); `driver.c:1647-1657` (`rebind_marked_interfaces(udev)` at `:1655`); called from `usb_dev_complete()` (`usb.c:533-536`) |
| `usb_reset_device()` also acts on the flag | `hub.c:6431-6451`: marks interfaces without `post_reset`, then `usb_unbind_and_rebind_marked_interfaces(udev)` at `:6451` |
| `usb_runtime_resume()` returns after `usb_resume_both()` | `driver.c:2022-2032` |
| nothing else acts on the flag | `git grep -n needs_binding da3cc0258 -- drivers/usb include/linux/usb.h`: setters `driver.c:1141`, `:1374`, `hub.c:6445`, `usb-serial.c:1338`; clearers `driver.c:332`, `:568`, `:1184` (`usb_rebind_intf`); readers `driver.c:1160`, `:1207`, `:1363`, `hub.c:6435`. The only callers of the rebind helpers are `usb_resume_complete()` and `usb_reset_device()` |
| every later resume skips the driver while the flag is set | `driver.c:1362-1364`: `/* Don't resume if the interface is marked for rebinding */ if (intf->needs_binding) goto done;` |
| `autosuspend_check()` keeps drivers without `reset_resume` out of autosuspend only for `USB_QUIRK_RESET_RESUME` devices | `driver.c:1959-1970` (`if (udev->quirks & USB_QUIRK_RESET_RESUME) { … if (!driver->reset_resume || intf->needs_remote_wakeup) return -EOPNOTSUPP;`) |
| btusb: `supports_autosuspend`, no `reset_resume` | `drivers/bluetooth/btusb_main.c:5096-5104` (`.suspend`, `.resume`, `.supports_autosuspend = 1`; no `.reset_resume`) |
| btusb: `BTUSB_SUSPENDING` stays set, HCI traffic stays on the deferred anchor | set in `btusb_suspend()` `btusb_main.c:4948`; cleared only in `btusb_resume()` `:5069`, `:5079`; `submit_or_queue_tx_urb()` `:2388-2408` anchors on `data->deferred` while it is set; every send path returns through it (`:2421`, `:2439`, `:2447`, `:2466`, and vendor variants) |
| the `needs_binding` handling is unchanged since 2014 | `git log --full-history -S"needs_binding" origin/master -- drivers/usb/core/{driver,hub,usb}.c` in `cache/linux`: last real change `6aec044cc2f56` (2014-03-12); the other hit, `028ef9c96e961` "Linux 7.0", is the shallow graft |

## 2. The reproduction (mail paragraphs 3-4)

| claim | source |
|---|---|
| QEMU, usbip `vhci_hcd`, emulated `13d3:3503` QCA9377 | `results/bt17-emulation-2026-11-13/README.md` "What it is" |
| holds the first GET_STATUS after a resume, answers normally once the host gives up | README "The fault": holds the request; with `--recover` healthy again *"when the host unlinks the held request, not at a USB reset"*. Log lines 102-104: `EMU resume #1: GET_STATUS held`, `EMU host gave up on held GET_STATUS of resume #1 (unlink)`, `EMU device recovers (--recover)` |
| the resume is started by powering hci0 off, so btusb's command-timeout reset never runs | README triggers (`close-recover`, *"btusb's close takes a PM reference"*); `docs/issues.md` BT-18 entry; no `Resetting usb device.` in `base-m-close-1.log` (`grep -c "Resetting usb device"` = 0) |
| all 5 unpatched runs end with Bluetooth dead | `grep -H "RESULT close-recover" logs/runs/base-m-close-{1..5}.log`: all five `bluetooth_works_after=False` |
| both interfaces print "no reset_resume" in every run | `grep -c "no reset_resume for driver btusb"` = 2 in each of the five logs |
| dynamic debug on | README "Debug on: USB core `hub.c` and `driver.c` …" |
| neither HCI Reset reached the device | `grep -n -E "HCI cmd |EMU "`: the emulator's last `HCI cmd` line is 93 (mono 3.18); none after the reset-resume; the two `0x0c03` failures are kernel lines 607 and 618 |
| the device answered the GET_STATUS at 16.46 normally | log line 112: `13.703 [mono  16.456791] EMU resume #2: GET_STATUS answered`; line 119: `EMU suspends 2 resumes 2 state healthy` |
| "wakeup 1" = `do_remote_wakeup` | `hub.c:3616-3618`: `dev_dbg(&udev->dev, "usb %ssuspend, wakeup %d\n", …, udev->do_remote_wakeup);` |

**The excerpt:** `results/bt17-emulation-2026-11-13/logs/runs/base-m-close-1.log`
(SHA-256 `910a54042433521811f9c05a2455883b944ca64ca632871206c75b32da11848b`, equal to
`logs/runs/SHA256SUMS` line 32; on `origin/main`, `git cat-file -e` OK), **lines 581, 583, 588,
591, 594, 596, 599, 600, 605, 607, 608, 612, 615, 616, 618**, colour codes removed by
`scripts/excerpt.py`. Checked against the mail with
`scripts/excerpt-check.py question-linux-usb.txt <log> 581 583 588 591 594 596 599 600 605 607 608 612 615 616 618`:

```
mail lines: 15 requested: 15
OK   581 [    5.191615] usb 2-1: usb auto-suspend, wakeup 1
OK   583 [    6.246282] bt17-emu: Set Powered off sent at mono 6.246867
OK   588 [    6.256233] usb 2-1: usb auto-resume
OK   591 [    6.316575] usb 2-1: finish resume
OK   594 [   11.525929] usb 2-1: retry with reset-resume
OK   596 [   11.645386] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
OK   599 [   11.782534] btusb 2-1:1.0: no reset_resume for driver btusb?
OK   600 [   11.782545] btusb 2-1:1.1: no reset_resume for driver btusb?
OK   605 [   13.784208] usb 2-1: usb auto-suspend, wakeup 1
OK   607 [   16.387289] Bluetooth: hci0: Opcode 0x0c03 failed: -110
OK   608 [   16.387781] Bluetooth: hci0: HCI reset during shutdown failed
OK   612 [   16.396845] usb 2-1: usb auto-resume
OK   615 [   16.455315] usb 2-1: finish resume
OK   616 [   17.416371] bt17-emu: Set Powered on sent at mono 17.417119
OK   618 [   19.427408] Bluetooth: hci0: Opcode 0x0c03 failed: -110
ALL VERBATIM
```

Left out on purpose: the vhci `unlink`/`speed not set` lines (592-593, 595, 597-598), hub state
lines, and the bare btusb `intf ffff…` debug lines (573, 580, 603-604), which carry no prefix and
would need explaining.

## 3. The laptop (mail paragraph 5)

`results/incident-2026-11-12-1803/README.md` lines 41-77 and the emulation README's comparison
table:
- idle 161.98 s (`18:00:26.845 → 18:03:08.827`, line 56); Ubuntu `7.0.0-42` (line 97); autosuspend
  on (trial row `autosusp=Y`, line 82);
- Write Class of Device sent 18:03:08.827012 (line 47), no event; first
  `reset full-speed USB device number 2 using xhci_hcd` at 18:03:14.120456 (line 66): 5.293 s;
- `device descriptor read/64, error -71` (line 67), `USB disconnect` (line 71), later
  `unable to enumerate USB device` (line 76);
- `usb auto-resume`, `finish resume`, `retry with reset-resume`: **not logged** (emulation README
  table: "not logged"); hence "inferred from the timing and the code". The 5 s matches
  `usb_get_std_status()`'s control timeout (`USB_CTRL_GET_TIMEOUT`); in emulation
  `finish resume` → `retry with reset-resume` took 5.21 s (lines 591, 594).

## 4. Precedents (mail "Earlier discussion")

| mail text | source |
|---|---|
| 2014 report, subject | mail-archive `msg38493` (Poulain, 2014-03-05), Message-ID `50C3158CF44D924791C15F1437EF2EC65887B5@HASMSX104.ger.corp.intel.com` |
| *"I suspect this is an oversight."* [1] | `msg38572`, Alan Stern, 2014-03-05; Message-ID `Pine.LNX.4.44L0.1403051117550.1629-100000@iolanthe.rowland.org` |
| "rebind: Add rebind mechanism for runtime-resume" reached v4 [2] | v1 `msg39089`, v2 `msg39123`, v3 `msg39215`, v4 `msg40098` (Message-ID `50C3158CF44D924791C15F1437EF2EC65D7467@HASMSX104.ger.corp.intel.com`) |
| *"This patch looks okay now."* on v2 | `msg39141`, Alan Stern, 2014-03-11 (Message-ID `Pine.LNX.4.44L0.1403111013580.1243-100000@iolanthe.rowland.org`) |
| only `6aec044cc2f5` ("USB: unbind all interfaces before rebinding any") landed | `git show -s 6aec044cc2f56`: Alan Stern 2014-03-12, *"Reported-and-tested-by: "Poulain, Loic""*; `git grep rebind_ws\|usb_queue_rebind da3cc0258` empty |
| `9be427efc764` (2016): *"run-time resume does not honour it"* | `git show -s 9be427efc7644`: Johan Hovold, 2016-05-02, Acked-by Alan Stern |
| `811ae81320da` (2021) | `git show -s 811ae81320da5`: Kai-Heng Feng, 2021-12-10, "xhci: Remove CONFIG_USB_DEFAULT_PERSIST to prevent xHCI from runtime suspending": *"there's no subsequent call of usb_dev_complete() -> usb_resume_complete() to force rebinding"*, *"btusb device stops working after xHCI controller is runtime resumed"* |
| pending "restore powered-off Intel adapters" keeps `needs_binding` for all other devices | https://lkml.iu.edu/hypermail/linux/kernel/2609.2/05888.html, `btusb_reset_resume()`: `if (!btusb_intel_acpi_power_manageable(data) \|\| test_bit(HCI_RUNNING, …)) { intf->needs_binding = 1; return 0; }`; unmerged (THREADS.md §1) |

**Lore links [1] and [2] were built from the Message-IDs; lore refuses this machine (403), so
they were not opened.** The same messages:
https://www.mail-archive.com/linux-usb@vger.kernel.org/msg38572.html and
https://www.mail-archive.com/linux-usb@vger.kernel.org/msg40098.html.

## 5. The questions

| mail text | source |
|---|---|
| Q2: "as in Poulain's v3" (per-device work, `usb_unbind_and_rebind_marked_interfaces()` under the device lock) | `msg39215` (v3): `udev->rebind_ws`, `schedule_work()` from `usb_runtime_resume()`, `usb_lock_device(udev); usb_unbind_and_rebind_marked_interfaces(udev);` |
| cannot run inline: `usb_unbind_interface()` starts with `usb_autoresume_device()` | `driver.c:429-443` (`/* called from driver core with dev locked */` … `error = usb_autoresume_device(udev);` at `:443`) |
| "which lock helper" | Alan on v1 (`msg39100`): *"Can't you just call usb_lock_device_for_reset()"*; v2 used it, v3/v4 used `usb_lock_device()`; the lock *"may or may not already be held"* (`msg38572`, v1-v4 commit text) |
| `usb_queue_reset_device()` rebinds from the system workqueue under `memalloc_noio_save()` | `hub.c:6490-6494` (`schedule_work(&iface->reset_ws)`); `message.c:1962-1975` (`usb_lock_device_for_reset()` → `usb_reset_device()`); `hub.c:6403` (`memalloc_noio_save()`), `:6451` (rebind), `:6455` (restore) |
| Oliver objected in August to the system workqueue for GFP_KERNEL work | https://ratatoskr.run/lkml/2026/08/17369900/t, Oliver Neukum 2026-08-05: *"you cannot just use the system work queue for this"*, *"You must not have any memory allocations with GFP_KERNEL on that queue."* |
| Q3: failing → `usb_port_resume()` logically disconnects | `hub.c:3880-3886` (`status = finish_port_resume(udev); if (status < 0) { … hub_port_logical_disconnect(hub, port1);`). Existing precedent: `hub.c:3672-3684` turns a reset-resume into `-ENODEV` for `USB_QUIRK_RESET` (`1d10255c1c496`, Alan Stern 2014-03-18) |
| "Your 2014 sketch skipped the fallback when do_remote_wakeup is set" | `msg38700`, Alan Stern 2014-03-06: `if (status && !udev->reset_resume && !udev->do_remote_wakeup && udev->persist_enabled)`; not merged (`hub.c:3695` today) |
| Q4: re-enumeration since `b1a8014471b0` (2013), devices that come back in HID mode | `git show -s b1a8014471b01`: Hans de Goede, 2013-09-28, revert of `502f76966297`: *"after having been reset they will revert to HID mode"*; *"let the usb-system re-enumerate the device"* |

## 6. Recipients: `get_maintainer.pl` and the precedent

Run by `scripts/getmaint.sh /root/exp/agent-work/bt17-emu-20261113/linux drivers/usb/core/driver.c drivers/usb/core/hub.c drivers/bluetooth/btusb_main.c`.
That tree is the newest one here: HEAD `c85b3899eb7b` = `da3cc0258` plus local btusb patches only
(`git diff --stat da3cc0258 HEAD`: `btusb_main.c` only), so `MAINTAINERS` is `da3cc0258`'s. The
`cache/linux` worktrees checked are older (`linux-bt-next` `c9c15d4d8956`, 2026-09-23;
`full-bt-next` `8abc0fb87492`, 2026-10-04), and the main checkout is at `028ef9c96e96` (Linux 7.0).

```
===== drivers/usb/core/driver.c (default: --no-git-fallback)
Greg Kroah-Hartman <gregkh@linuxfoundation.org> (maintainer:USB SUBSYSTEM)
linux-usb@vger.kernel.org (open list:USB SUBSYSTEM)
linux-kernel@vger.kernel.org (open list)
===== drivers/usb/core/hub.c (default: --no-git-fallback)
Greg Kroah-Hartman <gregkh@linuxfoundation.org> (maintainer:USB SUBSYSTEM)
linux-usb@vger.kernel.org (open list:USB SUBSYSTEM)
linux-kernel@vger.kernel.org (open list)
===== drivers/bluetooth/btusb_main.c (default: --no-git-fallback)
Marcel Holtmann <marcel@holtmann.org> (maintainer:BLUETOOTH DRIVERS)
Luiz Augusto von Dentz <luiz.dentz@gmail.com> (maintainer:BLUETOOTH DRIVERS)
linux-bluetooth@vger.kernel.org (open list:BLUETOOTH DRIVERS)
linux-kernel@vger.kernel.org (open list)
```

(`--rolestats` gives the same lists. The `--git --git-since 1-year-ago` run is **not usable** in
this tree: its history is local and partial, so it lists the tree's own patch commits and
unrelated merges; it is not reproduced here.)

**The header, and how it differs from the script:**
- **To: Alan Stern + linux-usb.** Alan is not an `M:` for `driver.c`/`hub.c`, but he wrote this
  code (`78d9a487ee96`, `86c57edf60f5`, `6aec044cc2f5`, `1d10255c1c49`), answered the 2014 report
  and every version of the series, and Acks most core PM changes (CO-43 prior art §5). The question
  is addressed to him.
- **Cc: Greg Kroah-Hartman** (the script's maintainer). The CO-43 prior art §5 had him in To; Cc
  here because the mail is a question to Alan, not a patch for Greg to apply.
- **Cc: Oliver Neukum** (`oneukum@suse.com`, his address in 2025-2026 commits): btusb's PM author
  (`7bee549e197c`), in the 2014 thread, the 2026-08 queue objection and the 2026-09 btusb review.
- **Cc: Johan Hovold** (`johan@kernel.org`): `9be427efc764`.
- **Cc: Marcel Holtmann, Luiz Augusto von Dentz, linux-bluetooth**: the script's output for
  `btusb_main.c`; btusb is the user.
- **Cc: Sean Rhodes** (`sean@starlabs.systems`, from his posted patches): his pending series is
  named in the mail. Not from the script or the precedent; an operator decision
  (`NOTES-FOR-OPERATOR.md`).
- **Not copied: linux-kernel@vger.kernel.org.** The script adds it for every file; the 2014 report
  and series went to linux-usb only, and this is a question. An operator decision.
- Addresses checked: `stern@rowland.harvard.edu`, `oneukum@suse.com`, `johan@kernel.org` in
  2025-2026 trailers (`git log origin/master --since=2025-06-01 --format=… --grep=…`).

## 7. The outside reviewers' T2 points, against the draft

| reviewer | point | taken? | why |
|---|---|---|---|
| 1 | rebind only from `usb_resume_complete()` and `usb_reset_device()` | yes | verified (§1) |
| 1 | 2014 Poulain series, never landed | yes | verified, and the earlier 2014 BUG report found (THREADS §2a) |
| 1 | "runtime resume path may already hold the lock" | as a question | now sourced (Alan, `msg38572`; Poulain's commit text); the mail asks "which lock helper" instead of asserting it |
| 1 | draft mixed laptop and emulation; GET_STATUS failure not logged | yes | separate paragraphs; inference marked |
| 1 | "until unplug or reboot" | no | not tested; a sysfs unbind/rebind also recovers (Poulain `msg38493`) |
| 1 | prefer core fix, btusb `reset_resume` as interim | no | a question, not a proposal; Q4 asks |
| 1 | work item analogous to `usb_queue_reset_device()` | yes | Q2, with the queue question |
| 2 | the call chain hub.c → driver.c | yes | §1 |
| 2 | device-level rebind (`6aec044cc2f5`) | yes | named; Q2 is per-device |
| 2 | would not fail an otherwise successful resume | no | an opinion; left as Q3 for the maintainers |
| 2 | 5/5 count | yes | §2 |
| 6 | not inline: `usb_unbind_interface()` autoresumes | yes | `driver.c:443` |
| 6 | options: deferred rebind with PM ref + device lock + allocating queue; or fail and re-enumerate | yes | Q2, Q3 |
| 6 | "fail" costs one more reset | no | length; maintainers know it |
| 6 | btusb fallback `btusb_check_missed_resume()` | no | btusb design; for linux-bluetooth after the answer |
| 6 | both interfaces' lines, verbatim with times | yes | §2 |
| 6 | Q4 "btusb's Realtek path relies on the rebind" | no | that is the *system* resume path (`reset_resume = 1` only for `!PMSG_IS_AUTO`, `btusb_main.c:4979-4982`); the 2013 HID-mode revert is the documented reason and fits a runtime question |
| 6 | Hongyu Xie RFC: Oliver against the system workqueue for GFP_KERNEL | yes | Q2, verified (THREADS §4) |
| 6 | "every later resume skips it" | yes | `driver.c:1362-1364` |
| 7 | the autosuspend gate covers only the quirk case | yes | one sentence |
| 7 | `811ae81320da` | yes | verified |
| 7 | btusb unregister can wait on HCI work blocked on the resume | no | not verified in code here; the deferral question covers it |
| 7 | refs, PM pin, ordering, `is_prepared`, disconnect | partly | compressed into Q2 (lock, PM reference, queue); `usb_rebind_intf()` already skips during system sleep (`driver.c:1183`) |
| 7 | failing the resume "is not a complete recovery policy" | no | does not hold for this path: a `finish_port_resume()` failure leads to `hub_port_logical_disconnect()` (`hub.c:3884-3886`) |
| 7 | close-initiated resume avoids btusb's timeout reset | yes | paragraph 3 |
| 7 | `BTUSB_SUSPENDING` remains set | yes | paragraph 2 |
| 7 | add the public URL and `get_maintainer.pl` recipients | yes | optional URL line; §6 |
