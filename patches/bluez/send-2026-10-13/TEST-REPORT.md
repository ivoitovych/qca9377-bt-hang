# BlueZ A1 and A2: pre-send checks, builds, unit tests, static analysis, emulator testers

Date: 2026-10-13, 06:22:46 to 06:49:42 (CEST), on the laptop (16 CPUs, KVM).

**What was not done on the host:**
- nothing was sent, posted, mailed or pushed;
- no kernel module was loaded, unloaded or rebound;
- no tester, bluetoothd, rfkill or `/dev/vhci` was touched.

Every tester and unit test ran inside a QEMU guest started by BlueZ's own `tools/test-runner`.
There was no commit, amend or rebase in any BlueZ tree by the test run, and the patches were not
edited. The A1 message was amended afterwards by the maintainer; see the addendum at the end.

Labels: verified (command and output here or in the named log), inferred (reasoning given),
not done.

Scripts and logs are in `/root/exp/qca9377-bt-hang/tmp/bluez-a1a2-20261013/`. `progress.log`
has start and end per step; `step.sh` writes the command, start, end and exit status into each
log.

## Summary

| check | base | A1 | A2 | verdict |
|---|---|---|---|---|
| pre-send-check against fetched master `9dc7e4096` | — | applies, OK to send | applies, OK to send | pass |
| checkpatch with BlueZ's `.checkpatch.conf` | — | 1 ERROR `GIT_COMMIT_ID` (first message; fixed, addendum) | 0/0 | A2 pass; A1 pass after the amend |
| gitlint with BlueZ's `.gitlint` | — | no violations | no violations | pass |
| `./bootstrap-configure` + `make -j16`, `-Werror` | exit 0, 0 warnings, 3 notes | same | same | no new warning |
| make check programs, run in the guest | 41 pass, 1 skip (mesh-crypto), 1813 cases pass | identical | identical | 0 of 1852 differ |
| UBSan reports in unit programs | 7 sites | same 7 | same 7 | pre-existing, unchanged |
| smatch, whole tree | 124 lines incl. VLA at `btdev.c:479:29` | 124 (only a2dp.c line shifts) | 123, VLA gone | as expected |
| clang analyzer on touched files | btdev.c 2, a2dp.c 4 | a2dp.c the same 4 | btdev.c the same 2 | nothing new |
| 11 emulator testers in QEMU/KVM, two rounds | 853 of 861 pass | not run (no emulator change) | 853 of 861, the same 8 fail | 0 of 860 case names differ |
| A2 positive control | — | — | 3 entries: abort in mgmt-tester's first case; 0 entries: abort in l2cap-tester's first connect | the check fires |
| `if (!setup->stream)` in `transport_cb()` | 2 | 1 | — | as intended |

## Observations

1. **A1's first message failed checkpatch** with `ERROR:GIT_COMMIT_ID` on "0bed9886cff3 and
   d84171e6cd68 add the same check". Bare commit ids need the `commit <sha> ("<title>")` form.
   The bot's `ci/checkpatch.py` (bluez/action-ci `60348956fc7b`) marks any `ERROR:` as FAIL.
   Fixed: see the addendum.
2. **A2's bound check compiles to nothing today.** Both callers pass constants (2 and 1), so gcc
   folds it away: `btdev.o` has no `__assert_fail` reference. It guards future callers only.
   BlueZ never defines `NDEBUG`.
3. **The 3-entry mutant needed `-Wno-error`.** It failed `-Werror=array-bounds` in an unrelated
   inlined function (`le_per_adv_new` into `cmd_pa_create_sync`), which surfaces once the assert's
   failure path is reachable. The real A2 build is clean.
4. **A stray `ltmain.sh`** (git-ignored) was left in the project root by libtoolize during the
   first configure attempt.
5. **`tools/test-runner` exits 0 even when the tester aborts.** Every verdict here comes from the
   parsed summaries.
6. **Failures on both sides identically** (environment):
   - `unit/test-mesh-crypto` skips (no AF_ALG AEAD in the guest kernel);
   - 4 mgmt-tester Ext Advertising cases fail or time out;
   - mesh-tester "Send cancel" 1 and 2 time out (unpatched control kernel, bluetooth-next of
     2026-10-05).
7. **Upstream nits, not ours:**
   - `configure.ac:50` tests `"LSAN_LIB"` without `$`;
   - `unit/test-avrcp` registers 3 test names twice;
   - ioctl-tester registers "Set Pkt Type - 2-DH" twice.

## States

| state | commit | build/unit/tester/clang tree | smatch tree |
|---|---|---|---|
| base | `9dc7e40962f1` | `cache/bluez-a1a2-base-20261013` | `cache/bluez-a1a2-smatch-base-20261013` |
| A1 (as tested) | `dc4dbbcb2c9d` | `cache/bluez-a1a2-a1-20261013` | `cache/bluez-a1a2-smatch-a1-20261013` |
| A2 | `694d9cba194f` | `cache/bluez-a1a2-a2-20261013` | `cache/bluez-a1a2-smatch-a2-20261013` |

