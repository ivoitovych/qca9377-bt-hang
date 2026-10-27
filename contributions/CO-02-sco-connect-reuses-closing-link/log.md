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

## 2026-10-22 11:30 to 12:40 UTC — review round 2 (six reviews of `4ee379d`) and package v2
Reviews: `reviews/2026-10-22-round2-reviews-of-4ee379d.md`. All six find the kernel series sound,
and none asks for another investigation. What each point led to:

| Point (reviewer) | Outcome |
|---|---|
| Patch 3 changelog: the wait is limited to the existing-link path, because only a linked connection can have pending disconnect work (2) | **The invariant is false, and patch 3 v1 had a gap.** A SCO connection the remote set up is never linked (there is no `hci_conn_link()` in `hci_event.c`); its hold comes from `__sco_chan_add()` (`sco.c:315`), and closing the accepted socket queues `disc_work` on an unlinked connection. A connect then takes the `else` branch, and `hci_conn_link()`'s hold does not wait either. New scratch case "Incoming Race Park" (`cache/co02-w2c-bluez-exp`): series v1 + park, 2 of 2 "connect() returned 0", then `SO_ERROR 103`, no setup. **Patch 3 v2** waits after both branches, so every reused connection is covered (a new one has no queued work). v2 + park: incoming 6 of 6 and linked 3 of 3 refused with `ECONNABORTED`. |
| Patch 3: say why the wait is safe (3); "an hci_conn_timeout() worker" (2) | v2's message names `hci_proto_disconn_ind()` (a constant) and `hci_abort_conn()` (it only queues the Disconnect), with `hci_conn_del()` as precedent; the cover letter uses the wording. |
| Patch 1: say why it was EBUSY before `e6720779ae61` (6) | Checked in `e6720779ae61`'s diff: `__sco_sock_close()` kept the closed socket attached in `BT_DISCONN` until the event, so `sco_chan_add()` refused. One clause added. |
| `READ_ONCE()` on the first `abort_reason` read (4) | Not changed. The argument is that patch 3 decides on the value read after the synchronous wait. That every other access in the tree is plain shows only existing practice, not that there is no data race (reviewer 5, round 3). The answer is ready if asked. |
| Lockdep run (4) | Already done: every final kernel and the park kernels have `PROVE_LOCKING`, `DEBUG_ATOMIC_SLEEP` and `DEBUG_LOCK_ALLOC`. `kernel-report-scan` matches lockdep reports, and all logs are clean. The parked runs make the wait actually block under `hdev->lock`. |
| BlueZ: the watch callbacks ignore `cond` (3, 5) | `io_connected()`: requires `G_IO_OUT` without ERR or HUP, then `SO_ERROR == 0` and `POLLOUT`; used for the first and the second socket. |
| BlueZ: check that the second link stays up (3, optional) | `reconnect_stable()`: 500 ms later, the second socket must still be connected, with no further Disconnect. |
| BlueZ: the ACL teardown is identified as "not the SCO handle" (4) | The ACL handle is now recorded from Connection Complete, and the ACL teardown is matched on it. |
| BlueZ: 3 s ACL deadline against the 2 s ACL idle timeout (6) | `RECONNECT_ACL_MS` 5000 for that wait (the case timeout is 8 s). |
| BlueZ: comment openers mixed (6) | Not changed: BlueZ `doc/coding-style.rst` M2 says a multi-line comment starts on the second line, which is what the test does. |
| BlueZ subject over 50 characters (2) | "tools/sco-tester: Add SCO reconnect tests" (41). |
| BlueZ diffstat hand-edited (6) | The mail is regenerated with `git format-patch` and the note is re-inserted below `---`. |
| Two `0001-` files in one directory (3) | `patch/v2/kernel/` and `patch/v2/bluez/`. |
| README opening stale (3, 4, 5) | Rewritten around `patch/v2/`. |
| Cover letter: mgmt-tester detail; refusal versus the end-to-end codec switch in one sentence (4) | Both added. |
| `get_maintainer.pl` on the final mails (2) | Marcel Holtmann, Luiz Augusto von Dentz, **Cen Zhang** (`blamed_fixes`: author of `8a5b0135d4a5`), linux-bluetooth, linux-kernel. |
| Residual window: the new connect lands before the worker runs and adopts the old link (6) | Not in the mail; the answer is ready if asked (reviewer 6's own advice). The incoming path has the same window. |
| `Cc: stable`; Cc list; BlueZ timing; ELL in `/usr`; permission clean-ups | The operator's decisions. `scripts/ci-local.sh` now installs ELL to `tmp/ci-local/ell-prefix` and finds it with `PKG_CONFIG_PATH`, never `/usr`. |
| 20 more mgmt-tester runs (round 1, reviewer 6) | Not done as such. Round-2 reviewers 2 and 5 say identical failure sets settle it. v2's first SMP run had a tenth not-passed case, so three alternating v2/base SMP repeats were run: identical sets each time, and the extra case (`LL Privacy - Remove Device 4 (Disable Adv)`, Timed out) also hit the base. |

**v2 results:** the focused cases pass 27 of 27, the base fails both bug cases, the full suites
show no difference, all 32 logs are clean, and every mail check that ran passed (scan-build is
not installed; VerifyFixes was done by hand):
`experiments/results-2026-10-22-v2.md`. `ci-local`'s BuildEll went to the private prefix, and
`/usr/lib/pkgconfig/ell.pc` still carries only the 2026-10-21 copy.

## 2026-10-22, evening — round 3 (reviewers 1 and 6 so far) and pre-send checks
- **Reviewer 1:** patch 3 v2 is correct and the refusal path is balanced; no changes asked.
- **Reviewer 6:** "v2 is sendable". The refusal path is checked in both branches. Two trims, the
  author's call:
  - the cover letter's mgmt sentence: **done**. It now ends "and so does mgmt-tester"; the nine
    failures and the flaky case stay in the results file;
  - `Cc: stable` on all three: the operator's decision.
- **bluetooth-next master** is still `27731ba09195` (`git ls-remote`).
- **Patchwork since 2026-10-21:** no kernel patch touches `hci_connect_sco()` or SCO. But **Luiz
  Augusto von Dentz posted a 27-patch BlueZ series at 15:46 UTC that moves the testers off GLib**
  (`[BlueZ,v1,24/27] tools: Run sco-tester, rfcomm-tester and 6lowpan-tester on the mainloop`,
  patchwork 14908123; 108 lines of `sco-tester.c`). It replaces `g_io_add_watch` with
  `tester_io_add_watch` and `g_timeout_add` with `timeout_add`. Our test is written against
  GLib, so the two patches collide in either order. The kernel series is not affected. Also in
  it: `03/27 mgmt-tester: Wait for LL Privacy setup to complete`, which matches the LL Privacy
  cases that fail or time out on SMP. Raw: `tmp/co02-round3/`.
- **The texts given as reviewers 2, 3 and 4** were their round-2 reviews of `4ee379d`, word for
  word (already in `reviews/2026-10-22-round2-reviews-of-4ee379d.md`, every point handled
  there). They are not recorded again.
- **Reviewer 5** (`reviews/2026-10-22-round3-review-5-of-482c7b2.md`) would send v2. The refusal
  path is balanced in both branches, and their earlier assessment had missed the incoming path.
  Wording points, all **done**:
  - results: "no additional failures observed; the extra timeout also occurs on the base";
  - "all checks that ran passed" (scan-build absent, VerifyFixes by hand);
  - the upstream tests do not drive patch 3's race; only the parked runs do;
  - the `READ_ONCE` argument rests on the synchronous wait, not on tree-wide practice;
  - a compact parked-race transcript is now `experiments/race-park-2026-10-22.md`.
  On stable: present the dependency between the patches if patches 1 and 3 are tagged.

## 2026-10-22 18:00 to 19:00 UTC — rechecks of `0824c49`, v3 reordered, stable check
Rechecks: `reviews/2026-10-22-rechecks-of-0824c49.md`. All six find no code problem. What each
point led to:

| Point (reviewer) | Outcome |
|---|---|
| The hold fix's context holds the refusal's lines, so stable cannot apply it alone on 6.6/6.12; reorder (6) | **Done: v3.** Hold fix, then refusal, then wait; the final tree is unchanged (`f5424dd92043`). Confirmed: v2's hold patch fails on 6.12.114. In v3 it applies alone on 6.6.160, 6.12.114, 6.18.58 and 7.2.12 (`patch -F0`). |
| Judge affected lines by code, not commit ids; check `816fb1590a4c` (5); the per-line matrix (2, 4, 6) | Done: `experiments/results-2026-10-22-v3.md`. 6.6/6.12 have patch 1's bug only, 6.18/7.2 all three, and 6.1 none (CVE fix present, no reuse path). The laptop's Ubuntu 7.0.0-38 has a combination of its own (kref, no `816fb1590a4c`), for the later Ubuntu step. |
| A base-versus-patched proof on 6.12 (4, 6) | Done. Connect Twice fails 3/3 unpatched and passes 3/3 with the hold fix, under the older ownership model. The full sco-tester differs only in that case. |
| Stable tags | The operator wants every tagged line built and tested first. 6.12 is done; 6.6, 6.18 and 7.2 are running. 6.1 would get a hold-fix attempt that does not apply, hence the proposed `# 6.6.x` on patch 1. |
| Connect Twice: check the teardown status and that SCO goes before ACL (3) | Done (`sco_gone`). |
| During fails on 6.12 with EBUSY, the correct pre-6.13 answer | The test now accepts EBUSY as a refusal; "connected at once without a link" still fails. |
| BlueZ: the rebase line below `---` (1, 3, 4, 6 yes; 2 only for a concrete conflict) | Kept: the conflict is concrete (patchwork 14908123 rewrites `sco-tester.c`). |
| BlueZ: a converted version in reserve (2, 3, 4 no; 1, 6 yes) | Dropped. Rebase only if that series lands first. |
| Cc opt-out search (2 searched: none; 3, 4, 6: brief is enough) | Done. **Operator, 2026-10-22: copy all four** (Cen Zhang, Aldo Ariel Panzardo, Hitalo Souza, Pauli Virtanen): they are involved, and none asked to be left out. |
| ELL (2, 3, 6 remove; 4 later; 5 with a manifest) | **Operator: archive them.** Done: `archive/ell-usr-install-20261021/` holds the exact set from the 10-21 install log, with symlinks, and a README. Not removed. |
| Ubuntu: 24.04's HWE kernel 7.0 is no longer a kernel.org stable line; check GA 6.8's own tree (2) | For the Ubuntu step after acceptance. |

**Checks on v3:** checkpatch `--strict` 0/0/0 ×3; BlueZ am, checkpatch and gitlint PASS. The
first patch alone on bluetooth-next: Connect Twice passes, During still fails, as it should.
Final test (sco-tester v6): 27 of 27 on the series, full sco-tester 33/33 on UP and SMP, and
unpatched bluetooth-next fails both bug cases.

## 2026-10-22 19:00 UTC on — round 4: all six approve v3; stable runs
Reviews: `reviews/2026-10-22-round4-reviews-of-472e898.md` (reviewers 1 to 5) and
`reviews/2026-10-22-round4-review-6-of-472e898.md`. No code change is asked.
- **Stable tags confirmed** (reviewers 2 to 6, against the stable rules):
  - patch 1: `Cc: stable@vger.kernel.org # 6.6.x`, meaning 6.6 and later, which skips 6.1;
  - patches 2 and 3: a plain tag, since their `Fixes:` already limits them.
  The tags go in once the 6.18 and 7.2 runs pass.
- **Cover letter, stable paragraph:**
  - "as checked on the current stable heads" (5);
  - "a backport of 8a5b0135d4a5" (3);
  - "apply on top of patch 1", since the dependency is textual, not functional (2, 4, 6);
  - one sentence on why 6.1.y needs nothing, which saves a FAILED mail (6).
- **Evidence:** it no longer promises what stable automation will do (5).
- **6.6.160:** Connect Twice fails 3/3 unpatched and passes 3/3 with the hold fix; only that case
  differs in the full suite; 14 logs clean.
- **6.18.58:** the tag fetch stalled at 20 MB for 15 minutes and was stopped (19:06 UTC); to be
  retried after 7.2.
- **Have ready if asked:** the stable paragraph belongs in per-patch tags, not the cover. Both
  places are harmless, and the tags are the authoritative part (6).

## 2026-10-22 19:20 to 20:00 UTC — stable check complete; final mails; dry run
- **6.18.58 and 7.2.12:** both bugs present unpatched; all fixed with the series; parked race
  refused 3/3; 34 logs clean. The 6.18 tag came from the GitHub mirror; its SCO files are
  identical to kernel.org's by blob id. All four affected lines are now built and tested, as the
  operator required before tagging.
- **Stable tags added** on `co02-send/v3-stable` (tree unchanged): `# 6.6.x` on patch 1, plain on
  patches 2 and 3.
- **Final mails** in `patch/v3/send/`. Checks pass. Heads unchanged. Luiz's mainloop patch is
  still `new`.
- **`git send-email --dry-run`:** threading and recipients as decided. `stable@` comes from the
  trailers, which the stable rules expect. Not sent.

## 2026-10-22 ~20:15 UTC — how this subsystem handles stable, checked in git
Prompted by the operator's question: does tagging create work or risk for the stable maintainers,
and how do people here handle fixes that apply to some lines only?
- **Stable rules** (`Documentation/process/stable-kernel-rules.rst`):
  - Option 1, the tag in the mainline patch, is "**strongly** preferred, the easiest and most
    common"; once mainlined, the patch is applied "without anything else needing to be done";
  - Option 3, hand-made backports, is for patches that need adjusting, and every deviation must
    be documented;
  - scripts and AUTOSEL also pick up commits that have only a `Fixes:` tag.
- **net/bluetooth since `e6720779ae61`:**
  - about 110 fixes carry `Cc: stable`;
  - version limits are in use and accepted by Luiz: `# 6.6.x`, `# 6.12.x`, `# 6.4`, `# 4.11`
    (btusb, qca); the prerequisite form appears once (L2CAP, `# 0b58004: …`).
- **`8a5b0135d4a5` had no stable tag, only `Fixes:`.** Sasha Levin's scripts still applied it
  unchanged ("[ Upstream commit … ]") to 6.1 (`dabf22269242`) and 6.6 (`adb90cd0f9f7`). That is
  how 6.6 and 6.12 got patch 1's bug. Leaving our tag out would not keep our patches out of stable;
  it would only drop the `# 6.6.x` limit.
- **Aldo's precedents:**
  - `e06d549fcd4a` (CIS hold on reuse, the model for our patch 1) went to 6.12 as a clean
    cherry-pick (`072bc8659f22`, "commit … upstream.", no adjustment) and to 6.18
    (`3ff5a8d949e3`), both by Greg Kroah-Hartman from the plain tag;
  - `816fb1590a4c` (`Fixes: e6720779ae61`, like our patches 2 and 3) went to 6.18 (`b108ea7ebba1`)
    but not to 6.12. The `Fixes:` limit worked as we expect for patches 2 and 3.
- **Conclusion:** our package follows the established practice of this subsystem. The tag and
  the limit route each patch, and the stable team has nothing to adapt.

## 2026-10-22 ~20:30 to 21:30 UTC — from-scratch review of `d7b011d` (reviewers 1 to 4); v4
Reviewers 5 and 6 are still to come. Reviewer 1 would send; reviewers 2, 3 and 4 asked for changes
before sending. Each finding was checked against the code:

| Finding (reviewer) | Checked | Outcome |
|---|---|---|
| Patch 2's early `abort_reason` read races with a lockless writer (4: must resolve) | **Valid.** The only writer is `hci_abort_conn()` (`hci_conn.c:3294`). Its callers that can reach an SCO connection are `hci_conn_timeout()` (`disc_work`, no `hdev->lock`) and `hci_disconnect()`; every `hci_disconnect()` caller holds `hdev->lock` and acts on ACL/LE connections (`hci_event.c`, `smp.c`, `hci_link_tx_to()`). So for SCO the early read races with the worker's write. It is harmless (a byte that only goes from 0 to set; patch 3 decides again after the wait), but it is a data race under the memory model. | **v4:** `READ_ONCE()` on that read and `WRITE_ONCE()` on the write; patch 2's message says why. Patch 3's later read is ordered by `cancel_delayed_work_sync()`, and with the caller's hold the work cannot be queued again; this is now in patch 3's message. |
| Patch 3's lock order needs a full argument (2, 3, 4) | Re-traced. The SCO worker path takes no `hdev->lock`; `hci_abort_conn()` queues the Disconnect; `hci_conn_del()` already waits for `disc_work` under `hdev->lock`. The parked runs blocked under `hdev->lock` with lockdep on, clean. | The message already said this; v4 adds that the work cannot be requeued while the hold is taken. |
| Refusal after `hci_conn_link()` leaves a link: who releases it? (3) | Every abort ends in `hci_conn_del()`: the Disconnection Complete; `hci_abort_conn_sync()` → `hci_conn_failed()` or `hci_conn_del()`; `hci_conn_hash_flush()` on power-off and unregister. `hci_conn_del()` unlinks and drops the ACL hold. | One sentence in patch 3's message. |
| "reference" is ambiguous; the code has holds and object references (4) | Valid. | Patch 1 and patch 2 now say "hold". |
| Patch 3's subject reads like waiting for the controller's disconnect (4) | Valid. | "Bluetooth: hci_conn: synchronize with SCO disconnect work before reuse". |
| Patch 3 should state its own validation (3) | Reasonable. | A short paragraph on the debug-only delay of `hci_conn_timeout()` and the result. |
| Cover letter: "PipeWire does exactly this" (4) | Valid. | "This sequence is exercised by PipeWire during an HFP codec change". |
| BlueZ test leaves the first socket open on early failure (2, 3) | **Valid:** `test_post_teardown()` closes `sk2` only. Existing tests also keep their socket in `data->sk`, closed through their GLib channel, so teardown cannot close it generically. | `reconnect_end()` (reached by every terminal path of the three cases) removes the first socket's watch and closes it. |
| `sync_complete` counts failed completions (2, 3) | Valid. | Only status-0 Synchronous Connection Complete events are counted; failures are printed. |
| `setting`/`codec` written before EBUSY (3) | Known and pre-existing (log, 2026-10-21: no practical effect). | Not in this series; no claim made either way. |
| BlueZ test size (2) | Reviewers 1, 3 and 4 do not ask to shrink it. | Not changed. |
| Mutation tests (2) | The negative controls on four kernels already fail the bug cases for the intended reasons. | Not added. |
| Survey of rejected patches (2, 4) | Neither could do it; our git survey covers accepted practice. | Noted. |

checkpatch caught one defect in my own rewrap of patch 1's message ("commit" and its ID split
across lines); fixed (`co02-send/v4b`, same tree as v4 `cb4e87e621b7`).

