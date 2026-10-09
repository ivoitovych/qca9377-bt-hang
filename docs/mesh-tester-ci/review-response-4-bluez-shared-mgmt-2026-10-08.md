# BlueZ shared/mgmt fix: fourth outside review (2026-10-08)

Reviewed: `ff23b5a` (series `d418103ef`/`1ca5067ee` on BlueZ master `d84171e6c`). Nothing has
been sent.

Result on `standalone/shared-mgmt-notify-leak-on-d84171e6c`: `9fbc84f5d` (fix) and
`5880a6874` (tests), exported to
`patches/mesh-tester/bluez-shared-mgmt-notify-leak-on-d84171e6c-2026-10-08/`. The reviewed
state is kept on `keep/shared-mgmt-notify-leak-on-d84171e6c-1ca5067ee` and its export in
`patches/mesh-tester/bluez-shared-mgmt-notify-leak-on-d84171e6c/`.
`src/shared/mgmt.c` is unchanged (blob `f5aeecf3f`); `unit/test-mgmt.c` is now blob `7de612b58`
(`git diff 1ca5067ee 5880a6874`: 19 insertions, 20 deletions, test file only).

## Findings and actions

| # | Finding | Checked | Action |
|---|---|---|---|
| 1 | The new test trips the clang static analyzer (`unit/test-mgmt.c:571: Assigned value is garbage or undefined`); the base file is clean, and the CI bot's ScanBuild diffs base against patched | Reproduced with `clang --analyze` (clang 18) and the tree's flags: series 1 warning, base `test-mgmt.c` 0, `mgmt.c` 0 (`logs-clang-analyze-2026-10-08/`) | taken: the expected call counts move into `struct unregister_test` (`.expected`), `unregister_run()` loses a parameter. After: 0 warnings |
| 2 | Blank line before and after the `for` in `unregister_all_from_cb()` (coding style M1) | Agreed | taken |
| 3 | `++` inside `g_assert_cmpuint()` in `unregister_destroy()` | Agreed | taken: increment, then assert |
| 4 | Patch 1, paragraph 1: "only marks it removed" | Agreed | "marks it removed instead of freeing it" |
| 5 | Patch 1, paragraph 3: "it" changes referent; say no caller checks the return value | Verified: `git grep "mgmt_unregister("`: the testers call it bare; `mesh_mgmt_unregister()` returns it to `mesh/mesh-io-mgmt.c:462–463`, which ignore it | taken, with the subject named and "No caller checks the return value." |
| 6 | (First reviewer's nit) quoted title broken across lines | — | paragraph 2 reflowed so `("shared/mgmt: Fix crash when removing index")` sits on one line; still checkpatch's `commit <sha> ("<title>")` form |
| 7 | Patch 2: first sentence needs a second read; list the cases by name, as accepted `unit/` commits do | Agreed | cases listed one per line. The reviewer's draft said each case checks the in-notification clauses; `/mgmt/unregister/6` unregisters outside a notification and never calls `unregister_check_alive()`, so the message says "In /3 to /5" and states /6 separately |
| 8 | Optional: the fix as a +8/−2 change in the function's existing shape | Behaviour equivalent | not taken: `mgmt.c` stays as three reviews and the QEMU tester runs saw it |
| 9 | Add the static analyzer to the pre-send gate | Agreed | `tmp/mesh-tester-ci/clang-analyze.sh <tree> <file> <label>` (scan-build itself is not installed; `clang --analyze` is the same checker per file) |
| 10 | a2dp duplicate guard on master | Already prepared (`dd8d241`, `patches/bluez/cleanup/`) | operator's decision, SEND.txt item 3 |

## Follow-up: list format in patch 2 dropped (`0722ddc78`)

The operator questioned the `- /mgmt/unregister/N` list. Measured with `tmp/bullet-survey.py`
(non-merge commits; a body counts if any line starts with `- `, `* ` or `1.`; trailers excluded):

| tree, paths, period | commits | `- ` | `* ` | numbered | no list |
|---|---|---|---|---|---|
| BlueZ, all, 2015–2020 | 4095 | 1.0% | 0.1% | 0.4% | 98.5% |
| BlueZ, all, 2021–2025 | 3002 | 1.7% | 0.1% | 0.7% | 97.5% |
| BlueZ, all, 2026 | 765 | 6.8% | 0.1% | 0.7% | 92.7% |
| kernel `net/bluetooth` + `drivers/bluetooth`, 2018–2023 | 1868 | 1.9% | 0.6% | 1.7% | 95.9% |
| kernel `tools/testing/selftests`, 2018–2023 | 10025 | 3.5% | 1.4% | 1.4% | 93.8% |

The three list examples the reviewer cited (`ed0b991aa`, `9f5adb00c`, `c1e0079c9`) are all from
2026. The older tradition of a case list in `unit/` exists (`tmp/commit-bodies.py`,
28 test-addition commits since 2023): Frédéric Danis's `unit/test-hfp` series of 2025
(`- /HFP/HF/...` with an indented description) and Prathibha Madugonde's RAP tests list PTS
cases. Small additions of one to four tests are written as one or two prose sentences
("Verify that ..."). GitHub's red lines are its diff highlighter on the `.patch` file; mail,
lore and patchwork show the message as plain text, and `git am` takes it as written.

Action: patch 2 back to prose, naming the cases (`/mgmt/unregister/3 to /5`, `/6`) and keeping
every fact; the first sentence the reviewer flagged is rewritten. Code unchanged
(`git diff 5880a6874 0722ddc78` empty); the list version is kept on
`keep/shared-mgmt-notify-leak-on-d84171e6c-5880a6874`. checkpatch 0/0, gitlint PASS, no line
over 72, `pre-send-check.sh` OK on `d84171e6c`.

## Checks at `5880a6874`

* `clang-analyze.sh`: `r4-test-mgmt` 0 warnings (was `series-test-mgmt` 1; `base-test-mgmt` 0;
  `series-mgmt` 0).
* `unit-mgmt-run.sh`: `r4-fixed` all 13 PASS; `r4-unfixed` (base `mgmt.c` checked out, then
  restored): unregister/3 FAIL `test-mgmt.c:480:unregister_check_idle … (0 == 1)`, unregister/4
  FAIL `AddressSanitizer: heap-use-after-free` (`#0 queue_foreach src/shared/queue.c:206`),
  unregister/5 FAIL `test-mgmt.c:540 … (1 == 0)`, the other 10 PASS.
* `make -j16 check`: `# TOTAL: 42`, `# PASS:  41`, `# SKIP:  1`, `# FAIL:  0`, `# ERROR: 0`.
* `bluez-lint.sh`: checkpatch `0 errors, 0 warnings` (35 and 237 lines); gitlint `PASS` both.
  No message line over 72 columns; no code line over 80.
* `pre-send-check.sh`: origin/master `d84171e6c`; both apply in order; `OK to send`.
* Tester runs: not repeated; `mgmt.c` is unchanged and the testers do not use `unit/test-mgmt.c`.
