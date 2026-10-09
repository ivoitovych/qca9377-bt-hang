# Review of the reworked retest (experiments, branch bluetooth-mgmt-mesh-tx-leak-retest, round 2)

Reviewed 2026-10-06: tip `a3858e6`, six new commits on top of `977b3a1`. Read in full: both
READMEs, REPORT.md, every changed script and the reproducer diff, `audit-logs.sh`,
`kmemleak-after-exit.sh`, `run-kmemleak-reps.sh`, `tabulate-reps.py`; logs read in full:
`control/` and `patched/busy-drain-legacy-1cpu`, `reps-diag-control/` and
`reps-diag-patched/enetdown-after-exit-r1`, `control/enomem-trace-legacy-1cpu`. Every other log
was checked by regenerating everything derived from it.

## Mechanical checks

`tmp/mesh-tester-ci/retest-verify.sh <kit> tmp/mesh-tester-ci/retest-verify-out`:

| Check | Result |
|---|---|
| `audit-logs.sh logs` vs committed `results/audit.txt` | identical; `AUDIT OK`, exit 0 |
| `summarize.py logs control patched` vs `summary-main.md` | identical |
| `summarize.py logs diag-control diag-patched` vs `summary-kmemleak.md` | identical |
| `tabulate-reps.py logs diag-control diag-patched` vs `summary-kmemleak-reps.md` | identical |
| log count | 139 (control 21, patched 21, diag-control 12, diag-patched 12, first-pass 6, probe 4, reps-diag-control 45, reps-diag-patched 18), matching REPORT's arithmetic |
| errnos in all logs | `-100` ×72, `-12` ×53, `-19` ×32 |
| e-mail addresses | only the author's own, in the delay patch's `From:` |
| MAC-like strings (our scan's regex) | three, only in the two mgmt-tester logs, all BlueZ test constants: the address `{0x00, 0x01, 0x02, 0x03, 0x04, 0x05}` of mgmt-tester.c:2736 and 2787; the address with bytes `0x11 0x34 0x56 0x78 0x9a 0xbc` in mgmt-tester.c; and the emulator's own address, which emulator/btdev.c:440 builds with `bdaddr[4] = 0xaa`. Our scan refuses all three as written in the logs |
| IPv4, UUIDs | none |

## Earlier findings (round 1), status

| # | Round 1 | Now |
|---|---|---|
| 1 | Cited logs missing | Fixed: all 139 logs committed, audit regenerates identically |
| 2 | One run per scenario, unstated | Fixed: stated in README, REPORT "Runs" and Caveats; kmemleak cases repeated 5× / 2× |
| 3 | A5 overstated (plain scans miss) | Fixed: S9 now "depending on when kmemleak scans"; after-exit plain scans 5/5 for every errno, in-process plain 0/5 for -ENETDOWN and -ENODEV; agrees with our record |
| 4 | A4 "Busy permanent" | Fixed: O3/O4 measure and state that another socket's transmission clears it |
| 5 | Third-party address in a Message-ID | Fixed: patchwork link only |
| 6 | Critique of an unsent mail | Fixed: "statements S1–S12", "a set of test results reported for the patch" |
| 7 | Separate kernel finding published | Mostly fixed: the unregister statement is gone and O1/O4 are scoped to the failed request. One sentence remains general (O1: "Pending requests are cleaned up only in the socket's destructor … which cannot run while that reference is held"); it describes every pending request, not only failed ones |
| 8 | Hard-coded paths, repository-level files | Fixed: `WORK`/`BLUEZ` variables; ATTRIBUTION.md and INSTRUCTIONS.md removed; root README added |

## New content, verified

* **O3, failed requests transmitted later** (`busy-drain`). Control log: after three
  powered-off failures (handles 1–3) and one Busy, socket B's first send (handle 4) produces
  completions 1,2,3,4; kprobes `handle=2 … mesh_send_sync=1`, `handle=3 … mesh_send_sync=1`,
  `handle=4 … mesh_send_sync=2`; controller `tag=2 adv_data_writes=1`, `tag=3
  adv_data_writes=1`, `tag=11 adv_data_writes=2`. Patched log: handles 1–3 `mesh_send_sync=0`,
  tags 1–3 `adv_data_writes=0`. Requests answered Failed reach the air on the unpatched kernel.
  This is new to us and within the patch's own bug.
* **S9 by scan method**: after-exit logs show the `mgmt_mesh_add` object from round 2 on
  control, nothing on patched (both r1 read in full).
* **Injection trace**: the dumped failure is `__kmalloc_cache_noprof` ← `hci_cmd_sync_submit`
  ← `mesh_send`; while that report is printed, the console's `alloc_buf` is failed too (the
  `times` counter is decremented after the dump). REPORT's caveat covers it; the Bluetooth
  result is one failure in `hci_cmd_sync_submit()`.
* **Socket kept alive (O1)**: `after_teardown … hci_sock_destruct=1` on control, `=2` on
  patched, in every kmemleak log read; the first count is the reproducer's `HCIGETDEVINFO`
  socket.

## Remaining points (small)

1. O1's general sentence (status 7 above): rescope to "the failed request's own reference
   keeps the socket's destructor, which is where its requests are cleaned up, from running".
2. The root README calls it "an independent retest"; the author is the same person as the
   reply's. "A separate retest" is accurate.
3. `run-kmemleak-reps.sh` does not aggregate failures the way `run-matrix.sh` now does.
4. O3 and O2 rest on one run per advertising type per kernel (sequential, deterministic);
   say so where they are stated, as the Caveats already do in general.

## Recommendation

Merge as a **squashed copy** of `bluetooth/mesh-tx-leak/` at `a3858e6` into this repository
(for example `retest/mesh-tx-leak/`), with the commit message naming the source commit. A
subtree import would carry the branch's earlier history, which contains the first REPORT with
a third-party address in a Message-ID and the unscoped kernel finding. The publish scan needs
the three BlueZ test addresses above added to its allowlist as exact addresses (this review
had to describe them by source location to pass the scan itself); the raw logs stay unedited.

For the reply, the facts maintainers can use:
* requests answered Failed are later transmitted when another socket sends (O3);
* the leaked entry holds the MGMT socket, so closing the socket does not release it (O1,
  scoped);
* one line pointing to the reproducer, configs and logs.
