# CO-02 log

Append-only. Newest last.

## 2026-09-29 — U7 found
Lenovo earbuds, E1 boot: three codec switches in a row. The two made while an mSBC link was
up got a Disconnect and then no Setup Synchronous Connection; the test sound was silent
(`docs/issues.md`, U7).

## 2026-10-03 — the timing comparison (`EX-060`)
`scripts/sco-switch-windows.sh` on the retained captures:
- **Earbuds:** `AT+BCS=` came 16 to 30 ms after the Disconnect, and the old link's
  Disconnection Complete came 177 to 205 ms after it. No setup followed.
- **MOMENTUM 4:** the reply came at 67 to 75 ms and the completion at 39 to 46 ms. A setup
  followed 24 to 26 ms after `OK`.

PipeWire master had no commit addressing it. STATUS left the host-side handling "to be
examined separately".

## 2026-10-20 — related upstream work found
BlueZ #2562 and Hitalo Souza's "Fix SCO setup failures after an abandoned setup" (v3,
2026-10-08): the same area, with a different trigger (a socket closed while its setup is
pending). Recorded as CO-02 in `reviews/2026-10-20T2309Z-contribution-opportunities.md`, and
as item 1 of the source investigation task.

## 2026-10-21 — reviewer 1's pointer, checked in source
- **The reviewer's claim:** the kernel reuses the dying connection by address and sends no
  setup.
- **Checked** on bluetooth-next `27731ba09195` and Ubuntu `7.0.0-38` source. The claim
  holds, with one correction: the old connection is `BT_CONNECTED`, not `BT_DISCONN`, so
  `sco_connect()` marks the new socket connected at once.
- **The series:** patches 2 and 4 of the abandoned-setup series do not touch
  `hci_connect_sco()`'s lookup.
- **Full record:** `reviews/2026-10-21T0009Z-source-investigation-reviewer-1.md`, SI1.

## 2026-10-21 — dossier opened

## 2026-10-21 — reviewers 2, 3 and 4: the same mechanism; PipeWire's side read
- **All three found the reuse independently.** All three, like reviewer 1, called the old
  state `BT_DISCONN`.
- **Checked:** no `hci_conn` is ever set `BT_DISCONN` (`git grep` over `net/bluetooth`).
  `hci_disconnect_sync()` waits for the completion with the state unchanged.
- **So the new socket is connected at once** (`sco.c:417`). The completion then closes it
  with `ECONNABORTED` (reason 0x16, `lib.c:128`).
- **PipeWire 1.0.5, read here:** it retries only an immediate `ECONNABORTED` (`backend-native.c:1447`).
  On HUP/ERR it closes the socket and sets the transport IDLE, with no new connect
  (`1653–1669`).
- **For the patch:** a connection being torn down is marked by `conn->abort_reason`, not by
  a state.
- **Full record:** `reviews/2026-10-21T0033Z-source-investigation-reviewers-2-4.md`, RV1.
- **Our own record corrected:** `docs/issues.md` U7's "not a kernel defect" sentence.

## 2026-10-21, worker W2 (QEMU only), about 05:00 to 06:30 local — reproduced, patches drafted
On the operator's go, a worker built the reproducer and the fixes on bluetooth-next
`27731ba09195`; the full account is `experiments/results-2026-10-21.md`, raw material in
`tmp/co02-w2/` on the development host.
- **Reproduced:** sco-tester "Reconnect During Disconnect" fails on every unpatched run (UP 0/5,
  SMP 0/10, KCSAN SMP 0/5): the second `connect()` returns 0 with no setup sent, then
  `SO_ERROR 103`. The control passes in every run.
- **Fixed by** `patch/kernel/0001` (refuse an aborting connection with `-ECONNABORTED`) and
  `0002` (a second defect: a second connect to a live SCO link drops the owner's hold and the
  first link is disconnected; since `06149746e720`, v6.4). During passes 20/20.
- **Not enough for PipeWire 1.0.5:** its immediate retries still fail on the refusing kernel;
  the deferral prototype (`patch/kernel-rfc-defer/`) makes them succeed.
