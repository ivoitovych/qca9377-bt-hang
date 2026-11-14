# CO-20 patch 1 as a standalone mail (2026-11-14, lane 6)

`WA` = `/root/exp/agent-work/lane6-btusb-20261114/`. `WA/out/co20/0001-Bluetooth-btusb-Report-SCO-receive-failures-by-cause.patch`,
the package's patch 1 unchanged, on `da3cc02587c6` (`git apply --check` OK; branch `l6-co20` in `WA/lx2`). No Signed-off-by,
no cover letter, no `Fixes:`. It does not use anything from patch 2. Patch 2 is held; see `NOTES.md`.

## Emulator, base against patch 1 alone (`harness/spec-co20.txt`, `run-batch-usbip.sh`)

Kernels (`img/*.commit`): `base-u` = `da3cc02587c6`, `co20p1` = base + patch 1 only. Emulator `harness/usbip-bt-emu.py`
(lane 1's, with a new judge `--expect p1`: no "corrupted SCO packet", at least one "unknown handle dropped", no
debug "closed handle" line). `rx-cycles`: 20 calls, one mSBC link with data in flight at the hang-up. `rx-unknown`: two
links up, five packets injected for a handle that never was a link. Three runs each; `logs/summaries/co20.txt`: 12 of 12 PASS
(base judged `--expect noisy`: "corrupted SCO packet" present; patched: absent).

| | base-u | co20p1 |
|---|---|---|
| rx-cycles, "corrupted SCO packet" / "unknown handle dropped", runs 1, 2, 3 | 21/0, 21/0, 24/0 | 0/19, 0/10, 0/15 |
| rx-unknown (5 injected), run 1 | 6/0 | 0/6 |

("unknown handle dropped" is rate limited, so it is lower than the number of rejected packets.)

Per-run counts are the `COUNTS` lines of `logs/runs/*c20-*.log`. As the patch says, the closed link's residue is still an
error (now the rate-limited "unknown handle dropped") and still counts in `err_rx`: patch 1 changes the message only.

## checkpatch `--strict --no-tree`

`ERROR: Missing Signed-off-by: line(s)`, `total: 1 errors, 0 warnings, 0 checks, 67 lines checked`.

## Bot CI

See the end of this file (appended after the run).

### Bot CI (run locally, out/bot-results/co20/)

Same setup, base da3cc02587c6. Patched: CheckPatch, VerifySignedoff, GitLint FAIL (only the missing Signed-off-by);
VerifyFixes PASS; SubjectPrefix, BuildKernel, CheckAllWarning, CheckSparse, BuildKernel32, CheckKernelLLVM,
TestRunnerSetup, IncrementalBuild PASS. Base: the six tree checks PASS.
