# BlueZ A1, A2 (newa) and the assert alternative: re-test on master fa6ba5502

Date: 2026-10-18, 02:11:53 to 03:32:42 (CEST), on the laptop (16 CPUs, KVM). A new run on
the new base; the 2026-10-13 numbers are not carried over.

**What was not done on the host:** nothing was sent, posted, mailed or pushed; no kernel
module was loaded, unloaded or rebound; no tester, bluetoothd, rfkill or `/dev/vhci` was
touched. Every tester and unit program ran inside a QEMU guest started by BlueZ's own
`tools/test-runner`.

Labels: verified (command and output in the named log), inferred (reason given), not done.
Scripts and logs: `/root/exp/qca9377-bt-hang/tmp/bluez-a1a2-20261018/` (`logs/`, 323
files; `SHA256SUMS`, itself sha256 `5a271ee4…db214`; `REPORT.md`). Kept on the machine
that ran them, with the raw build and tester logs. The summaries each table row rests on
are published in [`logs/`](logs/): the tester comparison (`final-compare.log`), unit
comparison (`unit-compare.txt`), build diagnostics (`build-compare.log`), smatch
(`smatch-all.log`), clang (`clang-all.log`), `-DNDEBUG` (`ndebug.log`), object code
(`obj-check.log`), the stream checks (`stream-checks.log`), and the final mails' lint and
apply checks (`final-mails.log`; its exit 1 is `mail-lint` on a raw `format-patch` file:
no `To:` header yet, the `@@` hunk header line over 72 columns, and the blank context
lines and `-- ` signature read as trailing whitespace). This project's own CI does not
run any BlueZ test; it checks this repository.

## Sides

| side | commit | what |
|---|---|---|
| base | `fa6ba5502` | BlueZ master, 2026-10-14; re-fetched 2026-10-18, unmoved |
| A1 | `9d0cd5ca3` | the 5-line removal; message then titled "a2dp: Remove duplicate stream check" |
| A2-assert | `37b76b9be` | fixed array + `assert()` (the alternative, not to send) |
| A2-newa | `3fda3b0f2` | `newa()`; message then titled "emulator: Fix smatch warning in send_cmd" |

The final A1 (`9963bb547`) and A2 (`50b231ceb`) differ from the tested A1 and A2-newa only
in their messages: `git diff --stat` between each pair prints nothing.

## Summary

| check | base | A1 | A2-assert | A2-newa | verdict |
|---|---|---|---|---|---|
| pre-send-check, alone and A1+A2 as a series | — | OK to send | OK to send | OK to send | pass |
| checkpatch, BlueZ `.checkpatch.conf` | — | 0/0 | 0/0 | 1 WARNING `EMAIL_SUBJECT` (subject fixed since; final 0/0) | pass after the fix |
| gitlint, BlueZ `.gitlint` | — | PASS | PASS | PASS | pass |
| `-Werror` maintainer build, ASan/LSan/UBSan | exit 0, 0 warnings, 3 notes | same | same | same | diagnostics diff exit 0 |
| A2-assert built with `-DNDEBUG` | fails at `tools/mesh-cfgclient.c:252` | — | the same single failure; its `btdev.o` is clean | — | nothing new from A2 |
| unit programs in the guest | 41 pass, 1 skip, 1813 cases | identical | identical | identical | 0 of 1852 names differ |
| smatch, whole tree | 124 lines incl. the VLA | 124 (a2dp.c lines shift) | 123, VLA gone | 123, VLA gone | no new line |
| clang `--analyze`, touched files | btdev.c 2, a2dp.c 4 | same 4 | same 2 | same 2 | nothing new |
| 11 emulator testers, two rounds | 843 of 866 case names pass | not run | identical | identical | 0 of 5196 verdicts differ (866 names × 3 sides × 2 rounds) |
| `if (!setup->stream)` in `transport_cb()` | 2 (lines 2747, 2752) | 1 | — | — | as intended |