**v4 results** (`experiments/results-2026-10-22-v4.md`):
- bluetooth-next: 27/27 focused on UP, SMP and KCSAN; full sco-tester 33/33;
- 6.18.58 and 7.2.12 rebuilt with v4: both bugs unpatched, all fixed;
- parked race refused 18 of 18 on the three kernels;
- unpatched full runs exercise the test's new early-failure cleanup (the other 31 cases pass);
- 59 logs clean.

The package is `patch/v4/send/`; the review request now points at it, in the same neutral form.
Reviews recorded: `reviews/2026-10-22-fresh-reviews-1-4-of-d7b011d.md`.

## 2026-10-22 ~21:30 UTC — reviewer 6's from-scratch review (of `d7b011d`); v5
Review: `reviews/2026-10-22-fresh-review-6-of-d7b011d.md`. Reviewer 6 found the series correct and
the test sound, with three items to settle and some wording. v4 had already done "hold" in patch 1
and patch 3's own validation paragraph.

| Point | Outcome |
|---|---|
| The queued-but-not-started window: a connect() before `disc_work` starts still keeps the live link, and the cover's "makes connect() report what happens" is false for it | **Valid.** v5 says so in patch 3 and in the cover; the cover no longer makes the general claim. Closing it with `delayed_work_pending()` is left for a follow-up (it would need the During test and the race experiment rerun). |
| No hardware run, and the mails don't say so | **Valid.** The cover now says the series has not yet been run on hardware. A run on the laptop (Ubuntu 7.0.0-38, the patches apply there) is the operator's decision, and only the operator handles the laptop's Bluetooth. |
| Patch 2: "sets up a link" (collides with `struct hci_link`); "only sets abort_reason" | Reworded: "sends a Setup Synchronous Connection only if…"; "sets abort_reason and queues the Disconnect but leaves the state alone". |
| Patch 3's long first paragraph | Split. |
| Cover: "the reference…"; "with lockdep enabled"; stable heads were run; shorter stable paragraph | All done. The stable sentence says what was run instead of "the same results", because on 6.6/6.12 only Connect Twice changes. |
| Clifton's pending `disc_work` patch on the same path | **Checked** on patchwork (14903178: `Closes:` syzbot `5897b3c764f5989ea942`; gates `hci_conn_drop()` in `hci_core.h` on `HCI_CMD_DRAIN_WORKQUEUE`). The cover names it as related and not overlapping. |
| Copy Pauli on the BlueZ mail | Done (he wrote most of the recent `sco-tester.c`); the operator can remove him. |
| `W=1` build | `make W=1 net/bluetooth/hci_conn.o` on the series: no warning. |
| `[PATCH bluetooth 0/3]` marker | Not taken: optional, and the base is bluetooth-next. |
| Copy Алексей Воронов | Not taken: his report could not be verified from here. |
| 82-character `Fixes:` line | The bot's gitlint config passes it; kernel rules forbid wrapping it. |
| Answers to have ready (why 2 and 3 are separate; why not in `hci_conn_hold()`; why a `BT_CONNECTED` SCO is reusable at all) | Kept here: 2 is the rule and 3 the race against the rule's own check (squash if Luiz prefers); `hci_conn_hold()` has callers that cannot sleep; the incoming-request cross-over (`BT_CONNECT`/`BT_CONNECT2`, no holder yet) must keep working, which is also why a refcnt==0 check would be wrong. |

