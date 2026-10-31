# Two AddressSanitizer reports at bluetoothd exit: upstream status, reproduction, fix

State 2026-11-01, builds and runs from 2026-10-31 22:59:58 to
2026-11-01 00:23:14 (`progress.log`, local time; guest log timestamps are
UTC). Nothing sent, posted or filed. Every
build and test ran in the BlueZ CI bot's image (`bluez-action-ci:60348956fc7b`,
CO-23's) with only `--device /dev/kvm`; the functional tests ran in its QEMU
guests on emulated controllers (btvirt), kernel `bzImage-bot-base-47d4d9f67e92`
(bluetooth-next 47d4d9f67e92, `doc/tester.config`, from CO-23). The host's
controller was not touched.

Trees: BlueZ master **14bd6ab65** (fetched 2026-10-31, `git describe`:
`5.87-455-g14bd6ab65`), BlueZ **5.72** (tag, 770ad5614), ELL 002b32d7c091
(0.83). Builds: `bootstrap-configure --disable-lsan --enable-asan
--enable-ubsan` (the bot's TestFunctional flags).

Claims are marked **[quoted]** (a log line or message, with its file),
**[source]** (`path:line` at a named commit) or **[inferred]**.

## Verdict

| | Report | On master 14bd6ab65 | Upstream fix | 5.72 / Ubuntu 24.04 |
|---|---|---|---|---|
| 1 | `heap-use-after-free profiles/audio/media.c:300 in clear_endpoint` | **present**: reproduced 10/10; on master it is masked by a newer use-after-free at `media.c:321` (fix 1), behind which the same `clear_endpoint` read follows (10/10 with fix 1 alone) | **none**: no commit, no list patch (a related, different RFC is pending, §1.3) | reproduced 10/10 on 5.72 with the same location, offset and size as the CO-03 report; backport (2 patches) applies to `5.72-0ubuntu5.8`; 10/10 clean with it |
| 1b | (new) `heap-use-after-free profiles/audio/media.c:321 in media_endpoint_remove`, at runtime and at exit; the same read as another campaign's `media.c:312` at ebbb4ee31ad7 (§1.2) | **present**, master only, introduced 2026-07-15 by 7482aceece70 (in no release) | none | not present (5.72 has no `endpoint->app`) |
| 2 | `heap-use-after-free src/device.c:6167 in device_set_rssi_with_delta` | **fixed**: 0/10 on master; 10/10 on master with the fix reverted | **7e3212fa233e** "adapter: clear discovery_found list before discovery_cleanup()", Pauli Virtanen, 2026-09-04, in no release yet (newest tag 5.87, 2026-07-03) | reproduced 10/10 on 5.72; the fix does not apply as is (context differs), a 3-line conflict resolution applies to `5.72-0ubuntu5.8` (offset +16); 10/10 clean with it |

The series for master (`patches/master/`, `git format-patch`, base 14bd6ab65):

1. `media: Fix use-after-free of app when removing a locked A2DP endpoint` (Fixes: 7482aceece70)
2. `media: Fix use-after-free releasing endpoints on adapter removal` (Fixes: ee0f3c03fb1d)
3. `test: Cover A2DP endpoint release with an acquired transport` (two functional tests, documented in `doc/functional-a2dp.rst`)

## 1. Report 1: `clear_endpoint` at exit

### 1.1 The ordering, from the source

At master 14bd6ab65 [source], with the 5.72 lines in brackets:

1. `main()` runs `plugin_cleanup()` before `adapter_cleanup()`
   (`src/main.c:1717`, `:1723`), so the media driver is unloaded while
   devices and connections still exist: `a2dp_exit()` →
   `btd_unregister_adapter_driver(&media_driver)` (`profiles/audio/a2dp.c:3912`)
   → `unload_driver` → `media_server_remove` → `media_unregister` →
   `g_dbus_unregister_interface` → `path_free()` (`profiles/audio/media.c:3801`).
2. `path_free()` first frees the applications, then releases the endpoints
   (`media.c:3806`, `:3808-3814`) [5.72: `media.c:3269`, `:3271-3277`].
3. `app_free()` removes each endpoint registered by the application with
   `media_endpoint_remove()` (`media.c:3102`) [5.72: `:2666`].
4. For an A2DP endpoint `media_endpoint_remove()` only calls
   `a2dp_remove_sep()` and returns (`media.c:314-317`) [5.72: `:224-227`].
   `a2dp_remove_sep()` takes the SEP off the server's list, but if one of
   its streams is locked it returns without unregistering it
   (`a2dp.c:3061-3062`). A stream is locked by `transport_a2dp_resume()`
   (`transport.c:586`), i.e. by an acquired transport. The endpoint stays
   in `adapter->endpoints`.
5. `path_free()` then calls `release_endpoint()` on it (`media.c:3813`)
   [5.72: `:3276`]; with the client still connected (`watch != 0`) that
   calls `clear_endpoint()` (`media.c:661`) [5.72: `:566`], whose loop
   `while (endpoint->transports != NULL) clear_configuration(...)`
   (`media.c:412-413`) [5.72: `:300-301`] destroys the transport:
   `endpoint_remove_transport()` → `media_transport_destroy()` →
   `media_transport_free()` → `media_transport_remove_owner()` (it has an
   owner) → `media_transport_suspend(transport, NULL)` →
   `transport_a2dp_suspend()` → `a2dp_sep_unlock()` (`transport.c:1802-1803`,
   `:401`, `:363`, `:469`).
6. `a2dp_sep_unlock()` finds the SEP no longer on the list and calls
   `a2dp_unregister_sep()` (`a2dp.c:3587-3589`), whose destroy callback
   `a2dp_destroy_endpoint()` (`a2dp.c:2892-2893`, `media.c:801-807`) calls
   `release_endpoint()` again, which ends in `media_endpoint_remove()` with
   `sep == NULL` and frees the endpoint (`media.c:335`, `:252`).
7. Back in the outer `clear_endpoint()`, the loop condition reads
   `endpoint->transports` of the freed endpoint: the report.

The 5.72 report's numbers fit this [source + quoted]: READ of 8 bytes at
offset 144 of a 152-byte region = `GSList *transports`, the last member of
5.72's `struct media_endpoint` (`media.c:108`), read at `media.c:300`.

Why only some exits [quoted + inferred]: on SIGTERM `bluetoothd` powers the
adapter off first (`src/main.c:1485`, `adapter_shutdown()`), which
disconnects the device. In all four CO-03 runs with this report the
daemon left by "Disconnected from D-Bus. Exiting." instead (the test
harness stopped the bus at the same moment), which skips the power-off
(`src/main.c:1534-1538`):

```console
$ grep -n -e "Terminating" -e "Disconnected from D-Bus" -e "has been disabled" -e "ERROR: AddressSanitizer" /root/exp/agent-work/co03/runs/exitcheck-base-t311x10/pytest.log
4255:… host.0.0.bluetoothd :  bluetoothd[52]: Terminating
4280:… host.0.0.bluetoothd :  bluetoothd[52]: Disconnected from D-Bus. Exiting.
4565:… host.0.0.bluetoothd :  ==52==ERROR: AddressSanitizer: heap-use-after-free …
26521:… host.0.0.bluetoothd :  bluetoothd[300]: Terminating
26540:… host.0.0.bluetoothd :  bluetoothd[300]: Disconnected from D-Bus. Exiting.
26655:… host.0.0.bluetoothd :  ==300==ERROR: AddressSanitizer: heap-use-after-free …
```

(full output: every reporting exit is preceded by "Disconnected from
D-Bus", every exit with "adapter … has been disabled" has no report;
the same for report 2 in `v2-l3pw-test_pipewire_a2dp/pytest.log:3592`).
The same exit follows when the power-off does not finish within
`SHUTDOWN_GRACE_SECONDS` [inferred, not tested].

### 1.2 On master: a newer use-after-free comes first (1b)

7482aceece70 (Frédéric Danis, 2026-07-15, "profiles/audio: fix UAF on
external media service teardown") added `endpoint->app` and unlinks it in
`media_endpoint_remove()` — but after the A2DP early return
(`media.c:314-323`). An endpoint whose SEP removal is deferred keeps
pointing to the application `app_free()` then frees (`media.c:3119`); when
the deferred removal completes, `media_endpoint_remove()` reads
`endpoint->app->endpoints` (`media.c:321`) [source]. This is reached

- **at runtime**, when the application (the sound server) leaves the bus
  while its transport is acquired: the app's disconnect watch frees the
  app, the owner's disconnect watch releases the transport, the stream is
  unlocked, the SEP unregistered, the endpoint removed [quoted, runs below:
  use stack `media_endpoint_remove ← a2dp_unregister_sep ← a2dp_sep_unlock ←
  transport_a2dp_suspend ← service_filter`], and
- **at exit**, in step 6 above, before step 7's read [quoted: use stack
  `… ← clear_endpoint ← release_endpoint ← path_free ← … ← a2dp_exit ←
  plugin_cleanup`, freed in `queue_remove_all` (`app_free`)].

**The same read, seen independently** (another campaign, BlueZ at
ebbb4ee31ad7 of 2026-09-18, which contains 7482aceece70; ASan, Fedora 44
PipeWire CI image; once in about 150 shutdowns):
`/root/exp/agent-work/co36/results/r05-t224-x10-pytest-log.txt:151544-151576`
[quoted] has `media_endpoint_remove profiles/audio/media.c:312` ←
`a2dp_unregister_sep a2dp.c:2838` ← `a2dp_sep_unlock a2dp.c:3533` ←
`transport_a2dp_suspend transport.c:465` ← `media_transport_free
transport.c:1790` ← … ← `clear_configuration media.c:382` ← `clear_endpoint
media.c:390` ← `release_endpoint media.c:634` ← `path_free media.c:3719` ←
… ← `a2dp_exit a2dp.c:3857` ← `plugin_cleanup`, 48 bytes inside a 72-byte
region freed in `queue_remove_all src/shared/queue.c:341`. At that commit
`media.c:312` is `queue_remove(endpoint->app->endpoints, endpoint);`,
`media.c:3712` is `queue_destroy(adapter->apps, app_free);` and
`a2dp.c:2838` is `sep->destroy(sep->user_data);` [source, `git grep` at
ebbb4ee31ad7]. That `bluetoothd` left the same way as in CO-03 [quoted,
`scripts/grep-range.py … 150000 151544 …`]:

```
151240:22:34:16.791 INFO host.0.0.bluetoothd Stop bluetoothd
151243:22:34:16.795 OUT host.0.0.bluetoothd bluetoothd[1576]: Terminating
151370:22:34:16.823 OUT host.0.0.bluetoothd bluetoothd[1576]: Disconnected from D-Bus. Exiting.
151478:22:34:16.840 OUT host.0.0.bluetoothd ==1576==ERROR: AddressSanitizer: heap-use-after-free …
```

It is 1b on the exit path, identical to this README's master exit report
(`media.c:321`, 48 of 72 bytes, freed in `queue_remove_all`): not a
different defect, but the read that, since 7482aceece70, comes one step
before report 1's read on the same teardown path. Both fixes of the
series cover it (fix 1 removes the stale pointer; fix 2 releases the
endpoints while the application is still alive, so the removal is never
deferred), and both apply to ebbb4ee31ad7 (`git apply --check`: offsets −9
and −94). Its rarity there (1 in ~150) is the rarity of the no-power-off
exit with a transport acquired [inferred]. The core file
(`co36/pw/test-bluezenv-hosts7.0-bluetoothd-1793486057-1576.core`) was not
opened or moved.

With fix 1 alone the runtime case passes and the exit case reports
exactly report 1 on master (`media.c:412 in clear_endpoint`, 168 bytes
inside the 184-byte endpoint = `transports`, freed in
`media_endpoint_remove`), 10/10 (§3).

### 1.3 Upstream search

- `git log 5.72..origin/master` over `media.c`, `a2dp.c`, `transport.c`,
  with `-G "release_endpoint|clear_endpoint|a2dp_destroy_endpoint|path_free|a2dp_unregister_sep|a2dp_remove_sep|a2dp_sep_unlock|app_free"`:
  `05f8bd489` (a2dp_sep mapping to a single stream, 2025-05-15) and
  `a14d59725` (Release during Acquire, 2024-11-02); neither changes the
  ordering. `path_free()`'s order is from `ee0f3c03fb1d` ("media: Fix
  UnregisterApplication", 2021-06-23), which added
  `queue_destroy(adapter->apps, app_free)` in front of the endpoint loop.
- linux-bluetooth archive (lore, since 2024-01-01, 29758 messages, cloned
  to `cache/lore-linux-bluetooth-0.git`): `git log -S clear_endpoint` and
  `-G "release_endpoint|path_free\(|a2dp_destroy_endpoint|a2dp_sep_unlock"`
  and subject searches: no report or patch for this ordering.
- **Related, different, pending:** Bastien Nocera, "[RFC BlueZ] media: Fix
  possible crash on exit/adapter removal", 2026-05-12, patchwork 14568134,
  state `new`, no review (his ping of 2026-06-02 unanswered) [quoted:
  `cache/pw-patch-14568134*.json`]. It reports an abort in
  `media_endpoint_destroy()` from `path_free()` on adapter removal
  (Fedora bug 2467980, bluez 5.86) and guards `release_endpoint()`'s final
  `media_endpoint_remove()` with `g_slist_find(adapter->endpoints, …)`.
  It does not fix this report: the read is in `clear_endpoint()`, before
  that guard, and `release_endpoint()` still uses the endpoint after
  `clear_endpoint()` returns [inferred from source]. Whether his crash is
  the same deferred-removal chain is not established (his report has no
  ASan output).

## 2. Report 2: `device_set_rssi_with_delta` at exit

[source, 5.72 `src/adapter.c:6941-6962`] `adapter_remove()` removes (and
frees) every device, then `discovery_cleanup()` (`adapter.c:1721`) walks
`adapter->discovery_found` with `invalidate_rssi_and_tx_power()` — devices
already freed when a discovery was running at exit. With SIGTERM,
`adapter_stop()` runs `discovery_cleanup()` at power-off
(`adapter.c:7963` at master) and clears the list first, which is why it
needs the same no-power-off exit as report 1 [source + quoted, §1.1].

Fixed on master by **7e3212fa233edbdcfd69f93e2a7418819172c599**, Pauli
Virtanen, authored and committed 2026-09-04 [quoted, `git show`]: frees the
list in `adapter_remove()` before `discovery_cleanup()`. Not in any tag
(`git tag --contains 7e3212fa2` is empty; newest tag 5.87 of 2026-07-03).
On the list as "[PATCH BlueZ] adapter: clear discovery_found list before
discovery_cleanup()" (lore commit d63ce3494, 2026-09-04), answered by
patchwork-bot the same day at 20:20 UTC (fbaf13b4e) [quoted:
`git -C cache/lore-linux-bluetooth-0.git log -G "invalidate_rssi_and_tx_power|discovery_found list"`].
Its commit message carries an ASan trace of the same shape as report 2
(`device_set_rssi_with_delta src/device.c:7121` ← `invalidate_rssi_and_tx_power`
← `discovery_cleanup` ← `adapter_remove` ← `adapter_cleanup`, freed in
`device_free`).

On 5.72 the test reports `src/device.c:6161 in device_set_rssi_with_delta`,
READ of 1 byte 645 bytes inside a 680-byte region allocated in
`device_new`, freed in `remove_interface` — the CO-03 report, whose
`device.c:6167` is the same line in Ubuntu's tree:

```console
$ grep -n "^void device_set_rssi_with_delta" /root/exp/agent-work/exit-uaf/repo-5.72/src/device.c /root/exp/agent-work/co03/build-f44/base/src/device.c
/root/exp/agent-work/exit-uaf/repo-5.72/src/device.c:6154:void device_set_rssi_with_delta(struct btd_device *device, int8_t rssi,
/root/exp/agent-work/co03/build-f44/base/src/device.c:6160:void device_set_rssi_with_delta(struct btd_device *device, int8_t rssi,
```

5.72: `git apply` fails (5.72 has `g_slist_free(adapter->load_keys)` between
the context lines); the cherry-pick conflict resolves by keeping both
blocks: `patches/5.72-discovery/0001-…patch` (author Pauli Virtanen,
`(cherry picked from commit 7e3212fa2…)`), applies to the Ubuntu
`5.72-0ubuntu5.8` tree (`co03/build-f44/base`) with offset +16.

## 3. Reproduction and results

### 3.1 The tests

`test/functional/test_a2dp.py` (patch 3):

- `MediaApp`, a host plugin that registers an A2DP Source endpoint (SBC)
  with `org.bluez.Media1.RegisterApplication` on its own bus connection,
  as PipeWire does, and acquires the transport it is configured with.
- `test_a2dp_app_exit_with_acquired_transport`: pair, connect, acquire;
  the plugin closes its bus connection; expect `[DEL] Transport`; then
  SIGTERM and `bluetoothd`'s exit status must be 0.
- `test_a2dp_exit_with_acquired_transport`: pair, connect, acquire; kill
  the guest's system `dbus-daemon` with SIGKILL, so `bluetoothd` exits on
  losing the bus without powering off and without first seeing the
  application leave; exit status must be 0.

`bluetoothd`'s exit status is read with `waitpid()` in the guest; under
ASan a report aborts (`abort_on_error=1`, status −6), and the harness also
turns the report into a `SanitizerWarning` error.

`test/functional/test_exit_discovery.py` (local only, not for
submission, commit 17e1a36cc): `bluetoothctl` `scan on` until the peer is
found, then the same two exits (`sigterm`, `bus`).

Exit triggers tried and why: SIGTERM alone passes on master (one run,
`runs/base-t0/probe-1.log`: `[sigterm]` PASSED) — the power-off comes
first. Stopping `dbus-daemon` with SIGTERM (first draft) makes the bus
announce the application's departure first, which reaches 1b at runtime
instead of the exit path (`runs/base-t0/probe-1.log`, use stack through
`service_filter`); hence the separate runtime test and SIGKILL for the
exit test.

### 3.2 Results, ten runs each

| tree | test | runs failing | sanitizer report |
|---|---|---|---|
| master + test (`runs/base-t0/rate`) | app exit | 10/10 | `media.c:321 in media_endpoint_remove`, main loop, ×10 |
| | bluetoothd exit | 10/10 | `media.c:321 in media_endpoint_remove`, exit path, ×10 |
| master + fix 1 + test (`runs/fix1/exit-rate`) | bluetoothd exit | 10/10 | `media.c:412 in clear_endpoint`, exit path, ×10 (report 1) |
| master + fix 1 + fix 2 + tests (`runs/fix12/rate`) | app exit | **0/10** | none |
| | bluetoothd exit | **0/10** | none |
| master with 7e3212fa2 reverted + discovery test (`runs/disc-revert/rate`) | discovery, bus lost | 10/10 | `src/device.c:7349 in device_set_rssi_with_delta`, ×10 |
| master + discovery test (`runs/base-t0/disc-rate`) | discovery, bus lost | **0/10** | none |
| 5.72 + harness (`runs/v572/exit-rate`) | bluetoothd exit | 10/10 | `media.c:300 in clear_endpoint`, ×10 |
| 5.72 + harness (`runs/v572/disc-rate`) | discovery, bus lost | 10/10 | `src/device.c:6161 in device_set_rssi_with_delta`, ×10 |
| 5.72 + backports + harness (`runs/v572fix/exit-rate`) | bluetoothd exit | **0/10** | none |
| 5.72 + backports + harness (`runs/v572fix/disc-rate`) | discovery, bus lost | **0/10** | none |
| 5.72 + harness (`runs/v572/app-rate`) | app exit | 0/10 | none (1b is not in 5.72) |
| 5.72 + backports + harness (`runs/v572fix/app-rate`) | app exit | 0/10 | none |

Commands: `python3 -I scripts/summarize.py runs/<tree> <label>` (verdicts
and SUMMARY lines per run) and `python3 -I scripts/report-table.py
runs/<tree> <label>` (one row per report, with the test and whether the
use came through the exit path or a main-loop D-Bus watch).

The decisive lines.

5.72, the CO-03 report reproduced (`runs/v572/probe6-1.*`,
`python3 -I scripts/asan-blocks.py runs/v572/probe6-1.log runs/v572/probe6-1.debug.log`):

```
READ of size 8 at 0x7c75fe5e0c30 thread T0
    #0 0x55f9eea269dc in clear_endpoint profiles/audio/media.c:300
    #1 0x55f9eea26acf in release_endpoint profiles/audio/media.c:566
    #2 0x55f9eea26e16 in path_free profiles/audio/media.c:3276
    #3 0x55f9eecbf999 in remove_interface gdbus/object.c:660
    #4 0x55f9eecc2d8b in g_dbus_unregister_interface gdbus/object.c:1394
    #5 0x55f9eeb9efb8 in unload_driver src/adapter.c:7574
    #7 0x55f9ee9e3073 in a2dp_exit profiles/audio/a2dp.c:3568
    #8 0x55f9eeb849f3 in plugin_cleanup src/plugin.c:217
    #9 0x55f9ee9baef6 in main src/main.c:1456
0x7c75fe5e0c30 is located 144 bytes inside of 152-byte region [0x7c75fe5e0ba0,0x7c75fe5e0c38)
freed by thread T0 here:
    #1 0x55f9ee9e2448 in a2dp_unregister_sep profiles/audio/a2dp.c:2611
previously allocated by thread T0 here:
    #2 0x55f9eea24762 in media_endpoint_create profiles/audio/media.c:1463
SUMMARY: AddressSanitizer: heap-use-after-free profiles/audio/media.c:300 in clear_endpoint
```

(The CO-03 report: the same frames and lines, `unload_driver
src/adapter.c:7590` and `a2dp_exit … :3575` there because Ubuntu's patches
move `adapter.c`/`a2dp.c`; 144 of 152 bytes; allocated at `media.c:1463`.
Its free frame `a2dp.c:2618` is the destroy callback call, as here:

```console
$ grep -n "sep->destroy(sep->user_data);" /root/exp/agent-work/exit-uaf/repo-5.72/profiles/audio/a2dp.c /root/exp/agent-work/co03/build-f44/base/profiles/audio/a2dp.c
/root/exp/agent-work/exit-uaf/repo-5.72/profiles/audio/a2dp.c:2611:		sep->destroy(sep->user_data);
/root/exp/agent-work/co03/build-f44/base/profiles/audio/a2dp.c:2618:		sep->destroy(sep->user_data);
```
)

Master, the full chain (`runs/base-t0/probe2-1.*`, second report):

```
#0 media_endpoint_remove profiles/audio/media.c:321
#1 a2dp_unregister_sep profiles/audio/a2dp.c:2893
#2 a2dp_sep_unlock profiles/audio/a2dp.c:3588
#3 transport_a2dp_suspend profiles/audio/transport.c:469
#4 media_transport_free profiles/audio/transport.c:1803
#5 remove_interface gdbus/object.c:742
#6 g_dbus_unregister_interface gdbus/object.c:1499
#7 media_transport_destroy profiles/audio/transport.c:258
#8 endpoint_remove_transport profiles/audio/media.c:374
#9 clear_configuration profiles/audio/media.c:405
#10 clear_endpoint profiles/audio/media.c:413
#11 release_endpoint profiles/audio/media.c:661
#12 path_free profiles/audio/media.c:3813
#15 unload_driver src/adapter.c:8027
#17 a2dp_exit profiles/audio/a2dp.c:3912
#18 plugin_cleanup src/plugin.c:251
0x7b7bca0e58b0 is located 48 bytes inside of 72-byte region   (struct media_app)
freed by thread T0 here:  #1 queue_remove_all src/shared/queue.c:341
```

Master + fix 1, report 1 itself (`runs/fix1/probe-1.*`):

```
#0 clear_endpoint profiles/audio/media.c:412
#1 release_endpoint profiles/audio/media.c:661
#2 path_free profiles/audio/media.c:3813
… #7 a2dp_exit profiles/audio/a2dp.c:3912  #8 plugin_cleanup src/plugin.c:251
0x7c69bcde12e8 is located 168 bytes inside of 184-byte region
freed by thread T0 here:  #1 media_endpoint_remove profiles/audio/media.c:335
```

ASan's "freed by" stacks are short (the fast unwinder stops in GLib,
built without frame pointers); the use stacks are complete. The frames
between `a2dp_unregister_sep` and `media_endpoint_remove` (the destroy
callback, `release_endpoint`) are tail calls at -O2 [inferred].

