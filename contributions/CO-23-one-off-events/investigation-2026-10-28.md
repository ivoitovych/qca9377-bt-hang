# CO-23 investigation, 2026-10-28

Read-only. Nothing was run against the Bluetooth controller, nothing was committed or sent.
Every claim is marked **[log]** (read in a record), **[source]** (read in code or a binary) or
**[inference]** (reasoned, not observed). Device addresses are written `<addr>`.

Helpers written for this note (in `tmp/co23/`, git-ignored, read-only on the journal archive):
- `jwindow.py ARCHIVE START END [REGEX]`: the `MESSAGE=` lines of one archived boot between two
  local times (same line parsing as `scripts/journal-archive-grep.py`).
- `multi-window.py START END REGEX ARCHIVE...`: the same over several archives.
- `acl-unknown-context.py ARCHIVE...`: for every "ACL packet for unknown connection handle", the
  nearest earlier teardown messages and the gap in milliseconds.

Source trees used (all in `cache/`): BlueZ tag `5.72` = `770ad5614e7e8074133e6f563495ce4822f63fe4`;
BlueZ `origin/master` = `b0bf49270d445da0852851f393cd67a0a1e5f05e` (2026-10-23, the local tree);
kernel `cache/ubuntu-7.0.0-31` = `028ef9c96e96197026887c0f092424679298aae8` (the nearest Ubuntu
tree to the kernel that was running, see event 2); `cache/linux-bt-next` =
`c9c15d4d8956df8c564f7c210e4dc5b9b820d97a`.

---------------------------------------------------------------------------------------------------

## Event 1: bluetoothd bad `free()`, 2026-09-08 10:23:43

### 1.1 The records

[log] The event is registered as a third, unrelated crash:
- `BRIEF.md:341` "bad `free()` under `g_main_loop_run`, 09-08, at neither patched site".
- `docs/contributions-roadmap.md:25` row `BZ-free`: "none yet: one occurrence, no mechanism. Keep the core; wait for a second".
- `patches/bluez/README.md:260`, `evidence/exhibits/041-patch-0002-prevented-four-crashes.md:130-151` (cleared of being ours).
- `reviews/2026-09-26-source-review-report.md:392-404`: "not enough information to map the third crash to an exact BlueZ function"; asks for a retained core with symbols or an ASan reproduction.

### 1.2 Is the core, or its stack, still there? No.

```
$ coredumpctl list bluetoothd --no-pager
No coredumps found.
$ ls -la /var/lib/systemd/coredump        (oldest core of any program: Oct 14; none of bluetoothd)
$ ls -la /var/crash                        (btmon, strace, apport crashes only)
$ find /root /var/tmp /var/lib/apport -name "*bluetoothd*"   (build trees and tool directories excluded when reading the result)
  -> only exhibits 032/035, evidence/baseline/ and evidence/sessions/20260819-005706-... (the 08-14 and 08-18 crashes)
```
[log] No file for PID 2841 exists anywhere. The journal shows the dump was taken and handled:
`Started systemd-coredump@1-5208-0.service` 10:23:43, `apport-coredump-hook@1-5208-0` 10:23:44,
but no "Stack trace of thread" message was logged for it.

### 1.3 What does survive

1. [log] The kernel line, in the archived boot `boot-3caa9acf` (kernel `7.0.0-31`, boot start 10:21:16):
```
$ python3 -I scripts/journal-archive-grep.py "bluetoothd.*(SIGSEGV|segfault|dumped core|Failed with result 'core-dump')|..." /root/bt-journal-archive/boot-*.export.zst
  2026-09-08 10:23:43  bluetoothd[2841]: segfault at fffffffffffffff9 ip 00007d4f240ade55 sp 00007fffd2aa0c20 error 5 in libc.so.6[ade55,7d4f24028000+188000]
  2026-09-08 10:23:44  bluetooth.service: Main process exited, code=dumped, status=11/SEGV
```
   `comm="/usr/local/libexec/bluetooth/bluetoothd -d"` in the dbus-daemon line: the project's
   debug-logging rebuild of `5.72-0ubuntu5.5` with the two fixes, installed 2026-08-25 03:37.
2. [log] **The complete `bluetoothd -d` log of the daemon's last minute** (the same archive;
   extracted with `tmp/co23/jwindow.py /root/bt-journal-archive/boot-3caa9acf.export.zst "2026-09-08 10:23:00" "2026-09-08 10:23:50" "(\.c:[0-9]+|[a-z_]+\(\) |bluetoothd|Rejected|org\.bluez)"`).
3. [source] The binary that ran is still on disk: `/usr/local/libexec/bluetooth/bluetoothd`,
   `ELF 64-bit LSB pie executable ... BuildID[sha1]=be8125795645c348fa2eee5d9fc7fbc462ec1b0b, with debug_info, not stripped`,
   modification time Aug 25 03:37. So frames can be mapped to source lines with `gdb`.