v5: branch `co02-send/v5`, tree `cb4e87e621b7` (the v4 code, so the v4 results stand); mails in
`patch/v5/send/`. checkpatch 0/0/0 ×3; `ci-local --kernel` PASS; dry run as intended.

## 2026-10-22/23 — the laptop's kernel: Ubuntu 7.0.0-38 needs two upstream commits first
Preparing the hardware run, the series was built on Ubuntu 7.0.0-38's own Bluetooth sources
(`cache/co02-ubuntu38`, branch `co02-ubuntu38/base` = v7.0 + Ubuntu's `net/bluetooth`,
`drivers/bluetooth`, `include/net/bluetooth`) and run in the emulator. That tree has the kref
change `e6720779ae61` and the CVE fix `8a5b0135d4a5`, but not `abd93c85c8667` ("give the socket
its own sco_conn reference") or `816fb1590a4c` ("serialise sco_conn lifetime against
sco_recv_scodata()"). No kernel.org stable line has that combination.

- **Series alone on Ubuntu (`co02-ubuntu38/series`): Connect Twice fails 6 of 6** (3 UP, 3 SMP)
  with "Timed out waiting for the next link event"; the unpatched base has no such timeout
  (`grep -c "Timed out waiting for the next link event" -r tmp/co02-hw/runs`: `u38-up-twice-1..3`
  and `u38-smp-twice-1..3` 1 each, `u38-base-smp-twice-1..3` 0).
- **Cause, from Ubuntu's `sco.c`:** `sco_conn_add()` takes a `sco_conn` reference for an existing
  connection (l.197), and `sco_connect()`'s EBUSY path (l.376–380) drops only the `hci_conn`, never
  that reference; `sco_conn_free()` is what drops the `hci_conn` hold (l.89–92). Before patch 1 the
  wrongly dropped hold disconnects the link anyway (read from the code; consistent with the base
  runs, which show no timeout); with patch 1 the leaked reference keeps the SCO
  link up after both sockets close. `abd93c85c8667` + `816fb1590a4c` rework this ownership.
- **With the two commits (`co02-ubuntu38/with816`, `96f7336a918f`; 816 alone fails 5 of 10 hunks,
  the pair applies with `-F0`):**
  - control (no series), SMP: Reconnect During Disconnect fails 3/3, Connect Twice fails 3/3,
    Reconnect After passes; full sco-tester 31/33 (the two bug cases);
  - series (`with816-series`, `ff077afb28e8`): Reconnect 2/2 and Connect Twice 1/1, 3 of 3 on UP
    and on SMP; full sco-tester 33/33 on UP; the parked race (`with816-park`) refused 3 of 3;
  - no leak timeout in any of these logs (`tmp/co02-hw/runs/u38w-*`, `tmp/co02-hw/progress-816.txt`).
  - KCSAN: a KCSAN kernel from this v7.0 tree stops at boot ("9p: Bad value for 'source'"), so the
    KCSAN coverage stays the bluetooth-next one.
- **Consequences:**
  - the laptop module must be Ubuntu + `abd93c85c8667` + `816fb1590a4c` + the series; the earlier
    `tmp/co02-hw/module/series` build (no prerequisites) must not be installed;
  - the Ubuntu backport request must carry the two commits under the series;
  - the upstream series is unaffected: every stable line with `e6720779ae61` has `816fb1590a4c`.
- **The operator decided (2026-10-23):** the cover letter says so, for distributions that have the
  kref change without `816fb1590a4c`: a paragraph after the stable one in `patch/v5/send/kernel/
  0000-cover-letter.patch` (and the send copy). The operator's reason: it tells whoever maintains
  Ubuntu's kernel that the combination is real, and shows that it was tested there.

## 2026-10-23 to 2026-10-25 — the run on the laptop
Results: `experiments/results-2026-10-24-hardware.md`; exhibits `EX-067` to `EX-073`.
- **Installed** on the operator's word: `module/full` (srcversion `0D084A056A9EEFB98E8F331`) in
  `updates/`, cold boot `257d1599…` at 2026-10-23 11:04:40 (`EX-071`).
- **Patch 2 on hardware:** the earbuds' three codec switches were refused (`ECONNABORTED`, the first
  connect and PipeWire's two retries), none falsely connected (`EX-067`, `EX-069`).
- **No regression:** MOMENTUM 4 2/2 and Shure AONIC 50 6/6 switches got a new link (`EX-070`); links
  closed (`EX-074`, by handle from the capture; `EX-073` is the kernel's weaker ledger); none of the
  searched kernel diagnostics on the boot (`EX-072`; the SCO error lines predate the series, `CO-20`).
- **Not exercised on hardware** (wording corrected 2026-10-26; it said "not reached"): patch 1's case
  (no second connect with a link up; reachable with a two-socket test program, not done) and patch
  3's race (it exists without instrumentation; the debug park only widens it). Patch 3's wait ran on
  each connect that led to a link (not on refused ones). Both are emulator-covered.
- **Found on the way, `U17`:** with a stream playing the earbuds were silent 5 s after a refused
  switch: PipeWire 1.0.5 retries at once and fails, WirePlumber suspends the failed nodes as idle
  5.004 s later and the stream still linked re-acquires the link (`EX-068`). Before the series no
  link followed at all: new test sounds 3, 2 and 26 s later were silent, and the next codec change
  ended it (`U7`; until 2026-10-26 this line said "silence until a restart", which the record does
  not show). The cover letter's
  PipeWire paragraph said the series "does not by itself make PipeWire's codec switch succeed",
  which the run refines: it succeeds after 5 s.
- **Cover letter:** the two paragraphs to change are drafted in `drafts/cover-letter-v6-hardware.txt`
  (the "not yet run on hardware" sentence and the PipeWire paragraph); not applied, pending the
  operator's reading. The code does not change, so the review verdicts and test results stand.
- **The deferral** (`patch/kernel-rfc-defer/`, 2026-10-21, on the old base) stays a separate RFC: a
  change of `connect()` semantics, never reviewed, never run on hardware; to be registered as its own
  contribution.

## 2026-10-26 — the reviews of `ee52148` (six reviewers; each point checked, not taken on authority)
All six agree with the narrow fix, with keeping the deferral separate (`CO-30`), and that a prose-only
change owes no new hardware run. Points, and what the check found:
- **The closure count (reviewer 4): right about the method, and the claim holds.** `sco-ledger.sh`
  counts the kernel's "opcode 0x0406 status" line. `hci_event_packet()` prints that line with status 0
  for any Disconnection Complete while a Disconnect is pending (`hci_event.c` l.7817–7822, `status`
  initialised to 0), with no handle. A failed Command Status prints its own status, and the ledger
  counted that as answered too. New `scripts/sco-link-closure.py` reads the capture by handle:
  36 links, 36 closed with Disconnection Complete status 0x00, all by the host, no failed setup, no
  gap (`EX-074`). Fixed in `sco-ledger.sh`: a nonzero status is `DISC-FAILED`, and the header says
  what the line proves. `EX-073`'s claim is corrected: it said "the HCI capture shows", but it reads
  the kernel log.
- **The BlueZ test's first socket on a framework timeout (reviewer 4): right that it can leak, wrong
  about where.** In the reviewer's example (the first completion withheld), the watch is still
  armed when teardown removes the controller, so it fires and `reconnect_end()` closes the socket:
  v5 closed 4/4. A stalled Connect Twice, timed out after the refused second connect, leaves it
  open: v5 2/2 open. v6 closes it in `test_post_teardown()`: 2/2 closed
  (`experiments/results-2026-10-26-bluez-v6.md`). Regression as v4: 18/18 focused, full 33/33 UP and
  SMP, base 31/33.
- **The 100 ms before "Reconnect After" connects again (reviewer 4): kept, and recorded as an
  unreproduced robustness risk, not dismissed.** It is a margin for the host to process the event
  the emulator has just sent. It passed every run on UP, SMP and KCSAN. If it were too short, the
  case would fail loudly, not pass falsely. Reviewer 4 holds, rightly, that a false failure on a
  correct kernel still costs maintainers time. A deterministic replacement would poll the host's
  connection list (HCIGETCONNLIST) until the old SCO connection is gone. That is not done: no flake
  has been seen, and it would add code to an already long test.
- **"Patch 3's window opens only with the debug change" (reviewers 2, 4): wrong, corrected.** The
  race exists without it; the park only widens it. **"Patches 1 and 3 not reached" (2, 3, 4, 5):
  corrected to "not exercised".** Patch 3's wait runs on every `hci_connect_sco()` call that gets
  past the earlier returns; on the laptop, on each connect that led to a link, not on the refused
  ones (first written as "every call"; corrected the same day, reviewer 4). Patch 1's case can be reached with a two-socket test program; not done, the operator's
  decision.
- **"Kernel log clean" / "no warning" (2, 3, 4, 5): narrowed** to the diagnostics searched, with the
  pre-existing SCO errors named. `EX-072`'s relevance no longer says an unbalanced hold "would show";
  an extra hold is silent, and `EX-074` covers that instead. "Same way as the unpatched boot" became
  "predate the series; rates not compared" (3, 4).
- **"Until the stream was restarted" (reviewer 6): wrong, corrected everywhere** (draft, results file,
  `EX-068`, `issues.md` U7/U17, this log). U7's record: new test sounds 3, 2 and 26 s after the
  failed switches got no link, and the next codec change ended the first silence.
- **Module wording, "with a stream playing", WirePlumber suspends nodes, the earlier run as
  historical (2, 3, 4, 6): taken** into revision 2 of the draft.
- **"`[PATCH v6]` must not be the first posting's subject" (5): already so.** The subjects are
  `[PATCH 0/3]` and `[PATCH BlueZ]`.
- **"Do not mail stable@vger.kernel.org" (5): not taken.** `stable-kernel-rules.rst` (l.70–77) expects
  `git send-email` to deliver to it, and warns only for unpublished vulnerabilities.
- **Upstream freshness (2, 3, 6): checked.** bluetooth-next `47d4d9f67e92` (+18 commits; none in the
  series' code); the series applies with `git am` at zero offset, `range-diff` identical, checkpatch
  0/0/0, builds with no warning. BlueZ master `a0580dad5655` (+4, none in sco-tester); the v6 test passes
  am/checkpatch/gitlint on it. The mainloop series (patchwork 14908123) has not landed.
  (`tmp/co02-fresh/`.) On the new head with the v6 test: Reconnect and Twice 6/6 runs, full
  sco-tester 33/33; the head alone 31/33 (During and Twice fail); no kernel report in any guest.
- **Reviewer 6's correction of their own 10-22 report** (Hitalo's sco-tester commit is not in
  master): noted; nothing here depended on it.

## 2026-10-26 — the v6 package, and two more review rounds on it
- **Second round** (on `f4d5d4e`): all six favourable. Taken after checking: links "in the HCI
  capture", "no HCI command timeout was logged", the log search named, the earlier reproduction as
  the capture shows it, the hardware paragraph split. Patch 3's wait runs only on connects that get
  past the earlier returns (reviewer 4; my "every call" was wrong). EX-074 was narrowed to links
  observed in the capture. The package was generated on `47d4d9f67e92` / `a0580dad5655` (`917568b`).
- **Third round** (on `917568b`): all six favourable on the mails; patches 1 to 3 and the BlueZ mail
  verified identical to what was reviewed. Taken:
  - the one ambiguous cover sentence (3, 4), regenerated by `remake-cover.sh` with patches 1 to 3
    checked byte-identical;
  - EX-073's "at hang-ups" and "no command timed out", narrowed, and the index regenerated (5);
  - in the optional hardware test, the guard now requires the link type `sco_connect()` looks up
    (6: a call link downgraded to plain SCO would have been missed, and the connect would have set
    up a new link); the socket is bound to the inspected adapter (4); and the README now says that
    the check-to-connect gap and same-handle reuse are settled by the capture, not the program
    (2, 3, 4).
- **The patch 1 hardware test was run on the operator's word** ("Okay, let's do the test"), at
  05:40 to 05:43 on the Shure in Hands-free mSBC, with the Sound panel's meter holding the link:
  3 of 3 EBUSY. The capture shows no setup or disconnect in the window (`EX-075`), one link
  through all three runs (`EX-076`), and voice data with no gap over 15.6 ms (`EX-077`). The cover's
  limits paragraph now says patch 1's case was run there; only patch 3's race stays emulator-only.
  Regenerated by `remake-cover.sh`, with patches 1 to 3 byte-identical.
- **v7 candidate** (`patch/v7-candidate/send/`): the five messages rewritten for quick reading from
  the six reviewers' proposals, each sentence checked; the code proven identical to every tested
  version by tool (`EX-078` to `EX-083`). Its README lists what was taken and what was not.
- **The BlueZ test's dependency:** its notes (v6 and v7) ask that it be applied after the kernel
  series is in bluetooth-next and link the series on lore, filled in at send time
  (`send-tools/`). Code unchanged, checked.

## 2026-10-27 — fresh full review requested
`REVIEW-REQUEST.md` rewritten for the current state: both packages (v7 candidate and v6), the
BlueZ dependency and the send tools, the laptop evidence and the code-identity proofs.

## 2026-10-27 — the reviews of `a2b6649` (six reviewers; each point checked)
All six find no kernel-code problem and would send v7 rather than v6. Points, and what the check
found:
- **`send.sh` hid a failed send (2, 3, 4, 5): right.** The last `echo` became the exit status.
  Reviewer 4's reproduction also showed `--check` passing when the BlueZ mail was missing (grep's
  error read as "no placeholder"): right. Fixed with the other guards they asked for: exact mail
  set, the package named in `send-tools/chosen-package`, mails tracked and committed, unknown
  options refused, a failed `git send-email` ends with its status. Tested without sending
  (`send-tools/README.md`).
- **The cover ID cannot be proven by the fill script (2, 3, 5): true, and inherent.** The lore
  check stays manual; both scripts now print what the link must show. Reviewer 6: a declined cover
  still uses up `-1-`; the procedure now says to quit and check lore if any answer is not `y`.
- **BlueZ master moved (2, 6):** `b0bf49270d44`, 7 commits, none in `tools/`, `emulator/`,
  `lib/` or `src/shared/` (what sco-tester is built from). The v7 test was rebased onto it:
  `change-code-compare.sh` against the tested `f480c93e9` and `patch-code-compare.py` against the
  previous mail: identical (patch-id `01df21faf4ee72b4`). bluetooth-next is unchanged
  (`47d4d9f67e92`).
- **"held back until the second socket has connected" (4): right.** The test releases the event
  once the second `connect()` has returned, whatever it returned (`sco-tester.c` l.1752–1782).
  Now "until the second connect() has returned".
- **The cover's test summary (4): right.** The unpatched base ran on UP and SMP, not KCSAN
  (`results-2026-10-22-v4.md`). Reworded.
- **mgmt-tester "otherwise the same results" (2, 4, 5; reviewer 6 on the README): right; my
  rejection of 26 October is withdrawn.** Two cases timed out intermittently, one also on the
  unpatched base (`results-2026-10-22-v2.md` l.52–57). The cover names both, briefly.
- **"without a gap" (4, 5): narrowed** to "SCO packets kept flowing in both directions"; EX-077
  measures intervals (longest 15.6 ms), not audio.
- **The cover's dashed underlines (6): right.** checkpatch reports BAD_COMMIT_SEPARATOR for each
  of the five; removed, the heading words kept. Reviewer 6's "v6's cover is 0/0/0" is not so:
  both covers draw checkpatch's commit-description error for bare hashes (6 each), a rule for
  commit messages; left as is.
- **`results-2026-10-24-hardware.md` (4): right on all four.** Narrowed "no setup failed / no gap"
  to EX-074's checks, "at hang-ups" to EX-073's, the historical "socket reported connected" to what
  the hardware record shows, and linked the 26 October patch 1 test.
- **The v7 README's "notes … v5's, verbatim" (3): right; corrected.**
- **Kept:** the 100 ms and 500 ms windows of the test (2), already recorded as an unreproduced
  risk; the test hooks assume one peer (3), and nothing claims more.
- **The operator chose v7** ("v7 is definitely the choice"): `send-tools/chosen-package` names
  `patch/v7-candidate/send`. v6 stays in the tree as a record, no longer maintained.

## 2026-10-27 — rechecks of `f553b9d` (six reviewers)
All six approve v7; no change to the mails is asked. Reviewer 6 has no further findings. Taken:
- `send.sh` checked four files in total, not one per number: two `0001` files and no `0002`
  passed (reviewers 3, 4; reviewer 4 reproduced it). Now one per number; tested.
- `chosen-package` could be changed locally without a commit (2, 5). Now it must be tracked and
  committed; tested.
- The lore-link pattern (2): reviewer 2 said `${AUTHOR//./\\.}` leaves the dots unescaped. On
  this bash it gives `\.` (checked inside double quotes, as in the script); changed to `[.]`
  anyway, which needs no escaping on any version.
- The v7 README and `REVIEW-REQUEST.md` still called v7 a candidate and the choice open (2, 3, 5):
  updated.
- The new-base BlueZ CI result (2, 3, 4, 5): recorded in `d27426a`, after their snapshot; no
  new finding.
- Not taken: checking the mails against a frozen manifest instead of the commit (3); the final
  dry run and the lore check cover it, as reviewer 3 says.

## 2026-10-27 — rechecks of `7768c9f` (six reviewers)
All six: ready to send, no findings on the mails. Reviewer 2 withdrew the regex point (the old
escaping was right). Reviewer 4 retested the guards in a committed scratch repository. Taken: the
`chosen-package` status check read a failed `git status` as clean (reviewer 3); it now refuses,
as the package check already did.

## 2026-10-27 — the list's CI bot, run here on v7 (the operator's request)
The operator asked to run as much of the receiving side's CI as possible before the send.
- **The bot's real source** is `bluez/action-ci` main. It was already cloned in
  `cache/action-ci-bluez`. `cache/action-ci` is the old 2024 fork; I had read it by mistake
  first, and it had also disabled `ci-local.sh`'s VerifyFixes. A first run built on that fork
  was stopped and is not evidence.
- **New tool** (`5fe6eca`): `scripts/bot-ci-local.sh`, which runs the bot's own check code in
  its own Docker image on the mails.
- **Results:** `experiments/results-2026-10-27-bot-ci.md`.
  - Kernel: every check the bot runs passes on v7, the 11 testers included. Tester verdicts are
    identical to the base, and the kernel logs are clean.
  - BlueZ: everything passes except CheckSmatch WARNING, which is upstream's (the same on master,
    and posted on unrelated patches).
