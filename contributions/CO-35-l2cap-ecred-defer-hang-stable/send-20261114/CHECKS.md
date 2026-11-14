# CO-35 refresh against today's stable tips, 2026-11-14 (UTC)

Work area: `/root/exp/agent-work/lane5-status-stable-20261114/co35/` (scripts at the top level, logs in `logs/`, kernel images in `img/`, mails in `mail/`; hashes in `SHA256SUMS`). Nothing was sent. The project tree was not written to.
"measured" = run today, log named; "from source" / "inferred" as marked. Tests: QEMU/KVM, 4 vCPUs, BlueZ `doc/tester.config` plus `CONFIG_DETECT_HUNG_TASK`, 20 s; one guest at a time; `make -j4`; scripts `build.sh`, `run-test.sh`, `run-all.sh`, `run-extra.sh` (the 2026-11-02 scripts, paths changed). Kernel trees: depth-1 fetches of the tags from the GitHub mirror (`k-fetch.sh`, log `logs/k-fetch.log`), because the project's `cache/linux` is a partial clone that cannot be cloned with `--shared`.

## 1. Facts (measured)

| what | value | source |
|---|---|---|
| newest tags | v7.3.4 (2026-11-10), v6.18.63 (11-10), v6.12.117 (11-10), v6.6.162 (11-06), v6.1.192 (11-06); mainline v7.4-rc2 (11-09) | kernel.org `releases.json` 2026-11-14 00:40Z; `git ls-remote` tips equal the tags |
| the pair in mainline | both in v7.4-rc1 and in master (commit dates 2026-10-14 17:24 and 17:25 UTC) | `gh api repos/torvalds/linux/commits/<sha>`; `l2cap_core.c` history of v7.4-rc2 and master |
| the pair in a stable release or queue | not in v7.3.4, v6.18.63, v6.12.117, v6.6.162, v6.1.192; `stable-queue-check.sh` for `bluetooth-l2cap-hold-conn-lock-for` and `bluetooth-l2cap-add-l2cap_chan_close_unlocked`: "not in queue" for 7.3, 6.18, 6.12, 6.6, 6.1 (2026-11-14 01:05-01:06 UTC) | `raw/command-outputs.txt` of the status check |
| `5874f8d03268` (SCI fix) on 7.3.y | **still not there**: not among the 100 newest `net/bluetooth` commits of v7.3.4 (`gh api`), not in queue-7.3 (`stable-queue-check.sh bluetooth-fix-the-le-read-connection-interval`, 01:21 UTC), and `git cherry-pick -x 5874f8d03268` onto v7.3.4 is not empty (5 insertions, 12 deletions in `hci_event.c`, `hci.h`) | `logs/apply-v7.3.4.log` |
| 7.3.4 newly has nearby L2CAP commits | `d3afd7803f9b` "refuse __l2cap_chan_add if chan already has conn" (10-30), "Reject mode changes on connected channels", TxWindow fixes (11-10) | `gh api commits?sha=v7.3.4&path=net/bluetooth`; they did not disturb the pair (next row) |

## 2. Does the pair apply today (measured, `logs/apply-<tag>.log`)

| tag | how | result |
|---|---|---|
| v7.3.4 | `git cherry-pick -x 608e0b7a675b2 32d86e048d8ef` (auto-merging `l2cap.h`, `l2cap_core.c`, `l2cap_sock.c`) | rc=0, clean; 5 files with the SCI fix added (`5874f8d03268` also clean) |
| v6.18.63, v6.12.117, v6.6.162 | `git am` of the unchanged 2026-11-02 backports (strict, no fuzz, no 3-way) | rc=0 on all three; the six patch files are byte-identical to `send-20261102/` (`cmp`, `logs/mail-lint-new.log`), so nothing was regenerated |
| v6.1.192, v5.15.225, v5.10.274 (not requested) | `git cherry-pick -x` of the pair (`logs/apply-old-*.log`) | patch 1 applies textually; **patch 2 conflicts in `net/bluetooth/l2cap_sock.c`** on all three. These lines have no `l2cap_chan_lock_conn()` and lack `ab4eedb790ca`; not built, not tested today. The 11-02 statement that the pair "does not apply" is confirmed for the pair as a whole |

## 3. Builds and tests (measured; times in `progress.log`)

Case "L2CAP Ext-Flowctl Server - Accept 2 Close 1" alone, 180 s limit (`logs/case-<tag>-<variant>.log`, `logs/summary-*.txt`):

| tag | plain (base) | with the pair | counts on 2026-11-02 |
|---|---|---|---|
| v7.3.4 | **HANG** (limit 180 s; hung-task reports: 7) | Passed 1.007 s; with the SCI fix too, 1.025 s; with the pair plus `dc1ddc65f06d`, 1.040 s | v7.3.1: hang; pass 1.034 / 1.040 s |
| v6.18.63 | **HANG** (7) | Passed 1.242 s | v6.18.60: hang (7); 1.067 s |
| v6.12.117 | **HANG** (7) | Passed 1.041 s | v6.12.115: hang (7); 1.074 s |
| v6.6.162 | **HANG** (7) | Passed 1.113 s | v6.6.161: hang (7); 1.036 s |

Whole l2cap-tester (`logs/full-*.log`):