### 1.4 The faulting instruction

[log] `segfault at fffffffffffffff9 ip ...ade55 error 5 in libc.so.6[ade55,...]`.

```
$ objdump -d --start-address=0xade20 --stop-address=0xade70 /lib/x86_64-linux-gnu/libc.so.6
00000000000ade30 <__libc_free@@GLIBC_2.2.5>:
   ade30: endbr64
   ade34: test %rdi,%rdi
   ade37: je   adf10
   ...
   ade55: mov  -0x8(%rdi),%rax
```
[source] Offset `0xade55` is the first dereference in `__libc_free`: it reads the chunk header at
`ptr - 8`. The fault address `0xfffffffffffffff9` is `-7`, so **`ptr` was exactly `1`**: `free((void *)1)`.
It is not heap corruption in the usual sense (a wild pointer would give a different address), and it
is not a NULL dereference.

Caveat [log]: libc was `2.39-0ubuntu8.8` on 2026-09-08 and `2.39-0ubuntu8.9` since 2026-09-11
(`/var/log/dpkg.log`); the disassembly is of 8.9. The fault offset lands exactly on the first load
of `free()`, which is consistent with an unchanged function; the 8.8 package is not on the disk.

### 1.5 What the daemon log says happened (10:23:41 to 10:23:43)

Device: an earbud connected since 10:23:04 (A2DP stream `OPEN`, never streaming; the laptop acted
as the A2DP source). Heap pointers are as logged. `<addr>` replaces the device address.

```
10:23:41.146  avrcp-controller connected -> disconnecting ; AVCTP Disconnected        (the earbud is leaving)
10:23:41.169  a2dp-sink connected -> disconnecting ; a2dp_sink_disconnect()           (-> avdtp_close, Close request sent)
10:23:41.171  Hands-Free Voice gateway disconnected
10:23:41.177499  avdtp.c:avdtp_ref() 0x61754f20f460: ref=2                           (setup_new: setup->session = avdtp_ref())
10:23:41.177569  a2dp.c:setup_ref() 0x61754f20d980: ref=1                            (a2dp_setup_get: a NEW setup, ref 1)
10:23:41.177590  avdtp.c:avdtp_close() avdtp_close: rejecting since close is already initiated
10:23:41.177616  avdtp.c:avdtp_sep_set_state() stream state changed: OPEN -> ABORTING   (avdtp_abort)
10:23:41.177638  avdtp.c:cancel_request() Close: Operation canceled (125)             (cancel_request(ECANCELED), req = the pending Close)
10:23:41.177655  a2dp.c:close_cfm() Source 0x61754f1f6a40: Close_Cfm                  (with an error)
10:23:41.177672  a2dp.c:setup_unref() 0x61754f20d980: ref=0
10:23:41.177689  a2dp.c:setup_free() 0x61754f20d980                                   (the setup is FREED here)
10:23:41.177705  avdtp.c:avdtp_unref() 0x61754f20f460: ref=1
        ... 2.7 s of nothing from the AVDTP session ...
10:23:43.874248  avdtp.c:cancel_request() Abort: Connection timed out (110)           (the 2 s Abort timer fires)
10:23:43.874805  avdtp.c:avdtp_ref() ... ref=2 ; connection_lost() ; abort_cfm() ; stream ABORTING -> IDLE
10:23:43.875001  avdtp_unref() ref=1 ; sink_set_state() -> DISCONNECTED ; a2dp.c:channel_remove()
10:23:43.875080  avdtp.c:avdtp_unref() 0x61754f20f460: ref=0
10:23:43.875132  kernel: bluetoothd[2841]: segfault at fffffffffffffff9 ip ...ade55 ...
10:23:43.875191  avdtp.c:avdtp_free() 0x61754f20f460                                  (stderr line, stamped by journald after the kernel line)
```
[log] The last bluetoothd line is `avdtp_free()`'s own debug line. Nothing is logged after it.

### 1.6 The code path (BlueZ 5.72, `770ad5614e7e`; the built tree has the same line numbers, checked in the binary)

1. [source] `profiles/audio/a2dp.c:1838-1919` `a2dp_reconfig()` (the D-Bus method `MediaEndpoint1.SetConfiguration` on a remote SEP,
   `set_configuration()` :1921, call at :1959). `:1852` `setup = a2dp_setup_get(chan->session)`;
   `:1856-1857` `cb_data = setup_cb_add(setup); cb_data->config_cb = reconfig_cb;`.
   `a2dp_setup_get()` `:469-481`: a new setup is created if none exists (`setup_new()` takes an `avdtp_ref`, :199) and `setup_ref()` gives ref 1.
   That ref is the one `setup_cb_free()` later drops (`:261-271`, `setup_unref(cb->setup)` at :269).
   This matches the log lines at .177499 and .177569. [inference] The caller of that D-Bus method is the audio server's media-endpoint client (`:1.86` in the same journal; its
   method return is the "Rejected send message" line at the crash), switching codec while the earbud leaves; the call itself is not in the debug log. `a2dp_config()` (:3054, :3084) also
   calls `avdtp_close()` but never `avdtp_abort()`, and `a2dp_cancel()` (:3229) creates no setup, so `a2dp_reconfig()` is the only match for "new setup, then reject, then ABORTING".