- **Found on the way:** `BT-12`, ioctl-tester's duplicate case name, registered in STATUS.
- **Not reproducible here:** the `sashiko-nipa` reviewer, which needs a language-model service.

## 2026-10-27 — v7 reviewed against Sashiko's published rules (the operator's yes)
Sashiko's prompts (github.com/sashiko-dev/sashiko, cloned to `cache/sashiko`) were applied by an
outside reviewer to the four kernel mails and checked against `cache/co02-v7-kernel`: the
multi-stage review, severity, false-positive guide, locking, call stack, pointer guards, and the
Bluetooth subsystem notes for 7.3.
- **Taken, cover letter:** "A connect() arriving before the worker starts still cancels the
  pending disconnect and keeps the live link, as before" was wrong for the base. Checked here on
  `47d4d9f67e92`: with an existing link, `hci_conn_link()` returns it without a hold
  (`hci_conn.c:1872`), `__sco_chan_add()` takes the socket's hold (`sco.c:315`), and
  `sco_connect()` drops "ours" (`sco.c:412`), so the count is 0 again and `hci_conn_drop()`
  queues `disc_work` once more (`hci_core.h:1758`–1781, SCO delay 0). The hold that keeps the
  link is patch 1's. The sentence now reads "A connect() arriving before the worker starts
  cancels the pending disconnect with the hold patch 1 gives it, and keeps the live link.
  Patches 2 and 3 leave that case unchanged." Regenerated by `tmp/co02-v7prose/remake-cover.sh`;
  patches 1 to 3 byte-identical. Patch 3's own sentence ("as it does without this patch") is
  right and unchanged.
