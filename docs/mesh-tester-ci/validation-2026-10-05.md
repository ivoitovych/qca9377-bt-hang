# Validation of 2026-10-05 — the posted mesh_tx cleanup (exact patch) and the BlueZ shared/mgmt leak fix

Started 2026-10-05 02:07 CEST (`date "+%F %T %Z"` → `2026-10-05 02:07:42 CEST`). Follows
`phase5-results.md` and `research-review-2026-10-05.md`. Everything runs inside qemu on freshly
built guest kernels; the host Bluetooth stack is not touched. Writes only under `cache/` and
`tmp/mesh-tester-ci/`. Nothing is sent, posted or mailed. Every claim is marked **quoted**
(command and output shown), **inferred** (derived from quoted material) or **not found**. Raw
logs: `tmp/mesh-tester-ci/logs/validation-2026-10-05/` with `SHA256SUMS`.

The other author's address is elided as `<address elided>` everywhere in this file.

## A1 — patch provenance and state (quoted)

- Patchwork REST (`curl … https://patchwork.kernel.org/api/1.3/patches/14831271/` →
  `cache/hui-peng-validation/patch-14831271.json`; summary by `pw-json-summary.py`):

      id:         14831271
      name:       Bluetooth: MGMT: fix mesh_tx leak on hci_cmd_sync_queue() failure
      date:       2026-09-19T11:54:36
      state:      new
      archived:   False
      delegate:   None
      submitter:  Hui Peng
      series:     [(1169247, '…', 1, …)]        (version 1; no other patch in the series)
      related:    []

