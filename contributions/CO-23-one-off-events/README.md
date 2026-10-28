# CO-23: three one-off events

**State:** investigated 2026-10-28, read-only. One new root-cause candidate with a code defect
(event 1), one event reclassified as benign (event 2), one event with no findable cause (event 3).

**Target:** BlueZ `profiles/audio/a2dp.c` (event 1); the Linux kernel `net/bluetooth` (event 2, a
log-level question only); GNOME Settings or BlueZ, undecided (event 3).

**Full record:** `investigation-2026-10-28.md` (every command, key output, `path:line` at a named
commit; reasoning marked [log], [source] or [inference]). Dated entries: `log.md`.

| | Event | Evidence | Candidate cause | Fix possible |
|---|---|---|---|---|
| 1 | bluetoothd bad `free()`, 2026-09-08 10:23:43 (the `BZ-free` row) | core and stack **gone**; kernel fault line, full `bluetoothd -d` log of the last minute, and the exact debug binary survive | **use-after-free in `a2dp_reconfig()`** (`a2dp.c:1899`), later turning a GLib timer's `name` into the pointer `1` | yes, small; present in BlueZ master |
| 2 | BT-6, "ACL packet for unknown connection handle" | kernel lines survive (15, not 1); the HCI capture is **gone** | none needed: ACL data taken by `rx_work` after the connection was removed at adapter power-off | only a log-level change, optional |
| 3 | Shure AONIC 50 connects and drops after 3 s, 2026-10-13 01:01:56 | BlueZ debug log survives; no HCI capture, no system-bus record | the cause is a local disconnect request in the 1.7 s after the link-up; its caller is **not recorded** | not identified |

## Event 1: bluetoothd bad `free()`

**Evidence available.** Gone: the core (`coredumpctl list bluetoothd` finds nothing; no file in
`/var/lib/systemd/coredump` or `/var/crash`). Present: the kernel line
`bluetoothd[2841]: segfault at fffffffffffffff9 ip ...ade55 error 5 in libc.so.6`; the complete
debug log of the crashed daemon (archived boot `boot-3caa9acf`); the binary that ran
(`/usr/local/libexec/bluetooth/bluetoothd`, with debug info). That is enough to find the
function without the core.

**What the evidence says.**
- The instruction at libc `0xade55` is the first load in `free()`, `mov -0x8(%rdi),%rax`; the fault
  address `-7` means `free((void *)1)`.
- The log shows a codec-switch `SetConfiguration` call arriving while a Close was pending:
  new `a2dp_setup` (ref 1), `avdtp_close: rejecting since close is already initiated`, `OPEN -> ABORTING`,
  `Close: Operation canceled (125)`, `setup_free`. Then 2.7 s later `Abort: Connection timed out (110)`, `avdtp_free`, crash.
- The code (`a2dp.c:1889-1899`, identical in BlueZ master): `a2dp_reconfig()` calls `avdtp_close()`/`avdtp_abort()`;
  that chain runs `close_cfm()` -> `finalize_config()` -> `setup_cb_free()`, which drops the setup's last reference and frees it;
  then `a2dp_reconfig()` executes `setup->reconfigure = TRUE;` on the freed object (the running binary has `movl $0x1,0x50(%rbx)` there).
- `struct a2dp_setup` is 112 bytes with `reconfigure` at offset 80. GLib's timeout source is also 112 bytes with its `name` pointer at offset 80,
  and the same call allocates the 2 s Abort timer. When that timer finishes, GLib frees `source->name`, which is now `1`. That gives the
  fault address, the instruction, the "free under `g_main_loop_run`" stack shape and the 2.7 s delay.

**Confidence.** The use-after-free is established from the log and the binary. That the freed
chunk was handed to the timer source is [inference]: it depends on allocator state that cannot be observed now. The fingerprint (size, offset, value) is specific, and
`Close: Operation canceled` occurs once in the archive, in this session; the other 24 Abort timeouts did not crash.

**Upstream.** No fix in BlueZ master (`b0bf49270d44`, 2026-10-23); `git log 5.72..origin/master` over the A2DP/AVDTP files has nothing for it.
The sibling `a2dp_config()` sets `reconfigure` before the call (`a2dp.c:3054`, `:3084`, BlueZ 5.72).