- **Not taken (code would change; the tested code stays):**
  - patch 2's comment says the aborting connection "stays BT_CONNECTED"; one aborted while
    still BT_CONNECT is rejected too. The check is right, only the comment is narrower (low);
  - patch 3 reads `abort_reason` plainly next to patch 2's `READ_ONCE()`. Dropped by the
    false-positive guide: after `cancel_delayed_work_sync()` and with the caller's hold, no
    writer can run. A human reviewer may ask; `READ_ONCE()` would cost nothing in a v2;
  - `hci_abort_conn()`'s own check of `abort_reason` (`hci_conn.c:3289`) stays a plain read
    beside patch 2's `WRITE_ONCE()`; the race is older than the series and benign (low).
- **Found, older than the series:** the `-ENOLINK` path of `hci_connect_sco()` drops a hold a
  new connection never had (`refcnt` starts at 0, `hci_conn.c:1159`), so a failed `kzalloc` of
  the link leaves the connection at -1, with no `disc_work` and still in the hash. Since
  `06149746e720`. Registered as `BT-13`.
- **Passed:** all four Fixes and reference commits exist with the quoted subjects and
  introduced what is claimed; hold balance on every return path after each patch; no deadlock
  from `cancel_delayed_work_sync()` under `hdev->lock` for SCO; each patch bisectable; the
  cover's diffstat.
