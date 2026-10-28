# CO-35 — backports of the ECRED deferred-accept hang fix to 6.18.y, 6.12.y, 6.6.y, 2026-10-28

Upstream pair (Pauli Virtanen), kept in this order:

1. `608e0b7a675b2affbbf38167cad0fa63d8e064f7` "Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and locking helpers"
2. `32d86e048d8efedb7aa6cbbd3c36c3c435401c92` "Bluetooth: L2CAP: hold conn->lock for __l2cap_ecred_conn_rsp_defer"

Method: QEMU/KVM, 4 vCPUs, tester.config kernels (`tmp/co02-w2c/build-tree.sh`), BlueZ l2cap-tester as in
results-2026-10-28.md. Logs in `tmp/l2cap-hang/logs/`. Patches in `backports/<line>/`
(`git format-patch`, `[ Upstream commit <hash> ]` line, author and original Signed-off-by kept). Added after
the outside reviews (2026-10-28): the `[ backport: ]` note moved below the upstream sign-offs and the
backporter's `Signed-off-by` appended (`tmp/l2cap-hang/add-backporter-signoff.py`; `git diff` shows only those
trailer lines changed, the diffs are untouched).

Scripts (all in `tmp/l2cap-hang/`): `make-618.sh`, `make-612.sh`, `make-66.sh` (build the commits; for 6.12/6.6 the
`l2cap_sock.c` conflict was resolved by hand, the resulting commit is the record), `commit-backport.sh` (stable-style
message), `verify-line.sh` (control + backport case + case-log scan + full run + report scan), `full-l2cap.sh`,
`compare-full.sh` (by-name comparison of two full logs), `base-phy.sh`, `run-rest.sh`.

## Summary

| line | base | backport commits | case "Accept 2 Close 1" | full l2cap-tester | report scan |
|---|---|---|---|---|---|
| 6.18.y | v6.18.59 | `601d1caa6833`, `c953b83a7c8c` | base HANG, backport Passed 0.026 s | 111 total, 93 passed, 18 failed (all BT_PHY set; the same 18 fail on the base in a PHY-only run) | clean |
| 6.12.y | v6.12.114 | `2140180eb76d`, `c2ce0cd7e717` | base HANG, backport Passed 0.038 s | 111 total, 33 passed, 78 failed (no regression among the cases compared; see 6.12 notes and BT-14) | clean |
| 6.6.y | v6.6.160 | `3e08be30f4fd`, `e9334dba491f` | base HANG, backport Passed 0.050 s | 111 total, 79 passed, 32 failed (no regression among the cases compared) | clean |

No version-specific prerequisite was needed on any line.

The full-suite totals are lower than 7.2's 111/111 on every line. What was compared: the 96 cases the base runs
before it hangs (by case name: no base pass fails with the backport), the PHY cases after the hang (PHY-only
base runs: the same sets fail), and, added after the outside reviews, the remaining post-hang failures in
filtered base runs (`ATT`, `Nval`, `Ethtool`; section "Matched controls for the post-hang failures" below). With
those, **every case that fails with the backport fails on the plain base too: 18/18 on 6.18, 78/78 on 6.12,
32/32 on 6.6** (`tmp/l2cap-hang/coverage-check.sh <618|612|66>`; the counts equal the tester's own "Failed:"
totals; 6.6's 32 include one timeout, failing on the base the same way). No regression observed; not every L2CAP path is
shown to work on these trees, since many cases fail on the bases themselves. 6.12.114's 78 failures are mostly BT-14 (L2CAP `getsockopt` → EOPNOTSUPP; fix
`5bd0dec150f56` queued for 6.12 on 2026-10-23), unrelated to this pair.

## What was changed

### 6.18.y (v6.18.59)
- Patch 1: applies; the context-analysis annotations 6.18 lacks were dropped: `__must_not_hold(&chan->lock)` on the
  `l2cap_chan_close_unlocked()` prototype, `__cond_acquires(true, &chan->conn->lock)` on the `l2cap_chan_lock_conn()`
  prototype (`__acquires(&chan->lock)` stays), `__context_unsafe(/* conditional locking */)` on its definition.
  Code unchanged. Commit note: `[ backport: dropped the context-analysis annotations 6.18 lacks ... ]`.
- Patch 2: applies with offsets, no change.

### 6.12.y (v6.12.114) and 6.6.y (v6.6.160)
- Patch 1: same three annotations dropped, same note. The rest applies with offsets.
- Patch 2: hunk 1 of `l2cap_sock.c` fails because these trees' `l2cap_sock_recvmsg()` has no `MSG_ERRQUEUE` block
  (that arrived later). Resolution: the new `l2cap_sock_defer()` function and the call
  `err = l2cap_sock_defer(sk); if (err) return err < 0 ? err : 0;` are exactly upstream's; only the three
  `MSG_ERRQUEUE` lines that precede the call upstream are absent, because the tree has no such code. Nothing else
  changed; the `done:` label in `l2cap_sock_recvmsg()` is still used. Commit note says so.
