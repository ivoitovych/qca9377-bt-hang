# Kernel patch — wrong status for pending commands flushed on power-off

## State at a glance — 2026-10-01

| | |
|---|---|
| **applied** | ✅ **2026-09-29 11:20 -0400** by Luiz Augusto von Dentz to `bluetooth-next` master as [`86ef0f58bdec`](https://git.kernel.org/bluetooth/bluetooth-next/c/86ef0f58bdec); patchwork-bot mail 09-29 17:40 local; patchwork `14845586` state `accepted`. Applied as sent: one file, +1/−1, author and date preserved (`git -C cache/linux show --stat 86ef0f58bdec` after `fetch bluetooth-next`, 2026-10-01). No human comment on the thread at any point. Reaches mainline with the next bluetooth-next pull; the `Fixes:` tag then carries it to stable on its own |
| **the mail** | [`0001-Bluetooth-MGMT-Fix-status-of-pending-commands-flushed-on-power-off.patch`](0001-Bluetooth-MGMT-Fix-status-of-pending-commands-flushed-on-power-off.patch) — exactly what goes out: `git format-patch --base` of commit `ff7646085b90` on **`bluetooth`** (the fixes tree) `c9c15d4d8956` (ER4-1, ER5-1; ER6-1 withdrawn) |
| diff | one line in `net/bluetooth/mgmt.c`, unchanged since 2026-09-19 (patch-id `6f4e06d4b60c` across every regeneration) |
| reviews | five (ER1–ER5 below): all "correct, should go in"; message corrected three times, shortened after ER4, one sentence reworded after ER5 |
| tested | yes, both ways on one kernel: stock `0x00`, patched `0x0f` (`EX-050`, `EX-049`, virtual controller); two hours of real use on the patched module without regression |
| checks | at `bluetooth` `c9c15d4d8956`: checkpatch `--strict` 0/0/0 in-tree, `W=1 -Werror` clean, sparse 0 new, `bluetooth.ko` builds unpatched and patched; applies to `bluetooth-next` `671d566d3c3b` (offset +2); builds at `linux-6.1.y` (checked 2026-09-24) |
| **sent** | ✅ **2026-09-24 19:11:58 +0200**, on the operator's word, `git send-email --suppress-cc=bodycc`, SMTP result `250`. Message-ID `<20260924171158.804136-1-yaroslav.voytovych@gmail.com>` — <https://lore.kernel.org/r/20260924171158.804136-1-yaroslav.voytovych@gmail.com>. To linux-bluetooth; Cc Marcel Holtmann, Luiz Augusto von Dentz, linux-kernel, the author; **not** stable (dry run and real run both). Sent file byte-identical to the committed patch (blob `68a84a35`). Pre-send: both trees fetched minutes before, tips unchanged (`c9c15d4d8956`, `671d566d3c3b`), defect present in both, no competing fix in either tree or on patchwork |
| **CI bot** | ✅ 2026-09-25 (mail 2026-09-24 21:33 local), [series 1173305](https://patchwork.kernel.org/series/1173305/), patch id `14845586`, bluetooth-next PR [#817](https://github.com/bluez/bluetooth-next/pull/817): **13 of 14 PASS** — CheckPatch, VerifyFixes, VerifySignedoff, GitLint, SubjectPrefix, BuildKernel, CheckAllWarning, CheckSparse, BuildKernel32, CheckKernelLLVM, TestRunnerSetup, **TestRunner_mgmt-tester** (the suite for the changed code), IncrementalBuild. **TestRunner_mesh-tester FAIL** (8/10; "Mesh - Send cancel - 1/2" timed out) is the bot's standing failure, not the patch's: over the 122 other kernel patches cached in `tmp/patchwork/survey/` (2026-07-22 → 09-21) mesh-tester failed **122 of 122**, and 119 of the bot's reports name the same "Mesh - Send cancel" cases (`grep -l 'Mesh - Send cancel' tmp/patchwork/survey/comments-*.json \| wc -l` → 119; checks read with a JSON count of `context == TestRunner_mesh-tester` → 122 runs, 122 `fail`). No reply to the bot |

## What goes out — the package

- **One mail**, plain text: the patch file above, as generated. Subject
  `[PATCH] Bluetooth: MGMT: Fix status of pending commands flushed on power off`.
- **To** `linux-bluetooth@vger.kernel.org`; **Cc** the Bluetooth maintainers Marcel
  Holtmann and Luiz Augusto von Dentz, and `linux-kernel@vger.kernel.org` —
  `scripts/get_maintainer.pl` output, printed by `scripts/kernel-preflight.sh`.
  (Luiz is also the author of the commit this `Fixes:`.)
- **`Cc: stable@vger.kernel.org` is a tag in the sign-off area, NOT a recipient**
  (`Documentation/process/submitting-patches.rst`): the send uses
  `--suppress-cc=bodycc`.
- **Not included:** no link to the public investigation repository; no separate bug
  report (the patch is the report); no reproducer (offered in a reply if asked); no
  `Tested-by:`/`Reported-by:` (the author reported and tested; the message says what
  was tested); nothing below `---` but the diffstat. The unrelated alt-1 controller
  fault is not mentioned.

## Not the BlueZ rules

| | BlueZ patches, 2026-09-19 | this kernel patch |
|---|---|---|
| `Signed-off-by` | forbidden | required |
| subject | `[PATCH BlueZ] adapter: …` | `[PATCH] Bluetooth: MGMT: …` |
| recipients | the list | list + maintainers + `linux-kernel` |
| stable | — | tag only, never mailed |
| below `---` | a note with the repo link | nothing |
| checks | BlueZ `.checkpatch.conf`, gitlint | kernel checkpatch `--strict`, `W=1`, sparse |
| before sending | (checked a month-old checkout — the v2 slip) | fetch `bluetooth` and `bluetooth-next` minutes before |

## The defect

| patch | file | defect |
|---|---|---|
| `0001` | `net/bluetooth/mgmt.c` | `cmd_complete_rsp()` hands a `struct cmd_lookup *` to `cmd_status_rsp()`, which reads it as `u8 *`, i.e. the first byte of `match->sk`; every pending command without a `cmd_complete` callback that is flushed by `__mgmt_power_off()` or `mgmt_index_removed()` is answered with that byte instead of Not Powered / Invalid Index — `0x00` Success when `match->sk` is NULL, a byte of a socket pointer when a Set Powered was pending (ER1-1) |

**Where it came from.** `EX-044`: the management channel of the 2026-08-14 capture shows
the kernel answering `bluetoothd`'s pending Start Discovery with Command Status `0x00`
while powering the adapter off — the reply that `patches/bluez/0001` guards against, seen
from the kernel's side. The defect and the introducing commit (`f53e1c9c726d`, v6.12) were
confirmed against current master (`net/bluetooth/mgmt.c` lines 1481–1503, 9815–9848 at the
time of writing) and the blame of those lines.

**What the fix changes for userspace.** A flushed Start Discovery gets `0x0f` Not Powered,
as it did before v6.12. In `bluetoothd`, `start_discovery_complete()` then takes its
existing non-success paths, and the no-clients branch returns before touching the reply —
so the crash `patches/bluez/0001` fixes is not reachable through this route. `0001` stays
correct on its own terms (a callback must not dereference a reply it has not measured) and
is not withdrawn.

**Stable exposure.** The introducing commit carries a `Fixes:` tag and was backported. The
first BlueZ-patch reviewer, shown the finding, checked the 6.1.120 stable review and
current 6.1; verified here against the stable mirror (`gregkh/linux`) on 2026-09-19:

| tree | `cmd_complete_rsp()` | fallback |
|---|---|---|
| `v6.1.119` | `u8 *status = data` (correct form) | `cmd_status_rsp(cmd, data)` — correct, `data` is `&status` |
| `v6.1.120`, `linux-6.1.y` | `struct cmd_lookup *match = data` | `cmd_status_rsp(cmd, data)` — **wrong** |
| `linux-6.6.y` | same | **wrong** |
| `linux-6.12.y` | same | **wrong** |
| `master` | same | **wrong** |

So the patch carries `Cc: stable@vger.kernel.org`. The message no longer lists the trees
(ER3-2: `Fixes:` carries it and does not go stale); the list stays here.

## Status

| check | result |
|---|---|
| hunk generated mechanically from the downloaded master source | ✅ `diff -u` of a one-line `sed` |
| `patch -p1 --dry-run` against master `mgmt.c` | ✅ |
| kernel `checkpatch.pl` (`--no-tree`) | ✅ 0 errors; 2 warnings, both "Unknown commit id", the artefact of running outside a tree |
| `git am` onto a scratch repository holding master's `mgmt.c` | ✅ clean; author and committer the operator's |
| compile — `scripts/build-bluetooth-module.sh tmp/kernel-0001.patch` (2026-09-19) | ✅ `bluetooth.ko` builds against `/lib/modules/7.0.0-31-generic/build` from `cache/linux` at `v7.0`, patched and unpatched; the hunk applies at offset −3 on v7.0. v7.0 carries the defect at `mgmt.c:1499` |
| **tips refreshed 2026-09-22** — defect present and patch applies (`git apply --check` against each tree's index): `bluetooth-next/master` `06d991977eef` (09-21), `bluetooth/master` `6d91041bb38b` (09-21), mainline `f0100363d8c3` (09-21), `linux-6.12.y` 6.12.111, `linux-6.6.y` 6.6.157, `linux-6.1.y` 6.1.188 | ✅ **6 / 6 — nobody fixed it meanwhile; the hunk applies unchanged everywhere it is needed.** Remotes now in `cache/linux`; re-run before any send |
| **compile at `bluetooth-next/master` `06d991977eef`** — `scripts/compile-mgmt-at.sh cache/linux-bt-next <patch>`: `mgmt.c` with that tree's headers first, `-Werror`, unpatched then patched (2026-09-22) | ✅ both compile; hunk at offset −2. ⚠️ **One file, not the module**: bluetooth-next's `net/bluetooth` no longer builds against the running 7.0 headers (`rfcomm_sock_getsockopt` / `getsockopt_iter`, unrelated) |
| **full-tree build at `bluetooth-next/master` `06d991977eef`** — `scripts/build-bluetooth-fulltree.sh bluetooth-next/master full-bt-next <patch>`: full worktree, `defconfig` + BT=m, `modules_prepare`, `make M=net/bluetooth KCFLAGS=-Werror` (2026-09-22) | ✅ **`bluetooth.ko` builds unpatched and patched**, 1 791 800 bytes each; hunk at offset −2. (`KBUILD_MODPOST_WARN=1`: no vmlinux, so core symbols are unresolved at modpost — a warning, not a compile problem) |
| **full-tree build at `stable/linux-6.1.y` 6.1.188** — same script, `full-6.1.y` | ✅ **`bluetooth.ko` builds unpatched and patched**, 1 349 032 bytes each; hunk at offset −44. `bison`, `flex`, `libelf-dev` installed on the host for this. The first reviewer's ask is met |
| the single-file shortcut (`scripts/compile-mgmt-at.sh`) at the stable tips | ❌ not possible — core headers too far from the running 7.0; superseded by the full-tree build above |
| the target tree's workflow, measured (`reviews/2026-09-22T1700Z-kernel-bluetooth-workflow-as-practised.md`) | ✅ form already matches: `Bluetooth: MGMT:` (9/9 split with `mgmt:`), `Fixes:` (173/300 commits), `Cc: stable` (61/300), sign-off; `VerifyFixes` will pass. ⚠️ **Sashiko** (Linux Foundation LLM reviewer) will review it on the list and the maintainer reads that — the external review before sending is the rehearsal |
| runtime, real hardware (2026-09-24) — patched module from `updates/`, two hours of heavy use | ✅ no regression; the fixed path was not reached by normal use (see below) |
| **runtime, the fixed path** (2026-09-24) — virtual controller, same kernel, stock vs patched module | ✅ **`0x00` stock (`EX-050`), `0x0f` patched (`EX-049`)** |
| message regenerated after the "Tested" paragraph — `git am` + `format-patch --base` on `bluetooth-next` `671d566d3c3b`, commit `b00c0e4ee93d`; preflight | ✅ checkpatch `--strict` 0/0/0, `W=1 -Werror` clean, sparse 0 new; recipients from `get_maintainer.pl` |
| applies at the fixes tree too — `bluetooth/master` `c9c15d4d8956` (2026-09-24) | ✅ `git apply --check` clean |
| sent | ✅ 2026-09-24 (table at the top) |

## External review before sending — by file, not by branch

Until 2026-10-09 this work lived on the branch `kernel/mgmt-flush-status` in the project's
private repository: kernel findings were then kept off `main` until their patch was sent.
Reviewers got the files as a package (the patch, this README, `REVIEW-TASK.md`, the
reproducer, exhibits 044/049/050). The files were ported to `main` on 2026-10-09.

### First external review, 2026-09-23 — diff kept, message corrected

Verdict: **the code change is correct; keep the one-line diff; revise two statements.**
Reviewer's own checks: `git apply --check` at mainline, v6.1.120, 6.6.y, 6.12.y; the
faulty conversion absent in v6.11 and v6.1.119, present in v6.12 and v6.1.120;
`Fixes:` attribution correct; checkpatch 0 errors, the same two "unknown commit" warnings.

| # | finding | verified here | action |
|---|---|---|---|
| ER1-1 | `match->sk` is **not always NULL**: in `__mgmt_power_off()` the preceding `mgmt_pending_foreach(MGMT_OP_SET_POWERED, …, settings_rsp, &match)` stores a pending Set Powered command's socket in `match.sk`, so the byte sent is then the first byte of a kernel pointer — an arbitrary status, not necessarily 0x00. `mgmt_index_removed()` keeps NULL | ✅ `settings_rsp()` at `bluetooth-next` `mgmt.c:1467–1477` (`if (match->sk == NULL) { match->sk = cmd->sk; … }`), called first in `__mgmt_power_off()` at 9839 | message now describes both cases |
| ER1-2 | Qualify the BlueZ crash by version: current BlueZ master already checks the length on that branch | ✅ — the check is our own patch, applied 2026-09-21 as `a734b0605` | message says "bluetoothd 5.72" and names the BlueZ fix; the kernel fix stands on its own |
| ER1-3 | Useful runtime check: flush a pending discovery on power-off and on removal (expect 0x0f / 0x11), **including power-off with a pending Set Powered** | — | added to the runtime plan; the module must be in place before the first probe (`EX-046`) |

After the change: diff byte-identical (`scripts/patch-replace-message.sh` refuses
otherwise), checkpatch 0 errors / 2 warnings as before, `git apply --check` clean at
`bluetooth-next/master` `06d991977eef`.

### Second external review, 2026-09-23 — independent, same verdict

Verdict: **"The one-line change is correct and should go in."** Formed without the first
review. Adds checks the record did not have:

| # | finding | action |
|---|---|---|
| ER2-1 | `cmd_complete_rsp()` has no other caller; other `cmd_status_rsp()` users pass `&mgmt_err` and are untouched; `mgmt_pending_foreach(…, true, …)` still frees after the callback, so no leak or double free; `hci_cmd_sync_dequeue()` runs first and `start_discovery_complete()` / `stop_discovery_complete()` return on `-ECANCELED` without a second reply | recorded — strengthens "no other path changes" |
| ER2-2 | NULL `match.sk` gives 0x00 on every endianness; with a pending Set Powered `match.sk` holds a socket and the byte is arbitrary — the same point as ER1-1 | already in the revised message (arch-neutral "first byte of a kernel pointer") |
| ER2-3 | **Do not** switch the fall-through to Command Complete: the flush has always used Command Status with no parameters, and changing it would alter the event for every callback-less pending command | agreed; the patch restores the pre-v6.12 behaviour and nothing more |
| ER2-4 | The BlueZ length check is a separate bug; the kernel must not report Success for a command it cancelled | consistent with the message |
| ER2-5 | Regression test that matters: btmon shows opcode `0x0023` answered with Command Status `0x0f` (or `0x11` on unregister), not `0x00`. `mgmt-tester` "Start Discovery - Power Off 1" may not assert it | ✅ **settled 2026-09-23: it does not reach the flush path.** That case (`mgmt-tester.c:13561`) expects `MGMT_STATUS_NOT_POWERED` with `force_power_off`, and it **passes on kernels carrying the bug**: of ~130 bot reports on kernel patches (2026-07-22 → 09-21, cached under `tmp/patchwork/survey/`) that list `TestRunner_mgmt-tester` failures, none names it (`grep -l "Start Discovery - Power Off"` over them: 0). So upstream has no test for this path; the btmon check (`0x0023` → Command Status `0x0f`/`0x11`, not `0x00`) is the regression test. A new mgmt-tester case that leaves Start Discovery pending across the power-off would be a natural follow-up patch |

### Third external review, 2026-09-23 — "the code is ready; I would not change the implementation"

A deep review (source, lifetime, protocol, stable rules, recent accepted corpus, CI matrix).
Adds: `match.mgmt_status` is always assigned before `cmd_complete_rsp()` runs (the zero it
starts with only matters during the earlier Set Powered pass); `start_discovery_complete` is
the HCI cmd-sync completion, not `mgmt_pending_cmd::cmd_complete`, so Start Discovery does
reach the fallback; MGMT protocol defines 0x0f/0x11 for exactly this; do not change
`cmd_status_rsp()` itself.

| # | recommendation | action |
|---|---|---|
| ER3-1 | "first byte of a kernel pointer, an arbitrary status" → the byte comes from the pointer's representation, not `match->mgmt_status` | ✅ adopted |
| ER3-2 | delete the hand-written stable-version paragraph; `Fixes:` + `Cc: stable` carry it and do not go stale | ✅ adopted (the inventory stays here, in this README) |
| ER3-3 | regenerate with `git format-patch --base` from the current tree; run checkpatch `--strict`, `W=1`, sparse in-tree | ✅ `git am` onto `bluetooth-next` **`671d566d3c3b`** (2026-09-23) → commit `841f9b067f49`, `format-patch -1 --base=HEAD~1`. `scripts/kernel-preflight.sh`: checkpatch `--strict -g HEAD` **0 errors, 0 warnings, 0 checks** (Fixes resolved in-tree); `make M=net/bluetooth W=1 KCFLAGS=-Werror` **clean**; sparse on `mgmt.c` **0 findings at base, 0 patched**, with the CHECK step verified in the log. ⚠️ The first sparse run reported 0 while the kernel had skipped sparse (Ubuntu 0.6.4 too old); current sparse built in `cache/sparse` |
| ER3-4 | add one sentence on the post-fix run **only if it was actually observed** | ⏳ not run — the runtime test waits on the operator (`updates/` + cold boot, `EX-046`) |

### Runtime test on the machine, 2026-09-24 — no regression; the flush path was not reached

Patched `bluetooth.ko` (Ubuntu 7.0.0-31 source + this patch, srcversion
`66D38200362CD82D3F68A9D`) installed in `updates/`, cold boot 01:18:55, confirmed loaded from
`/sys/module/bluetooth/srcversion`; all nine dependant modules loaded
(`scripts/check-modversions.sh` beforehand: 0 CRC mismatches). The operator then used the
machine hard until 03:39: dozens of Bluetooth off/on cycles, pairing, unpairing, discovery,
two hours of audio.

`scripts/mgmt-replies.sh` over both independent recorders (`capture/`, 9 files; `trace/`,
6 files): **~450 management replies, every Start Discovery answered by Command Complete
Success; the only Command Status replies are Set Default System Configuration `0x0d`
(bluetoothd's normal start-up probe, identical on stock) and one Set Discoverable `0x05` after
the 03:24:59 alt-1 wedge (`EX-047`).** So: **no regression in the paths used**, and **the flush
path this patch changes was not reached** — a healthy controller completes discovery in
~110 ms, and the 08-14 flush needed a slow HCI operation holding the sync lock in front of a
queued discovery plus an rfkill power-off (traced in the source, `hci_rfkill_set_block` →
`hci_dev_do_poweroff` takes `req_sync_lock` directly; `Set Powered` off queues behind the
discovery and cannot reach it; and a pending Set Powered puts its socket in `match->sk`).
A dedicated trigger for that timing was not built (see BRIEF). The stock control run of
00:33 the same way: Command Complete, flush not reached.

**Consequence for the message (ER3-4):** no post-fix sentence — nothing was observed on the
fixed path. What can honestly be said, if a maintainer asks: built from the distribution
source for 7.0.0-31, ran two hours of normal use without regression; the fixed branch itself
was not exercised on hardware.

### Runtime test on a virtual controller, 2026-09-24 — the fixed path, both ways

An outside reviewer's reproduction design (`repro-mgmt-flush-status.py` beside the patch; its original
kept byte for byte, two transport bugs fixed in the working copy): a `/dev/vhci` controller
holds power-off inside HCI Write Scan Enable(0), Start Discovery is submitted during the
stall, and on release `__mgmt_power_off()` flushes it. Same kernel (7.0.0-31), same script,
same procedure; the loaded `bluetooth.ko` is the only difference:

| `bluetooth.ko` | srcversion | reply to the flushed Start Discovery | exhibit |
|---|---|---|---|
| **stock** (Ubuntu) | `052335E5B69A055D6D15874` | Command Status **`0x00` Success** — the bug, as on 08-14 | `EX-050` |
| **patched** | `66D38200362CD82D3F68A9D` | Command Status **`0x0f` Not Powered** | `EX-049` |

In both runs a Set Powered was pending across the flush (its Complete follows the Start
Discovery reply), i.e. `match->sk` held a socket; on stock the byte still came out `0x00`.
**ER3-4 is now closed honestly:** the message carries one "Tested on 7.0 with a virtual
controller …" paragraph. Regenerated on `bluetooth-next` `671d566d3c3b` (commit
`b00c0e4ee93d`), checkpatch `--strict` 0/0/0, `W=1 -Werror` clean, sparse 0 new.

### Fourth external review, 2026-09-24 — "send after changes", no blockers

Submission-focused, per [`REVIEW-TASK.md`](REVIEW-TASK.md): a cold read of the mail alone
first, then the evidence, then open ground. Cold impression: *"The code looks obviously
right; I want to check the history, the special Set Powered lifetime, target tree, and
evidence before Acking it"* — and all of those checked out. Checked independently against
current upstream: the diff, `f53e1c9c726d`, lifetime and locking, the Set Powered case,
the four-byte vhci reply, the BlueZ commit. Open ground: **no sibling** — `cmd_status_rsp()`
has one caller besides its definition, and no other `mgmt_pending_foreach()` callback
mistypes its argument, so the one line is the whole regression; callback-less
`mgmt_pending_add()` registrations (Set Powered, Discoverable, Connectable, Link Security,
SSP, LE, Local Name, Advertising, Mesh Receiver, the two Adv Patterns Monitor variants,
the three discovery starts, Stop Discovery) all reach the fallback; `btmgmt` also takes a
bogus 0 as success.

| # | severity | finding | action |
|---|---|---|---|
| ER4-1 | should | base on `bluetooth` (fixes tree), not `bluetooth-next`: a stable regression fix with no next-only dependency | ✅ both trees fetched 2026-09-24 (tips unchanged: `c9c15d4d8956`, `671d566d3c3b`); `scripts/build-bluetooth-fulltree.sh bluetooth/master full-bt` builds 1 778 632 bytes unpatched and patched, hunk offset −2; `scripts/kernel-regenerate.sh` → commit `43634de3f381`, patch-id unchanged; `scripts/kernel-preflight.sh cache/full-bt`: checkpatch `--strict` **0/0/0**, `W=1 -Werror` **clean**, sparse **0 at base, 0 patched**; `get_maintainer.pl` the same four recipients, Luiz `blamed_fixes:1/1`. Applies to `bluetooth-next` at offset +2 (`patch --dry-run`) |
| ER4-2 | should | message longer than a one-line fix needs | ✅ quoted function and capture excerpt dropped (−19 lines). Kept: the type confusion, the introducing commit, both caller cases with the status each should send (their suggested draft said only Not Powered — incomplete, Invalid Index on unregister), the fix, one QCA9377/BlueZ paragraph, the test. Every line ≤ 72 except the unwrappable `Fixes:` |
| ER4-3 | should | "Tested on 7.0" less exact than the evidence | ✅ "Tested on Ubuntu 7.0.0-31 with a virtual controller (hci_vhci)" |
| ER4-5 | could | reproducer diagnostic says "low 8 bits of `match->sk`" | ⏳ open — say "first byte of the pointer's representation" |
| ER4-6 | could | reproducer teardown race: `close()` clears `self.fd` while the worker may still write — the post-result exception in `EX-049`/`EX-050` | ⏳ open — keep the fd local to the worker or close after it exits |
| ER4-7 | could | `EX-050` records the capture shell's exit 0 while the reproducer exits 1 (bug reproduced) | ⏳ open — label both |
| ER4-8 | could | no runtime exhibit for the `0x11` (unregister) value | ⏳ optional follow-up; the fix has no status-specific logic |

Keep as is (reviewer): the diff; `Fixes:`; `Cc: stable` with **no** `# 6.1.120+` hint
(`Fixes:` implies it); `--suppress-cc=bodycc`; recipients from `get_maintainer.pl` on send
day; not a security framing. A new mgmt-tester case remains a natural follow-up.

### Fifth review, 2026-09-24 — of the outgoing mail only

The fourth reviewer re-read the regenerated patch and this README from the private
repository, as the mail that reaches the list, with no new brief. **No technical or
presentation blocker.** ER4-1, ER4-2 and ER4-3 confirmed resolved; ER4-5 … ER4-8 do not
touch the mail. Confirmed: one inline `[PATCH]`, no cover letter, no attachments or
links, the recipients, `Cc: stable` as a trailer only with `--suppress-cc=bodycc`; keep
the diff exactly; "a good information order now".

| # | finding | action |
|---|---|---|
| ER5-1 | optional: "the status sent is the first byte of the struct, that is of match->sk" reads as if `match->sk` were a byte field; prefer "comes from the first byte of match->sk's representation, not from match->mgmt_status" | ✅ adopted; regenerated (`scripts/kernel-regenerate.sh`) → commit `fe5c2d4297dc`, patch-id `6f4e06d4b60c` unchanged; preflight at `bluetooth` `c9c15d4d8956`: checkpatch `--strict` 0/0/0, `W=1 -Werror` clean, sparse 0 at base / 0 patched, same four recipients |
| ER5-3 | this README said "This branch is never pushed", but it is pushed to the private repository | ✅ corrected ("External review before sending") |

### Sixth review, 2026-09-24 — what the test statement covers

Read the mail before the ER4 regeneration, so its main presentation ask — cut a quarter to
a third — was already done.

| # | finding | action |
|---|---|---|
| ER6-1 | say what was not verified: the `mgmt_index_removed()` path is untested | ↩️ **added (`344d1c2ee934`), then withdrawn (`ff7646085b90`)** after reading the source: `hci_unregister_dev()` sets `HCI_UNREGISTER` (`hci_core.c:2661`), closes the device (`:2684`) — for a powered device `hci_dev_close_sync()` runs `__mgmt_power_off()` (`hci_sync.c:5607`), which flushes every pending command with **Invalid Index** because of that flag (`mgmt.c:9837`), through the fixed line — and only then calls `mgmt_index_removed()` (`:2690`), whose list is then normally empty. Its own flush matters only for a device removed while never powered, where next to nothing can be pending. The sentence pointed a maintainer at a near-empty corner; the test paragraph already states exactly what was tested. The `0x11` value itself is reachable (unregister of a powered device with a command still queued) and is the ER4-8 follow-up. Preflight on `ff7646085b90`: checkpatch `--strict` 0/0/0, `W=1 -Werror` clean, sparse 0 new, same recipients |

## How to send — on the operator's word only

1. **Freshness, minutes before** (the BlueZ v2 lesson): fetch `bluetooth` and
   `bluetooth-next` into `cache/linux`; confirm the defect line is still there and the
   patch applies to both tips; look at both for anyone else's fix to
   `cmd_complete_rsp()`. The base is **`bluetooth`** (ER4-1). If it moved, regenerate:
   `scripts/build-bluetooth-fulltree.sh bluetooth/master full-bt <patch>` (updates the
   worktree only if it is new — otherwise check out the new tip in `cache/full-bt`
   first), `scripts/kernel-regenerate.sh cache/full-bt <patch>`, then
   `scripts/kernel-preflight.sh cache/full-bt`.
2. **Publish the branch in the same minute** — the rule at the time (BRIEF §7 until
   2026-10-09). Not done on send day; the files were ported to `main` on 2026-10-09.
3. **Dry run, then send**, one invocation. The two maintainer addresses are the ones
   `scripts/kernel-preflight.sh` prints from `get_maintainer.pl` on send day (not kept
   here: the publish scan refuses personal addresses in tracked files):

   ```console
   $ git send-email --dry-run --suppress-cc=bodycc \
       --to=linux-bluetooth@vger.kernel.org \
       --cc="<Marcel Holtmann, from get_maintainer.pl>" \
       --cc="<Luiz Augusto von Dentz, from get_maintainer.pl>" \
       --cc=linux-kernel@vger.kernel.org \
       patches/kernel/0001-*.patch
   ```

   The dry run must list exactly those four plus the sender (from `Signed-off-by`), and
   **not** `stable@vger.kernel.org`. Then the same command without `--dry-run`, with a
   one-use app password; afterwards `scripts/smtp-login-check.sh` confirms it revoked.
4. **After:** record the Message-ID; watch patchwork and the bot (kernel set: builds,
   sparse, checkpatch, gitlint, SubjectPrefix, VerifyFixes, VerifySignedOff, testers —
   tester failures are advisory, `reviews/2026-09-22T1700Z-…`) and Sashiko. No reply to
   the bot unless a finding is ours. A v2 only if a maintainer asks, as a new mail.
