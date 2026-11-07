# Review round 2026-11-01: every candidate package, as it stands

An intermediate round. It is not the final check of any one package. The aim is an outside view
of everything that is drafted, packaged or sent and under review, so that each package can be
improved before it is sent. Nothing listed here has been sent unless the row says so.

**For each package, please answer:**
1. Is it technically correct (code, test, claims)?
2. Is anything missing that a maintainer would ask for?
3. Is it ready to send, nearly ready, or far from it, and why?
4. Is there anything to cut?

The state of every item is in [`docs/STATUS.md`](../docs/STATUS.md); the index of all
contributions is [`README.md`](README.md).

## Packages to review

| # | package | target | state | start here | known open points |
|---|---|---|---|---|---|
| 1 | **CO-02** SCO connection reuse: 3 kernel patches + a BlueZ sco-tester test | kernel (bluetooth-next, `Cc: stable`); BlueZ | **sent 2026-10-27**, no human reply | [README](CO-02-sco-connect-reuses-closing-link/README.md), [the patches as sent](CO-02-sco-connect-reuses-closing-link/patch/v7-candidate/send/), [log](CO-02-sco-connect-reuses-closing-link/log.md) (2026-11-01 entry) | The automated reviewer Sashiko rates patch 2 high-severity: on its own it leaves the race that patch 3 closes. Should 2 and 3 be folded into one in a v8, or should we answer that they belong together? A second Sashiko instance (sashiko.dev, 10-27) rates patch 1 High, for a `setting`/`codec` fall-through that predates the series: should v8 also return early on that branch? Since 2026-10-29 BlueZ master has the tester rework (`e37f17751`), so the test needs a port |
| 2 | **CO-03** U12: Ubuntu 24.04 BlueZ 5.72 backport of `a14d59725` (+ BT-7) | Ubuntu (Launchpad) | built and VM-tested; not installed; not filed | [backport/README.md](CO-03-bluez-u12-backport/backport/README.md) (the draft Launchpad bug is §7), [TEST-PLAN.md](CO-03-bluez-u12-backport/backport/TEST-PLAN.md), [debian patches](CO-03-bluez-u12-backport/backport/debian-patches/) | Only VM tests so far; the test with the real headset is pending. Is the companion `664a5d3785a1` right to take? Should a 5.72 SRU also carry U23/U24 (item 9)? |
| 3 | **CO-04** mesh `mesh_send_sync` use-after-free: our own fix | kernel | package ready, not sent | [patch/README.md](CO-04-mesh-test-14888791/patch/README.md) | Lock order and completeness. Another author's 14927631 (2026-10-30, pending) changes the same area |
| 4 | **CO-05 + CO-26** mesh advertising-list locking (two patches) | kernel | package ready, not sent | [patch/README.md](CO-05-mesh-adv-list-lock-i12/patch/README.md) | 14927631 takes `hdev->lock` around `hci_add_adv_instance()`; our 1/2 no longer applies on top of it. Rebase, drop, or point at theirs? |
| 5 | **CO-11a** btmon crash: Ubuntu debdiff `5.72-0ubuntu5.9` | Ubuntu (Launchpad) | ready to file | [debdiff](CO-11-small-btmon-and-flaky-test/ubuntu/bluez_5.72-0ubuntu5.8_5.72-0ubuntu5.9.debdiff), [Launchpad report draft](CO-11-small-btmon-and-flaky-test/ubuntu/lp-report.md), [results](CO-11-small-btmon-and-flaky-test/ubuntu/results-2026-10-28.md) | Should it merge with CO-03 into one bluez SRU (same base version)? |
| 6 | **CO-19** U1: PipeWire codec line, Ubuntu debdiff | Ubuntu (Launchpad) | code reviewed; the laptop test is pending | [README](CO-19-pipewire-u1-codec-line/README.md), [debdiff](CO-19-pipewire-u1-codec-line/pipewire_1.0.5-1ubuntu3.3_1.0.5-1ubuntu3.4.debdiff), [Launchpad report draft](CO-19-pipewire-u1-codec-line/lp-report.md) | — |
| 7 | **CO-23** bluetoothd `a2dp_reconfig()` use-after-free (two mails) | BlueZ | send package ready, not sent | [patch/send/README.md](CO-23-one-off-events/patch/send/README.md), [results](CO-23-one-off-events/experiments/results-2026-10-29.md) | Route: the public list, or BlueZ's security contact? |
| 8 | **CO-25** Qualcomm ROM report: our reply to Zijun Hu (Qualcomm) | kernel list | report **sent 2026-10-29**; the reply is a draft | [the reply draft](CO-25-qualcomm-rom-report/drafts/reply-1-zijun-hu.eml), [the report as sent](CO-25-qualcomm-rom-report/send/report.eml), [EVIDENCE.md](CO-25-qualcomm-rom-report/EVIDENCE.md) | The reply corrects "QCA9377 is not ROME". Is its tone and evidence right? A survey of other ROME IDs missing from btusb (CO-22, in progress) may answer our second question |
| 9 | **CO-37** bluetoothd use-after-free at exit (U23): 2 fixes + a functional test; 5.72 backports (U23, U24) | BlueZ; Ubuntu | series written, not sent; no review yet | [README](CO-37-bluez-media-endpoint-exit-uaf/README.md), [master series](CO-37-bluez-media-endpoint-exit-uaf/work/patches/master/), [5.72 backports](CO-37-bluez-media-endpoint-exit-uaf/work/patches/5.72/), [the record](CO-37-bluez-media-endpoint-exit-uaf/work/README.md) | First review. Is fix 1 (unlink before the A2DP early return) the right shape, or should `a2dp_remove_sep()`'s deferral own it? Does it overlap Bastien Nocera's RFC (patchwork 14568134)? |
| 10 | **CO-35** BT-10: L2CAP ECRED deferred-accept hang, stable backports | stable kernel | package ready, not sent | [send/README.md](CO-35-l2cap-ecred-defer-hang-stable/send/README.md) | The 6.1/5.15/5.10 lines hang too and are not covered |
| 11 | **CO-36** PipeWire: the HFP volume resend outlives the SCO link (U15) | PipeWire | evidence and test suite only. PipeWire's rules: the operator writes and files the report; no tool-written text | [README](CO-36-pipewire-hfp-volume-resend-after-release/README.md), [homework (VM reproduction)](CO-36-pipewire-hfp-volume-resend-after-release/homework/README.md), [TEST-PLAN.md](CO-36-pipewire-hfp-volume-resend-after-release/homework/TEST-PLAN.md), [part 2 results](CO-36-pipewire-hfp-volume-resend-after-release/homework/part2/RESULTS.md) | Is the evidence complete and convincing? Which fix variant should be tested first (V1–V5 in the plan)? |

## Not in this round

- **CO-12** (extended-advertising duration overflow): reproduced in QEMU with a draft clamp fix, but the
  fix is not in the repository yet.
- **CO-21** (btusb alternate setting with two SCO links): a candidate fix exists only in a work area;
  the research is in progress.
- The research on the parked items is still running.