- The mbox (the JSON's `mbox` URL, fetched with `curl` to
  `cache/hui-peng-validation/14831271.mbox`, sha256
  `a044131cc8093a97bf79de2163f09335b89ba58b6336b7b4c5c2f91ddedff8c2`). Headers (quoted, the
  address elided):

      From: Hui Peng <address elided>
      To: <Marcel Holtmann>, <Luiz Augusto von Dentz>          (addresses in the mbox)
      Cc: <lee@ kernel.org address; Lee Jones, inferred>, linux-bluetooth@vger.kernel.org, linux-kernel@vger.kernel.org
      Subject: [PATCH] Bluetooth: MGMT: fix mesh_tx leak on hci_cmd_sync_queue() failure
      Date: Sat, 19 Sep 2026 11:54:36 +0000
      Message-ID: <20260919115436.3998954-1-<address elided>>

  Trailers include `Fixes: b338d91703fa ("Bluetooth: Implement support for Mesh")` and
  `Signed-off-by: Hui Peng <address elided>`. Below the `---`: "the remaining half of
  … [PATCH v3] Bluetooth: MGMT: Fix mesh_tx Use-After-Free and leak in mesh_send() …, which I
  am withdrawing" and "Found by code inspection … I have not reproduced the leak on its own;
  hci_cmd_sync_queue() only fails on -ENOMEM or when the controller is going down, which I did
  not manage to induce reliably. Compile tested only." The claims the commit message makes
  (quoted): the entry "stays on hdev->mesh_pending even though the command has been failed back
  to userspace with MGMT_STATUS_FAILED … until then it counts against the MESH_HANDLES_MAX
  budget enforced by send_count(), so repeated failures eventually make MGMT_OP_MESH_SEND
  return MGMT_STATUS_BUSY." The diff (quoted in full):

      diff --git a/net/bluetooth/mgmt.c b/net/bluetooth/mgmt.c
      index 9d3de5a..8991aa8 100644
      --- a/net/bluetooth/mgmt.c
      +++ b/net/bluetooth/mgmt.c
      @@ -2543,10 +2543,8 @@ static int mesh_send(struct sock *sk, struct hci_dev *hdev, void *data, u16 len)
       		err = mgmt_cmd_status(sk, hdev->id, MGMT_OP_MESH_SEND,
       				      MGMT_STATUS_FAILED);
       
      -		if (mesh_tx) {
      -			if (sending)
      -				mgmt_mesh_remove(mesh_tx);
      -		}
      +		if (mesh_tx)
      +			mgmt_mesh_remove(mesh_tx);
       	} else {
       		hci_dev_set_flag(hdev, HCI_MESH_SENDING);

- Replies: patchwork comments API (`…/patches/14831271/comments/` →
  `comments-14831271.json`) → `comments count: 1`, comment `27219612 2026-09-19T15:33:03`,
  "This is automated email and please do not reply to this email!" — the CI bot's result mail
  only, no human reply. Checks (`checks-14831271.json`, last state per context):
  `BuildKernel:success BuildKernel32:success CheckAllWarning:success CheckKernelLLVM:success
  CheckPatch:success CheckSparse:success GitLint:fail IncrementalBuild:success
  SubjectPrefix:success TestRunnerSetup:success TestRunner_mesh-tester:fail
  TestRunner_mgmt-tester:fail VerifyFixes:success VerifySignedoff:success pre-ci_am:success`
  (GitLint: B3 hard tabs in the quoted code of the message).
- lkml mirror (`curl … https://lkml.iu.edu/2609.2/10074.html` →
  `cache/hui-peng-validation/lkml-2609.2-10074.html`): same subject, `Date: Sat Sep 19 2026 -
  07:54:49 EST`, the `Fixes:` and "Compile tested only."; the page has "Next message" /
  "Previous message" links and **no "Next in thread" / reply link** (`grep -n -i -E
  "Next in thread|Reply"` → only line 43/149 `Next message: … Hui Peng: "Re: [PATCH v3] …"`,
  which is his withdrawal note on the v3 thread, not a reply to this patch).
- No v2: `pw-query-v.sh submitter-187565 "project=bluetooth&submitter=187565&since=2026-09-01T00:00:00"`
  → 10 hits; the mesh ones are `14831271 new … fix mesh_tx leak on hci_cmd_sync_queue()
  failure` and `14831256 new [v3] Bluetooth: MGMT: Fix mesh_tx Use-After-Free and leak in
  mesh_send()` (the withdrawn one); nothing later from him on mesh. `… q-mesh_tx
  "project=bluetooth&q=mesh_tx&since=2026-09-01T00:00:00"` → `hits: 2`, the same two.
- Trees: `git -C cache/linux fetch bluetooth` → no output; `… fetch bluetooth-next` → no
  output. `rev-parse bluetooth/master bluetooth-next/master` →
  `08e90633377f1b2567ab5ad6810b74c552246a07`, `036d4119079a757c9d1b4d35205c7c467f0018fb`
  (unchanged since phase 5; `log -1 --format="%h %ci %s" bluetooth-next/master` → `036d4119079a
  2026-10-02 12:26:49 -0400 Bluetooth: btusb: add ASUS 0b05:1825 to QCA Rome quirks`).
  `git -C cache/linux log --oneline -F --grep="mesh_tx leak" bluetooth-next/master` → nothing;
  the same on `bluetooth/master` → nothing. `git grep -n -A3 "if (mesh_tx) {"
  bluetooth-next/master -- net/bluetooth/mgmt.c` → `mgmt.c:2547: if (mesh_tx) {` /
  `2548: if (sending)` / `2549: mgmt_mesh_remove(mesh_tx);` — the unfixed error path.
- **State (inferred from the above): posted once (v1), `new`, no delegate, no human reply, no
  v2, not applied to bluetooth or bluetooth-next as of 2026-10-05 02:15 CEST.** The preimage
  blob of the diff, `9d3de5a`, is not the current `mgmt.c` of either tree (`rev-parse
  bluetooth-next/master:net/bluetooth/mgmt.c` → `aea3482e…`), so the hunk is 4 lines away
  from its recorded position (`@@ -2543` vs line 2547).
- Seen in passing (not part of this validation, recorded for the operator): `pw-query-v.sh
  q-mesh "project=bluetooth&q=mesh&since=2026-09-15T00:00:00"` → `2026-10-03T08:12 14864878
  new Jiale Yao Bluetooth: mgmt: handle mesh send completion queue failure` — another author's
  patch on the same defect as series v3 4/5 (`mesh_send_done()`'s `hci_cmd_sync_queue()`
  failure leaves `HCI_MESH_SENDING` set); its diff calls `mesh_send_done_sync()` and
  `mesh_next()` directly when the queueing fails. Raw JSON
  `logs/validation-2026-10-05/patchwork-patch-14864878.json`. See Open.

## A2 — apply (quoted)

- `cache/mesh-guest`: `git fetch bluetooth-next`, `git fetch bluetooth` → no output; tips
  `036d4119079a757c9d1b4d35205c7c467f0018fb` (bluetooth-next/master) and
  `08e90633377f1b2567ab5ad6810b74c552246a07` (bluetooth/master).
- Control: `git branch control/bluetooth-next-for-hui-peng-validation-2026-10-05 036d4119079a…`
  (the tip itself, nothing applied).
- Exact patch: `git checkout -b validate/hui-peng-mesh-tx-leak-on-bluetooth-next-2026-10-05
  036d4119079a…`, then `git am cache/hui-peng-validation/14831271.mbox` → `Applying:
  Bluetooth: MGMT: fix mesh_tx leak on hci_cmd_sync_queue() failure` (no fuzz message, no
  conflict). Commit `19fdd346e00ce3f12a7eae0cc1444992a95e94a1`; `git log -1 --format=…` →
  `Author: Hui Peng`, `AuthorDate: Sat Sep 19 11:54:36 2026 +0000`, committer the local user;
  the message is the posted one verbatim (every trailer included),
  `net/bluetooth/mgmt.c | 6 ++----`.
- Same change as posted: `patch-id-compare.sh cache/mesh-guest 19fdd346e00c… 14831271.mbox` →
  `commit …: df5568b26335abd1bbeb198e91bc58feb182cf3d` and `mbox …:
  df5568b26335abd1bbeb198e91bc58feb182cf3d` (`git patch-id --stable` of both).
- **The patch applies unchanged on the current bluetooth-next tip, so no older base and no
  adapted variant were needed** (the reviewer's addition 1: nothing labelled "adapted" exists).
  The only difference to the posting is the line position (`@@ -2543` in the posting,
  `mgmt.c:2547` in the tree; `git am` applies hunks at an offset without fuzz).
- Under series v3 (§A6): `git checkout -b
  validate/hui-peng-mesh-tx-leak-then-series-v3-on-bluetooth-master-2026-10-05 08e90633377f…`,
  `git am …14831271.mbox` → `Applying: …` (clean on bluetooth/master too), then `git
  cherry-pick 08e90633377f..71a4243699c8` → the five series commits, each `Auto-merging
  net/bluetooth/mgmt.c` without conflict, tip `d532f88c0961`. `git diff --stat 64bd2d50f5de
  d532f88c0961` → no output: **the resulting tree is byte-identical to phase 5's
  `scratch/with-upstream-leak-fix-on-71a4243699c8` (series + local equivalent)**; `git diff
  71a4243699c8 d532f88c0961` → exactly the posted hunk.

## A3 — builds (quoted)

`build-chain-validation.sh` (log `logs/validation-2026-10-05/build-chain-validation.log`,
02:41:19 to 02:43:25), each image `doc/tester.config` of the BlueZ tree +
`frag-fault.config`, `make olddefconfig`, `make -j16`, toolchain `gcc (Ubuntu
13.3.0-6ubuntu2~24.04.1) 13.3.0` for all three; each build log ends `Kernel:
arch/x86/boot/bzImage is ready`:

| image | commit | config sha256 | bzImage sha256 |
|---|---|---|---|
| `bzImage-val-btnext-control` | `036d4119079a` (bluetooth-next tip) | `d9d228fed92a835d…6a59` | `a50b168252b8…bcec` |
| `bzImage-val-btnext-hui` | `19fdd346e00c` = `036d4119079a` + the posted patch | `d9d228fed92a835d…6a59` (identical) | `a37192f09c99…064d` |
| `bzImage-val-hui-series` | `d532f88c0961` = `08e90633377f` + posted patch + series v3 | `798f78ed8a44…14f4` | `d7ad3623b83b…214a` |

All three configs: `CONFIG_KASAN=y`, `CONFIG_PROVE_LOCKING=y`, `CONFIG_FAULT_INJECTION=y`,
`CONFIG_FAILSLAB=y`, `CONFIG_FAULT_INJECTION_DEBUG_FS=y` (grep in the chain log). The guests
report `Linux version 7.3.0-rc2-00486-g036d4119079a` (control) and
`7.3.0-rc2-00487-g19fdd346e00c` (patched) — **control and patched are built from the same base
with the same config and toolchain and differ only by the posted patch** (reviewer's
addition 2). Full config hashes: control and patched
`d9d228fed92a835d8cc16361e57d228c437f358c381c88195dcecfaf891a6d59`.

## A4 — targeted results (quoted)

### What the existing "rejected start" cases mean on plain bluetooth-next (inferred from the code, then confirmed)

`mesh_tx_rejected_start` (`tools/mesh-tester.c`, phase-5 branch) asserts, besides "Read Mesh
Features lists only request 2's handle", the series' tear-down behaviour: `.mesh_tx_stops = 2`
and `.mesh_tx_cmplt_stops = mesh_tx_stops_1_2` (each completion must follow a tear-down of the
mesh set, which only series 2/5 issues on extended advertising). So on a kernel without the
series these cases cannot isolate the posted fix. Confirmed by the runs
(`run-val-control-rejected-start.log`, `run-val-hui-rejected-start.log`, try1 02:44:04 to 02:44:27;
the same in `-t2`):

- control, both variants: `Read Mesh Features at +478 ms: 2 of 3 handles pending` →
  `Expected only handle 7 (request 2) to be pending` → failed (the leak);
- patched: legacy **passes** (`Read Mesh Features at +… 1 of 3 … handle 7`, then every check);
  Ext Adv passes the Read Mesh Features check (`1 of 3 handles pending / handle 7`) and then
  fails on `Handle 7 completed after 0 tear-downs, expected 1` — the series-only tear-down
  expectation, not the posted fix (`case-trace.sh … "Mesh - Send queue - rejected start - Ext
  Adv"`, lines 2081-2113).

### The new case: "Mesh - Send - failed start" (legacy) and "… - Ext Adv"

Added to the phase-5 BlueZ branch as a new commit (§A4-commit below), runs on any kernel with
fault injection, asserts nothing about tear-downs. Method: `/proc/self/fail-nth` (failslab with
`ignore-gfp-wait=0`, `cache-filter=0`) is set to n immediately before a Mesh Send written with
`mgmt_send_nowait()`, then reset to 0; n is raised from 1 until a send is answered Failed **and**
the next accepted send's handle skips one (the failed request was added and given a handle, so
the failing allocation was the one in `hci_cmd_sync_queue()`). Packet 0 is the failing
request's packet, packets 1-4 are distinct packets of accepted requests; an HCI post-command
hook on the emulator records every LE Set (Extended) Advertising Data that carries one of the
packets ("load") and every enable of the mesh set ("start"). Assertions, each counted
separately, verdict at the end:

- (a) after every failure, Read Mesh Features lists no handle (all requests come from the one
  socket whose handles that command lists);
- (b) packet 0 is never loaded or started after the first failure, through to the end;
- (c) no Mesh Packet Complete for any handle that was not accepted;
- (d) right after the first failure, `max_handles` (3) Mesh Sends back to back are all accepted,
  each started once and completed once;
- (e) `max_handles + 2` (5) further failing sends are all answered Failed, none Busy (once the
  last read shows all handles in use, packet 0 is sent without fail-nth, because the kernel then
  answers Busy before reaching the failing allocation);
- (f) a following Mesh Send (packet 4) is accepted, started once and completed once; its handle
  must equal the last accepted handle + the number of failed starts + 1 (so every failing send
  really hit `hci_cmd_sync_queue()`).

Tester correction during this step (recorded, try1 logs kept): in try1, once the control kernel
had all handles in use, fail-nth 6 hit the socket write instead (`mgmt: … send_request() write
failed: Cannot allocate memory`, `run-val-control-failed-start-1.log:1327`), which the library
reports as `Failed (0x03)` — that masked the kernel's Busy and made (e) PASS on control. try2
detects a write failure (answer inside `mgmt_send_nowait()`) and sends without fail-nth when
the handles are exhausted. The verdicts below are try2 (`*-t2.log`).

### Table (quoted; try2, `runs-targeted-t2.log` 02:45:46 to 02:46:25; 3 runs × 2 variants per image)

| assertion | control `036d4119079a` | exact patch `19fdd346e00c` |
|---|---|---|
| fault point | `fail-nth 6 fails the start: packet 0 was given handle 6 and answered Failed, packet 1 got handle 7` | the same line |
| (a) not listed | **FAIL** (6 violations): reads `1, 0, 1, 2, 3, 3, 3` handles pending | **PASS**: 8 reads, all `0 handles pending` |
| (b) packet 0 never loaded/started | PASS (`packet 0: … 0 loads, 0 starts`) | PASS (same) |
| (c) no completion for a failed handle | **FAIL**: `Handle 6 completed although its Mesh Send was answered Failed` | **PASS** |
| (d) capacity after the first failure | **FAIL** (2): `Mesh Send of packet 3 … Busy (0x0a)` with 2 of 3 handles used by accepted requests; `packet 1: handle 7, … 2 starts, 1 completions` (transmitted twice) | **PASS**: handles 7, 8, 9 accepted, each `1 loads, 1 starts, 1 completions` |
| (e) 5 more failures, never Busy | **FAIL** (2): `3 failed and 2 answered Busy` | **PASS**: `5 failed and 0 answered Busy` |
| (f) next request | **FAIL**: `Mesh Send of packet 4 … Busy (0x0a)` | **PASS**: `handle 15` (= 9 + 5 + 1), `1 loads, 1 starts, 1 completions` |
| case verdict, legacy / Ext Adv, 3 runs | Failed ×3 / Failed ×3 | Passed ×3 / Passed ×3 |
| `Mesh - Send queue - rejected start` / `- Ext Adv` | Failed / Failed | Passed / Failed (tear-down expectation only) |

(Excerpts: `grep -a -E "Violates|Busy|PASS|FAIL|Failed start:|packet [0-4]: handle|Read Mesh
Features [0-9]+:"` on `run-val-control-failed-start-1-t2.log` and
`run-val-hui-failed-start-1-t2.log`; legacy and Ext Adv print identical counts except the loads of
packet 1 — legacy `0 loads` because the kernel does not reload advertising data the controller
already holds, Ext Adv `1 loads` (patched) / `2 loads` (control).) The control behaviour of (c)/(d) is the
mechanism inferred from the code: the leaked entry is the oldest on `mesh_pending`, so the
done work of the next transmission completes it (`mesh_send_done_sync()` →
`mgmt_mesh_next(hdev, NULL)`) and `mesh_next()` then starts the still-pending request again.

Not done for (a): no kprobe or debugfs read of `mesh_pending` (the images have no
`CONFIG_KPROBE_EVENTS`); Read Mesh Features lists exactly the `mesh_pending` entries of the
calling socket (`mesh_features()` → `mgmt_mesh_foreach(hdev, send_count, &rp, sk)`), and every
request in the case comes from that socket. "References" in the reviewer's (e) are inferred,
not measured: each entry holds `sock_hold(sk)` (`mgmt_util.c:426`) and is released only with
the entry (`mgmt_mesh_remove()` → `sock_put()`), so no entry left means no reference left.

### A4-commit — the tester commit (quoted)

`cache/bluez-upstream`, branch `mesh-tester/phase5-lifecycle-tests-2026-10-03`: `git log
--oneline -2` → `8488ba994 tools/mesh-tester: Add failed start tests`, `7c62b76f4
tools/mesh-tester: Test mesh advertising lifecycle`. Message: `tmp/mesh-tester-ci/msg-bluez-failed-start.txt`
(BlueZ style, no Signed-off-by). The commit adds `mesh_tx_fault_open()` (split out of
`mesh_tx_probe_start()`, no behaviour change for the old cases), `struct mesh_fail`,
`test_mesh_fail()` with its own HCI hook, and the two registrations. History of the commit:
`1ece02bba` (kept on `keep/mesh-tester-validation-1ece02bba`) is the code the try2 runs and
the full/series runs used (built as `bluez-make-testers-validation-try2.log`, 0 warnings);
BlueZ checkpatch then reported `WARNING:LONG_LINE: line length of 81 exceeds 80 columns` at
`tools/mesh-tester.c:4143`; the amend wraps that one line (`git diff
keep/mesh-tester-validation-1ece02bba HEAD` → the single `tester_warn("Expected handle %u",`
line split in two). Rebuilt (`…-try3.log`, `grep -c -E "warning|error"` → `0`) and run once
more on both kernels (`runs-extra.log`, `val-control-failed-start-t3` 02:54:05 to 02:54:10,
`val-hui-failed-start-t3` 02:54:10 to 02:54:16): same verdicts. Lint of the export
(`standalone/tester-failed-start-v2/0001-tools-mesh-tester-Add-failed-start-tests.patch`,
`bluez-lint.sh`): `0 error(s), 0 warning(s), 0 check(s)`, 884 lines; gitlint `PASS no
violations`.

Stability (`assertion-fingerprint.py` over the assertion lines, load counts removed):
`967b91416fc3` for all five control logs (`-1/-2/-3-t2`, `-t3`, `mesh-full`), `42c84fe58d06`
for all five patched logs — identical results in five runs per kernel, both variants.

## A5 — full-suite comparison, control vs exact patch (quoted)

`runs-validation.sh full` (`runs-full.log`), tester `cache/bluez-upstream` (ASAN; phase-5 branch
plus the new case, 57 mesh cases), one VM at a time; `compare-verdicts.py <control> <patched>`:

| run | start-end | control `036d4119079a` | exact patch `19fdd346e00c` |
|---|---|---|---|
| mesh-tester, all 57 | 02:46:48 to 02:47:13 / 02:47:14 to 02:47:41 | `Total: 57, Passed: 18, Failed: 39` | `Total: 57, Passed: 21, Failed: 36` |
| mgmt-tester, all 503 | 02:47:41 to 02:48:34 / 02:48:34 to 02:49:28 | `Total: 503, Passed: 502, Failed: 1` | `Total: 503, Passed: 502, Failed: 1` |

- mesh-tester: `cases with different verdicts: 3` — `Mesh - Send - failed start` (Failed →
  Passed), `… - Ext Adv` (Failed → Passed), `Mesh - Send queue - rejected start` (Failed →
  Passed). Every other case has the same verdict on both: the 4 pre-existing upstream `Mesh -
  Send cancel - 1/2[ - Ext Adv]` `Timed out` (the bot's standing failure, phase 4/5), and the 32
  phase-5 lifecycle cases that assert series behaviour (power, held commands, receiver,
  tear-down counts) — expected to fail without the series, identical on both.
- mgmt-tester: `cases with different verdicts: 0`, `not-passed sets identical: True (A 1, B 1)`;
  the one failure on both is `Pairing Acceptor - LE Security Level Changed` (a tester
  expectation; BlueZ master has since `7a55a67cb mgmt-tester: Fix LE Security Level Changed
  expected encryption type` — inferred from the subject, not run here with this tester). Both
  runs: `tx timeout: 2 … command 0x0405 tx timeout` (mgmt-tester's own timeout cases, as in
  phase 5) and `SUMMARY: AddressSanitizer: 120 byte(s) leaked in 5 allocation(s).` (the
  emulator hook list, phase-4 Open 6) — identical on both.
- No LeakSanitizer report in either mesh-tester run (`grep -c -a -E "LeakSanitizer|leaked in"`
  → `0`, `0`).

**BlueZ master's own testers** (`4dc15be8e`, built in `cache/bluez-standalone-mgmt-leak`, ASAN,
binaries `standalone/bin-unpatched/`), the same binaries on both kernels — the comparison the
reply cites:

| run | control `036d4119079a` | exact patch `19fdd346e00c` | compare-verdicts |
|---|---|---|---|
| mesh-tester (10 cases) | `val-B-mesh-unpatched` 02:52:31 to 02:52:38: `Total: 10, Passed: 8, Failed: 2` | `val-B-mesh-upstream-on-hui-kernel` 02:53:05 to 02:53:12: `Total: 10, Passed: 8, Failed: 2` | `cases with different verdicts: 0`, `not-passed sets identical: True (A 2, B 2)` (`Mesh - Send cancel - 1`, `- 2` `Timed out` on both) |
| mgmt-tester (503) | `val-B-mgmt-unpatched` 02:50:44 to 02:51:37: `Total: 503, Passed: 503` | `val-B-mgmt-upstream-on-hui-kernel` 02:53:12 to 02:54:05: `Total: 503, Passed: 503` | `cases with different verdicts: 0` |

## A6 — the exact patch under series v3 (quoted)

Image `bzImage-val-hui-series` (`d532f88c0961` = `08e90633377f` + the posted patch by `git am` +
the five series v3 commits cherry-picked; tree identical to phase 5's `64bd2d50f5de`, §A2) and,
for the differential, phase 5's `bzImage-v3-final` (`71a4243699c8`, series alone,
`frag-fault.config`). `runs-validation.sh series` (`runs-series.log`, 02:49:28 to 02:50:43):

| run | series + exact patch `d532f88c0961` | series alone `71a4243699c8` |
|---|---|---|
| failed start, legacy + Ext, ×3 | `Total: 2, Passed: 2` ×3 (02:49:28 to 02:49:45) | `Total: 2, Passed: 0, Failed: 2` ×3 (02:49:49 to 02:50:05) |
| rejected start, legacy + Ext | `Total: 2, Passed: 2` (02:49:45 to 02:49:49) | `Total: 2, Passed: 0, Failed: 2` (02:50:05 to 02:50:07) |
| full mesh-tester (57) | **`Total: 57, Passed: 57 (100.0%)`** (02:50:07 to 02:50:43) | — (phase 5: 53/55, the two rejected-start cases) |

- **The phase-5 results with the local equivalent hold with the exact patch**: phase 5 had
  55/55 on `64bd2d50f5de`; the exact patch gives 57/57 on a byte-identical tree (55 + the two
  new cases).
- Series alone, the new case (`case-trace.sh run-val-series-alone-failed-start-1.log "Mesh -
  Send - failed start"`): all six assertions fail, and **(b) fails only here**: `Mesh Packet
  Complete handle 7 at +1082 ms`, then `Packet 0 loaded into the mesh set at +1085 ms`, `Mesh
  set started with packet 0 at +1092 ms`, `Mesh Packet Complete handle 6 at +1174 ms` / `Handle
  6 completed although its Mesh Send was answered Failed`. Inferred: with the series'
  hand-over (`mesh_next()` starts the oldest pending entry), the request answered Failed is
  put on air. Without the series (control, §A4) it is only completed, never transmitted. This
  makes the posted cleanup a hard prerequisite of series v3, as its cover already says.

## A7 — splats (quoted)

`splat-all-validation.sh` (`splat-check.sh` on every `logs/validation-2026-10-05/run-*.log`,
output `splat-summary.txt`, 37 logs): every mesh-tester log `clean` (none of `BUG:`, `WARNING:`,
KASAN, KCSAN, lockdep circular/recursive/other, hung task, sleep in atomic, Oops/GPF, `tx
timeout`, kmemleak); the only kernel dumps are the `FAULT_INJECTION: forcing a failure.` stacks
of the fault points (14 per control failed-start run, 18 per patched one — the patched run
injects 5 more failures that reach the allocation; 8 per rejected-start run). The six
mgmt-tester logs each report `tx timeout: 2 … command 0x0405 tx timeout` — mgmt-tester's own
connection-timeout cases, on control and patched alike and in phase 5 (positive control of the
checker). No KASAN, lockdep or WARNING report on any of the four kernels.

## A8 — the draft reply (not sent)

`cache/hui-peng-validation/reply-draft.txt` (under `cache/`, not committed; it carries the
full Message-ID and the addresses). Headers: From the operator, To the author, Cc the two
maintainers and linux-bluetooth (as instructed), `Subject: Re: [PATCH] Bluetooth: MGMT: fix
mesh_tx leak on hci_cmd_sync_queue() failure` (folded), `In-Reply-To:` / `References:` his
Message-ID. Body: base commit and config, the control, the fault-injection method in two
sentences, without/with results (from §A4, five runs each), "In neither case was the failed
packet ever sent to the controller", no kernel reports, BlueZ master's mgmt-tester (503) and
mesh-tester (10) identical per case on both kernels (§A5), then `Tested-by: Iaroslav Voitovych
<yaroslav.voytovych@gmail.com>`. Nothing about series v3: a sentence about an unposted series
gives the author and maintainers nothing to act on, so it was left out. `scripts/mail-lint.sh
cache/hui-peng-validation/reply-draft.txt` → `clean: headers present, body within 72 columns,
ASCII, no trailing whitespace` (the script accepts a plain mail file with headers).

Every statement in the body maps to a quoted result: base and config §A3; n = 6 §A4 (`fail-nth
6 fails the start`); "lists the failed handle" (a) control; "gets a Mesh Packet Complete … sent
a second time" (c) control and `packet 1: handle 7, 2 starts`; "third gets Busy" (d) control;
"first three fail and stay listed (1, 2, 3 handles), the other two and the next valid Mesh Send
get Busy" (e)/(f) control; with the patch (a)-(f) PASS; "neither case … sent" (b) PASS on both;
the testers §A5.

## B1 — the standalone branch and the exact commit tested (quoted)

- `git -C cache/bluez-upstream fetch origin` → `ae69dcddd..4dc15be8e  master -> origin/master`
  (7 new commits, `git log --oneline ae69dcddd..origin/master`, among them `7a55a67cb
  mgmt-tester: Fix LE Security Level Changed expected encryption type`; none touches
  `src/shared/mgmt.c`).
- To keep the phase-5 tester binary in `cache/bluez-upstream` untouched, the branch lives in a
  new worktree: `git -C cache/bluez-upstream worktree add -b
  standalone/shared-mgmt-notify-leak-2026-10-05 cache/bluez-standalone-mgmt-leak origin/master`
  → `HEAD is now at 4dc15be8e client: Print discoverable broadcasters in red`.
- `git cherry-pick 2a32642aa9787604a702eb0d41814804116f7142` (the phase-5 commit "shared/mgmt:
  Fix leak when unregistering from a notify callback") → `[standalone/… 9c7873766] …`, `1 file
  changed, 16 insertions(+), 7 deletions(-)`, no conflict. **It applies to current BlueZ
  master.**
- The message was then rewritten for a standalone patch (§B5): `git commit --amend -F
  standalone/msg-shared-mgmt-leak.txt` → **`bdd3acd51 shared/mgmt: Fix notify leak in
  mgmt_unregister()`**; `git diff --stat 9c7873766 bdd3acd51` → no output (code unchanged; the
  plain cherry-pick is kept on `keep/standalone-shared-mgmt-leak-9c7873766`). The binaries
  tested were built from `9c7873766`, i.e. the same tree as `bdd3acd51`.
- **Exact BlueZ objects tested:** unpatched = `4dc15be8ee3f7422d447087f1893d215575cb2c8`
  (BlueZ master), patched = `9c78737664affe435fda94263e2202169ba4735d` (tree identical to the
  exported `bdd3acd51`). Built by `build-bluez-standalone.sh` (`libtoolize`, then
  `./bootstrap-configure --disable-lsan` as the bot, then `make tools/mesh-tester
  tools/mgmt-tester`): `bluez-make-testers-standalone-unpatched.log` and `-patched.log`, `grep
  -c -E 'warning|error'` → `0` and `0`; the patched build recompiled `CC
  src/shared/libshared_glib_la-mgmt.lo`. Binary sha256 (`standalone/bin-*/`): mgmt-tester
  unpatched `ec7ccdd6…05ae`, patched `76dfffd1…d11d`; `grep -c -a __asan_init` → `3`
  (instrumented). The first configure attempt failed (`configure.ac:36: error: required file
  './ltmain.sh' not found`), fixed by running `libtoolize` first as in phase 2.

## B2 — prior art (quoted / not found)

- `git log --oneline --since=2026-09-01 origin/master -- src/shared/mgmt.c src/shared/mgmt.h`
  → nothing; last changes to `src/shared/mgmt.c`: `63b82054c 2026-02-27`, `61f25f9aa
  2026-02-27 shared/mgmt: Add mgmt_parse_io_capability`.
- `git log --oneline -i --since=2026-01-01 -E --grep="shared/mgmt|notify.*leak|leak.*notify|mgmt_unregister"
  origin/master` → `a734b0605 adapter: Fix crash on short start discovery reply`, `61f25f9aa
  shared/mgmt: Add mgmt_parse_io_capability`, `024b148d7 device: fix memory leak` — none is this
  fix.
- `git grep -n -A22 "^bool mgmt_unregister(struct mgmt \*mgmt, unsigned int id)" origin/master --
  src/shared/mgmt.c` → still `notify = queue_remove_if(…)` then `notify->removed = true;` while
  in_notify: **the defect is present on master**.
- Patchwork, project bluetooth (`pw-query-v.sh`, raw JSON in `logs/validation-2026-10-05/`):
  `q=shared/mgmt since 2026-09-01` → `hits: 0` (positive control `since 2026-01-01` → `hits: 1`,
  `14442088 accepted … shared/mgmt: Add mgmt_parse_io_capability`); `q=mgmt_unregister since
  2026-01-01` → `hits: 0`; `q=notify since 2026-09-01` → 8 hits, all `shared/gatt-client`,
  `shared/gatt-db` or `shared/mcp`; `q=leak since 2026-09-01` → 16 hits, none in `src/shared/mgmt.c`
  (obexd, kernel drivers, MGMT mesh). **Not found: no earlier fix, upstream or posted.**

## B3 — the leak before and after; ordinary behaviour (quoted)

`runs-bluez-standalone.sh` (`runs-bluez-standalone.log`), qemu KVM, guest kernel
`bzImage-val-btnext-control` (`036d4119079a`) for all four runs, VM launcher
`cache/bluez-upstream/tools/test-runner`:

| run | BlueZ | result | LeakSanitizer |
|---|---|---|---|
| `val-B-mgmt-unpatched` 02:50:44 to 02:51:37 | `4dc15be8e` | `Total: 503, Passed: 503 (100.0%), Failed: 0` | `Direct leak of 9080 byte(s) in 227 object(s) allocated from: #0 … in malloc … #1 … in util_malloc src/shared/util.c:46`; `Direct leak of 120 byte(s) in 5 object(s) … in btdev_add_hook emulator/btdev.c:8916`; `SUMMARY: AddressSanitizer: 9200 byte(s) leaked in 232 allocation(s).` |
| `val-B-mgmt-patched` 02:51:38 to 02:52:31 | `9c7873766` | `Total: 503, Passed: 503 (100.0%), Failed: 0` | only `Direct leak of 120 byte(s) in 5 object(s) … btdev_add_hook`; `SUMMARY: AddressSanitizer: 120 byte(s) leaked in 5 allocation(s).` |
| `val-B-mesh-unpatched` 02:52:31 to 02:52:38 | `4dc15be8e` | `Total: 10, Passed: 8, Failed: 2` (`Mesh - Send cancel - 1/2` `Timed out`) | `Direct leak of 120 byte(s) in 3 object(s) … util_malloc src/shared/util.c:46`; `SUMMARY: AddressSanitizer: 120 byte(s) leaked in 3 allocation(s).` |
| `val-B-mesh-patched` 02:52:38 to 02:52:44 | `9c7873766` | `Total: 10, Passed: 8, Failed: 2` (same two) | none (`grep -c -a -E "LeakSanitizer|leaked in"` → `0`) |

- **Leak reproduced before** (LeakSanitizer output quoted above): 227 × 40 B in mgmt-tester,
  3 × 40 B in mesh-tester. **No leak after**: the 40-byte `util_malloc` records are gone from
  both; what remains in mgmt-tester is the unrelated emulator hook list (`btdev_add_hook`,
  phase-4 Open 6), identical before and after.
- Attribution (inferred): LeakSanitizer printed only two frames, so the records do not name
  `mgmt_register()`; they are 40 bytes each, the size of `struct mgmt_notify` (phase 5 §D0.2),
  and the only code difference between the two binaries is `mgmt_unregister()`. Phase 4/5 had
  225 objects with an older mgmt-tester; 227 now.
- **Ordinary behaviour unchanged**: `compare-verdicts.py` unpatched vs patched — mgmt-tester
  `A: 503 cases Passed=503`, `B: 503 cases Passed=503`, `cases with different verdicts: 0`;
  mesh-tester `A: 10 cases Passed=8 Timed out=2`, `B: … the same`, `cases with different
  verdicts: 0`, `not-passed sets identical: True`. Kernel side: `splat-summary.txt` → mesh logs
  `clean`, mgmt logs only mgmt-tester's own `command 0x0405 tx timeout` ×2, same before and
  after.

## B4 — lint (quoted)

`bluez-lint.sh standalone/bluez-shared-mgmt-leak` (BlueZ master's `.checkpatch.conf` and
`.gitlint`): checkpatch `total: 0 errors, 0 warnings, 34 lines checked` / `0 error(s), 0
warning(s), 0 check(s)`; gitlint `gitlint, version 0.19.1` … `PASS no violations`.
`make -C cache/bluez-standalone-mgmt-leak -j16 check` at `bdd3acd51`
(`bluez-standalone-make-check.log`, started 02:56:3x, log last written 02:59:26 per `stat`,
`exit 0`): `Testsuite summary for bluez 5.87`,
`# TOTAL: 42`, `# PASS: 41`, `# SKIP: 1`, `# FAIL: 0`, `# ERROR: 0`.

## B5 — the exported patch (quoted)

`git format-patch --subject-prefix="PATCH BlueZ" --base=4dc15be8e… -1 bdd3acd51 -o
tmp/mesh-tester-ci/standalone/bluez-shared-mgmt-leak/` →
`0001-shared-mgmt-Fix-notify-leak-in-mgmt_unregister.patch`: `From: Iaroslav Voitovych`,
`Subject: [PATCH BlueZ] shared/mgmt: Fix notify leak in mgmt_unregister()` (title 49
characters), no Signed-off-by, `Fixes: 872729a91632 ("shared/mgmt: Fix crash when removing
index")` (the commit that introduced the `removed`/`need_notify_cleanup` path in
`mgmt_unregister()`: `git show 872729a91 -- src/shared/mgmt.c` adds `notify->removed = true;
mgmt->need_notify_cleanup = true;` after the `queue_remove_if()`), `base-commit:
4dc15be8ee3f…`. Re-read as a standalone patch: it names no series and no non-upstream test;
the reproduction paragraph uses only upstream tools (mgmt-tester and mesh-tester, built with
`./bootstrap-configure --disable-lsan`, run with test-runner) and the numbers of §B3.

## Summary

**A — the posted patch, exactly as posted.** Patchwork 14831271 is `new`, no delegate, v1 only,
no human reply (only the CI bot's mail), and is in neither bluetooth (`08e90633377f`) nor
bluetooth-next (`036d4119079a`) as of 2026-10-05 02:15. `git am` of the patchwork mbox applies
unchanged on the bluetooth-next tip (patch-id identical to the posting; no adapted variant
exists). Control and patched kernels: same base, same config (sha256 `d9d228fe…6a59`), same
compiler, differing only by the patch. On the new tester case (fault injection on the first
`hci_cmd_sync_queue()` allocation of a Mesh Send), five runs per kernel, legacy and extended:

| assertion | control | exact patch |
|---|---|---|
| (a) failed request not listed by Read Mesh Features | FAIL (1, then 1/2/3/3/3) | PASS (0 in all 8 reads) |
| (b) failed packet never loaded or started | PASS | PASS |
| (c) no Mesh Packet Complete for a failed handle | FAIL (handle 6 completed) | PASS |
| (d) 3 sends right after the failure accepted, each once | FAIL (3rd Busy; next request sent twice) | PASS |
| (e) 5 more failures, never Busy | FAIL (3 Failed, 2 Busy) | PASS (5 Failed) |
| (f) next request accepted, started and completed once | FAIL (Busy) | PASS (handle 15) |

Full suites, control vs patched: phase-5 mesh-tester 18/57 vs 21/57, differing only in the
three fault-injection cases; mgmt-tester 502/503 vs 502/503, identical; BlueZ master's
mesh-tester 8/10 vs 8/10 and mgmt-tester 503/503 vs 503/503, identical. Under series v3 the
exact patch gives 57/57 (phase 5's local equivalent: 55/55 on a byte-identical tree); series v3
without it transmits the request answered Failed. No KASAN, lockdep or WARNING report on any
kernel. Reply draft: `cache/hui-peng-validation/reply-draft.txt`, mail-lint clean, not sent.

**B — the BlueZ shared/mgmt fix, standalone.** Applies to BlueZ master `4dc15be8e` without
conflict; tested objects `4dc15be8e` (before) and `9c7873766` (after; same tree as the exported
`bdd3acd51`). Before: LeakSanitizer `Direct leak of 9080 byte(s) in 227 object(s)` (mgmt-tester)
and `120 byte(s) in 3 object(s)` (mesh-tester), all 40-byte `util_malloc` records. After: none of
those (only the unrelated emulator `btdev_add_hook` 120 B/5 in mgmt-tester, unchanged).
mgmt-tester 503/503 before and after, mesh-tester 8/10 before and after, identical per case.
checkpatch 0/0/0, gitlint pass, `make check` 41 pass / 1 skip / 0 fail. No prior fix upstream or
on patchwork. Export: `tmp/mesh-tester-ci/standalone/bluez-shared-mgmt-leak/0001-shared-mgmt-Fix-notify-leak-in-mgmt_unregister.patch`.

## Open

1. **Recipients of the reply.** The original mail went To the two maintainers and Cc
   one more kernel.org developer (address elided here), linux-bluetooth and linux-kernel. The draft follows the instruction (To
   the author; Cc the two maintainers and linux-bluetooth); a reply-all would also keep the
   other two. Operator's call.
2. **The tester case is local.** The reply calls it "a local mesh-tester case"; the commit
   `8488ba994` sits on the unposted phase-5 BlueZ branch. If the author or a maintainer asks
   for it, it would have to go out with (or after) the BlueZ test split.
3. **Series v3 depends on the posted patch more than its cover says** (§A6): without it, the
   series puts a request that was answered Failed on air. Worth stating in the cover if the
   series is sent before the patch lands.
4. **Another author's patch overlaps series v3 4/5**: patchwork 14864878 (2026-10-03, `new`),
   "Bluetooth: mgmt: handle mesh send completion queue failure" — same defect (the done work's
   `hci_cmd_sync_queue()` failure leaves `HCI_MESH_SENDING` set), different fix (calls
   `mesh_send_done_sync()` and `mesh_next()` directly on failure). Not evaluated here.
5. **BlueZ trailers.** The export carries the `Fixes:` tag BlueZ asks for. Operator to
   confirm the trailers for this BlueZ patch before sending.
6. **Not done:** a kprobe/debugfs read of `mesh_pending` for assertion (a) (no
   `CONFIG_KPROBE_EVENTS` in these images; Read Mesh Features stands in, §A4); reference counts
   measured directly (inferred from the code); lore not checked (blocked for curl; patchwork and
   the lkml mirror used); no real controller (emulator only); no stable kernel.

## Archive (quoted)

`sha256-validation.sh` → `95 tmp/mesh-tester-ci/logs/validation-2026-10-05/SHA256SUMS`, `all
entries OK`, list hash `7a0855ba46998221f9360430a41d569e14f71fc6772fe40fc1403a10672af1e5`.
It covers every raw log and build log of this validation, the three `bzImage-val-*` images and
`config-val-*` files, `standalone/` (binaries, exports, messages) and `cache/hui-peng-validation/`
(mbox, patchwork JSON, lkml page, reply draft); this results file is not in it. Verify later
from `/root/exp/qca9377-bt-hang`: `sha256sum -c tmp/mesh-tester-ci/logs/validation-2026-10-05/SHA256SUMS`.
Helpers written for this validation (all in `tmp/mesh-tester-ci/`): `vstep.sh`,
`pw-json-summary.py`, `pw-comments-show.py`, `pw-show-content.py`, `pw-query-v.sh`,
`patch-id-compare.sh`, `run-logged.sh`, `build-chain-validation.sh`,
`build-bluez-standalone.sh`, `runs-validation.sh`, `runs-chain-validation.sh`,
`runs-bluez-standalone.sh`, `runs-extra-validation.sh`, `compare-verdicts.py`,
`splat-all-validation.sh`, `assertion-summary.sh`, `assertion-fingerprint.py`, `bluez-lint.sh`,
`sha256-validation.sh`, `replace-fail-block.py` (with `validation-fail-block.c`, the source
block it inserted).

Nothing was sent, posted, mailed or commented; no commit in the repository or its worktrees
other than in `cache/mesh-guest` (branches `control/…`, `validate/…`), `cache/bluez-upstream`
(`8488ba994`, `keep/mesh-tester-validation-1ece02bba`, `keep/standalone-shared-mgmt-leak-9c7873766`)
and its new worktree `cache/bluez-standalone-mgmt-leak` (`standalone/shared-mgmt-notify-leak-2026-10-05`).

## Step log (appended at the start and end of every step)

- 2026-10-05 02:10:14 A1 start: patch provenance and state
- 2026-10-05 02:27:53 A1 end
- 2026-10-05 02:28:19 A2 start: git am of the exact patch on bluetooth-next/master
- 2026-10-05 02:29:20 A2 end: applied as 19fdd346e00c on 036d4119079a
- 2026-10-05 02:40:06 A4-prep start: new tester case test_mesh_fail written; building the ASAN tester
- 2026-10-05 02:41:09 A3 start: guest kernel builds (build-chain-validation.sh)
- 2026-10-05 02:41:25 B1 start: BlueZ fetch, standalone branch, cherry-pick
- 2026-10-05 02:43:42 A3 end: three images built (control 036d4119079a, exact patch 19fdd346e00c, patch+series d532f88c0961); B1 end: fix cherry-picked as 9c7873766 on 4dc15be8e, both tester builds 0 warnings
- 2026-10-05 02:43:47 A4 start: targeted runs (runs-validation.sh targeted)
- 2026-10-05 02:46:47 A4 end (targeted try1 02:43:48 to 02:44:27, tester flaw found; try2 02:45:46 to 02:46:25); A5/A6/B3 start: runs-chain-validation.sh (full suites, series, BlueZ standalone)
- 2026-10-05 02:56:34 A5/A6 end (full 02:46:48 to 02:49:28, series 02:49:28 to 02:50:43); B3 end (02:50:44 to 02:52:44); extra runs 02:53:05 to 02:54:16; B commit reworded as bdd3acd51, exported, linted; B make check started
- 2026-10-05 03:00:37 A7/A8/B2-B5 written; make check 02:56-02:59 exit 0; archive start: SHA256SUMS
- 2026-10-05 03:00:50 archive end; validation ended
