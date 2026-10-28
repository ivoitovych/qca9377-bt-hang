# CO-35 — 7.3.y, 7.2.y, the older lines and the backports' bases re-checked, 2026-10-28 (evening)

Method as `results-2026-10-28.md` and `results-backports-2026-10-28.md`: QEMU/KVM, 4 vCPUs
(`tmp/mesh-tester-ci/qemu-smp.sh`), BlueZ's `doc/tester.config` kernels, BlueZ trees as for CO-02
(`cache/co02-w2c-bluez` runner, `cache/co02-bluez/tools/l2cap-tester`). Differences:
- builds with `make -j6` (`tmp/co35/build-tree.sh`, a copy of `tmp/co02-w2c/build-tree.sh`);
- **the case alone, by its exact name.** test-runner joins the tester's arguments with spaces
  into `TESTARGS` and the guest runs them through `sh -c`, so a multi-word `-s` name reaches the
  tester as its first word ("L2CAP": the whole suite up to the case or a hang;
  `tmp/l2cap-hang/run-one.sh`'s header). Here the command is a wrapper,
  `tmp/co35/case-accept2close1.sh`, that runs `l2cap-tester -s "L2CAP Ext-Flowctl Server - Accept 2
  Close 1"`; the guest log shows only that case (`Total: 1`);
- full runs as before (`-s L2CAP`, 900 s limit; `tmp/co35/run-case.sh <image> <log> 900 word L2CAP`);
  later runs use `run-case2.sh`, the same plus two modes for the lines before v6.2 (§3).

Scripts, images and logs of this round: `tmp/co35/` in the worker's checkout (git-ignored, like
`tmp/l2cap-hang/`), logs in `tmp/co35/logs/` with `SHA256SUMS`. All checks were made on
2026-10-28 between 20:33 and 21:35 UTC.

## 1. The stable lines' newest tags and the queue (no newer tag since the backports)

```
$ git -C cache/linux fetch stable linux-7.3.y:refs/remotes/stable/linux-7.3.y … linux-5.10.y:…   (rc 0)
$ tmp/co35/tips.sh
7.3.y  tag=v7.3       tip=c03c1a14507df 2026-10-18 Linux 7.3
7.2.y  tag=v7.2.13    tip=3c172eede0d6b 2026-10-26 Linux 7.2.13
6.18.y tag=v6.18.59   tip=1253a6aa5d104 2026-10-26 Linux 6.18.59
6.12.y tag=v6.12.114  tip=85d82e0d7c2df 2026-10-21 Linux 6.12.114
6.6.y  tag=v6.6.160   tip=0aebf2870d53a 2026-10-21 Linux 6.6.160
6.1.y  tag=v6.1.190   tip=79807e970724c 2026-10-15 Linux 6.1.190
5.15.y tag=v5.15.223  tip=792fbe1537d8d 2026-10-15 Linux 5.15.223
5.10.y tag=v5.10.272  tip=aca95a35f1bcc 2026-10-15 Linux 5.10.272
checked 2026-10-28 20:33 UTC
```

Re-fetched 7.3.y and 7.2.y at 21:08 UTC: `tips.sh` printed the same eight lines ("checked
2026-10-28 21:08 UTC"). `https://www.kernel.org/releases.json` (20:33 UTC) agrees: mainline 7.3, stable 7.2.13, longterm
6.18.59, 6.12.114, 6.6.160, 6.1.190, 5.15.223, 5.10.272; none EOL. 7.3.y has no release yet;
its branch is at v7.3.

```
$ scripts/stable-queue-check.sh bluetooth-l2cap-add-l2cap_chan_close_unlocked 7.3 7.2 6.18 6.12 6.6 6.1 5.15 5.10
7.3    not in queue
7.2    not in queue
6.18   not in queue
6.12   not in queue
6.6    not in queue
6.1    not in queue
5.15   not in queue
5.10   not in queue
checked 2026-10-28 20:34 UTC against https://git.kernel.org/pub/scm/linux/kernel/git/stable/stable-queue.git/tree/queue-<v>
$ scripts/stable-queue-check.sh bluetooth-l2cap-hold-conn-lock 7.3 7.2 6.18 6.12 6.6 6.1 5.15 5.10
(the same eight "not in queue" lines)
checked 2026-10-28 20:34 UTC against https://git.kernel.org/pub/scm/linux/kernel/git/stable/stable-queue.git/tree/queue-<v>
$ scripts/stable-queue-check.sh net-call-getsockopt_iter 6.12 7.3        (positive control)
6.12   QUEUED  net-call-getsockopt_iter-if-available.patch
7.3    not in queue
```

`queue-7.3` exists in stable-queue (its tree listing, 20:35 UTC), so "not in queue" for 7.3 is a
real answer.

```
$ tmp/co35/in-lines.sh 608e0b7a675b2 32d86e048d8ef ab4eedb790ca     (ancestor, else same subject)
== 608e0b7a675b2 "Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and locking helpers"
  7.3.y  absent
  7.2.y  absent
  6.18.y absent
  6.12.y absent
  6.6.y  absent
  6.1.y  absent
  5.15.y absent
  5.10.y absent
== 32d86e048d8ef "Bluetooth: L2CAP: hold conn->lock for __l2cap_ecred_conn_rsp_defer"
  7.3.y  absent
  7.2.y  absent
  6.18.y absent
  6.12.y absent
  6.6.y  absent
  6.1.y  absent
  5.15.y absent
  5.10.y absent
== ab4eedb790cae "Bluetooth: L2CAP: Fix corrupted list in hci_chan_del"
  7.3.y  ancestor
  7.2.y  ancestor
  6.18.y ancestor
  6.12.y by subject: f87271d21dd4e
  6.6.y  by subject: efc30877bd4bc
  6.1.y  absent
  5.15.y absent
  5.10.y absent
checked 2026-10-28 20:36 UTC
```

No one has asked the stable team for the pair either: a lore search over all lists for
`32d86e048d8e OR "hold conn->lock for __l2cap_ecred_conn_rsp_defer"` (2026-10-28 21:00 UTC,
`curl -A qca9377-bt-hang/check …&x=A`, HTTP 200; `tmp/co35/atom-list.py`) returns 9 messages:
the upstream series and its bot replies (2026-08-29 to 09-02), the BlueZ test patch (09-01), and
the pull requests "[GIT PULL] bluetooth-next 2026-10-14" and "[GIT PULL] Networking for 7.4"
(10-22). None on the stable list.

Mainline, re-fetched 21:07 UTC (`git fetch origin master`: `8a36f53fd5ec3..c339f4010dea8`): tip
`c339f4010dea8` 2026-10-28 "Merge tag 'platform-drivers-x86-v7.4-1' …", no v7.4-rc1 tag yet;
`git merge-base --is-ancestor 32d86e048d8ef origin/master`: exit 0. So "in mainline since the
7.4 merge window" still holds.

BT-14's fix is not on the 6.12.y branch either (`git log -n 1 stable/linux-6.12.y -- net/socket.c`:
`c770217044d9c 2026-06-19 net: Drop the lock in skb_may_tx_timestamp()`; `5bd0dec150f56` would
touch that file) and is still in `queue-6.12` (above, QUEUED).

