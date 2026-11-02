# CO-35 ready-to-send package: results, 2026-11-02

Work area: /root/exp/agent-work/co35-ready-20261102/ (scripts at its top level, raw logs in logs/, images in img/).
Every number below is MEASURED today unless marked "from source" or "inferred". Nothing was sent.
Mail files: this directory (request-v3.eml, request-sci-7.3.y.eml, 6.18.y/, 6.12.y/, 6.6.y/); diffs against the
2026-11-01 drafts in diffs/; draft copies in ../draft-orig/. SHA256SUMS lists logs and mails.

## 1. Facts (logs/facts.log, logs/facts2.log, releases-20261102.json; commands: facts.sh, facts2.sh, releases.py)

kernel.org releases.json fetched 2026-11-02 (`curl -s -f https://www.kernel.org/releases.json`), `releases.py` output:

    mainline  7.4-rc1   2026-11-01
    stable    7.3.1     2026-10-30  iseol=False   (latest_stable 7.3.1)
    stable    7.2.15    2026-11-01  iseol=True    (7.2.y has ended)
    longterm  6.18.60   2026-10-30  iseol=False
    longterm  6.12.115  2026-10-30  iseol=False
    longterm  6.6.161   2026-10-30  iseol=False
    longterm  6.1.191, 5.15.224, 5.10.273  2026-10-30  iseol=False

No tag newer than the tested ones (v7.3.1, v6.18.60, v6.12.115, v6.6.161): checkpoint 3 "rerun only the case with the
final files" applies. (The 6.1/5.15/5.10 tags are newer than the v6.1.190/v5.15.223/v5.10.272 named in the request's last
paragraph; those lines are not requested and that paragraph describes the earlier tests with those tag names.)

Mainline: `git -C cache/linux fetch origin tag v7.4-rc1 --no-tags` (new tag). Tag object bc71431221f5ba8bb33918399552636e059c2c45;
the commit it points to is 6628e7d4c6b25c8d18f1345e3a20d21829aae7e4 (`git rev-parse v7.4-rc1^{commit}`; the brief's
"bc71431221f5" is the tag object, not the commit). `git ls-remote origin refs/tags/v7.4-rc1 refs/tags/v7.4-rc1^{}` agrees.

`git merge-base --is-ancestor <c> v7.4-rc1` (rc=0 means yes):

    608e0b7a675b2affbbf38167cad0fa63d8e064f7  rc=0  Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and locking helpers
    32d86e048d8efedb7aa6cbbd3c36c3c435401c92  rc=0  Bluetooth: L2CAP: hold conn->lock for __l2cap_ecred_conn_rsp_defer
    5874f8d03268d34189c6c12c56586b64d26a8bcc  rc=0  Bluetooth: Fix the LE Read Connection Interval response layout
    d54601f21faf1ab5728e98e2102c3f738be0c177  rc=0  Bluetooth: btusb: add ASUS 0b05:1868 to QCA Rome quirks
    cfa67a1dbfd9425044f6eef037a114b2d108f436  rc=0  Bluetooth: btusb: add ASUS 0b05:1825 to QCA Rome quirks

Stable queue (`/root/exp/qca9377-bt-hang/scripts/stable-queue-check.sh <stem> 7.3 6.18 6.12 6.6 6.1 5.15 5.10`, 2026-11-02 13:38-13:39 UTC,
header read first: it greps the queue-<v>/ tree page of stable-queue.git for the stem). Stems used: close_unlocked,
ecred_conn_rsp_defer, ecred-conn-rsp-defer, le-read-connection-interval, asus-0b05-1868, asus-0b05-1825. All five commits:
"not in queue" on all seven lines. Positive control, stem "bluetooth": QUEUED on every line (e.g. 7.3:
bluetooth-forget-a-peer-s-rpa-once-it-advertises-its-identity-address.patch), so the fetch and the grep work.
Caveat (inferred): the script matches a stem in the file name; a differently named file would be missed, but the
two spellings tried per commit cover the usual title-derived names.

Also in no released tag: `is-ancestor` rc=1 for all five commits in v7.3.1, v6.18.60, v6.12.115, v6.6.161 (logs/facts2.log);
no commit of the same subject in btusb.c history of those tags.

CO-22 facts: both ASUS commits (d54601f21faf 0b05:1868, cfa67a1dbfd9 0b05:1825) ARE in v7.4-rc1. They are NOT in
any stable queue (7.3, 6.18, 6.12, 6.6, 6.1, 5.15, 5.10 checked) and NOT in the released v7.3.1/v6.18.60/v6.12.115/v6.6.161.
So CO-22's stable request can name both as mainline commits in v7.4-rc1. (6.1, 5.15, 5.10 releases not checked for presence,
only their queues.)

## 2. Corrections applied (diffs/*.diff; other authors' patch bodies untouched)