- Both trees have `conn->lock`, `l2cap_conn_get/put` and `l2cap_chan_lock`, so the helpers need nothing else.

## Commands and verdicts

Control and backport case, per line (`verify-line.sh` -> `try-picks.sh`, 180 s limit):

```
verify-line.sh .../stable-6.18.y 618 v6.18.59 601d1caa68332e187f7896bbb5d26d9c9cdc8c70 c953b83a7c8c31bdc2a09732ad5a442ef20e0978
  bzImage-bt10-618-ctl: HANG (limit 180 s)
  bzImage-bt10-618-bp: L2CAP Ext-Flowctl Server - Accept 2 Close 1 Passed 0.026 seconds
  try-618-bp.log  kernel=6.18.59-dirty  clean
verify-line.sh .../stable-6.12.y 612 v6.12.114 2140180eb76de40c010c397b5dd06ad5f374b6b3 c2ce0cd7e717ff6d167abd2d26a7160be61c2c0a
  bzImage-bt10-612-ctl: HANG (limit 180 s)
  bzImage-bt10-612-bp: L2CAP Ext-Flowctl Server - Accept 2 Close 1 Passed 0.038 seconds
  try-612-bp.log  kernel=6.12.114-dirty  clean
verify-line.sh .../stable-6.6.y 66 v6.6.160 3e08be30f4fdb2fa415ceae0d512319e28f413f0 e9334dba491fd3460577717f70cc9659900bafa1
  bzImage-bt10-66-ctl: HANG (limit 180 s)
  bzImage-bt10-66-bp: L2CAP Ext-Flowctl Server - Accept 2 Close 1 Passed 0.050 seconds
  try-66-bp.log  kernel=6.6.160-dirty  clean
```

Full l2cap-tester (`full-l2cap.sh bt10-<line>-bp 900`), totals and scan:

```
6.18: Total: 111, Passed: 93 (83.8%), Failed: 18, Not Run: 0     full-bt10-618-bp.log  kernel=6.18.59-dirty  clean
6.12: Total: 111, Passed: 33 (29.7%), Failed: 78, Not Run: 0     full-bt10-612-bp.log  kernel=6.12.114-dirty  clean
6.6 : Total: 111, Passed: 79 (71.2%), Failed: 32, Not Run: 0     full-bt10-66-bp.log   kernel=6.6.160-dirty  clean
```

Full run on each plain base (`full-l2cap.sh bt10-<line>-ctl 900`): killed by the 900 s limit at the hanging case
(`exit=124`), so no totals; scan: `full-bt10-618-ctl.log kernel=6.18.59 clean`, `full-bt10-612-ctl.log kernel=6.12.114 clean`,
`full-bt10-66-ctl.log kernel=6.6.160 clean`. Cases completed before the hang: 96 on each line.

Comparison by case name (`compare-full.sh <ctl log> <bp log>`), the same on all three lines: cases done in base but not in patched: none;
failed in base but not in patched: none; failed in patched but not in base among the cases the base completed: none.
Failed in patched only among cases the base never reached (after its hang):

- 6.18: `Ext-Flowctl Server - Set PHY 1M/2M/Coded`.
- 6.12: `Ext-Flowctl Server - Nval Conn Req`, `- PHY`, `- PHY 2M/Coded`, `- Set PHY 1M/2M/Coded`, `LE ATT Client Change Sec - Success`, `LE ATT Client - Success`, `LE ATT Server - Success`, `LE EATT Client Change Sec - Success`, `LE EATT Client - Success`, `LE EATT Server - Success`, `LE Ethtool Get Ts Info - Success`.
- 6.6: `Ext-Flowctl Server - PHY`, `- PHY 2M/Coded`, `- Set PHY 1M/2M/Coded`, `LE Ethtool Get Ts Info - Success`.

The PHY ones were then run on the plain base with `base-phy.sh` (the case-name filter of `run-one.sh` is unquoted
through TESTARGS, so only the one-word filter `-s PHY` works; that selects all PHY cases and not the hanging one;
note that `run-one.sh <case>` with a multi-word name therefore filters on its first word and effectively runs the
whole suite up to the hang). Result on all three lines: the set of failed PHY cases on the base equals the set in the
patched full run (18 on 6.18, 28 on 6.12, 26 on 6.6; "failed in patched but not on base": none, "failed on base but not
in patched": none). Reason: `setsockopt(BT_PHY): Protocol not available (92)` (6.18, 6.12, 6.6: BT_PHY and, on 6.6,
`SO_TIMESTAMPING: Invalid argument (22)` are features these trees lack; 7.2 has them).