The smatch line on base, verbatim (`logs/smatch-base/make.log`):
`emulator/btdev.c:479:29: warning: Variable length array is used.` Gone on both A2 sides.
No smatch line mentions `alloca`, `newa` or `assert`.

Per tester, by case name, the same on every side and in both rounds
([`logs/final-compare.log`](logs/final-compare.log)): mgmt 501/514, l2cap 103/111, sco
30/30, iso 141/141, mesh 8/10, smp 8/8, bnep 1/1, rfcomm 11/11, ioctl 27/27, userchan
4/4, 6lowpan 9/9; 843 of 866. The 23 that do not pass are named in that log: 15 killed
on the 6.2 emulator (7 mgmt, 8 l2cap), 4 mgmt Ext Advertising, 2 mgmt Scan RPA, 2 mesh
"Send cancel" (observation 2). ioctl-tester registers one name twice, so its own summary
says "Total: 28, Passed: 28" and the testers' own totals add up to 844 of 867.
(Corrected 2026-10-18: this report first said 845 of 866 and "ioctl 28/28".)

## Observations

1. **What the compiler emits** (`logs/obj-check.log`). A2-assert: no `__assert_fail`
   (both callers pass constants, 2 and 1) and a fixed frame for `send_cmd()`. A2-newa: a
   variable-size stack allocation (`sub %rax,%rsp`), as on base. It clears the warning,
   not the allocation.
2. **Failures identical on every side, base included (environment or upstream):**
   - Testers on the 6.2 emulator stall with this guest kernel since master `02aa5ea21`
     and `8ebf7ffe7`, which add a `min` byte to the reply to 0x20a3; the guest kernel
     (bluetooth-next of 2026-10-05) logs `Invalid response length for 0x20a3`, the case
     times out and its teardown never returns (inferred from the diff and that message).
     mgmt-tester and l2cap-tester were therefore run one process per case, 30 s each; the
     15 such cases (7 mgmt, 8 l2cap) are killed alike on every side. They passed on 10-13.
   - Two mgmt-tester cases new since master `dd9d5ba1f` (2026-10-14) fail: "Scan RPA -
     Auto-connect with IRK" and "Background report with IRK". Not investigated.
   - As on 10-13: `unit/test-mesh-crypto` skips (no AF_ALG AEAD in the guest kernel);
     4 mgmt-tester Ext Advertising cases fail; mesh-tester "Send cancel" 1 and 2 time out.
3. **Upstream, found on the way:** with `-DNDEBUG` the whole tree fails to build:
   `tools/mesh-cfgclient.c:260` calls `strftime()` inside `assert()`, so with asserts off
   `tm` is unused and `buf` would be printed uninitialised. Not ours; a candidate for a
   separate fix.
4. **Sanitizers:** unit programs, the same 11 UBSan lines at 7 sites on all four sides;
   testers, UBSan only in mgmt-tester (`mgmt-tester.c:7929` ×5, `7977` ×1), identical in
   all 6 logs. No ASan report and no assertion failure anywhere.
5. `tools/test-runner` exits 0 even when a tester aborts; every verdict comes from the
   parsed per-case results.

## Not done

- A2-assert's positive control (its 10-13 mutant run, in `../send-2026-10-13/TEST-REPORT.md`,
  was not repeated).
- Testers on A1 (no emulator change).
- A literal `make check` on the host; scan-build itself; sparse.
- The CI bot's checkpatch.pl version, and the kernel side of the 0x20a3 length check.
- A verdict for the 15 cases on the 6.2 emulator, on any side.

## Tools

gcc 13.3.0, clang 18.1.3, QEMU 8.2.2; smatch `5e13a0ee549b`; gitlint 0.19.1; checkpatch.pl
from bluetooth-next (`cache/full-bt-next`); guest kernel
`tmp/mesh-tester-ci/bzImage-val-btnext-control` ("7.3.0-rc2-00486-g036d4119079a",
`doc/tester.config`), the same on every side.