1. 7.2.y removed from request-v3.eml, the SCI request and the three covers (`grep -n 7\.2` over final/ *.eml *.patch: no match).
2. Identity claim: it was NOT in any mail or patch file of the draft (grep for patch-id/identical/"same as upstream" in the draft:
   no match); it was only in the history docs: CO-35 README.md line 6, log.md lines 143 and 204, send/README.md line 114,
   experiments/results-send-2026-10-28.md lines 43-45. Those are outside my write area and not changed; they need a
   correction. Measured today (`git patch-id --stable`, logs/sizes.log):
   - upstream 608e0b7a675b2 e... 70fa1c63fd06519b; 32d86e048d8ef cc164bd1e65c0b5b
   - 6.18.y patch 1 e9f3fc9991400f98 (differs); patch 2 cc164bd1e65c0b5b (EQUAL to upstream)
   - 6.12.y patch 1 e9f3fc9991400f98 (differs); patch 2 3f878ced940dad64 (differs)
   - 6.6.y patch 1 07f7fad21c2c14e4 (differs); patch 2 3f878ced940dad64 (differs)
   The `[ backport: ]` notes carry no identity claim; the covers list the deviations only (kept).
3. Per-line non-pass breakdowns replaced by "all other non-passes are pre-existing on plain <tag> (features the tree lacks)".
   The numbers are kept here (section 5).
4. Request mail 1 subject: was "Please backport 608e0b7a675b and 32d86e048d8e (Bluetooth: L2CAP) to 7.3.y and 7.2.y" (95 columns
   as stated); now "Please backport 608e0b7a675b and 32d86e048d8e to 7.3.y" (63 columns including "Subject: "). I also shortened the SCI
   request's subject (it was about 100 columns) to "Please backport 5874f8d03268 (Bluetooth: SCI response fix) to 7.3.y"; that
   one was not on your list; revert in diffs/request-sci-7.3.y.diff if unwanted.
5. Size sentence added to the request and the three covers: "The first changes 78 lines (a 149-line diff), more than the 100 lines
   the stable rules allow; I am asking for it whole, as merged, because that is the conservative choice compared with a smaller
   locking patch written only for stable." Measured (logs/sizes.log): 608e0b7a675b2 = 17+56 added, 0+5 deleted = 78 changed lines in
   2 files, 149 lines of `git show --format=` output (about 140 without file headers); 32d86e048d8ef = 68 changed, 93 lines. The
   brief's "about 130" does not match any count I get; checkpatch counts "130 lines checked" for the backports' patch 1 (and 132 for
   upstream's). I used the measured 78/149 and did not write "130". Say if you want the checkpatch figure instead.
6. dc1ddc65f06d (from source, v7.3.1 net/bluetooth/l2cap_core.c lines 3894-3930, identical code at v6.18.60, v6.12.115, v6.6.161):
   l2cap_ecred_rsp_defer() runs l2cap_chan_del(chan, ECONNRESET) on each channel of the same ident without taking that channel's
   chan->lock, in the else branch taken only when rsp->pdu.rsp.result is non-zero (the refusal path set by
   __l2cap_ecred_conn_rsp_defer() when l2cap_ecred_list_defer() finds a channel neither pending nor connected). dc1ddc65f06d adds
   sibling locking there (plus lockdep asserts, a hold/put, and an early return); that is a lock-context issue separate from the
   caller's own socket lock that hangs the case, which 32d86e048d8ef fixes. Measured: the case also passes with the pair alone and
   with pair + dc1ddc65f06d (1.048 s, today). The text says: "...is not requested: in v7.3.1, l2cap_ecred_rsp_defer() calls
   l2cap_chan_del() on the sibling channels without their chan->lock only in its refusal branch, which is a lock context issue
   separate from the caller's own socket lock that hangs the case below; the case passes with and without it." (The covers say the
   same minus the "passes" clause.) I did not establish whether the test case itself reaches that branch.
7. One neutral sentence in the request only: "The deadlock path it removes predates ab4eedb790ca; it comes from 9aa9d9473f15 (v6.3)."
   Fixes: trailers untouched (patch files byte-identical to the drafts; see section 3).
Other edits needed by the above: v7.2.14 test statements removed from the request; the "111 of 111" claim now attached to
v7.3.1 with the SCI fix (re-measured today, section 5); "in mainline since the 7.4 merge window (v7.4-rc1)"; SCI request: "v7.2.14 does
not" became "v6.18.60 does not" (2f8784cfe8a9 is in v7.3.1: rc=0; in v6.18.60: rc=1) and the queue check time is today's.

## 3. Code patches unchanged

`mkdiffs.sh` output: 6.18.y, 6.12.y, 6.6.y patches 0001 and 0002 byte-identical (cmp) to send-20261101-draft/.
The builds below applied exactly these files from final/<line>/ (git apply).

## 4. Local checks (logs/checks.log; script checks.sh)

