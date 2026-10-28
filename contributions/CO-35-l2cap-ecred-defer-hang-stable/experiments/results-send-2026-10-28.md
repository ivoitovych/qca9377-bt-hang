# CO-35 — checks of the send package, 2026-10-28

Package: `send/request-v2.eml`, `send/6.18.y/`, `send/6.12.y/`, `send/6.6.y/` (`send/README.md`).
Scripts in the worker's `tmp/co35/`; the full output of the last run of every mechanical check is
`tmp/co35/logs/verify-package-20261028T213015Z.txt` (`tmp/co35/verify-package.sh`, run
2026-10-28 21:30:15 UTC on the final mails; sections 1, 2, 4, 5 below are its output).

## How the series were made

```
$ git -C cache/linux worktree add --detach /root/exp/agent-work/co35/am-6.18.y v6.18.59   (also 6.12.114, 6.6.160)
$ git -C …/am-6.18.y -c user.name="Iaroslav Voitovych" -c user.email=… am backports/6.18.y/0001-… backports/6.18.y/0002-…
Applying: Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and locking helpers
Applying: Bluetooth: L2CAP: hold conn->lock for __l2cap_ecred_conn_rsp_defer
(the same two lines for 6.12.y and 6.6.y; git am takes no fuzz)
$ git -C …/am-6.18.y format-patch --cover-letter --subject-prefix="PATCH 6.18.y" --base=v6.18.59 -o send/6.18.y v6.18.59..HEAD
(likewise 6.12.y with v6.12.114, 6.6.y with v6.6.160)
```
The covers' "*** SUBJECT HERE ***" and "*** BLURB HERE ***" were then written by hand; their
shortlog, diffstat and `base-commit:` lines are format-patch's. The editor dropped the trailing
space of format-patch's "-- " signature line; `tmp/co35/fix-sig.py` restored it (one line per
cover; `git diff --check` reports exactly those three lines as trailing whitespace, as intended).

## 1. The mailed code is the tested code

```
$ tmp/co35/tree-match.sh
am-6.18.y base=v6.18.59
  patch 1 tree 9a118537a420706aa542643975561502c73df0f5 tested 9a118537a420706aa542643975561502c73df0f5 SAME
  patch 2 tree f8c50d772cdb037bc4073293b32eed6706d3db8c tested f8c50d772cdb037bc4073293b32eed6706d3db8c SAME
am-6.12.y base=v6.12.114
  patch 1 tree b1c644d0fef18275d227eead0ae1f071bdd239e7 tested b1c644d0fef18275d227eead0ae1f071bdd239e7 SAME
  patch 2 tree d5ae4282962083a58853595dbea312bd46b6fade tested d5ae4282962083a58853595dbea312bd46b6fade SAME
am-6.6.y base=v6.6.160
  patch 1 tree 3ffb8966a6988dfefb84ac8a3473d1fb4652c36e tested 3ffb8966a6988dfefb84ac8a3473d1fb4652c36e SAME
  patch 2 tree 1c9ce210e2d801f89ab48b1166b8111f8d74feec tested 1c9ce210e2d801f89ab48b1166b8111f8d74feec SAME
```
"tested" = the tree of the commits built and run in `results-backports-2026-10-28.md`
(`601d1caa6833`/`c953b83a7c8c`, `2140180eb76d`/`c2ce0cd7e717`, `3e08be30f4fd`/`e9334dba491f`).