2. [source] `:1889` `err = avdtp_close(chan->session, tmp->stream, FALSE);`. `profiles/audio/avdtp.c:3688-3691`:
   `if (stream->close_int == TRUE) { error("avdtp_close: rejecting since close is already initiated"); return -EINVAL; }`.
   Log line .177590. (The sink's disconnect, `a2dp_sink_disconnect`, had already sent a Close: `close_int` is TRUE.)
3. [source] `:1890-1891` `if (err < 0) err = avdtp_abort(chan->session, tmp->stream);`.
   `avdtp.c:3726-3747` `avdtp_abort()`: `avdtp_sep_set_state(..., AVDTP_STATE_ABORTING)` (:3744, log .177616), then
   `if (session->req && stream == session->req->stream) return cancel_request(session, ECANCELED);` (:3746-3747).
   The pending request is the Close.
4. [source] `avdtp.c:2528-2629` `cancel_request()`: `case AVDTP_CLOSE:` (:2581-2589) logs `Close: %s (%d)` (log .177638) and calls
   `lsep->cfm->close(session, lsep, stream, &averr, lsep->user_data)` = `a2dp.c:1403-1430` `close_cfm()`.
   With an error: `setup->stream = NULL; setup->err = err; finalize_config(setup); return;` (:1419-1424).
5. [source] `finalize_config()` `:320-340` calls `cb->config_cb` (`reconfig_cb`, :1823, which sends the D-Bus reply) and then
   `setup_cb_free(cb)` (:336). That is `setup_unref()` with ref 1 -> 0 -> `setup_free()` (:206-226, `g_free(s)` at :225).
   Log lines .177672, .177689, .177705 (`setup_free` calls `avdtp_unref(s->session)`, :222).
6. [source] Back in `cancel_request()`, after the `switch`: `send_request(session, TRUE, stream, AVDTP_ABORT, ...)` (:2613) -> `send_req()`:
   `req->timeout = timeout_add_seconds(timeout, request_timeout, session, NULL)` (:2692, `timeout = ABORT_TIMEOUT` = 2 s, :78, :2683).
   `src/shared/timeout-glib.c:75-100` `timeout_add_seconds()` -> `g_timeout_add_seconds_full()`: **a new GLib timeout source is allocated here, after the setup was freed**.
7. [source] `cancel_request()` returns 0, `avdtp_abort()` returns 0, and back in `a2dp_reconfig()`:
   `a2dp.c:1899` `setup->reconfigure = TRUE;` **writes to the freed setup** (the pointer `setup` is not re-checked; the function returns 0 at :1901).
   Verified in the running binary:
```
$ gdb -batch -ex "disassemble /s set_configuration" /usr/local/libexec/bluetooth/bluetoothd
1891  err = avdtp_abort(chan->session, tmp->stream);
   0x32bc9 <+889>: call 0x37df0 <avdtp_abort>
1892  if (err < 0) {
   0x32bce <+894>: test %eax,%eax
   0x32bd0 <+896>: jns  0x32b8d <set_configuration+829>
1899  setup->reconfigure = TRUE;
   0x32b8d <+829>: movl $0x1,0x50(%rbx)          <- rbx = the freed setup, store of the value 1 at offset 0x50
```
8. [source] The layout of the freed object, from the debug info:
```
$ gdb -batch -ex "ptype /o struct a2dp_setup" /usr/local/libexec/bluetooth/bluetoothd
/* 80 | 4 */ gboolean reconfigure;   /* 84 | 4 */ gboolean start;   ...   total size (bytes): 112
```
   So the store writes `0x0000000000000001` into the 8 bytes at offset 80 (`start` is 0).

### 1.7 The link to `free(1)`

[source] GLib's timeout source is **112 bytes** and its `name` field is at **offset 80**.
```
$ objdump -d --disassemble=g_timeout_source_new_seconds /lib/x86_64-linux-gnu/libglib-2.0.so.0
 5e845: mov $0x70,%esi          ; g_source_new(&g_timeout_funcs, 0x70 = 112)
$ objdump -d --start-address=0x5bac0 --stop-address=0x5bb30 /lib/x86_64-linux-gnu/libglib-2.0.so.0
 5bae0: mov 0x50(%rbx),%rdi     ; source->name, offset 0x50 = 80
 5bae4: call g_free             ; in the source's finalisation (reached when the source is not static-named)
 5b931: movq $0x0,0x50(%rbx)
```
(`g_source_unref` `0x5c370` -> internal unref `0x5b840`. The GLib on the disk is `2.80.0-6ubuntu3.10`; on 09-08 it was
`3.8`, `/var/log/dpkg.log`: 3.9 on 09-22, 3.10 today. A patch-level update of a stable GLib does not change the layout of `GSource`. [inference])

[inference] The chain, in order:
1. `setup_free()` returns a 112-byte chunk (`struct a2dp_setup`, 112 bytes) to the allocator.
2. Inside the same call (`cancel_request`), the Abort timer allocates a `GTimeoutSource` through `g_source_new(&g_timeout_funcs, 112)` (zeroing allocation; `g_source_new` was not re-read, only called in the disassembly), the same size, and gets that chunk back
   (this needs the chunk to be reachable by `calloc`; glibc 2.39's `calloc` does not take chunks from the tcache, so it needs the freed chunk to sit in a fastbin, which is where `free()` puts it when the tcache bin of that size is full. A daemon that allocates almost everything with `calloc` (`g_new0`, `new0`) and frees to the tcache fills that bin quickly. Not observed.)
3. `a2dp_reconfig()` then stores `1` at offset 80, which is now `source->name`.
4. The Abort timer fires 2.7 s later (10:23:43.874, `request_timeout` -> `cancel_request(ETIMEDOUT)`). The callback returns `FALSE`; GLib destroys and finalises the source in `g_main_context_dispatch()`: `g_free(source->name)` = `g_free((gpointer)1)` = `free(1)` = the fault at `__libc_free+0x25`, address `-7`.

This explains, with no further assumption, three things that were unexplained:
- the **fault address** (`-7` = `1 - 8`) and the instruction (first load of `free`);
- the **stack shape**: the crash is in GLib's dispatch, after `request_timeout()` had returned, so the frames above `g_main_loop_run` are libc and GLib only, with no bluetoothd frame between (the review noted exactly "`__GI___libc_free` under `g_main_loop_run`");
- the **timing**: no crash at the store (10:23:41.177), a crash 2.7 s later when the Abort timer completed (10:23:43.875), right after the last `avdtp_free()` line.

### 1.8 Why the other Abort timeouts did not crash

[log] `Abort: Connection timed out (110)` occurs 25 times in the archive (`journal-archive-grep.py "Abort: Connection timed out|Close: Operation canceled"`).
**`Close: Operation canceled (125)` occurs once: 2026-09-08 10:23:41**, the crashed session. The other 24 Abort timeouts have no such line, so in them the abort did not
cancel a pending Close: `close_cfm()` with an error did not run in that call, and no setup was freed under `a2dp_reconfig()` [inference from the log lines]. [inference] The defect needs: a `SetConfiguration` call
on a remote SEP while a Close is pending (a codec switch racing a disconnect), a setup that exists only for this call (ref 1), and the heap state of 1.7.

[log] `python3 -I scripts/journal-archive-grep.py "rejecting since close is already initiated|Reconfigure: |SetConfiguration: Operation canceled" /root/bt-journal-archive/boot-*.export.zst`
gives **one match in all 64 archived boots: 2026-09-08 10:23:41, the crashed session** (`total: 1`); `journalctl -b 0 _COMM=bluetoothd --grep "rejecting since close|Close: Operation canceled"`
(2026-10-23 to now) gives no entries. So the trigger sequence has been seen once in about 11 weeks of journal; that is why it was a single crash.

### 1.9 Upstream

- [source] BlueZ master `b0bf49270d44`: `profiles/audio/a2dp.c:2110-2175` `a2dp_reconfig()` has the same shape: `err = avdtp_close(...)` :2162, `err = avdtp_abort(...)` :2164,
  `setup->reconfigure = TRUE;` :2173 after the call, with no reference held. `close_cfm()` :1675-1702 and `setup_cb_free()` :333-343 and `finalize_config()` :410-430 are the same.
  `avdtp.c:3733` the reject message, `:3791` `return cancel_request(session, ECANCELED);`.
- [source] `git log --format="%h %ad %s" 5.72..origin/master -- profiles/audio/avdtp.c profiles/audio/a2dp.c profiles/audio/sink.c gdbus/object.c`
  (46 commits) has nothing for this: the nearby fixes are `c04b96dda` (2024-03-16, `setup->err` stack use-after-free: a different object),
  `ef54133c6` (2026-10-01, UAF after a rejected SetConfiguration in `auto_config`: a different path),
  `b7d71e506`/`912f5efb0` (2026, `load_remote_sep()` buffer limits), `4d7d25b70` (2025-09-14, CLOSING->IDLE ordering). **No upstream fix for `a2dp_reconfig()`.**
- [source] The sibling code in `a2dp_config()` sets the flag **before** the call: `a2dp.c:3054-3055` and `:3084-3085` (5.72) `setup->reconfigure = TRUE; if (avdtp_close(...) < 0)`.

### 1.10 Open points

- [log] Other occurrences of the trigger: none (1.8).
- Not observed: the allocator state in 1.7 (step 2). A direct check needs the allocation to be reproduced; an AddressSanitizer build reports the
  store at `a2dp.c:1899` as a heap-use-after-free without any heap grooming (the freed object, the freeing stack in `setup_free` and the store stack are all in one call chain).
- [inference] Candidate fix, **not applied, not built, not tested**: hold a reference across the close/abort in `a2dp_reconfig()`:
```diff
@@ a2dp_reconfig()
+	setup_ref(setup);	/* close_cfm() may drop the last reference */
 			err = avdtp_close(chan->session, tmp->stream, FALSE);
 			if (err < 0) {
 				err = avdtp_abort(chan->session, tmp->stream);
 				if (err < 0) {
 					error("avdtp_abort: %s", strerror(-err));
+					setup_unref(setup);
 					goto fail;
 				}
 			}

 			setup->reconfigure = TRUE;
+			setup_unref(setup);

 			return 0;
```
  (`fail:` calls `setup_cb_free(cb_data)`, which also unrefs; the `setup_ref` before the loop would have to be balanced on every exit. A test in the BlueZ emulator
  would call `SetConfiguration` while a Close is pending.) The alternative, matching `a2dp_config()`, is to set `reconfigure` before the call.

---------------------------------------------------------------------------------------------------

## Event 2: BT-6, "ACL packet for unknown connection handle"

### 2.1 The record, and a correction to it

[log] `docs/issues.md:574-597` BT-6: "observed once", 2026-08-12 08:27:36.996 handle 1; `docs/STATUS.md:47` "observed, none planned".
**It is not a single occurrence.**
```
$ python3 -I scripts/journal-archive-grep.py "ACL packet for unknown connection handle" /root/bt-journal-archive/boot-*.export.zst
  2026-08-12 05:47:24 (x2)  handle 1     boot-7ab86388
  2026-08-12 06:25:17       handle 1     boot-7ab86388
  2026-08-12 08:27:36       handle 1     boot-d28ebac2   <- the one in issues.md
  2026-08-12 10:07:30       handle 1
  2026-08-12 14:15:36 (x2)  handle 1
  2026-08-12 14:49:45       handle 2
  2026-08-12 15:36:17       handle 1
  2026-08-12 16:22:50       handle 1
  2026-08-12 18:06:32       handle 1
  2026-08-12 22:14:23 (x2)  handle 1     (all boot-d28ebac2)
  2026-08-14 10:25:27       handle 4     boot-d6d9b2dc
  2026-08-19 18:38:03       handle 2     boot-e9399c8c
  total: 15 lines in 4 boots
```
[log] None in the other 60 of the 64 archived boots (2026-08-12 to 2026-10-23); boot 0 (2026-10-23 to now) is checked in 2.6.
The kernel on 08-12 was `7.0.0-28-generic` (`boot-d28ebac2`, first message "Linux version 7.0.0-28-generic ... 7.0.12").

### 2.2 What each of the 15 coincides with

```
$ tmp/co23/acl-unknown-context.py boot-7ab86388 boot-d28ebac2 boot-d6d9b2dc boot-e9399c8c   (.export.zst)
every one of the 12 events (15 lines; the doubled lines are the same instant) comes 17 to 32 ms after
   "hcon ... state BT_CLOSED", 20 to 39 ms after "Terminating" / "Stopping bluetooth.service",
   and 27 to 43 ms after "Recovering Bluetooth controller at 3-3 ..." (the project's watchdog)
   with "src/adapter.c:dev_disconnected() Device <addr> disconnected, reason 21" in between
```
[log] All 12 events follow a stop of `bluetooth.service` (adapter power-off) while a device was connected:
one earbud 9 times, a second device 2, a third 1. In 10 of the 12 the watchdog line `Recovering Bluetooth controller` comes first
(all on 2026-08-12); on 2026-08-14 10:25 and 2026-08-19 18:38 the group starts at `Terminating` (a stop by another cause, not looked up).
[log] There is none after 2026-08-19.
[inference] BT-6 appears only when `bluetooth.service` is stopped while a device has traffic in flight, which in August was mostly the watchdog's own reset.
`reason 21` is `0x15`, `HCI_ERROR_REMOTE_POWER_OFF`, the reason `hci_power_off_sync()` gives to `hci_disconnect_all_sync()` (`net/bluetooth/hci_sync.c:5848`). [inference for the link of "21" to the kernel value]

### 2.3 The 08-12 08:27:36 instant in detail

Command: `tmp/co23/jwindow.py /root/bt-journal-archive/boot-d28ebac2.export.zst "2026-08-12 08:27:36" "2026-08-12 08:27:37" "^MESSAGE=(?!.*(change_state|hcon 00000000bd0bddad mode))"`
(the kernel's dynamic debug was on, so rx_work's per-packet lines are in the journal). The decisive lines, in order:
```
08:27:36.753   adapter.c:connected_callback(): the earbud had connected 0.2 s before (its A2DP signalling channel connects at .956)
08:27:36.736 to .957   ACL data packets of 14 to 109 bytes (connection set-up signalling: SDP, AVDTP, AVCTP), not media
08:27:36.959   EARLY intervention: 1 audio-teardown failure(s) in 90s - resetting BEFORE any HCI timeout.   (the project's watchdog)
08:27:36.960   Recovering Bluetooth controller at 3-3 ...
08:27:36.964   Terminating ; adapter_shutdown() ; adapter_set_power_state() on-disabling ; Stopping bluetooth.service
08:27:36.965   hci0: Opcode 0x0c1a  (Write Scan Enable, scan off)
08:27:36.968   hci0: Opcode 0x0406  (Disconnect)           <- the host's Disconnect for the power-off
08:27:36.970   dev_disconnected() Device <addr> disconnected, reason 21 ; avdtp connection_lost() ; avdtp_free()
08:27:36.971   hci0 Event packet ; opcode 0x0406 status 0x00 ; "hcon ... state BT_CLOSED" ; "handle 0x01 reason 0x13"
08:27:36.976   hci0 ACL data packet                         <- the next frame rx_work takes: ACL data, 5 ms after the event
08:27:36.984   hci0 hcon ... handle 1   (hci_conn_del)
08:27:36.996   Bluetooth: hci0: ACL packet for unknown connection handle 1   <- 20 ms after rx_work took the frame
```
[log] The same shape in the other groups looked at (05:47:24, 06:25:17 on `boot-7ab86388`; 2026-08-14 10:25:27; 2026-08-19 18:38:03):
`Terminating` -> `dev_disconnected` -> `BT_CLOSED` -> unknown-handle line 20 to 37 ms later.
At 05:47:24 the frames in flight are again 12 to 144 bytes (`tmp/co23/jwindow.py ... "^MESSAGE=(hci0 type 2 len|hci0 ACL data packet|Recovering|Terminating)"`);
the last `ACL data packet` before the stop is at .392, two more are taken at .435678 (right after `BT_CLOSED` at .435650) and .462605, and the two
messages are printed at .462595 and .462622: the first frame waited about 27 ms.
Clock caveat: kernel debug lines carry kernel time, daemon lines carry the time journald received them; orderings closer than about 10 ms between the two kinds are not reliable.
The conclusions use kernel-stamped lines only.

### 2.4 The code

At the kernel tree nearest the running kernel (`cache/ubuntu-7.0.0-31`, `028ef9c96e96`; `7.0.0-28` itself is not in `cache/`, so the identity of these functions between the two is not checked):
- [source] `net/bluetooth/hci_core.c:3833-3862` `hci_acldata_packet()`: `err = l2cap_recv_acldata(...)`; `if (err == -ENOENT) bt_dev_err(hdev, "ACL packet for unknown connection handle %d", handle);` (:3855-3858).
  The SCO twin at :3889-3892 is `bt_dev_err_ratelimited`; the ACL line is not rate-limited.
- [source] `net/bluetooth/l2cap_core.c:7719-7734` `l2cap_recv_acldata()`: `hci_dev_lock(hdev); hcon = hci_conn_hash_lookup_handle(hdev, handle); if (!hcon) { ...; return -ENOENT; }`.
  So the message means: the frame reached `rx_work`, `rx_work` took `hci_dev_lock`, and no connection with that handle was in the hash any more.
- [source] `hci_rx_work()` (`hci_core.c:4027-4097`) handles `rx_q` strictly in order. So the data frame was queued **after** the Disconnection Complete event (the event is processed first, `hci_disconn_complete_evt()` `hci_event.c:3396-3480`, which sets `conn->state = BT_CLOSED`).
- [source] The deletion of the connection and the hash flush happen in the power-off/close path: `hci_power_off_sync()` `hci_sync.c:5822-5857` (`hci_disconnect_all_sync(hdev, HCI_ERROR_REMOTE_POWER_OFF)` :5848, whose `hci_abort_conn_sync()` deletes each connection, then `hci_dev_close_sync()`), and `hci_dev_close_sync()` `hci_sync.c:5302-5416` (`flush_work(&hdev->rx_work)` :5346, `hci_conn_hash_flush()` under `hci_dev_lock` :5371-5386, `skb_queue_purge(&hdev->rx_q)` :5416).
- [source] btusb delivers events and ACL data from two different endpoints with separate URBs: `btusb_intr_complete()` `drivers/bluetooth/btusb.c:1431` (interrupt-in pipe, :1509) and `btusb_bulk_complete()` :1555 (bulk-in pipe, :1621). Their relative order is not guaranteed by USB.

### 2.5 Reading

[inference] Two sequences produce the line, both benign:
1. The controller (or the USB bulk-in path) delivers an ACL data frame **after** the Disconnection Complete for its link. In the 08-12 instant the frame was dequeued 5 ms after the event and found no connection 20 ms later, after the connection was removed (`hci_conn_del` at .984). The 20 ms between "took the frame" (.976) and the message (.996) is `rx_work` waiting for `hci_dev_lock` while the power-off path (which holds that lock for `hci_conn_hash_flush`) removed the connection.
2. Data in flight when the link is deleted. In the two cases read in detail the traffic was connection set-up signalling (12 to 144 byte frames), because the watchdog reset the controller within a second of a device reconnecting.

Not a state disagreement between host and controller (BT-6's original reading): the host had asked for the disconnect itself in all 12 cases (the power-off teardown). It is also unrelated to the `0x2005` desync of BT-2, and to BT-1: no SCO link, no command timeout in the window.
It is **not** produced in a normal (not power-off) disconnect on this laptop: 0 lines in the other 60 archived boots, which hold many ordinary disconnects; boot 0: see 2.6.

### 2.6 Evidence that survives and what is gone

- [log] The kernel journal lines above survive (archived boots).
- [log] The HCI capture of 08-12 does **not**: `bt-20260812-082736.btsnoop` was written (journal: `capturing to bt-20260812-082736.btsnoop` 08:27:36.826, after `btmon exited (#3)` at .821, "~1s of capture lost"), but no `bt-202608*` file exists anywhere
  (`find / -xdev -name "bt-202608*"` -> nothing); `archive/bt-trace/MANIFEST.tsv` starts with `bt-20260924-182910.btsnoop` (archived 2026-10-11): the August captures were pruned by the rotation before the archive existed.
- [log] Boot 0 (`257d1599...`, 2026-10-23 to now): `journalctl -k -b 0 -p err --grep "unknown connection handle" --no-pager -o short-iso` returns about 100 lines, **all "SCO packet for unknown connection handle"** (CO-20's subject, rate-limited); **no ACL line**. (An unfiltered `--grep` over the debug-flooded kernel journal did not finish and was stopped.)

### 2.7 Is it a defect?

[inference] A cosmetic one at most: an `error`-level line for an expected race at a power-off or abrupt disconnect, once per frame (not rate-limited, unlike the SCO message). The data is dropped correctly (`kfree_skb`, `-ENOENT`). A candidate upstream change would be
to rate-limit it or log it at debug level, which is a policy decision for the maintainers and would only be worth sending if there are user complaints; none was searched for here.
There is no evidence of a functional fault.

---------------------------------------------------------------------------------------------------

## Event 3: Shure AONIC 50 drop

### 3.1 The record

[log] `docs/issues.md:1111` and `:1135` (U11 side observation, 2026-10-13): "the AONIC 50 connected, dropped after 3 s, and connected again (01:01:56, 01:01:58, 01:02:04). Not read further." `:1150-1151`: "At 01:01:58.979 the new link dropped with reason 2 (local host), logged twice." `:1152`: `connect_profiles() ... client :1.347` at 01:02:03.395.
Related headset-initiated short links with the same headset: `:1208` 2026-10-21 06:37:49 "connected over BR/EDR and dropped after 4 s (reason 3)" (U13).
No other "AONIC 50 drop" record was found (`grep -n -i "AONIC 50.*drop\|dropped" docs/issues.md`).

### 3.2 The logs that exist

[log] The BlueZ debug log and the audio stack's log of the instant survive: archived boot `boot-e8152eae` (kernel `7.0.0-38`, ends 2026-10-13 21:07).
**No HCI capture exists**: `find / -xdev -name "bt-20261013-*"` -> nothing; `archive/bt-trace/MANIFEST.tsv` ends at `bt-20261009-064652`; `bt-audio-policy` and `bt-ui-atspi` were down (`docs/issues.md:1137`).
There is no system-bus record of that moment.

### 3.3 What the log shows

Commands: `tmp/co23/multi-window.py "2026-10-13 01:01:55" "2026-10-13 01:02:00" "(\.c:[0-9]+|[a-z_]+\(\) |bluetoothd|Rejected|org\.bluez|Disconnect|disconnect|reason|connect)" /root/bt-journal-archive/boot-e8152eae.export.zst`
and a wider window with `(?i)(bluez|bluetooth|gnome-shell|control-center|Device1|...)`.
```
01:01:50.259  Started app-gnome-gnome-bluetooth-panel-1065666.scope - Application launched by gnome-shell
01:01:50.311  agent.c:add_default_agent() Default agent set to :1.347 /org/gnome/bluetooth/settings   (the Settings panel opened 6 s earlier)
01:01:56.081  adapter.c:connected_callback() hci0 device <addr> connected eir_len 21      (the headset's own page; Connected=1)
01:01:56.083  quirk property name=Shure AONIC 50  ...
01:01:57.748  profile.c:ext_confirm() incoming connect from <addr>                         (the headset opens HFP, 1.67 s after the link)
01:01:57.749  adapter.c:adapter_authorize() Authorization request while disconnecting      -> "Hands-Free Voice gateway authorization failure"
01:01:58.353  a2dp.c:confirm_cb() AVDTP: incoming connect          -> "Authorization request while disconnecting"  ; channel_remove()
01:01:58.548  avctp.c:avctp_confirm_cb() AVCTP: incoming connect  -> "Authorization request while disconnecting"  ; AVCTP Disconnected
01:01:58.964  shared/mgmt.c:send_request() command 0x0014                                  (MGMT_OP_DISCONNECT, sent by bluetoothd)
01:01:58.979  adapter.c:dev_disconnected() Device <addr> disconnected, reason 2             (local host); and again .001 ("No matching connection")
01:02:03.397  device.c:connect_profiles() <path> (all), client :1.347                       (the Settings panel connects)
01:02:04.259  connected_callback() ... eir_len 16 ; HFP/A2DP/AVRCP connect ; the audio node is created
```
[log] The headset powered on, connected to the laptop by itself, and began opening its three profiles (HFP, A2DP, AVRCP). All three were refused
**by BlueZ's own state**: `adapter_authorize()` returns early when `device_is_disconnecting()` (`src/adapter.c:7705-7708`), i.e. when `device->disconn_timer > 0`.
That timer is set only in `device_request_disconnect()` (`src/device.c:1895-1897`, `DISCONNECT_TIMER` = 2 s, :69), which `disconnect_all()` (:1720-1735) answers with `MGMT_OP_DISCONNECT`: the command at .964 and the event at .979 (reason 2 = local host).
[inference] The timer fired at 58.964. GLib rounds second-granularity timeouts to whole seconds, so the arming time is known only to about a second (roughly 56.4 to 57.5). Two facts bound it exactly:
`device_request_disconnect()` arms the timer only if the device is connected (`device.c:1889-1893` returns early otherwise), so it was after the link came up (56.081); and the headset's first profile request at 57.748 was already refused as "disconnecting", so it was before 57.748.
**`device_request_disconnect()` was called in the 1.7 s between the link-up and the first profile request**, before any profile connected.

### 3.4 Who called `device_request_disconnect()`? Not recorded

[source] The callers in 5.72 (`git grep -n device_request_disconnect 5.72`): `src/adapter.c:3603` (D-Bus `RemoveDevice`), `src/device.c:2063` (D-Bus `Device1.Disconnect`),
`src/device.c:2978` (the requester of a bonding exited: `create_bond_req_exit`), `src/device.c:6294` and `:6305` (`device_set_unpaired`, a bond removed).
None of these logs at debug level before the timer starts, and the system bus was not recorded. The log has no `RemoveDevice`, bonding or unpairing line in the window.
[inference] The Settings panel (`:1.347`) was open and is the only D-Bus client in the window; its next act was `Connect` at 01:02:03.397. A click on a row that already showed "Connected"
(the link was up at 56.08) would call `Disconnect()`; this is consistent with the timing but **not observed** and the operator's account of 10-13 (`docs/issues.md:1105`) does not mention a click.
The other candidates (a stale bond: `device_set_unpaired`) would need a `Paired` change, which the audio stack's property log in the window does not show for this device.

### 3.5 Contrast with the other short links

[log] 2026-10-11 14:00:51 (`boot-c34cfa10`, another headset): the same three "Authorization request while disconnecting" lines, but `dev_disconnected ... reason 3` (the remote ended it) and no local `MGMT_OP_DISCONNECT`: a different sequence.
[log] `docs/issues.md:1208`: 2026-10-21 06:37:49 the Shure connected over BR/EDR and dropped after 4 s with reason 3 (remote), while the laptop's bond was already lost (U13). That drop is the headset's.
Across the archive, "Authorization request while disconnecting" occurs only on 2026-10-11 14:00:51 (2) and 2026-10-13 01:01:57-58 (3) (`journal-archive-grep.py` over `boot-c34cfa10 e8152eae 17cfdfc4 d479d374 226965f1 855a927e`).

### 3.6 Assessment

- Not a controller or kernel matter: the controller did what it was told (`MGMT_OP_DISCONNECT`, complete .001).
- The refusals of the three profiles are consequences of the pending local disconnect, not causes.
- The cause is the caller of `device_request_disconnect()` in the 1.7 s after the link-up. It cannot be found from the logs that exist.
- Whether it is a defect depends on that caller: a human click, or a Settings panel that disconnects what just connected, is a GNOME UX matter; a BlueZ-internal call would be a BlueZ one. Nothing to fix has been identified.