checkpatch.pl (v7.3.1 tree's, run inside it):
- upstream 608e0b7a675b2: 0 errors, 1 warning ("The commit message has 'syzkaller', perhaps it also needs a 'Fixes:' tag?"), 132 lines.
- upstream 32d86e048d8ef: 0 errors, 0 warnings, 88 lines.
- each line's patch 1: 1 error + 1 warning, 130 lines. Error: `[ Upstream commit 608e0b7a675b2affbbf38167cad0fa63d8e064f7 ]`
  ("Please use git commit description style 'commit <12+ chars of sha1> ..."): the expected `[ Upstream commit ]` line stable prescribes.
  Warning: the same upstream syzkaller warning.
- each line's patch 2: 1 error, the same `[ Upstream commit 32d86e048d8efedb7aa6cbbd3c36c3c435401c92 ]`; 88 lines (6.18.y), 81 lines (6.12.y, 6.6.y).
  No other finding on any file.

mail-lint.sh: clean for both requests and, as format-patch-stripped copies (To: added, cut at "-- "), the three covers.

ci-local.sh --kernel (stable-backport mode, patches only, --base bluetooth-next/master 42b8c2d729268a65, checkpatch from v7.3.1 tree,
targets v6.18.60 / v6.12.115 / v6.6.161; summaries ci-local-<line>/summary.txt):

    check              6.18.y   6.12.y   6.6.y
    am                 PASS     PASS     PASS     (git am onto the tag)
    am-bluetooth-next  EXPECTED EXPECTED EXPECTED (upstream commit already there)
    checkpatch         NEW      NEW      NEW      (the two [ Upstream commit ] errors + upstream's syzkaller warning)
    gitlint            NEW      NEW      NEW      patch 1 title 82>80 / 82>80 / 81>80 with the "[<line>,1/2] " prefix; upstream's subject kept
    subjectprefix      PASS     PASS     PASS
    verifyfixes        PASS     NEW      NEW      6.12/6.6: ab4eedb790ca is present as its backport (f87271d21dd4, efc30877bd4b), not as an ancestor; upstream Fixes: kept
    verifysignedoff    PASS     PASS     PASS

Same findings as the 2026-10-28 run (results-send-2026-10-28.md section 3). Not run: --build (BuildKernel, W=1, C=1, 32-bit); the
tester.config builds below stand in for BuildKernel only. Warnings from net/bluetooth in those builds: logs/btwarn-*.log
(see file sizes in SHA256SUMS; empty files mean none).

## 5. Tests (QEMU/KVM, 4 vCPUs, BlueZ doc/tester.config + CONFIG_DETECT_HUNG_TASK=y, 20 s; scripts build-final.sh, run-test.sh,
## patched-runs.sh, base-runs.sh; times UTC in progress.log)

Final patch files applied by git apply (6.x) or the upstream pair by cherry-pick --no-commit (7.3.1; same file contents as the
commits requested). Case "L2CAP Ext-Flowctl Server - Accept 2 Close 1" alone, 180 s limit:

    tag        base (plain, 2026-11-01 images, rerun today)   patched today (final files)
    v6.6.161   HANG (hung-task reports: 7)                    Passed 1.036 s
    v6.12.115  HANG (7)                                       Passed 1.074 s
    v6.18.60   HANG (7)                                       Passed 1.067 s
    v7.3.1     HANG (7)                                       Passed 1.034 s (pair); 1.040 s (pair + 5874f8d03268); 1.048 s (pair + dc1ddc65f06d, image of 2026-11-01)

Full unfiltered l2cap-tester on the patched kernel (logs/full-*.log):

    v6.18.60 pair          111 cases: 93 passed, 18 failed (all "Set PHY" cases)
    v6.12.115 pair         111 cases: 79 passed, 31 failed, 1 timed out (BR/EDR PIN Code Change Sec)
    v6.6.161 pair          111 cases: 79 passed, 31 failed, 1 timed out
    v7.3.1 pair + 5874f8d03268   111 of 111 passed
    v7.3.1 pair alone      not rerun (stalls in "SCI Fast Mode" as the plain tag does; 2026-11-01 result)

Non-passes against the pooled plain-tag verdicts of 2026-11-01 (compare.py; logs/compare.log; base side = the earlier
full-<tag>-base and word-*-<tag>-base logs in /root/exp/agent-work/co35/refresh-20261101/logs/, 102 cases pooled per tag, not rerun today):
    v6.18.60: 0 regressions, 18 non-pass also non-pass on base
    v6.12.115: 0 regressions, 32 also non-pass on base (26 PHY, 3 TX timestamping, 2 ethtool, 1 PIN-code timeout)
    v6.6.161:  0 regressions, 32 also non-pass on base (same breakdown)
Kernel-report scan (scripts/kernel-report-scan.py inside run-test.sh): patched runs "clean" (no lockdep or KASAN report; no
hung-task); base runs "hung-task=7".
The 6.12.115 and 6.6.161 breakdown (26/3/2/1) is the kept-out-of-the-mail number set; it matches the 2026-11-01 log.

## 6. Not done / limits
- 7.3.1 "pair alone" full run, and the base full runs: not rerun (the pooled base verdicts are from 2026-11-01).
- The tester config enables hung-task detection only; no separate lockdep/KASAN-enabled build was made today (the "no lockdep or
  KASAN report" statement rests on the scan of the patched runs, whose config is tester.config).
- Nothing was committed or sent; the history docs listed in section 2 item 2 still carry the identity claim.