**Tools:**
- gcc 13.3.0, clang 18.1.3, QEMU 8.2.2;
- ell 0.83 (`002b32d7c091`);
- smatch `5e13a0ee549b` (the CI image's pin, built here);
- gitlint 0.19.1;
- checkpatch.pl 0.32 (bluetooth-next `8abc0fb87492`).

**Guest kernel:** `tmp/mesh-tester-ci/bzImage-val-btnext-control`, "Linux version
7.3.0-rc2-00486-g036d4119079a", built from `doc/tester.config` (BT_HCIVHCI=y, KASAN=y, UHID=y).
The same kernel was used on every side.

## Per task (abridged from the run's own report; full logs in `logs/`)

**1. format-patch.** `--subject-prefix="PATCH BlueZ" --base=origin/master`, written to
`patches/a1`, `patches/a2`; base-commit `9dc7e40962f11d1d9a5568f8a7633a695288329c`.

**2. pre-send-check.** A1, A2 and both as a series: "applies … yes", "OK to send", exit 0.

**3. checkpatch and gitlint.**
- A1 (first message): 1 error, 0 warnings:
  `ERROR:GIT_COMMIT_ID: Please use git commit description style 'commit <12+ chars of sha1> ("<title line>")' …`
- A2: 0 errors, 0 warnings.
- gitlint: both PASS.

**4. Builds.** Maintainer mode (`-Wall -Werror -Wextra`), with `--enable-testing` and
ASan/LSan/UBSan. Exit 0 on all three sides, with the same 3 notes ("variable tracking size limit
exceeded") and a diagnostics diff of exit 0.

**5. Unit tests in the guest.** Not run on the host, because `unit/test-uhid` would auto-load
`uhid` and `test-mesh-crypto` would auto-load `algif_aead`. 42 programs per side; 1852 case
names; identical verdicts.

**6. Static analysis.**
- **smatch:** base vs A2 differs only by the VLA line; base vs A1 only by shifted "see line"
  numbers. The bot posts only keys equal to touched relative paths, so it would show PASS for
  both (inferred).
- **clang `--analyze` per file:** the same reports, line-shifted only.

**7. A2 testers in QEMU, two rounds.**

| tester | passed (base and A2) |
|---|---|
| mgmt | 504/508 |
| l2cap | 111/111 |
| sco | 30/30 |
| iso | 141/141 |
| mesh | 8/10 |
| smp | 8/8 |
| bnep | 1/1 |
| rfcomm | 11/11 |
| ioctl | 28/28 |
| userchan | 4/4 |
| 6lowpan | 9/9 |

- 0 case names differ, in either round.
- UBSan in mgmt-tester, on both sides: `tools/mgmt-tester.c:7929:9` and `7977:8`.
- No ASan report, abort or assertion.

**8. Positive control.** In the throwaway worktree `cache/bluez-a1a2-a2-mutant-20261013` (an
uncommitted mutation, later removed), both mutants abort with:
`emulator/btdev.c:486: send_cmd: Assertion 'iovlen > 0 && iovlen <= SEND_CMD_IOV_MAX' failed.`
- 3 entries: mgmt-tester, status 134.
- 0 entries: l2cap-tester, status 134.

**9. A1.** `transport_cb()` has 2 checks on base (lines 2747 and 2752) and 1 on A1 (line 2747).

**Not done:**
- literal `make check` on the host;
- scan-build itself (the same analyzer was run per file);
- sparse;
- testers on A1.

**Left in place:**
- six worktrees `cache/bluez-a1a2-{base,a1,a2}-20261013` and
  `cache/bluez-a1a2-smatch-{base,a1,a2}-20261013`;
- `cache/smatch`, `cache/sqlite3-dev`, `cache/action-ci-bluez`;
- `cache/action-ci` (an old fork, unused).

## Addendum (maintainer, after the run)

A1's message was amended to the required form, with no code change:
`transport_cb() checks setup->stream twice in a row: commit 0bed9886cff3 ("a2dp: Fix crash on NULL stream in transport_cb") and commit d84171e6cd68 (...) add the same check. Remove the second copy.`

- New commit `ddc71e8b3` on `send/a1-a2dp-cleanup-20261013`; the mail is in `patches/a1-v2/`.
- `lint-a1v2.sh`: checkpatch "0 error(s), 0 warning(s), 0 check(s)", gitlint "PASS no
  violations", exit 0.
- `pre-send-check.sh` on `patches/a1-v2` + `patches/a2` against `9dc7e4096`: both "applies …
  yes", "OK to send".
- The diff is byte-identical to the tested `dc4dbbcb2`, so tasks 4, 5, 6 and 9 still apply.