### 3.3 The fix

**Fix 1** (`profiles/audio/media.c`, `media_endpoint_remove()`): unlink
the endpoint from its application before the A2DP early return. An
endpoint whose removal is deferred then no longer points to an
application that may be freed; when the removal completes, `app` is NULL.
In `app_free()` the queue is already detached by `queue_destroy()`, so the
`queue_remove()` is a no-op there.

**Fix 2** (`path_free()`): release the endpoints before freeing the
applications. `release_endpoint()` then clears the transports while the
SEP is still on the server's list, so `a2dp_sep_unlock()` only unlocks;
`media_endpoint_remove()` → `a2dp_remove_sep()` finds the stream unlocked
and unregisters the SEP, whose destroy callback frees the endpoint after
the outer `clear_endpoint()` has returned. `app_free()` then finds only
endpoints it still owns.

Alternatives considered:
- Bastien Nocera's membership check in `release_endpoint()`: does not
  cover the read in `clear_endpoint()` (§1.3).
- Clearing all transports before `app_free()` (an extra loop): leaves the
  order as is but would clear endpoints whose client already left
  (`watch == 0`, which `release_endpoint()` deliberately skips) and could
  free those inside the new loop.
- Clearing the transports in `media_endpoint_remove()` so that removal is
  never deferred: changes `UnregisterEndpoint`/`UnregisterApplication`
  semantics at runtime for a transport in use; not minimal.