| image | today | 2026-11-02 |
|---|---|---|
| v7.3.4 + pair + `5874f8d03268` | **111 of 111 passed** (all 8 SCI cases pass) | v7.3.1: 111 of 111 |
| v7.3.4 + pair alone | stalls at "L2CAP LE Client - SCI Fast Mode" ("test timed out", kernel log "Invalid response length for 0x20a3" once), run killed at 300 s | v7.3.1: stalls in the same case |
| v6.18.63 + pair | 93 passed, 18 failed (all "Set PHY") | 93 / 18 |
| v6.12.117 + pair | 79 passed, 32 not passed (one of them timed out: "BR/EDR Client PIN Code Change Sec - Success") | 79 / 31 + 1 timed out |
| v6.6.162 + pair | 79 passed, 32 not passed (same one timed out) | 79 / 31 + 1 |

Kernel-report scan (`kernel-report-scan.py`): all patched runs "clean" (no lockdep, KASAN or hung-task report); base runs `hung-task=7`. Build warnings in `net/bluetooth`: `logs/btwarn-*.log` (empty = none). Not rerun today: the plain-tag whole-tester runs (they cannot finish: the case hangs), so "all other non-passes are pre-existing on the plain tag" still rests on the 2026-11-01 pooled verdicts; the tester config has hung-task detection only (no separate lockdep/KASAN build) - as before.

Answer to the open questions: 7.3.y, 6.18.y, 6.12.y and 6.6.y all have the bug today (hang without the pair on each tip). The pair applies as it is to 7.3.4; the three backports apply and pass on 6.18.63, 6.12.117 and 6.6.162. 6.1.y/5.15.y/5.10.y: the dossier's finding stands (hang with `enable_ecred`, since v6.3), the pair does not apply, not covered, not retested.

## 4. checkpatch and other local checks (measured, `logs/checks.log`)

checkpatch.pl from the v7.3.4 tree: upstream `608e0b7a675b2`: 0 errors, 1 warning (commit message has "syzkaller", as before), 132 lines; `32d86e048d8ef`: 0 errors, 1 warning "Unknown commit id 'ab4eedb790ca'" (an artefact of the depth-1 tree; on 2026-11-02 in a full tree: 0 warnings), 88 lines; `5874f8d03268`: same artefact for `2f8784cfe8a9`. Each line's patch 1: 1 error (the `[ Upstream commit ... ]` line stable prescribes) + the syzkaller warning, 130 lines; patch 2: the same one error + the artefact, 88 (6.18.y) or 81 lines (6.12.y, 6.6.y). Same findings as 2026-11-02 and 2026-10-28. mail-lint: clean for both new requests and the three new covers (`logs/mail-lint-new.log`). Subjects: 63 and 76 columns including "Subject: ".

`ci-local.sh --kernel` was **not rerun**: it works in `cache/linux` (a worktree there), which this lane must not write to. What it checked on 2026-11-02 is covered here as far as possible: am on the tag (section 2, PASS), checkpatch (above), SubjectPrefix and VerifySignedoff are unchanged by the files (patches byte-identical); gitlint (title 82/82/81 > 80 with the stable-line prefix) and VerifyFixes (`ab4eedb790ca` present as a backport on 6.12.y and 6.6.y, not as ancestor) are properties of the unchanged files and are expected to repeat. Rerun it from the main session if the exact CI output is wanted.

## 5. Follow-ups F-33 to F-39, F-85, F-91

| id | status today |
|---|---|
| F-33 drop 7.2.y | done on 11-02; 7.2.y is EOL (7.2.15); the new mails name 7.3.y only |
| F-34 both commits in v7.4-rc1, one batch, newest line first | commits in v7.4-rc1 re-verified today (section 1). The batch order (newest line first) is the sender's: nothing to write |
| F-35 one sentence on `dc1ddc65f06d` | in the request and the covers; its "the case passes with and without it" is now re-measured on v7.3.4 (1.040 s) |
| F-36 `Fixes:` origin sentence | decided on 11-02 (one neutral sentence kept); kept; operator may still delete it |
| F-37 non-pass breakdown to one sentence | done on 11-02; unchanged |
| F-38 shorten mail 1's subject | done (63 columns) |
| F-39 recheck queues and newest tags on the send day | done for today (section 1); **must be repeated on the actual send day** |
| F-85 rerun checkpatch and local CI | checkpatch rerun (section 4); local CI not rerun (reason above) |
| F-91 drop the patch-id identity claim | no identity claim in the mails (grep over `mail/`: none); the history documents named on 11-02 (README line 6, log.md, send/README.md, experiments/results-send-2026-10-28.md) are outside this lane and still need it |

## 6. New mail text (new files; the old ones are kept in `send-20261102/`)

`mail/request-v4-20261114.eml` (7.3.y request: v7.3.4 in place of v7.3.1), `mail/request-sci-7.3.y-20261114.eml` (v7.3.4, queue check time 2026-11-14 01:21 UTC), `mail/6.18.y|6.12.y|6.6.y/0000-cover-letter-20261114.patch` (tag names v6.18.63, v6.12.117, v6.6.162; `base-commit` of each tag; counts unchanged) and the unchanged patches 0001/0002 beside them. The old 6.1.y/5.15.y/5.10.y paragraph keeps the earlier test tags (v6.1.190, v5.15.223, v5.10.272) because those lines were not retested.
Differences from the 11-02 text are only the release numbers and dates, plus the removal of "in v7.3.1" from the `dc1ddc65f06d` sentence in the request (it now reads as a general statement, which the 11-02 note said held at all four tags and today's v7.3.4 `l2cap_ecred_rsp_defer()` matches by source).