- **The test config is uniprocessor:** BlueZ's `doc/tester.config` sets `# CONFIG_SMP is not
  set`; the worker's first "4-CPU" runs were UP kernels in a 4-vCPU guest and are not counted
  as multi-CPU; SMP and KCSAN kernels were rebuilt with an SMP fragment.
- **Hitalo Souza's series** (14875449 to 14875454) does not fix it (During 0/5 with it alone);
  ours applies on top without conflict.

## 2026-10-21 04:44 UTC — re-checked before entering the dossier
The decisive pair re-run independently of the worker's own runs
(`tmp/co02-w2/run-case.sh <kernel> sco-tester <log> 1 -s Reconnect`, logs in
`tmp/co02-check/`):
- unpatched `27731ba09195`: After Passed, **During Failed**; "Second connect() returned 0
  (Success)", then "SO_ERROR 103 … 1 setup commands";
- refuse + hold `bfac3f388548`: **both Passed**; "Second connect() refused: Software caused
  connection abort (103)";
- `scripts/kernel-report-scan.py`: both logs clean, each the intended kernel.
The drafts were checked for tool or model names and trailers (none) before being copied in.

## 2026-10-22 — pre-send checks (worker W2b) done; two changes needed before sending (PAUSED here)
Full report: the worker's final message, raw in `tmp/co02-send/` (SHA256SUMS, progress.md).
All checks pass (bases unmoved; testers; preflight; ci-local kernel + BlueZ; failure paths incl.
races 42/42 fixed; patch-ids SAME). To do before any send:
1. **Patch 2's `Fixes:` is wrong.** At `06149746e720` the `sco_chan_add()` error path only
   `return err;` (no hold drop). The drop came with `8a5b0135d4a5d` (Cen Zhang, 2026-03-26,
   "Bluetooth: SCO: fix race conditions in sco_sock_connect()": "Adding hci_conn_drop() on
   sco_chan_add failure"). The defect needs both (no hold taken on reuse since 06149746e720,
   dropped on error since 8a5b0135d4a5d): decide the tag (likely `8a5b0135d4a5d`) and reword
   "still drops the caller's hold after sco_chan_add()" to the error path.
2. **GitLint (bot) T1 title > 80 with the patchwork prefix** on both kernel subjects; shorter
   subjects in `tmp/co02-send/patches-short-subject/` pass (patch-id unchanged).
Also: on base the refused-path ACL hold leaks (R1), worth one sentence; UP mgmt flakes 1/9 base vs
3/9 series (LL Privacy, pairing; not SCO code) deserve more runs; Jeremy Dean Clifton's 10-20
`hci_conn_drop()` patch is adjacent.
**Side effect to report to the operator:** `scripts/ci-local.sh`'s BuildEll ran `make install`
of ELL into `/usr` (`/usr/lib/libell*`, `/usr/include/ell`, 07:41). Inert (not in ld cache, no
distro libell, bluetoothd does not link it); removal is the operator's call; fix the tool to a
private prefix.

## 2026-10-22 — the two changes made; package complete
- Branch `co02-send/final` in `cache/co02-send` (the previous series kept as
  `co02-send/presend-v0`). Subjects: "Bluetooth: hci_conn: don't reuse an aborting SCO
  connection", "Bluetooth: hci_conn: hold a reused SCO connection for its caller".
- Patch 2's message rewritten for the two commits that together make the defect, `Fixes:
  8a5b0135d4a5`; ids in kernel style (12 characters).
- Code unchanged: tree `5cb237982c3d` for both the final and the tested series; `patch-id-compare.sh`
  SAME for both patches (`20f80382…`, `106cab62…`). checkpatch `--strict` inside the tree: 0
  errors, 0 warnings, 0 checks for both (outside the tree it cannot resolve commit ids:
  `tmp/co02-send/final/checkpatch-in-tree.sh`).
- Final files: `patch/kernel-final/`; the cover letter has its base and shortlog.
- Next: outside review of the package; the operator's decisions; re-check the base just before
  sending.

## 2026-10-22 — four outside reviews of `4c82e91`
Text: `reviews/2026-10-22-reviews-of-4c82e91.md`. Reviewer 1: ready. Reviewers 2 and 3: do not send
unchanged, two technical restrictions. Reviewer 4: strong, conditional.

| point | who | done |
|---|---|---|
| BlueZ test oracle passes on any immediate error, the After control on a refusal | 2, 3 | worker W2c reworks the test: After only on a real fresh link; During only on `ECONNABORTED` or a real new link |
| The test's Disconnect hook skips the emulator's own teardown | 3 | W2c: hold only the Disconnection Complete event, let btdev tear down normally |
| Assertions on the scenario; timers | 3 | W2c |
| Patch 2 has no upstream test | 3 | W2c adds a Connect Twice case |
| `hci_conn_timeout()` reads `refcnt` unlocked, then `hci_abort_conn()` without a re-check: a connect taking its hold in between gets a link that is then aborted | 2, 3 | **confirmed in source** (`hci_conn.c:641-662`, `:3253-3281`, no lock, no re-check); W2c: deterministic proof with a scratch barrier, then a fix analysis |
| `Fixes:` empirical (parent OK, commit broken) | 4 | W2c builds kernels at the parents and the commits |
| base + patch 1 alone sane | 4 | W2c |
| `sco->setting`/`codec` written by a failing duplicate connect | 3 | W2c, source only; a separate follow-up if it matters |
| Cover-letter subject too long; defer framed as a question; Hitalo's series not linked; patch 2 evidence not visible | 2, 3 | cover letter rewritten (`drafts/kernel-cover-letter.txt`): "fix SCO connection reuse", the deferral as an optional RFC, the series link; the test results line waits for the reworked test |
| Stale `patch/kernel/` and old `Fixes:` references | 3 | README and results point to `patch/kernel-final/` and the correction |
| Cc Hitalo Souza | 2, 3 (4: only if relevant) | relevant (same SCO-abort family, tested together): recommended to the operator |
| `Cc: stable` trailers | 2 | the operator's decision, after the race result |
| BlueZ test timing | 2: with the series; 3: after acceptance; 4: separate thread right after | recommended: a separate `[PATCH BlueZ]` mail right after the kernel series, stating the dependency |
| ELL files in `/usr` | 2, 3 | `dpkg -S`: owned by no package; removal is the operator's decision; the tool to use a private prefix |
| Hardware retest | 3 (recommended), 2 (not a blocker) | the operator's decision (laptop) |

## 2026-10-22 — reviews 5 and 6 (recorded only; no new work started, budget)
Text: `reviews/2026-10-22-reviews-5-6-of-4c82e91.md`. Reviewer 5: request changes (the same test
oracle, emulator teardown, Connect Twice test and timeout race as 2 and 3; qualify the testing
claims; a committed manifest of the failure-path cases; BlueZ comment style M2). Reviewer 6:
send after message fixes, no code changes. New points, to take up when work resumes:
- **Patch 2's message:** write it around the contract (`hci_connect_sco()` returns one reference
  the caller owns; since `816fb1590a4c` `sco_connect()` drops it on every path), keep `Fixes:
  8a5b0135d4a5`, and cite the accepted CIS precedent `e06d549fcd4a`.
- **Patch 1's message:** one sentence that before `a13f316e90fd` the dying connection was reused
  too but the socket went to `BT_CONNECT`; that commit regressed "reports success at once". One
  sentence on the window between `close()` and the timeout work (refcnt 0, no `abort_reason`);
  reviewer 6 argues against widening the check to `!refcnt` (incoming SCO connections sit at
  refcnt 0 in `BT_CONNECT`/`BT_CONNECT2`).
- **Cover letter:** "independent of his series; applies with or without it" instead of "on top
  of"; patch 1 stands on its own and a deferral would build on it; "EBUSY" stays, patch 2 stops
  the collateral disconnect.
- **Cc:** Aldo Ariel Panzardo (author of `816fb1590a4c`, `e06d549fcd4a`), Pauli Virtanen
  (PipeWire's bluez5 backend), Hitalo Souza. **`Cc: stable`** on patch 2 (its trigger is a
  backported fix); patch 1 a judgment call.
- **BlueZ test:** same day, after the kernel series, the dependency under `---`; say that
  During accepts two outcomes on purpose.
- **Before sending:** 20 more mgmt-tester runs; re-check patchwork for `hci_connect_sco()` /
  `hci_conn_drop()` work (Jeremy Dean Clifton's 10-20 patch).
- **ELL in `/usr`:** both say remove it and use a private prefix.

## 2026-10-22 — worker W2c, paused at the operator's request (results NOT yet re-checked)
State: `tmp/co02-w2c/progress.md` (SHA256SUMS, 269 files; `summarize.sh` reprints the counts).
- **BlueZ test v2** (branch `co02/sco-tester-reconnect-v2-w2c`, commit `693abcbd2` in
  `cache/co02-w2c-bluez`; patch `tmp/co02-w2c/patch-bluez-t3/`): strict oracle (After only on a
  real new link; During only on `ECONNABORTED` or a real new link; anything else fails with a
  message); the Disconnection Complete held with a `POST_EVT` hook so btdev tears down normally;
  counters assert the scenario; a **Connect Twice** case (exactly `EBUSY`, no Disconnect, first
  link still up after 500 ms, both sockets' close then disconnects SCO and ACL). ci-local
  am/checkpatch/gitlint PASS. Distinct handles cannot be asserted: btdev reuses 0x0100 once the
  first link is gone. Positive control: the deferral kernel passes During through a real new link.
- **Counts** (3 runs each, After / During / Connect Twice): base 3/0/0 on UP, SMP and KCSAN;
  patch 1 alone 3/3/0 (UP); the series 3/3/3 on UP, SMP and KCSAN. Full sco-tester: base 31/33,
  patch 1 alone 32/33, series 33/33. kernel-report-scan: 101 of 104 logs clean, 3 KCSAN reports
  outside SCO and `hci_conn.c`.
- **The timeout race is REAL, deterministically:** a scratch module parameter parks
  `hci_conn_timeout()` after it saw `refcnt == 0`; with the series, a second connect during the
  park gets "returned 0 (Success)" with no setup, then `SO_ERROR 103` (4 of 4, SMP). A prototype
  (in patch 2's reuse branch: `cancel_delayed_work_sync(&sco->disc_work)` after the hold, then
  refuse if `abort_reason` is set) refuses it 3 of 3 and passes the focused cases 9 of 9, no
  report; branch `w2c/proto-20261022`, patch in `tmp/co02-w2c/patch-kernel-prototype/`. The
  worker reads it as a pre-existing, separate `hci_conn` lifetime race (`hci_connect_acl` has no
  `abort_reason` check at all). Not run: the race on the unpatched base (image built).
- **`Fixes:` check, empirical:**
  - patch 2: at the parent of `8a5b0135d4a5` the first link survives the second connect but
    never disconnects after both sockets close (a leaked hold); at `8a5b0135d4a5` it is
    killed. So patch 2 fixes a leak older than `8a5b0135d4a5` (from `06149746e720`) and the kill
    from `8a5b0135d4a5`; the message and tags need that nuance (reviewer 5 said as much);
  - patch 1: **`a13f316e90fd` is not supported**: neither it nor its parent shows the false
    success (During gets `EBUSY` there). A bisect between `a13f316e90fd` (good) and the parent
    of `8a5b0135d4a5` (bad), limited to `net/bluetooth`, is about 3 steps from the answer
    (`dc26097bdb86` bad; five good; step 7 `4a5e0ba68676` was building). Resume:
    `git -C cache/co02-w2c-hist bisect run tmp/co02-w2c/bisect-step.sh`.
- **`setting`/`codec`** written by a failing duplicate connect: no practical effect on the live
  link (read only at setup, completion and cleanup; airmode values 1 and 2 aside).
- **Side effect:** a `libtoolize` rewrote the git-ignored `ltmain.sh` in the project root (same
  libtool 2.4.7, same size); the build script no longer runs it.

## 2026-10-22 09:00 to 09:20 UTC — resumed; the race re-checked, patch 3, bisect, package v1
- **Re-checked W2c's race result:** series + park 2/2 killed after "Success"; + prototype 2/2
  refused with `ECONNABORTED`; unpatched base + park 2/2 killed (no hold: patch 2's bug).
- **Patch 3 adopted** from the prototype (11 lines); deadlock argument: no `hdev->lock` on the
  SCO timeout path, and `hci_conn_del()` already waits for `disc_work` under `hdev->lock`.
- **Bisect finished:** first bad `e6720779ae61` (v6.13); patch 1 and patch 3 carry it.
- **Messages:** patch 1 with the history sentence; patch 2 around the ownership contract, citing
  `e06d549fcd4a`, claiming nothing about the pre-`8a5b0135d4a5` behaviour that is not identified;
  patch 3 new.
- **BlueZ test:** multi-line comments in BlueZ's style; dependency note below `---`.
- **Final runs:** 27 of 27 focused, full suites unchanged (SMP mgmt the same nine), 26 of 26 logs
  clean, base re-checked failing both bug cases. `experiments/results-2026-10-22.md`.
- **Package:** `patch/v1/`; review request round 2.