Not fixed and not tested [inferred from source]: an endpoint whose removal
was already deferred **before** exit (unregistered at runtime while another
client holds its transport) still reaches the same read when `path_free()`
releases it. Both fixes keep the existing double `Release()` call to an
A2DP endpoint at exit (the nested `release_endpoint()`), which legacy
`RegisterEndpoint` endpoints already get.

## 4. Checks, base vs base + series

Base = master 14bd6ab65 + the test (`runs/base-t0`); base + series =
`runs/fix12`. Same image, same flags.

| check | base | base + series | difference |
|---|---|---|---|
| build (`-Werror`, ASan/UBSan) | 0 warnings | 0 warnings | none |
| `make check` | 42 total, 41 pass, 1 skip (`unit/test-mesh-crypto`), 0 fail, no sanitizer line | the same | none |
| CheckPatch (bot's: `checkpatch.pl --ignore UNKNOWN_COMMIT_ID`, `patches/checkpatch.log`) | — | 0 errors, 0 warnings, all three | — |
| GitLint (bot's config: title ≤ 80, body lines except `Fixes:`) | — | titles 60–69 chars; body lines ≤ 72 but one `Fixes:` line (exempt) | — |
| functional suite, all 64 tests incl. kernel testers (`runs/*/suite2.verdicts`) | 60 passed, 3 failed, 4 errors, 1 skipped | 62 passed, 1 failed, 2 errors, 1 skipped | **only the two new tests** (fail on base by design) |

The base's own failures, present on both sides: `l2cap-tester` aborts in
the guest with `heap-use-after-free src/shared/timeout-mainloop.c:33 in
timeout_callback` (FAILED, ERROR at its teardown, and its core dump
reported at the teardown of the next test, `test_bluetoothctl_show`);
`test_kernel_selftest` skipped (`CONFIG_BT_SELFTEST` not enabled). The
`l2cap-tester` report is a candidate of its own (master moved the testers
to the mainloop on 2026-10-21, `477642f6b`, `3bce4ad01`) [inferred, not
investigated].

**A defect in the first version of the test, found by the suite and
fixed:** killing `dbus-daemon` with SIGKILL left `/run/dbus-system.socket`
behind; the next test on the same reused guest then took its new bus
daemon as ready before it listened, and its setup failed with
`org.freedesktop.DBus.Error.NoServer: Failed to connect to socket
/run/dbus-system.socket: Connection refused` [quoted,
`runs/base-t0/suite.debug.log:52363`]. That gave `test_bearer_le_connect`,
`test_hog` ×2 and once `test_mpris_proxy_playback_control[bredr]` setup
errors in the first suite runs (`runs/*/suite.verdicts`, on both sides).
The test now removes the socket after the kill (`stop_bluetoothd()`);
`suite2` is with that version, and all four pass on both sides. The
superseded patch is kept in `patches/superseded/`. The ten-run rates were
repeated with the final test (`runs/*/final-rate`): base 10/10 runs
failing, 20 reports, all `media.c:321 in media_endpoint_remove` (10 in
the main loop for the app-exit test, 10 on the exit path for the exit
test); base + series 0/10, no sanitizer SUMMARY.

## 5. 5.72 and Ubuntu 24.04

- Report 1 exists in 5.72 (10/10 above). Fix 2 cherry-picks cleanly onto
  5.72, but alone it would be wrong there: 5.72's `media_endpoint_remove()`
  does not unlink endpoints from `app->endpoints` (no `endpoint->app`), so
  `app_free()` would then remove endpoints `release_endpoint()` already
  freed [source, 5.72 `media.c:219-240`, `:2666`]. The backport is two
  patches (`patches/5.72/`):
  1. `media: Unlink endpoints from their application on removal` — the
     endpoint half of 7482aceece70, with the unlinking before the A2DP
     return as in fix 1;
  2. fix 2, unchanged.
- Fix 1 does not apply to 5.72: the bug it fixes came with 7482aceece70.
- Report 2: `patches/5.72-discovery/` (7e3212fa2 with the conflict
  resolved).
- `git apply --check` of all three against the CO-03 Ubuntu trees
  `co03/build-f44/base` (`5.72-0ubuntu5.8`) and `co03/build-f44/backport`
  (CO-03's U12 backport): applies, `media.c` offset −8, `adapter.c` +16.
- 5.72 builds with the backports with the same 40 compiler warnings as
  without (all pre-existing, from the image's newer compiler; built with
  `CFLAGS=-Wno-error`, see `runs/TREES.md`), none in `media.c` or
  `adapter.c`.
- Functional tests on 5.72 ran with master's test harness and master's
  test tools (`btvirt`, `bluetoothctl`, `btmgmt`, `test-runner`; 5.72's
  are too old for the harness) driving 5.72's `bluetoothd`; one pytest
  session per test, as 5.72 cannot pair twice in reused guests (CO-03
  noted the same). They used the test before the socket cleanup of §4,
  which only matters for a later test in the same session (there was
  none).
- Not done: the Ubuntu package was not built with the patches, and the
  CO-03 PipeWire harness was not rerun.

## 6. Files

To copy into the project (small, written here):

- `README.md` (this file)
- `patches/master/0001…0003-*.patch` — the series, `git format-patch`
  (author Iaroslav Voitovych, from the project's git config; no trailers)
- `patches/5.72/0001…0002-*.patch`, `patches/5.72-discovery/0001-*.patch`
- `patches/checkpatch.log`
- `msg/` (commit messages as written)
- `patches/superseded/` (the first test patch, which left the bus socket
  behind, and its CheckPatch log)
- `scripts/` (`asan-tree.sh`, `asan-blocks.py`, `summarize.py`,
  `report-table.py`, `grep-range.py`, `use-master-tools.sh`,
  `update-tests.sh`, `run-572.sh`, `run-572-app.sh`, `run-checks.sh`,
  `checkpatch.sh`)
- `runs/TREES.md`, `runs/*/commits.txt`, `runs/*/*.results`,
  `runs/*/*.verdicts`, `runs/*/make-check.log`; the ASan report blocks of one
  failing run per tree, cut from the full logs, in `runs/asan-reports.txt`.
  The pytest outputs (`runs/*/*-[0-9]*.log`), the full guest logs
  (`.debug.log`) and the suite logs stay in the work area,
  `/root/exp/agent-work/exit-uaf/`.
- `progress.log`
- `upstream-fix/` (format-patch of 7e3212fa2, for reference); 7482aceece70
  is BlueZ master's own commit and is not copied
  (`git show 7482aceece70`)

Local only (rebuildable): `repo/` (clone with branches `exit-uaf-fix`,
`exit-uaf-test`, `local-revert-7e3212fa2`, `backport-5.72`,
`backport-5.72-discovery`, `local-5.72-harness`), `repo-5.72/` and
`repo-ebbb4ee/` (its worktrees), `runs/*/src` and `runs/*/ell` (built trees), `bluez/` and
`bluez-5.72/` (read-only worktrees of `cache/bluez-upstream`),
`cache/lore-linux-bluetooth-0.git` (lore since 2024-01-01).

## 7. Rerun

One command per line, from the host; every step runs in a container.

The final commits: series `3c8e880f8` (fix 1), `5534b2688` (fix 2),
`1a1d7376a` (test) on branch `exit-uaf-fix`; local discovery test
`17e1a36cc` + `7c0926ecf` on `exit-uaf-test`; revert of 7e3212fa2
`1dbce15de`. A fresh rerun with them (new tree names):

```console
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh build base 14bd6ab65 1a1d7376a 17e1a36cc 7c0926ecf
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh build series 14bd6ab65 3c8e880f8 5534b2688 1a1d7376a 17e1a36cc 7c0926ecf
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh build fix1only 14bd6ab65 3c8e880f8 1a1d7376a
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh test base acquired_transport 10 rate
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh test series acquired_transport 10 rate
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh test fix1only test_a2dp_exit_with_acquired_transport 10 exit-rate
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh check base
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh check series
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh suite base suite
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh suite series suite
$ /root/exp/agent-work/exit-uaf/scripts/checkpatch.sh /root/exp/agent-work/exit-uaf/patches/master/0001-media-Fix-use-after-free-of-app-when-removing-a-lock.patch /root/exp/agent-work/exit-uaf/patches/master/0002-media-Fix-use-after-free-releasing-endpoints-on-adap.patch /root/exp/agent-work/exit-uaf/patches/master/0003-test-Cover-A2DP-endpoint-release-with-an-acquired-tr.patch
```

How the recorded runs were made (trees as listed in `runs/TREES.md`):

```console
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh build base-t0 14bd6ab65 e4694315f
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh build fix1 14bd6ab65 3c8e880f8 e4694315f
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh build fix12 14bd6ab65 3c8e880f8 9f40136a4 e4694315f 17e1a36cc
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh build disc-revert 14bd6ab65 1dbce15de 17e1a36cc
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh test base-t0 acquired_transport 10 rate
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh test fix12 acquired_transport 10 rate
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh test fix1 test_a2dp_exit_with_acquired_transport 10 exit-rate
$ /root/exp/agent-work/exit-uaf/scripts/update-tests.sh 1a1d7376a 7c0926ecf base-t0 fix12
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh suite base-t0 suite2
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh suite fix12 suite2
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh test base-t0 acquired_transport 10 final-rate
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh test fix12 acquired_transport 10 final-rate
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh test disc-revert "test_exit_discovering and bus" 10 rate
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh test base-t0 "test_exit_discovering and bus" 10 disc-rate
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh build v572 03b684514
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh remake v572 "CFLAGS=-g -O2 -Wno-error"
$ /root/exp/agent-work/exit-uaf/scripts/use-master-tools.sh v572 base-t0
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh build v572fix 03b684514 c72936943 99e56936b 11d09e35b
$ /root/exp/agent-work/exit-uaf/scripts/asan-tree.sh remake v572fix "CFLAGS=-g -O2 -Wno-error"
$ /root/exp/agent-work/exit-uaf/scripts/use-master-tools.sh v572fix base-t0
$ /root/exp/agent-work/exit-uaf/scripts/run-572.sh
$ /root/exp/agent-work/exit-uaf/scripts/run-checks.sh
```

(`build` refuses an existing `runs/<name>`; use a new name. The two
`build v572*` commands exit 1 at the `-Werror` stage by design of 5.72's
maintainer mode; `remake` completes them. `base-t0` was built from an
earlier draft of the test, its test files replaced afterwards, see
`runs/TREES.md`; `e4694315f` is that test as run.)
