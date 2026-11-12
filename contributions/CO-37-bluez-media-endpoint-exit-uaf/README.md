# CO-37: bluetoothd use-after-frees at exit with a streaming sound server (U23, U24)

> **Current state, 2026-11-12** (the index `../README.md` is the current record): **fix series
> ready, nothing sent.** Six mails exist since 2026-11-02 (the sixth fixes the duplicate
> `MediaEndpoint1.Release` the series exposed): `work/patches/master-final-6-20261102/`, and the
> 5.72 backport `5.72-3-20261102/`; the bot's checks pass on both. `U27` (5.72 only) is not covered.
> Open: the route, one or two series, subjects, fixtures (decisions D3, D13).

**State (2026-11-01):** reproduced on BlueZ master and on 5.72 under ASan; a fix series and a
test for master are written; backports for 5.72 are ready. Nothing is sent. Sending is the
operator's decision.

**Target:**
- BlueZ master: U23 (two patches and a test).
- Ubuntu 24.04's `bluez 5.72`: U23 (backport), and U24 through upstream's own fix.

**Comes from:** CO-03's VM runs (2026-10-31). The ASan builds of bluetoothd reported both at
exit (`contributions/CO-03-bluez-u12-backport/backport/runs/asan-exit-reports.txt`).

**Full record:** [`work/README.md`](work/README.md) has every claim with its source line, run,
and rerun command. `work/runs/asan-reports.txt` holds the report of one failing run per tree.

## U23: endpoint released after it was freed (present on master, no fix upstream)

**How it happens** [source, master `14bd6ab65`]:
1. At exit, the media driver is unloaded while transports still exist, so `path_free()` runs
   then.
2. `path_free()` frees the applications first. That removes their endpoints, but an A2DP
   endpoint whose stream is locked by an acquired transport has its removal deferred
   (`a2dp_remove_sep()`), so it stays in the adapter's list.
3. `release_endpoint()` then clears its transport. That unlocks the stream, unregisters the
   SEP and frees the endpoint while `clear_endpoint()` is still using it.

**When it happens:** only when bluetoothd exits without powering the adapter off first, for
example when it loses the bus. In every CO-03 occurrence it had just logged "Disconnected from
D-Bus. Exiting.".

**On master an earlier read fires first.** It is in `media_endpoint_remove()`
(`media.c:321`), on the application pointer that `7482aceece70` (2026-07-15, in no release)
added. A postponed removal leaves that pointer dangling. It happens at exit, and also while
running, when the sound server leaves the bus during streaming. The case another campaign hit
at CI's commit `ebbb4ee31ad7` (`media.c:312`, CO-36 part 2) is this same defect.

**Fix series** (`work/patches/master/`):
1. `media: Fix use-after-free of app when removing a locked A2DP endpoint`. It unlinks the
   endpoint from its application before the A2DP early return.
   `Fixes: 7482aceece70`.
2. `media: Fix use-after-free releasing endpoints on adapter removal`. `path_free()` releases
   the endpoints before freeing the applications. `Fixes: ee0f3c03fb1d`.
3. `test: Cover A2DP endpoint release with an acquired transport`. It adds two functional tests:
   - the application leaves the bus;
   - bluetoothd loses the bus.

   Each asserts a clean exit.

**Results, ten runs each** (`work/runs/*/*.results`):

| tree | failing runs | report |
|---|---|---|
| master | 10/10 | `media.c:321` |
| master + fix 1 | 10/10 | `media.c:412 in clear_endpoint` (U23 itself) |
| master + fixes 1 and 2 | **0/10** | none |
| 5.72 | 10/10 | `media.c:300 in clear_endpoint`, as in CO-03 |
| 5.72 + backport | **0/10** | none |

**Checks:**
- **Style:** the CI bot's CheckPatch gives 0 errors and 0 warnings on all three patches.
- **Build:** 0 warnings under `-Werror` on both sides.
- **`make check`:** 41 pass and 1 skip, on both sides.
- **Functional suite:** the only change is the two new tests. Master's own failures are the same
  on both sides (`l2cap-tester` aborts in `timeout_callback`; not investigated).

**Upstream search:** no commit and no list patch fixes it. Bastien Nocera's RFC (patchwork
14568134, 2026-05-12, unreviewed) adds a check that comes after the failing read.

**Not covered, from reading the source:** an endpoint unregistered while running, while another
client holds its transport, may still reach the same read at exit. Untested.

## U24: discovery cleanup on a freed device (fixed upstream)

- **The fix:** upstream `7e3212fa233e` ("adapter: clear discovery_found list before
  discovery_cleanup()", Pauli Virtanen, 2026-09-04). It is in no release yet; the newest tag is
  5.87.
- **Master:** 0/10 failing. With that commit reverted: 10/10.
- **5.72:** 10/10 failing (`device.c:6161`, the same line as CO-03's 6167 in the Ubuntu tree).
  With the backport: 0/10.

## What applies to Ubuntu 24.04 (5.72)

- **U23 needs two patches** (`work/patches/5.72/`):
  1. the endpoint half of `7482aceece70` (unlink before the A2DP return);
  2. fix 2, unchanged.

  Fix 2 alone would be wrong on 5.72, and fix 1 is not needed there.
- **U24:** `work/patches/5.72-discovery/`, which is `7e3212fa233e` with a trivial conflict
  resolved.
- **All three apply to CO-03's `5.72-0ubuntu5.8` trees:** both the base and the backport.
- **How 5.72 was tested:** master's test tools drove 5.72's bluetoothd. No Ubuntu package was
  built with these patches yet.

## Next

1. **The operator:** read the series, then decide the route (the linux-bluetooth list, as with
   CO-23) and the send. No mail is drafted.
2. **Before any send:** an outside review of `work/patches/master/`, and the CI bot's checks
   on the exact mails, base and base + series (as for CO-23).
3. **Ubuntu:** a later CO-03 package may carry the 5.72 backports (U23 and U24) next to U12,
   on the operator's word.

**Decides:** sending and filing are the operator's.
