# Review of the independent retest (experiments, branch bluetooth-mgmt-mesh-tx-leak-retest)

Reviewed 2026-10-06: branch tip `977b3a1`, 11 commits on `origin/empty`, all by the project
author. Every file was read except the four kernel configs; those were diffed against each
other and against our validation config.

## What was checked, and how

| Item | Check | Result |
|---|---|---|
| Same patch | `sha256sum cache/hui-peng-validation/14831271.mbox` | `a044131c…f8c2`, identical to `kernel/patch-mbox.sha256` |
| Same postimage | `kernel/mesh-tx-leak-fix.diff` vs `git diff 036d4119079a 19fdd346e00c` | both `index aea3482e3..e73dc9c2f`, same hunk |
| Control and patched configs identical | `diff config-control config-patched`, `diff config-diag-control config-diag-patched` | no output for either |
| Diag builds differ only by kmemleak | `diff config-control config-diag-control` | only `CONFIG_DEBUG_KMEMLEAK=y` and its three options |
| Their config vs ours | `diff tmp/mesh-tester-ci/config-val-btnext-control kernel/config-control` | very different: theirs is x86_64_defconfig + tester.config (SMP, NO_HZ, cgroups, audit, KASAN_INLINE …); ours is tester.config alone |
| Delay knob | `kernel/test-only-mesh-send-delay.patch` | `msleep()` between `mgmt_mesh_add()` and `hci_cmd_sync_queue()`, under `hci_dev_lock()`, only when `!sending`; equivalent to ours |
| kprobe offset `+40` for `mgmt_mesh_tx.handle` | `mgmt_util.h:20-28` at `036d4119079a` | list 16, index 4 (+4 pad), param_len 8 at 24, sk 8 at 32, handle at 40: correct for this base |
| A2 mechanism | `hci_sock.c:2185-2187`, `mgmt.c:10989-11006`, `mgmt_util.c:426` | confirmed: cleanup of a socket's entries runs only from `hci_sock_destruct()`, which cannot run while an entry holds `sock_hold(sk)` |
| A3 completion seen by socket B | `mgmt.c:1084-1094` | `mgmt_event(…, NULL)` broadcasts Mesh Packet Complete to every control socket, so B seeing A's handle is expected; the cross-socket damage is B's own packet started twice (`mesh_send_sync=2` for handle 2) |
| `mesh_pending` frees | `git grep mesh_pending 036d4119079a -- net/bluetooth` | no use in any unregister or power-off path; only add, foreach, next and remove |

## Findings

**Agreements with our record.** Every behaviour the reply states reproduces on their
kernels, legacy and extended advertising, one and four CPUs, unmodified mgmt-tester 503/503 and
mesh-tester 8/10 on both kernels with the same two `Send cancel` timeouts.

**New facts worth having** (not in our record):
1. A3 cross-socket effect: a failed send on a socket that is then closed still makes another
   socket's next packet start twice (`close-reuse`, both advertising types).
2. The failslab stack filter (`require` `mesh_send`, `reject` `mgmt_mesh_add`) with a dumped
   call trace placing the failure in `hci_cmd_sync_submit()`; a cleaner method than our
   fail-nth calibration, and stable on 4 CPUs (ours was not, validation-extra-paths E).
3. kprobe evidence that `hci_sock_destruct` never runs for the failing socket on the unpatched
   kernel and does on the patched one.

**Problems to fix before this is published further or linked from a mail.**

1. **The cited logs are not in the branch.** REPORT cites `results/logs/*` throughout;
   `bluetooth/mesh-tx-leak/.gitignore` excludes `logs/` and no `results/logs/` was committed.
   Only the generated summaries are there. The paths in the scripts (`/home/user/work`) and
   "TCG, no KVM" show the runs were made elsewhere. Without the logs the claims have no
   exhibit; the summaries carry one run per scenario and no hashes.
2. **One run per scenario.** 72 VM runs = 36 main + 24 diag + the first-pass and probe runs:
   each scenario ran once per kernel. Our record has 5 runs per case. Fine for a retest, but
   the report should say so.
3. **A5 overstates.** "The kmemleak claim for -ENETDOWN and -ENODEV only holds when the slab
   caches are shrunk" contradicts our record: plain scans (two, after the tester process had
   exited) reported the `mgmt_mesh_add()` objects for -ENETDOWN (`x2 size 96`, both runs) and
   -ENODEV (1 object, 3/3 runs), validation-extra-paths C. Their scans run while the reproducer
   process is still alive, on a very different config. The accurate statement: in this setup
   plain scans missed them; detection depends on procedure and config.
4. **A4 overstates.** "Busy is permanent for that socket": the per-socket count drops when any
   transmission on the controller completes a stale entry, and A3 shows another socket can
   start one. Permanent only while no other socket transmits.
5. **A third-party address.** REPORT line 5 quotes the patch's Message-ID, which contains the
   author's address; our repository's scan refuses it. Use the patchwork number and a lore
   link by number, or elide the address.
6. **It reviews an unsent draft as "the reply".** Once public it reads as a critique of a mail
   that has not been sent, and several of its "leaves out" items (A1 BlueZ revision, A7 how
   the adapter was powered off, A8 method details) are exactly what the reply leaves to the
   linked material. Recast as a standalone report of the retest.
7. **A separate kernel finding is public.** A2 states that nothing frees `hdev->mesh_pending`
   on unregister and that a pending entry pins its socket, so socket close never cleans up.
   That holds for accepted requests too, with the patch (our extra-paths E: 23 objects on the
   patched kmemleak kernel). It is a bug beyond Hui's patch, and the standing rule keeps such a
   finding private until a patch exists. It is already public in the experiments repository.
   Moving it into this repository, and linking it from the mailing list, would broadcast it.
8. Smaller: hard-coded `/home/user/work` in four scripts; `+40` offset valid only for this
   struct layout (comment says so); `emu` written without atomics in the main loop while the
   worker reads it atomically (harmless here); repository-level ATTRIBUTION.md, INSTRUCTIONS.md
   and `tools/check-attribution.sh` belong to that repository, not this one.

## Recommendation

Bring `bluetooth/mesh-tx-leak/` into this repository as its own directory (history kept by
reference to `977b3a1`), after: the logs are committed with SHA256SUMS (problem 1), REPORT is
recast as a standalone retest report with A4 and A5 corrected (3, 4, 6), and the Message-ID is
elided (5). Leave the three repository-level files behind. Whether A2 stays in the published
report is the operator's decision (7); if it stays out, keep it in the private record.

For the reply, at most two additions: one sentence that the leaked entry also holds a
reference on the MGMT socket, so closing the socket does not free it (within the patch's own
bug, and it corrects the patch's commit message); and one line pointing to the reproducer,
logs and configs once they are published. The cross-socket effect is optional.