```
$ python3 -I scripts/patch-code-compare.py backports/<line> send/<line>      (each line)
6.18.y: 0001 code IDENTICAL, patch-id e9f3fc9991400f98 / e9f3fc9991400f98; 0002 code IDENTICAL, patch-id cc164bd1e65c0b5b / cc164bd1e65c0b5b
6.12.y: 0001 code IDENTICAL, patch-id e9f3fc9991400f98 / e9f3fc9991400f98; 0002 code IDENTICAL, patch-id 3f878ced940dad64 / 3f878ced940dad64
6.6.y : 0001 code IDENTICAL, patch-id 07f7fad21c2c14e4 / 07f7fad21c2c14e4; 0002 code IDENTICAL, patch-id 3f878ced940dad64 / 3f878ced940dad64
RESULT: the code is identical in every pair      (printed once per line; "message: changed" for each)
$ diff backports/<line>/000N-… send/<line>/000N-…     (each of the six)
```
Every difference is the `From <hash>` line (new commit ids from git am) and the subject prefix,
`[PATCH 1/2]` → `[PATCH 6.18.y 1/2]` etc. (with the subject's line fold moved). Nothing else.

Why the commits cannot go as they are to 6.18.y/6.12.y/6.6.y (patch 1's annotations):
```
$ git -C cache/linux grep -c -E "define __must_not_hold|define __context_unsafe" v7.3 v6.18.59 v6.12.114 v6.6.160 -- include/linux/compiler-context-analysis.h include/linux/compiler_types.h
v7.3:include/linux/compiler-context-analysis.h:2
```
(no match on the three older tags.)

## 2. checkpatch.pl (v7.3's, run inside the v7.3 tree; `tmp/co35/checkpatch-all.sh`)

| file | result |
|---|---|
| upstream `608e0b7a675b2` | 0 errors, 1 warning: "The commit message has 'syzkaller', perhaps it also needs a 'Fixes:' tag?" |
| upstream `32d86e048d8ef` | 0 errors, 0 warnings |
| each line's patch 1 (6.18.y, 6.12.y, 6.6.y) | 1 error, 1 warning: the error on `[ Upstream commit 608e0b7a675b2affbbf38167cad0fa63d8e064f7 ]` ("Please use git commit description style 'commit <12+ chars of sha1> ("<title line>")'"), the warning upstream's own (syzkaller) |
| each line's patch 2 | 1 error: the same, on `[ Upstream commit 32d86e048d8efedb7aa6cbbd3c36c3c435401c92 ]` |

The error is the known false positive: `stable-kernel-rules.rst` (option 3) prescribes exactly
that line. No other finding.

## 3. scripts/ci-local.sh --kernel, backport mode (`tmp/co35/ci-all.sh`)

`--tree cache/linux --base bluetooth-next/master` (47d4d9f67e92, 2026-10-23), checkpatch from the
v7.3 tree, no `--build`; the stable tags were present with history, so VerifyFixes ran.
Summaries `tmp/co35/ci-local-<line>-final/summary.txt`:

```
6.18.y  target v6.18.59 1253a6aa5d104312bf0992afacc15220ae35bdf9
  am                 PASS          all 2 patch(es) apply to v6.18.59 with git am
  am-bluetooth-next  EXPECTED      does not apply to bluetooth-next/master — expected for a backport: upstream commit 608e0b7a675b2affbbf38167cad0fa63d8e064f7 is in bluetooth-next/master already
  checkpatch         NEW           (the two [ Upstream commit ] errors and upstream's syzkaller warning, as in §2)
  gitlint            NEW           1: T1 Title exceeds max length (82>80): "[6.18.y,1/2] Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and locking helpers"
  subjectprefix      PASS          every subject carries "Bluetooth: "
  verifyfixes        PASS          verify_fixes.sh 1253a6aa5d104312bf0992afacc15220ae35bdf9..HEAD: no complaint
  verifysignedoff    PASS          verify_signedoff.sh 1253a6aa5d104312bf0992afacc15220ae35bdf9..HEAD: no complaint
6.12.y  target v6.12.114 85d82e0d7c2dfd3e75d34f35b7ebbf41f45c9c4e
  am PASS; am-bluetooth-next EXPECTED; checkpatch NEW (as §2); gitlint NEW (82>80, "[6.12.y,1/2] …")
  subjectprefix PASS; verifysignedoff PASS
  verifyfixes        NEW           Commit: 4fb59e1e36a07 ("Bluetooth: L2CAP: hold conn->lock for __l2cap_ecred_conn_rsp_defer")
                                   Fixes tag: Fixes: ab4eedb790ca ("Bluetooth: L2CAP: Fix corrupted list in hci_chan_del")
                                   Has these problem(s): - Target SHA should be an ancestor of your tree
6.6.y   target v6.6.160 0aebf2870d53a8d97e02a99e2103ea0b38950c1b
  am PASS; am-bluetooth-next EXPECTED; checkpatch NEW (as §2); gitlint NEW (81>80, "[6.6.y,1/2] …")
  subjectprefix PASS; verifysignedoff PASS
  verifyfixes        NEW           (the same message for b42fc29c7c939)
```
(6.12.y and 6.6.y condensed here; their summary files hold every line.) Reading:
- **gitlint T1:** the BlueZ bot's limit (80) on "[<line>,1/2] " plus upstream's 69-character
  subject; the subject must stay upstream's. Expected on any stable backport of this commit
  that is copied to linux-bluetooth, where the bot runs.
- **VerifyFixes on 6.12.y/6.6.y:** `ab4eedb790ca` is there as its backport (`f87271d21dd4e`,
  `efc30877bd4bc`; `tmp/co35/in-lines.sh`), not as an ancestor; the `Fixes:` line is upstream's
  and stays. The covers name the backport ids.
- Not run: `--build` (BuildKernel, W=1, C=1, 32-bit). The series were built (tester.config,
  x86_64) and run in the backport round; a W=1/C=1/32-bit build of the backports was not made.

## 4. mail-lint (`tmp/co35/lint-mails.sh`)

```
== request-v2.eml
clean: headers present, body within 72 columns, ASCII, no trailing whitespace
== 6.18.y cover (checked copy …/tmp/co35/lint/cover-6.18.y.eml)
clean: headers present, body within 72 columns, ASCII, no trailing whitespace
== 6.12.y cover (checked copy …/tmp/co35/lint/cover-6.12.y.eml)
clean: headers present, body within 72 columns, ASCII, no trailing whitespace
== 6.6.y cover (checked copy …/tmp/co35/lint/cover-6.6.y.eml)
clean: headers present, body within 72 columns, ASCII, no trailing whitespace
```
The covers are checked as copies with "To: stable@vger.kernel.org" added after From: and cut at
format-patch's "-- " line (`lint-mails.sh`'s header); the 0001/0002 patch mails are not
mail-linted (their diff lines are code, checked by checkpatch).

## 4a. Where each factual statement of the mails comes from

| statement | source |
|---|---|
| both commits in mainline, 7.4 merge window, no `Cc: stable` | `results-7.3-and-older` §1 (origin/master 21:07 UTC; no v7.4-rc1 tag), the commits' messages |
| patches 2 and 7 of the 16-patch series | §4 there (the series cover on lore) |
| never finishes on v7.3, v7.2.13, v6.18.59, v6.12.114, v6.6.160 | §2 there (v7.3, case alone); `tmp/l2cap-hang/logs/try-7.2.13-plain.log`, `try-618-ctl.log`, `try-612-ctl.log`, `try-66-ctl.log` (each ends with "Accept deferred setup sk = 34" and `exit=124`) |
| hung-task observation (v7.3; v6.1.190 in the request) | §5 there |
| cherry-pick cleanly onto v7.3 and v7.2.13 | §2 there (`pick-check.sh`) |
| 111 of 111 on v7.2.13 | `results-2026-10-28.md` §4 (`full-bt10-7.2.13-608e-32d8.log`: "Total: 111, Passed: 111") |
| 111 of 111 on v7.3 with `5874f8d03268` | §2 there (`fullall-7.3-sci-pair.log`) |
| SCI stall on v7.3 with or without the pair | §2 there |
| 6.1.y/5.15.y/5.10.y: ECRED off by default; with it on, never finishes; commits do not apply | §3 there |
| per-line totals, failing cases also failing on the base, BT_PHY/ENOPROTOOPT on 6.18 | `results-backports-2026-10-28.md`; failure reasons re-read with `tmp/co35/fail-reasons.py` (6.18.59: 18 of 18 "setsockopt(BT_PHY): Protocol not available (92)"; 6.6.160: 26 PHY, 3 TX timestamping, 2 ethtool, 1 PIN-code timeout; 6.12.114: 69 of 78 "Operation not supported (95)") |
| "No lockdep or KASAN report in either" | `kernel-report-scan.py`: the backport runs (`results-backports-2026-10-28.md`) and the base controls `try-618-ctl.log`, `try-612-ctl.log`, `try-66-ctl.log`, `try-7.2.13-plain.log`: "clean" each (re-run 21:32 UTC); v7.3 logs: §2 |

## 5. Subjects in send order

```
Subject: Please backport 608e0b7a675b and 32d86e048d8e (Bluetooth: L2CAP) to 7.3.y and 7.2.y
Subject: [PATCH 6.18.y 0/2] Bluetooth: L2CAP: fix the deferred ECRED accept hang
Subject: [PATCH 6.18.y 1/2] Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and locking helpers
Subject: [PATCH 6.18.y 2/2] Bluetooth: L2CAP: hold conn->lock for __l2cap_ecred_conn_rsp_defer
Subject: [PATCH 6.12.y 0/2] Bluetooth: L2CAP: fix the deferred ECRED accept hang
Subject: [PATCH 6.12.y 1/2] Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and locking helpers
Subject: [PATCH 6.12.y 2/2] Bluetooth: L2CAP: hold conn->lock for __l2cap_ecred_conn_rsp_defer
Subject: [PATCH 6.6.y 0/2] Bluetooth: L2CAP: fix the deferred ECRED accept hang
Subject: [PATCH 6.6.y 1/2] Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and locking helpers
Subject: [PATCH 6.6.y 2/2] Bluetooth: L2CAP: hold conn->lock for __l2cap_ecred_conn_rsp_defer
```
(the empty line the script printed after each cover's subject, from its two-line unfold, is
left out.) Not done here: the mailer's dry run (the main session's).
