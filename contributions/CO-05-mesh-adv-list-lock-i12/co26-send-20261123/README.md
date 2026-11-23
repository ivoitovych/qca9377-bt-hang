# CO-26 standalone send package of 2026-11-23

CO-26 was 2/2 of CO-05's series. CO-05 1/2 is overtaken: on bluetooth-next, `1d7a52778858` makes
`mesh_send_sync()` take `hdev->lock`. CO-26 is still needed. On the tip a failed add sets `err`, and
`mesh_send_sync()` then schedules the instance that was never added, which returns `-ENOENT` in place of the
real error. This package sends it alone.

**The patch.** It is regenerated on bluetooth-next `cf357cfc025e` (`git am`, then `format-patch --base`).
The patch-id equals that of `../review-fixes-20261114/` (`c03eac506a29…`), so the code is unchanged. The
message changes in three ways: no "2/2", the trace names the tip, and a testing note goes below `---`. It
comes in two variants, which differ in one line. Choosing one is the operator's call:
- `variant-A-with-fixes/` keeps `Fixes: b338d91703fa`;
- `variant-B-without-fixes/` drops it. The message already says it is a cleanup of the error path, not a
  change a client sees.

**Checked on the tip** (`net/bluetooth/mgmt.c` and `hci_core.c` at `cf357cfc025e`):
- `hci_add_adv_instance()` fails only when the instance does not exist yet (`-EOVERFLOW` or `-ENOMEM`). So
  without the patch the later `hci_schedule_adv_instance_sync()` finds no instance and returns `-ENOENT`,
  unless an `-EPERM` or `-EBUSY` comes first.
- `mesh_send_start_complete()` reports any error the same way: a Mesh Packet Complete event, which carries
  no status. So the message's "the same event in both cases" holds on the tip.

**Fault injection rerun, 2026-11-23** (QEMU, tester config with KASAN and lockdep plus kprobe events):
- **Method:** a test-only module parameter makes the first mesh add fail (`evidence/apply-co26-knob.py`,
  never in a patch). A kprobe trace covers the start path (`evidence/co05-guest.sh`). BlueZ mesh-tester runs
  with `-s Send`, 3 guests per kernel.
- **Base, 3 of 3:** `hci_add_adv_instance` returns `-12`, then `hci_schedule_adv_instance_sync(instance 6)`
  returns `-2`, `mesh_send_sync` returns `-2`, and `mesh_send_start_complete(err=-2)` runs.
- **With CO-26, 3 of 3:** `hci_add_adv_instance` returns `-12`, `mesh_send_sync` returns `-12`, and
  `mesh_send_start_complete(err=-12)` runs. There is no schedule call.
- **The `-s Send` set:** 4 of 5 pass on both kernels. "Mesh - Send", whose add is the one made to fail, times
  out on both; the other four pass on both. So the injection, not the patch, decides that case.
- **Knob off:** full mesh-tester 10 of 10 on both. Full mgmt-tester 528 of 531 on both. The 2 failures are the
  CO-38 and CO-44 cases, whose kernel fixes these images lack. The 1 not run is the same on both.
- **Reports:** no kernel report in any log.
- **Scripts:** `evidence/` (build, run, knob, kprobes fragment, guest script). Raw logs stay machine-local.

**checkpatch** `--strict --no-tree --no-signoff`: 0 errors. Variant A has only the "unknown commit id"
warning that `--no-tree` gives; variant B has no warning.

**A neighbouring defect, kept out on purpose** (an outside recheck, 2026-11-23 evening). A few lines above the
change, `mesh_send_sync()` returns `MGMT_STATUS_BUSY` (0x0a, a positive MGMT status) where an errno is expected
(bluetooth-next `mgmt.c` l.2462). `mgmt_status()` reads a positive value as an HCI status: 0x0a is "Max Number
of SCO Connections", so it becomes `MGMT_STATUS_NO_RESOURCES`. The Mesh Packet Complete event carries no status,
so nothing is visible. CO-26 stays one change. A separate one-liner (`-EBUSY`) is a candidate, and whether to
make it is the operator's call.

**Fixes: variant:** reviewers 2, 3 and 7 prefer A, with `Fixes:` and no `Cc: stable` (all three confirmed in the focused round of 2026-11-23 evening). Their reason: `Fixes:`
records a real bug's origin, whatever user space sees. Reviewer 1 prefers B. The stable rules document
`Cc: <stable+noautosel@kernel.org> # reason` for keeping a fix out of automatic selection, an option only one
reviewer suggests (`../../../reviews/2026-11-23T2100Z-fixes-and-stable-trailers-question.md`).

**Still to do:** the operator's choice of A or B, the Signed-off-by, the bot's checks and a dry run.
Recipients: `get_maintainer.pl` at send time. CO-26 is fifth in the queue (`BRIEF.md`, hand-off).