Consequences: **step 2 (7.2.y)** and **step 4 (6.18.y, 6.12.y, 6.6.y)** need no rerun: no newer
tag, the tested bases are still the newest; no 6.12.y release carries `5bd0dec150f56` yet
(BT-14 still limits 6.12's totals).

## 2. 7.3.y: v7.3 with and without the pair

Builds (`tmp/co35/step1-builds.sh`, `builds-2.sh` → `pick-build.sh`, worktree
`/root/exp/agent-work/co35/linux-7.3.y`; `git cherry-pick --no-commit` in the order given):
```
v7.3 plain                                   make rc=0  bzImage-bt10-7.3-plain     09501f27638a32f8…
v7.3 + 608e0b7a675b2 + 32d86e048d8ef          make rc=0  bzImage-bt10-7.3-pair      b9fb56d0528231920…
  Auto-merging include/net/bluetooth/l2cap.h / net/bluetooth/l2cap_core.c / net/bluetooth/l2cap_sock.c
  3 files changed, 121 insertions(+), 25 deletions(-)        (no conflict)
v7.3 + 5874f8d03268                           make rc=0  bzImage-bt10-7.3-sci       66ff407dfcd0577d…
v7.3 + 5874f8d03268 + the pair                make rc=0  bzImage-bt10-7.3-sci-pair  9d455b6a03c5c102…
```
(full SHA-256 in `tmp/co35/img/SHA256SUMS`; no `net/bluetooth` warning in any build log.)

The same pick on every requested base, as a three-way merge without a worktree (what `git
cherry-pick` does):
```
$ tmp/co35/pick-check.sh v7.3 v7.2.13 v6.18.59 v6.12.114 v6.6.160
v7.3: both pick cleanly; result tree d7ad7b02664b0b3372e8d94cfd4e77940af75816
 3 files changed, 121 insertions(+), 25 deletions(-)
v7.2.13: both pick cleanly; result tree c41c74fc14fcf0cc0d97d9fa0b4d8a99f7ebe61e
 3 files changed, 121 insertions(+), 25 deletions(-)
v6.18.59: both pick cleanly; result tree 55388e595040106fe4419c0738cc32e856c1f75c
 3 files changed, 121 insertions(+), 25 deletions(-)
v6.12.114: 32d86e048d8efedb7aa6cbbd3c36c3c435401c92 CONFLICTS after 608e0b7a675b2affbbf38167cad0fa63d8e064f7
CONFLICT (content): Merge conflict in net/bluetooth/l2cap_sock.c
v6.6.160: 32d86e048d8efedb7aa6cbbd3c36c3c435401c92 CONFLICTS after 608e0b7a675b2affbbf38167cad0fa63d8e064f7
CONFLICT (content): Merge conflict in net/bluetooth/l2cap_sock.c
```
(per-file stat lines omitted; 6.18.59 picks cleanly but does not build, `results-2026-10-28.md`
§5.) This matches the request: 7.3.y and 7.2.y take the commits as they are, the older lines
need the backports.

**The case alone** (`run-case.sh … 180 exact`):
```
bzImage-bt10-7.3-plain [exact ]: HANG (limit 180 s)
…/case-7.3-plain.log  kernel=7.3.0  clean
bzImage-bt10-7.3-pair [exact ]: L2CAP Ext-Flowctl Server - Accept 2 Close 1 Passed 1.018 seconds
Total: 1, Passed: 1 (100.0%), Failed: 0, Not Run: 0
…/case-7.3-pair.log  kernel=7.3.0-dirty  clean
```
The plain log ends with the case's "run" step, "Listening for connections", "New client
connection with handle 0x0001", "Sending L2CAP Request from client", "Accept deferred setup sk =
14" (`case-7.3-plain.log` l.83–88), then nothing until the limit: the BT-10 symptom.

**The whole l2cap-tester stalls on v7.3 before it reaches the case, with or without the pair:**
```
bzImage-bt10-7.3-pair [word L2CAP]: HANG (limit 900 s)
…/full-7.3-pair.log  kernel=7.3.0-dirty  clean
$ grep -a -n -E "Invalid response length|test timed out|exit=" tmp/co35/logs/full-7.3-pair.log
1783:Bluetooth: hci8: Invalid response length for 0x20a3
1785:L2CAP LE Client - SCI Fast Mode - test timed out
1788:exit=124 end 2026-10-28 21:01:10 UTC
$ grep -a -n -E "Invalid response length|test timed out|exit=" tmp/co35/logs/full-7.3-plain.log
1786:Bluetooth: hci9: Invalid response length for 0x20a3
1788:L2CAP LE Client - SCI Fast Mode - test timed out
1791:exit=124 end 2026-10-28 21:16:10 UTC
bzImage-bt10-7.3-plain [word L2CAP]: HANG (limit 900 s)
…/full-7.3-plain.log  kernel=7.3.0  clean
$ python3 -I scripts/compare-tester-verdicts.py tmp/co35/logs/full-7.3-plain.log tmp/co35/logs/full-7.3-pair.log
…/full-7.3-plain.log: no summary table; using 41 progress lines
…/full-7.3-pair.log: no summary table; using 41 progress lines
A: 41 cases Passed=40 Timed out=1
B: 41 cases Passed=40 Timed out=1
cases with different verdicts: 0
not-passed sets identical: True (A 1, B 1)
```
(colour codes stripped.) Both stop at the same place with identical verdicts for the 41 cases
before it; the pair changes nothing there. After "SCI Fast Mode" times out, its teardown never
ends. Opcode `0x20a3` is LE Read Connection Interval (the SCI feature). v7.3 carries the SCI feature `2f8784cfe8a9` but not its fix
`5874f8d03268` ("Bluetooth: Fix the LE Read Connection Interval response layout", Luiz Augusto
von Dentz; `Fixes: 2f8784cfe8a9`, no `Cc: stable`; in mainline):
```
$ tmp/co35/in-lines.sh 2f8784cfe8a9 5874f8d03268
== 2f8784cfe8a96 "Bluetooth: Add support for Shorter Connection Interval (SCI) feature"
  7.3.y  ancestor
  7.2.y  absent
  6.18.y absent
  6.12.y absent
  6.6.y  absent
  6.1.y  absent
  5.15.y absent
  5.10.y absent
== 5874f8d03268d "Bluetooth: Fix the LE Read Connection Interval response layout"
  7.3.y  absent
  7.2.y  absent
  6.18.y absent
  6.12.y absent
  6.6.y  absent
  6.1.y  absent
  5.15.y absent
  5.10.y absent
checked 2026-10-28 20:47 UTC
$ git -C cache/linux branch -r --contains 5874f8d03268
  bluetooth-next/master
  bluetooth/master
  origin/master
  stable/master
$ scripts/stable-queue-check.sh bluetooth-fix-the-le-read-connection-interval 7.3
7.3    not in queue
```
This is the defect that confounded the first bisect (see "Corrections" below), and a separate
7.3.y defect (proposed BT-15). So the full suite on 7.3 was run with `5874f8d03268` applied to
both sides:

```
$ tmp/co35/runs-2.sh
bzImage-bt10-7.3-sci [exact ]: HANG (limit 180 s)
…/case-7.3-sci.log  kernel=7.3.0-dirty  clean
bzImage-bt10-7.3-sci-pair [exact ]: L2CAP Ext-Flowctl Server - Accept 2 Close 1 Passed 1.009 seconds
Total: 1, Passed: 1 (100.0%), Failed: 0, Not Run: 0
…/case-7.3-sci-pair.log  kernel=7.3.0-dirty  clean
bzImage-bt10-7.3-sci-pair [word L2CAP]: L2CAP Ext-Flowctl Server - Accept 2 Close 1 Passed 0.010 seconds
Total: 110, Passed: 110 (100.0%), Failed: 0, Not Run: 0
…/full-7.3-sci-pair.log  kernel=7.3.0-dirty  clean
bzImage-bt10-7.3-sci [word L2CAP]: HANG (limit 900 s)
…/full-7.3-sci.log  kernel=7.3.0-dirty  clean
== verdicts by case name: v7.3+5874f8d03268 (A) vs v7.3+5874f8d03268+pair (B)
…/full-7.3-sci.log: no summary table; using 95 progress lines
A: 95 cases Passed=95
B: 110 cases Passed=110
cases with different verdicts: 15
  L2CAP Ext-Flowctl Server - Accept 2 Close 1             A=-          B=Passed
  L2CAP Ext-Flowctl Server - Nval Conn Req                A=-          B=Passed
  L2CAP Ext-Flowctl Server - PHY                          A=-          B=Passed
  L2CAP Ext-Flowctl Server - PHY 2M/Coded                 A=-          B=Passed
  L2CAP Ext-Flowctl Server - Set PHY 1M                   A=-          B=Passed
  L2CAP Ext-Flowctl Server - Set PHY 2M                   A=-          B=Passed
  L2CAP Ext-Flowctl Server - Set PHY Coded                A=-          B=Passed
  L2CAP LE ATT Client - Success                           A=-          B=Passed
  L2CAP LE ATT Client Change Sec  - Success               A=-          B=Passed
  L2CAP LE ATT Server - Success                           A=-          B=Passed
  L2CAP LE EATT Client - Success                          A=-          B=Passed
  L2CAP LE EATT Client Change Sec - Success               A=-          B=Passed
  L2CAP LE EATT Server - Reject                           A=-          B=Passed
  L2CAP LE EATT Server - Success                          A=-          B=Passed
  L2CAP LE Ethtool Get Ts Info - Success                  A=-          B=Passed
not-passed sets identical: True (A 0, B 0)
$ grep -a -n -E "Accept deferred|exit=" tmp/co35/logs/full-7.3-sci.log
3883:  Accept deferred setup sk = 33
3885:exit=124 end 2026-10-28 21:34:27 UTC
```
The base passes all 95 cases it reaches (the SCI cases among them) and then hangs in the case;
the 15 differences are the case itself and the 14 after it, which the base never reaches. No
case passing on the base fails with the pair.
**Filter note.** `-s L2CAP` (the "word" mode) selects the 110 cases whose name contains "L2CAP";
the 111th, "Non-connected getpeername - Failure", does not (`compare-tester-verdicts.py` of the
7.2.13 full log against `full-7.3-sci-pair.log`: "cases with different verdicts: 1 /
Non-connected getpeername - Failure A=Passed B=-"). `full-l2cap.sh` of the earlier rounds ran the
tester unfiltered. So the patched image was also run unfiltered (`tmp/co35/run-case3.sh`):
```
$ tmp/co35/run-case3.sh tmp/co35/img/bzImage-bt10-7.3-sci-pair tmp/co35/logs/fullall-7.3-sci-pair.log 900
bzImage-bt10-7.3-sci-pair [all]: L2CAP Ext-Flowctl Server - Accept 2 Close 1 Passed 0.009 seconds
Total: 111, Passed: 111 (100.0%), Failed: 0, Not Run: 0
…/fullall-7.3-sci-pair.log  kernel=7.3.0-dirty  clean
```
(run at 21:20 UTC while the filtered base run and the older-line runs were in their stalls: three
guests for those seconds.)
So `5874f8d03268` alone does not fix the case; the pair does, with or without it.

## 3. 6.1.y, 5.15.y, 5.10.y: do they hang?

They lack `ab4eedb790ca` (§1) and still have the older `conn->chan_lock`:
```
$ tmp/co35/old-lines-src.sh v6.1.190 v5.15.223 v5.10.272 v6.6.160      (excerpt)
v6.1.190:include/net/bluetooth/l2cap.h:669:	struct mutex		chan_lock;
v5.15.223:include/net/bluetooth/l2cap.h:707:	struct mutex		chan_lock;
v5.10.272:include/net/bluetooth/l2cap.h:709:	struct mutex		chan_lock;
v6.6.160:include/net/bluetooth/l2cap.h:669:	struct mutex		lock;
```
The deferred ECRED response and its caller exist on all three
(`v6.1.190:net/bluetooth/l2cap_sock.c:1188`, `v5.15.223:…:1179`, `v5.10.272:…:1195`:
`__l2cap_ecred_conn_rsp_defer(pi->chan);`).

**ECRED is off by default before v6.2.** `462fcd53924cc` ("Bluetooth: Add
CONFIG_BT_LE_L2CAP_ECRED"; `git tag --contains 462fcd53924cc --list "v6.[0-9]"`: v6.2 first)
made it a Kconfig default; before, it is a module parameter that defaults to false:
```
$ git -C cache/linux grep -n -E "^bool enable_ecred|module_param\(enable_ecred" v5.15.223 v5.10.272 v6.1.190 v6.6.160 -- net/bluetooth/l2cap_core.c
v5.15.223:net/bluetooth/l2cap_core.c:48:bool enable_ecred;
v5.15.223:net/bluetooth/l2cap_core.c:8924:module_param(enable_ecred, bool, 0644);
v5.10.272:net/bluetooth/l2cap_core.c:48:bool enable_ecred;
v5.10.272:net/bluetooth/l2cap_core.c:8908:module_param(enable_ecred, bool, 0644);
v6.1.190:net/bluetooth/l2cap_core.c:46:bool enable_ecred;
v6.1.190:net/bluetooth/l2cap_core.c:7989:module_param(enable_ecred, bool, 0644);
v6.6.160:net/bluetooth/l2cap_core.c:46:bool enable_ecred = IS_ENABLED(CONFIG_BT_LE_L2CAP_ECRED);
v6.6.160:net/bluetooth/l2cap_core.c:7944:module_param(enable_ecred, bool, 0644);
```
test-runner does not set it (`grep -rn enable_ecred tools/test-runner.c tools/l2cap-tester.c`: no
match). So each older line was run three ways (`tmp/co35/runs-old.sh`, `run-case2.sh`):
1. the case alone, as test-runner leaves the kernel;
2. the case alone after `echo 1 > /sys/module/bluetooth/parameters/enable_ecred` in the guest
   (`tmp/co35/case-accept2close1-ecred.sh`; it prints the value before and after);
3. every "Ext-Flowctl" case with the same switch (`group-extflowctl-ecred.sh`): the positive
   control that the switch turns ECRED on (the other ECRED cases must pass).

The pair on these lines:
```
$ tmp/co35/pick-check.sh v6.1.190 v5.15.223 v5.10.272
v6.1.190: 32d86e048d8efedb7aa6cbbd3c36c3c435401c92 CONFLICTS after 608e0b7a675b2affbbf38167cad0fa63d8e064f7
CONFLICT (content): Merge conflict in net/bluetooth/l2cap_sock.c
v5.15.223: 32d86e048d8efedb7aa6cbbd3c36c3c435401c92 CONFLICTS after 608e0b7a675b2affbbf38167cad0fa63d8e064f7
CONFLICT (content): Merge conflict in net/bluetooth/l2cap_sock.c
v5.10.272: 32d86e048d8efedb7aa6cbbd3c36c3c435401c92 CONFLICTS after 608e0b7a675b2affbbf38167cad0fa63d8e064f7
CONFLICT (content): Merge conflict in net/bluetooth/l2cap_sock.c
```
(patch 1 merges as text but takes `conn->lock`, which `struct l2cap_conn` there does not have:
its mutex is `chan_lock`, above; so it would not build either; inferred, not built.)

Control that the ECRED wrapper still shows the hang where it exists: v6.6.160's control image of
the backport round (`tmp/co02-w2c/img/bzImage-bt10-66-ctl`, read only).

Builds (`builds-2.sh`, worktree `/root/exp/agent-work/co35/linux-old`, gcc 13.3): v6.1.190,
v5.15.223, v5.10.272 plain, `make rc=0` each; `CONFIG_BT=y`, `CONFIG_KASAN=y`,
`CONFIG_PROVE_LOCKING=y` in each `.config`; `CONFIG_BT_LE_L2CAP_ECRED` does not exist there.

Results (`tmp/co35/runs-old.sh`; each line's decisive log lines below):
```
bzImage-bt10-66-ctl [exact-ecred ]: HANG (limit 180 s)          (control: the wrapper keeps the hang)
enable_ecred before: Y
enable_ecred after: Y
…/case-ecred-v6.6.160-ctl.log  kernel=6.6.160  clean
  case-ecred-v6.6.160-ctl.log:96:  Accept deferred setup sk = 14
  case-ecred-v6.6.160-ctl.log:98:exit=124 end 2026-10-28 21:09:29 UTC

bzImage-bt10-v6.1.190-plain [exact ]: L2CAP Ext-Flowctl Server - Accept 2 Close 1 Failed 0.017 seconds
Total: 1, Passed: 0 (0.0%), Failed: 1, Not Run: 0
…/case-v6.1.190-plain.log  kernel=6.1.190  clean
  case-v6.1.190-plain.log:89:  Can't set mode: Protocol not available (92)       (ECRED off)

bzImage-bt10-v6.1.190-plain [exact-ecred ]: HANG (limit 180 s)
enable_ecred before: N
enable_ecred after: Y
…/case-ecred-v6.1.190-plain.log  kernel=6.1.190  clean
  case-ecred-v6.1.190-plain.log:95:  Accept deferred setup sk = 14
  case-ecred-v6.1.190-plain.log:97:exit=124 end 2026-10-28 21:12:31 UTC

bzImage-bt10-v6.1.190-plain [group-ecred ]: HANG (limit 300 s)
enable_ecred before: N
enable_ecred after: Y
…/group-ecred-v6.1.190-plain.log  kernel=6.1.190  clean
  passed: Ext-Flowctl Client - Success, - Close, - Timeout, Client Direct Advertising - Success,
          Client SMP - Success, - Command Reject, - Open two sockets, - Open two sockets close one,
          Server - Success, Server - Nval SCID
  failed: Ext-Flowctl Client - PHY, - PHY 2M/Coded, - Set PHY 1M/2M/Coded, - Defer limit
  group-ecred-v6.1.190-plain.log:632:  Accept deferred setup sk = 21   (the target case, then nothing)
  group-ecred-v6.1.190-plain.log:634:exit=124 end 2026-10-28 21:17:31 UTC

bzImage-bt10-v5.15.223-plain [exact ]: L2CAP Ext-Flowctl Server - Accept 2 Close 1 Failed 0.016 seconds
Total: 1, Passed: 0 (0.0%), Failed: 1, Not Run: 0
…/case-v5.15.223-plain.log  kernel=5.15.223  clean
  case-v5.15.223-plain.log:89:  Can't set mode: Protocol not available (92)     (ECRED off)

bzImage-bt10-v5.15.223-plain [exact-ecred ]: HANG (limit 180 s)
enable_ecred before: N
enable_ecred after: Y
…/case-ecred-v5.15.223-plain.log  kernel=5.15.223  clean
  case-ecred-v5.15.223-plain.log:95:  Accept deferred setup sk = 14
  case-ecred-v5.15.223-plain.log:97:exit=124 end 2026-10-28 21:20:33 UTC

bzImage-bt10-v5.15.223-plain [group-ecred ]: HANG (limit 300 s)
enable_ecred before: N
enable_ecred after: Y
…/group-ecred-v5.15.223-plain.log  kernel=5.15.223  clean
  compare-tester-verdicts.py group-ecred-v6.1.190-plain.log group-ecred-v5.15.223-plain.log:
    A: 16 cases Failed=6 Passed=10 / B: 16 cases Failed=6 Passed=10 /
    cases with different verdicts: 0 / not-passed sets identical: True (A 6, B 6)
  group-ecred-v5.15.223-plain.log:632:  Accept deferred setup sk = 21
  group-ecred-v5.15.223-plain.log:634:exit=124 end 2026-10-28 21:25:33 UTC

bzImage-bt10-v5.10.272-plain [exact ]: L2CAP Ext-Flowctl Server - Accept 2 Close 1 Failed 0.019 seconds
Total: 1, Passed: 0 (0.0%), Failed: 1, Not Run: 0
…/case-v5.10.272-plain.log  kernel=5.10.272  clean
  case-v5.10.272-plain.log:77:  Can't set mode: Protocol not available (92)     (ECRED off)

bzImage-bt10-v5.10.272-plain [exact-ecred ]: HANG (limit 180 s)
enable_ecred before: N
enable_ecred after: Y
…/case-ecred-v5.10.272-plain.log  kernel=5.10.272  clean
  case-ecred-v5.10.272-plain.log:83:  Accept deferred setup sk = 14
  case-ecred-v5.10.272-plain.log:85:exit=124 end 2026-10-28 21:28:35 UTC

bzImage-bt10-v5.10.272-plain [group-ecred ]: HANG (limit 300 s)
enable_ecred before: N
enable_ecred after: Y
…/group-ecred-v5.10.272-plain.log  kernel=5.10.272  clean
  compare-tester-verdicts.py group-ecred-v6.1.190-plain.log group-ecred-v5.10.272-plain.log:
    A: 16 cases Failed=6 Passed=10 / B: 16 cases Failed=6 Passed=10 /
    cases with different verdicts: 0 / not-passed sets identical: True (A 6, B 6)
  group-ecred-v5.10.272-plain.log:620:  Accept deferred setup sk = 21
  group-ecred-v5.10.272-plain.log:622:exit=124 end 2026-10-28 21:33:35 UTC
```
(colour codes stripped.) **Result:** on all three older lines the case cannot run as test-runner
leaves the kernel (ECRED off: "Can't set mode"), and with `enable_ecred=1` it never finishes,
exactly as on the newer lines, while the other ECRED cases pass. So 6.1.y, 5.15.y and 5.10.y are
affected for anyone who turns ECRED on; §5 shows why. The request names them and says it does
not cover them.

## 4. The upstream series the pair comes from

The pair are patches 2 and 7 of Pauli Virtanen's "[PATCH 00/16] Bluetooth: L2CAP: fix and annotate
l2cap_conn::chan_l locking" (linux-bluetooth, 2026-08-29;
`https://lore.kernel.org/all/cover.1788013041.git.pav@iki.fi/`, read 2026-10-28 with `curl -A
qca9377-bt-hang/check`, HTTP 200). Where each patch is (by exact subject in `origin/master`, then
ancestry or a same-subject commit on each stable branch):

```
$ tmp/co35/series16.sh
01  385c0829e09e7  Bluetooth: L2CAP: take chan->lock for l2cap_chan_add/ready/del
      Fixes: 6fef032af009 ("Bluetooth: L2CAP: Fix use-after-free in l2cap_sock_new_connection_cb()")
      on stable: none
02  608e0b7a675b2  Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and locking helpers
      (no Fixes:, no Cc: stable)
      on stable: none
03  79ff49a72c06a  Bluetooth: L2CAP: fix race condition in l2cap_sock_shutdown()
      Fixes: ab4eedb790ca ("Bluetooth: L2CAP: Fix corrupted list in hci_chan_del")
      on stable: none
04  a69dd52612ea6  Bluetooth: 6lowpan: use l2cap_chan_close_unlocked()
      Fixes: 15f32cabf426 ("Bluetooth: 6lowpan: add missing l2cap_chan_lock()")
      on stable: none
05  5ccdbf71f1e5e  Bluetooth: L2CAP: remove unused l2cap_chan_close()
      (no Fixes:, no Cc: stable)
      on stable: none
06  df5175dfcf487  Bluetooth: 6lowpan: avoid concurrent peer_del() in bt_6lowpan_disconnect
      Fixes: 15f32cabf426 ("Bluetooth: 6lowpan: add missing l2cap_chan_lock()")
      on stable: none
07  32d86e048d8ef  Bluetooth: L2CAP: hold conn->lock for __l2cap_ecred_conn_rsp_defer
      Fixes: ab4eedb790ca ("Bluetooth: L2CAP: Fix corrupted list in hci_chan_del")
      on stable: none
08  115e6a21c88a5  Bluetooth: L2CAP: hold l2cap_conn::lock in l2cap_connect_cfm()
      Fixes: ab4eedb790ca ("Bluetooth: L2CAP: Fix corrupted list in hci_chan_del")
      on stable: none
09  889dfdde79e27  Bluetooth: L2CAP: add annotations for l2cap_chan list locking
      (no Fixes:, no Cc: stable)
      on stable: none
10  dc1ddc65f06df  Bluetooth: L2CAP: take lock for l2cap_chan_del in l2cap_ecred_rsp_defer
      (no Fixes:, no Cc: stable)
      on stable: none
11  b508a2a2d846c  Bluetooth: L2CAP: hold chan in l2cap_ecred_conn_rsp()
      Fixes: 41c2713b204e ("Bluetooth: L2CAP: Fix possible crash on l2cap_ecred_conn_rsp")
      on stable: none
12  0e4d951a2fcee  Bluetooth: L2CAP: annotate locking for l2cap_chan_del()
      (no Fixes:, no Cc: stable)
      on stable: none
13  a0c672c410554  Bluetooth: L2CAP: annotate locking for l2cap_ops callbacks
      (no Fixes:, no Cc: stable)
      on stable: none
14  aba67d585b993  Bluetooth: L2CAP: make concurrent l2cap_set_timer() refcounting safe
      (no Fixes:, no Cc: stable)
      on stable: none
15  6098ed784e2ca  Bluetooth: L2CAP: remove conditional locking from l2cap_connect()
      (no Fixes:, no Cc: stable)
      on stable: none
16  86b55991d3cd6  Bluetooth: L2CAP: refuse __l2cap_chan_add if chan already has conn
      Fixes: b66774b48dd9 ("Bluetooth: L2CAP: Fix UAF in channel timeout by holding conn ref")
      on stable: none
```

Eight carry a `Fixes:` tag, so the stable team's Fixes-based selection may take some of them
after the merge window (an inference). Patches 03 and 04 call `l2cap_chan_close_unlocked()`
from patch 02, which the backports in this package add. The mails say the pair is "patches 2
and 7 of the series" and that "the other patches are not needed for the problem below and were
not tested here". (Whether other patches of the series fix other real problems on the stable
lines was not examined.)

## 5. What the hang is (diagnostic; not used as the request's evidence)

The tester images have the hung-task detector off (Corrections, 2). Plain v7.3 and plain v6.1.190
were rebuilt with it on (`tmp/co35/diag-build.sh`: tester.config plus `tmp/co35/hungtask.config`,
`CONFIG_DETECT_HUNG_TASK=y`, `CONFIG_DEFAULT_HUNG_TASK_TIMEOUT=20`) and the case run alone:
```
$ tmp/co35/run-case2.sh tmp/co35/img/bzImage-diag-ht-7.3-plain tmp/co35/logs/diag-ht-7.3-plain.log 180 exact
diag-ht-7.3-plain.log:
88:  Accept deferred setup sk = 14
89:INFO: task l2cap-tester:38 blocked for more than 20 seconds.
90:      Not tainted 7.3.0 #5
…
96:locks held by l2cap-tester/38: 2, on CPU#0:
97: #0: ffff8880026e9240 (sk_lock-AF_BLUETOOTH-BTPROTO_L2CAP){+.+.}-{0:0}, at: l2cap_sock_recvmsg+0x5d/0x770
98: #1: ffff8880026e9240 (sk_lock-AF_BLUETOOTH-BTPROTO_L2CAP/1){+.+.}-{0:0}, at: l2cap_sock_teardown_cb+0x10a/0x370
102:INFO: task l2cap-tester:38 blocked for more than 40 seconds.
115:INFO: task l2cap-tester:38 blocked for more than 61 seconds.
128:INFO: task l2cap-tester:38 blocked for more than 81 seconds.
141:INFO: task l2cap-tester:38 blocked for more than 102 seconds.
154:INFO: task l2cap-tester:38 blocked for more than 122 seconds.
167:INFO: task l2cap-tester:38 blocked for more than 143 seconds.
181:exit=124 end 2026-10-28 21:29:12 UTC
bzImage-diag-ht-7.3-plain [exact ]: HANG (limit 180 s)
…/diag-ht-7.3-plain.log  kernel=7.3.0  hung-task=7
```
(each report repeats the same two held locks; no stack was printed, only the lock list.)
Quoted: the tester's task sleeps uninterruptibly holding the socket lock it took in
`l2cap_sock_recvmsg()` and waiting for **the same lock** (same address) in
`l2cap_sock_teardown_cb()`. The nested subclass (`/1`, from `lock_sock_nested(sk,
atomic_read(&chan->nesting))`) is why lockdep, on in these images, reports no recursive locking.

Inferred from the source (v7.3; the same code on 6.1.190, below), the path: `l2cap_sock_recvmsg()`
takes `lock_sock(sk)` (l2cap_sock.c:1257) and, for a deferred ECRED channel, calls
`__l2cap_ecred_conn_rsp_defer()` (l.1264) with it held. With the first of the two channels
already accepted and closed, `l2cap_ecred_list_defer()` finds a channel neither pending nor
connected, so the response becomes a refusal, and `l2cap_ecred_rsp_defer()` calls
`l2cap_chan_del(chan, ECONNRESET)` (l2cap_core.c:3925) on every channel of the request, the
caller's own included; `l2cap_chan_del()` calls `chan->ops->teardown()` (l.687), which is
`l2cap_sock_teardown_cb()`, and that takes `lock_sock_nested()` on the same socket (l2cap_sock.c:
1729). `32d86e048d8ef` moves the defer handling into `l2cap_sock_defer()`, which releases the
socket lock before calling `__l2cap_ecred_conn_rsp_defer()` (its diff, `backports/*/0002-…`).

This path is older than `ab4eedb790ca`: the ECRED defer code is from `15f02b9105625`
("Bluetooth: L2CAP: Add initial code for Enhanced Credit Based Mode", 2020-03-02; first in v5.7:
`git tag --contains 15f02b9105625 --list "v5.[0-9]"`: v5.7 v5.8 v5.9), and 6.1.190 has the same
three steps (`l2cap_sock.c:1181` lock_sock, `:1188` the call; `l2cap_core.c:3893`
`l2cap_chan_del(chan, ECONNRESET)` in `l2cap_ecred_rsp_defer()`; `l2cap_sock.c:1654`
`lock_sock_nested(sk, atomic_read(&chan->nesting))` in the teardown callback). That is why the
older lines hang too once ECRED is on (§3).

The same on 6.1.190 with ECRED on:
```
$ tmp/co35/diag-runs.sh      (run-case2.sh … bzImage-diag-ht-v6.1.190-plain … 180 exact-ecred)
diag-ht-v6.1.190-plain.log:
67:enable_ecred before: N
68:enable_ecred after: Y
95:  Accept deferred setup sk = 14
96:INFO: task l2cap-tester:55 blocked for more than 20 seconds.
97:      Not tainted 6.1.190 #4
105:2 locks held by l2cap-tester/55:
106: #0: ffff888001bd0130 (sk_lock-AF_BLUETOOTH-BTPROTO_L2CAP){+.+.}-{0:0}, at: l2cap_sock_recvmsg+0x35/0x320
107: #1: ffff888001bd0130 (sk_lock-AF_BLUETOOTH-BTPROTO_L2CAP/1){+.+.}-{0:0}, at: l2cap_sock_teardown_cb+0x80/0x1a0
111/126/141/156/171/186: the same report at 40, 61, 81, 102, 122, 143 seconds
202:exit=124 end 2026-10-28 21:31:41 UTC
bzImage-diag-ht-v6.1.190-plain [exact-ecred ]: HANG (limit 180 s)
…/diag-ht-v6.1.190-plain.log  kernel=6.1.190  hung-task=7
(`grep -a -c "at: l2cap_sock_teardown_cb"`: 7 in each diag log)
```
So 6.1.y (and by the same code 5.15.y and 5.10.y, inferred) has the same self-deadlock; it is not
caused by `ab4eedb790ca`. A fix for those lines needs `32d86e048d8ef`'s socket-side change
adapted to their `conn->chan_lock`: not attempted here.

## Corrections to earlier records (found in this round)

1. **The first bisect's confound was not "a hang on the same case".** `results-2026-10-28.md`
   §2, `log.md` and STATUS (BT-10) say that between `2f8784cfe8a9` and `5874f8d03268`
   bluetooth-next "hangs on this case for that second reason". The first bisect's runs used
   `run-one.sh` with the multi-word name, so they ran the whole suite (its header), and they
   stopped in an earlier case:
   ```
   $ grep -a -n -E "SCI|Invalid response length|Accept 2 Close 1|exit=" tmp/l2cap-hang/logs/bisect-c4154fc34772.log
   1:start 01:08:37 kernel …/bzImage-bt10-bis-c4154fc34772 cpus 4 case L2CAP Ext-Flowctl Server - Accept 2 Close 1 limit 180
   17:Command line: … TESTARGS='…/l2cap-tester -s L2CAP Ext-Flowctl Server - Accept 2 Close 1'
   59:Running command …/l2cap-tester -s L2CAP Ext-Flowctl Server - Accept 2 Close 1
   1782:L2CAP LE Client - SCI Fast Mode - init
   1786:Bluetooth: hci9: Invalid response length for 0x20a3
   1788:L2CAP LE Client - SCI Fast Mode - test timed out
   1789:L2CAP LE Client - SCI Fast Mode - teardown
   1791:exit=124 end 01:11:37
   ```
   (colour codes stripped here). The "HANG" verdicts of that bisect were this SCI stall. The
   second bisect's HANG steps did reach the case and stop in it (`bisect2-024e05f73a4c.log`,
   `bisect2-c0bb764fc082.log`, `bisect2-df5175dfcf48.log`, line 3886 each: "Accept deferred setup
   sk = 34", then `exit=124`), so its result, `32d86e048d8ef`, stands. On v7.3, which has the SCI
   feature without its fix, the case alone passes with the pair (§2 below): the SCI defect
   does not touch this case.
2. **"No hung-task report" claimed a check that could not fire.** `doc/tester.config` leaves
   `CONFIG_DETECT_HUNG_TASK` off:
   ```
   $ grep -n -E "DETECT_HUNG_TASK|CONFIG_PROVE_LOCKING=|CONFIG_KASAN=" tmp/co35/img/config-bt10-7.3-pair
   2829:CONFIG_KASAN=y
   2852:# CONFIG_DETECT_HUNG_TASK is not set
   2870:CONFIG_PROVE_LOCKING=y
   $ grep -n DETECT_HUNG_TASK tmp/co02-w2c/img/config-bt10-618-bp
   2865:# CONFIG_DETECT_HUNG_TASK is not set
   ```
   Lockdep and KASAN were on; the hung-task detector was not.
3. **"`2f8784cfe8a9` … is on no stable line"** (`results-2026-10-28.md` §2) is no longer true:
   it is in v7.3 (`git tag --contains 2f8784cfe8a96 --list "v7*"`: v7.3-rc1 … v7.3-rc7, v7.3), so
   7.3.y carries it, without its fix (§2, proposed BT-15). `send/request-v1.txt` and STATUS
   (BT-10: "No lockdep, KASAN or hung-task report in the guest") say otherwise; the new mails
   say "no lockdep or KASAN report".