**Next step.** (1) Reproduce under AddressSanitizer in the BlueZ emulator: `SetConfiguration` on a remote SEP while a Close is pending; the
report will name `a2dp.c:1899`. No hardware needed. (2) Write the fix (hold a reference across the close/abort, or set the flag first) with that test;
a draft diff is in the investigation note, section 1.10, **not built or tested**. (3) Send as a BlueZ patch. (4) Correct the records that call this crash
"unrelated" and "cleared" (`BRIEF.md:341`, `docs/contributions-roadmap.md:25`, `patches/bluez/README.md:260`, exhibit 041): it is cleared of
being caused by patches `0001`/`0002`, but it has a mechanism now.

## Event 2: BT-6, ACL data for an unknown handle

**Evidence available.** The kernel journal lines of 15 occurrences in 4 archived boots (2026-08-12, 08-14, 08-19; kernel `7.0.0-28`), with
the kernel's per-packet debug lines around them. Gone: every HCI capture of those days (`bt-202608*` was pruned before `archive/bt-trace` began on 2026-09-24).
The record ("observed once", `docs/issues.md:574`, `docs/STATUS.md:47`) is wrong on the count.

**Cause.** All 12 distinct instants fall 17 to 32 ms after a connection was marked closed during an adapter power-off (`bluetooth.service` stopped; 10 of 12 by the project's watchdog on 2026-08-12).
`hci_rx_work()` handles frames in order, so the data frame was queued after the Disconnection Complete event; `l2cap_recv_acldata()` finds no connection and returns `-ENOENT`,
which `hci_acldata_packet()` logs at error level (`hci_core.c:3855-3858`). At 08:27:36 the frame was taken 5 ms after the event and the message came 20 ms later, after
`hci_conn_del`, consistent with `rx_work` waiting for `hci_dev_lock` while the power-off path flushed the connections. USB delivers events and ACL data on separate endpoints with separate
URBs (`btusb.c:1431`, `:1555`), so the order is not guaranteed.

**Verdict.** A benign race (data after disconnect), not a host/controller state disagreement, not related to BT-1 or BT-2. None since 2026-08-19.
The only change that could be offered is cosmetic: the SCO twin of this message is rate-limited (`hci_core.c:3891`), the ACL one is not. Not worth sending without a user complaint.

**Next step.** Update the BT-6 entry and the STATUS row (count, cause, "benign"). Nothing else.

## Event 3: Shure AONIC 50 drop

**Evidence available.** `docs/issues.md:1111,1135,1150-1152` (noted, "not read further"). Survives: the BlueZ debug log and the audio log of the instant
(`boot-e8152eae`, 2026-10-13 01:01:50 to 01:02:11). Gone or never taken: HCI capture, system-bus record, UI clicks (`bt-audio-policy` and `bt-ui-atspi` were down).

**What the log shows.** The headset powered on and connected by itself at 01:01:56.081. Between the link-up and the headset's first profile request, 1.7 s later, something called `device_request_disconnect()`, which arms a
2 s timer (`device.c:1895`). The headset then opened HFP (57.748), A2DP (58.353) and AVRCP (58.548); each was refused by `adapter_authorize()` with
"Authorization request while disconnecting" (`adapter.c:7705`). At 58.964 the timer sent `MGMT_OP_DISCONNECT`; the event at 58.979 has reason 2 (local host).
The headset connected again at 04.26 after the Settings panel's `connect_profiles()` at 03.397. The only D-Bus client visible is the Settings panel
(opened 01:01:50); a click on the row would fit the timing but is not observed.

**Cause.** Not findable from what exists. The controller and the kernel did what they were told. The three refusals are consequences, not causes.
It is not the 10-21 06:37 drop, which was the headset's (reason 3).

**Next step.** None until it recurs. If it does, the system-bus record and the HCI capture that are now routinely taken decide it in one look
(who called `Device1.Disconnect`, `RemoveDevice` or unpaired). A BlueZ-side hardening idea that is independent of the caller: none identified.

## Records to correct (from this note; not edited here)

- `docs/issues.md` BT-6 and `docs/STATUS.md:47`: 15 lines in 4 boots, cause = ACL data after power-off teardown, benign.
- `BRIEF.md:341`, `docs/contributions-roadmap.md:25`, `patches/bluez/README.md:260`, exhibit 041 "unrelated crash": mechanism found, `a2dp_reconfig()` use-after-free.
- `docs/issues.md:1135`: the "side observation" has now been read (event 3).

Other occurrences: event 1's trigger line appears once in 64 archived boots and not in boot 0; event 2 has no ACL line in boot 0 (only the SCO variant of CO-20).
