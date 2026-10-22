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