- BlueZ mail: the placeholder is filled by `fill-bluez-link.sh` after the kernel send; the
  setup macro's `malloc` → `calloc` is not named in the message (low, not changed).

## 2026-10-27 — rechecks of `a021fca` (six reviewers)
All six: ready to send, no findings on the mails. All confirm that the cover correction is right,
and that patches 1 to 3 and the BlueZ mail are byte-identical to `7768c9f`. Reviewer 6 withdraws
their first review's reading of the pending-disconnect window: it is not "pre-existing and
unchanged". Patch 1 changes it from aborted to kept.
- **Correction to the entry above (reviewer 5):** "hold balance on every return path after each
  patch" is about the paths the series adds or changes. The `-ENOLINK` path that the series keeps
  is unbalanced, as that entry's own `BT-13` item says.
- **An answer ready if the maintainers ask (reviewer 6), not a change:** with the series, a
  connect() between the close and the start of the disconnect worker keeps the old link, with its
  old air parameters and no new Setup. The window runs from close() to the start of the worker.
  The worker is ordered and high-priority and is queued with no delay. PipeWire's gap is tens of
  milliseconds. Refusing that case too would mean testing `delayed_work_pending()` next to
  `abort_reason`, which could be offered as a follow-up. The cover already names the case.
- **Reviewer 4:** the bot's unchanged tester verdicts complement the sco-tester cases that fail
  without the series and pass with it. They do not replace them.
- **Tooling (reviewer 3):** `scripts/bot-ci-local.sh` printed the harness's not-PASS count but
  always exited 0. It is fixed separately (see the commit that follows this entry); the evidence
  was always read from the verdicts and comparisons, not from the exit status.