The remaining post-hang failures were first attributed by cause only (as written here, kept); the next section
gives them matched base controls:
- 6.12 `LE ATT/EATT ... Success`, `Ext-Flowctl Server - Nval Conn Req`: reason `getsockopt(L2CAP_OPTIONS)` / `getsockopt(BT_RCVMTU): Operation not supported (95)`, the same reason as the 65 failures the base shows before its hang (see finding below).
- 6.12 and 6.6 `LE Ethtool Get Ts Info - Success`: `SIOCETHTOOL failed`, as `BR/EDR Ethtool Get Ts Info - Success` on the same base.

## Matched controls for the post-hang failures (2026-10-28, after reviewer 4)

`tmp/l2cap-hang/post-hang-controls.sh` → `base-filter.sh <base> <patched full log> <word>`: the base image runs
only the cases matching one word that does not select the hanging case; the failed set is compared by name with
the patched full run's cases matching the same word. Logs `tmp/l2cap-hang/logs/filter-<word>-<base>.log`.

```
[ATT on bt10-612-ctl] base: 1 passed, 6 failed; patched full run: 6 failed matching 'ATT'
  failed with the backport, passed on the base (regressions):
  failed with the backport, not run or not concluded on the base:
  failed on both:
    L2CAP LE ATT Client Change Sec  - Success
    L2CAP LE ATT Client - Success
    L2CAP LE ATT Server - Success
    L2CAP LE EATT Client Change Sec - Success
    L2CAP LE EATT Client - Success
    L2CAP LE EATT Server - Success
[Nval on bt10-612-ctl] base: 2 passed, 1 failed; patched full run: 1 failed matching 'Nval'
  failed on both:
    L2CAP Ext-Flowctl Server - Nval Conn Req
[Ethtool on bt10-612-ctl] base: 0 passed, 2 failed; patched full run: 2 failed matching 'Ethtool'
  failed on both:
    L2CAP BR/EDR Ethtool Get Ts Info - Success
    L2CAP LE Ethtool Get Ts Info - Success
[Ethtool on bt10-66-ctl] base: 0 passed, 2 failed; patched full run: 2 failed matching 'Ethtool'
  failed on both:
    L2CAP BR/EDR Ethtool Get Ts Info - Success
    L2CAP LE Ethtool Get Ts Info - Success
```

(The empty "regressions" and "not concluded" lists of the last three runs are omitted above; all were empty.)

Every patched failure against every base result (`tmp/l2cap-hang/coverage-check.sh`):

```
618: patched failures 18; failed on the base too: 18
612: patched failures 78; failed on the base too: 78
  patched failures passing in some base run (regressions):
    L2CAP BR/EDR Server - PHY
    L2CAP BR/EDR Server - Success
66: patched failures 32; failed on the base too: 32
```

(Failures here are " - test failed" and " - test timed out" verdicts; a first version of the checker read only
the former and gave 31 on 6.6. The 32nd is `L2CAP BR/EDR Client PIN Code Change Sec - Success`, "test timed
out" with the backport and on the base, `full-bt10-66-ctl.log`.)

The two 6.12 lines are not regressions: in the base's own full run each of those cases prints "test passed"
and then "test failed" (`full-bt10-612-ctl.log` lines 892/895 and 1221/1224), and the checker counts both
lines; the case's final verdict on the base is failed, as with the backport. Some cases print "test failed"
twice (6.6 has 35 such lines for 31 names); the checker counts distinct names.

## Uncertain / side findings

1. 6.12 totals (33/111) are poor because of a different problem on the plain v6.12.114: every `getsockopt` on an L2CAP
   socket returns `Operation not supported (95)`. `l2cap_sock.c` there uses `.getsockopt_iter` (commit
   `22ebe6ab0b679` "Bluetooth: L2CAP: convert to getsockopt_iter", a stable-dep-of backport, is an ancestor of
   v6.12.114), but `net/socket.c` of 6.12.114 has no `getsockopt_iter` dispatch (`grep getsockopt_iter net/socket.c`: no
   match), and `.getsockopt` is gone from the L2CAP ops. Not diagnosed further (no check of the other protocols
   converted the same way, no run on the laptop's stock kernel). It would need its own report; it reduces how much of
   the 6.12 full suite is informative for this backport. On 6.6 and 6.18 the tree has no `getsockopt_iter` at all and getsockopt works.
2. The case itself passes on all three; the base-vs-backport comparison of the other cases is by name only up to the
   base's hang (96 cases) plus the PHY cases run separately. Cases after the hang other than PHY (listed above) have
   no base run.
3. The control images are built from v6.18.59 / v6.12.114 / v6.6.160 with the same `tester.config` and are not the old
   `bzImage-*-base-smp` images (those are 6.18.58 and older).
4. Patch 1 adds `l2cap_chan_close_unlocked()` without any caller (as upstream); the unlocked-pattern conversions are
   other upstream commits not part of this pair.
5. The worktrees were reset and left on their base tags; the backport commits exist as unreferenced objects in
   `cache/linux`'s object store (hashes above, also in the patch files). `btusb.c.orig` untouched.
