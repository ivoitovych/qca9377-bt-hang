# Evidence behind E's and A's CHECKS.md

Copied on 2026-11-14 from the work area `/root/exp/agent-work/co43-ea-send-20261113/` (`stress/`
and `scripts/`, unchanged except as noted), so that what `E/CHECKS.md` and `A/CHECKS.md` cite is
in the repository and not only on one disk. Paths inside the files still name that work area,
where the runs happened; the kernel images and build trees stayed there.

**Changed on copy (wording only, no result):**
- `stress/logs/ea-base-st-3.log` and `stress/logs/ea-e-st-3.log`, last line: qemu's
  "terminating on signal 15 from pid 4343 (…)" named the process that stopped the guest; it now
  reads "(the harness)". `stress/SHA256SUMS` carries the new hashes; the old ones were
  `a6c5377d…6320c` and `db89a3a4…c5766`.
- `scripts/build-ea.sh` and `stress/kernels/build-ea.sh`, line 7: a comment now reads "another
  build may be running".
- `stress/harness/run-bt23-and-controls.sh`, line 18: the grep for timeouts read `tx timeout`;
  it now reads `command( 0x[0-9a-f]+)? tx timeout`, the one spelling the repository's test suite
  allows for timeout counts. The six `stress/logs/ea-*-dbg-bt23-*.log` it reads hold no "tx
  timeout" line of either kind (`grep -c`: 0 each, 2026-11-14; the parked command shows as
  `failed: -110` and the harness's `RESULT` line), so the summary it writes is the same.
- `scripts/summarize-stress.py`: given its executable bit, as its shebang says.
