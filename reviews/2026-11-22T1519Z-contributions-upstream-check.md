# Every possible contribution checked against upstream (2026-11-22)

**Question.** For each row of the contribution register (`contributions/README.md`): is the
defect already fixed upstream, or is someone else's patch for it posted; is there a public bug
report or discussion; are any of our items linked to each other through one upstream thread;
and where a fix by someone else exists, is a backport request (stable kernels, Ubuntu 24.04)
the right next step, and what homework would it need first.

**Tree read:** `main` at `5a7238f6` (2026-11-22 14:19 +0100). **Upstream read:**
2026-11-22, from 15:19 UTC.

**Relation to the report of the same day.** `2026-11-22T1240Z-kernel-contributions-readiness.md`
read upstream for the kernel items a few hours earlier and rates their readiness. This page
does not rate readiness. It verifies that report's upstream statements independently, adds the
items it leaves out (BlueZ, PipeWire, WirePlumber, GNOME, gvfs, systemd, Ubuntu packages), and
looks for other people's work on the same defects.

**Sources reachable from where this was written:** the patchwork API (project `bluetooth` and
others), git (kernel.org: bluetooth-next, mainline, the stable lines, the stable queue, BlueZ;
freedesktop: PipeWire, WirePlumber), kernel.org's release list, the Launchpad API, the
freedesktop GitLab API, the kernel bugzilla. **Not reachable by a plain request:** lore's web
pages and git archive, GitHub's API (BlueZ and systemd issues), GNOME's GitLab API, syzbot.
Where an item depends on one of those, it says "not checked".

**Limits.** Nothing was built, run in a guest or tried on the laptop. A "backport candidate"
below is a candidate only: the project's rule (every line built and tested, the receiving
project's CI run on base and on base plus ours, before anything is sent) is not met by this
page for any item, and the homework each one needs is listed with it. Nothing was sent,
posted or commented anywhere. The register itself is not edited; a proposed text for each
row is given so that the maintainer of `main` can apply it.

Sections 1 (summary) and 2 (what to do) are written last; section 3 holds the items as they
were checked.

## 3. The items, as checked

Verdicts used: **still ours** (nothing competing found) · **overlap** (someone's pending patch
touches the same code) · **fixed by others** · **fixed by others, backport candidate** ·
**delivered** · **cannot tell**. "Checked" after a fact means the lead reviewer repeated the
lookup; the rest are the part reader's lookups, with the query kept in the companion file.

### 3.1 Kernel: SCO, `hci_conn`, btusb's SCO path

Upstream state: bluetooth-next tip `cf357cfc02` (2026-11-20). `hci_connect_sco()` and
`hci_abort_conn()` are byte-identical to the packages' base `da3cc02587c6`; `net/bluetooth/sco.c`,
`btusb_recv_isoc()`, `btusb_notify()` and `btusb_work()` are unchanged since that base.

| item | verdict | what decides it | proposed register text |
|---|---|---|---|
| CO-02 (SCO connect reuses a closing link) | **still ours** | Patchwork 14919266 to 14919269 are all `new` (checked for 14919266, 14919267, 14919269), no human reply on any; the only non-CI mail is the bot's note of 2026-11-12 that the mirror pull request was closed and the series must be resent. Sashiko's check on 2/3 is still "fail, high". Nobody else has posted a fix for the reuse. The v1 patches and the two-patch candidate apply to the tip's files (`git apply --check`, not built) | sent 2026-10-27, no reply; v2 (two patches) is also the resend the bot asks for; applies to `cf357cfc02`; to do: checkpatch, the bot's CI on the tip, send commands |
| BT-13 (`-ENOLINK` path drops a hold never taken) | **overlap** | Wentao Liang's "Bluetooth: delete the new SCO link if linking it fails", patchwork 14942649 (2026-11-04, `new`, checked; `Cc: stable`, `Fixes: 06149746e720`), fixes this branch. It is not applied; a reviewer objected to its process (untested, checkpatch not run), not to the code; its CI shows CheckPatch and l2cap-tester failing. It conflicts textually with CO-02 v2 1/2, which edits the same branch | no patch of ours; name 14942649 in CO-02 v2's cover as touching the same lines; a Tested-by on it is possible once a reproducer with fault injection exists |
| CO-01 (Tested-by on the abandoned-setup SCO series) | nothing to send | Hitalo Souza's v3 (series 1181908, 14875449 to 14875454) is all `new`; no v4; none of it is in the tip | unchanged: wait for a v4 |
| CO-20 patch 1 (SCO receive failures by cause) | **still ours** | no competing patch; the function and the message are unchanged | unchanged: ready, patch 1 alone |
| CO-21 (SCO alt setting with two links) | **still ours** | no competing patch; Hitalo Souza's stalled 14875454 touches the same flow | unchanged |
| CO-30 (defer a SCO connect, RFC) | **still ours** | `sco.c` untouched; nothing competing | unchanged: after CO-02 v2, re-tested on the two-patch candidate |
| CO-18 / U8 (earbuds silent in mSBC) | nothing to send in the kernel | no kernel patch; public bugzilla entries 221598 (RTL8821C) and 221722 (MT7925) are other chips | unchanged |
| BT-6 (packets for an unknown connection handle) | **fixed by others, already queued for stable** (the message's missing newline only) | Hitalo Souza's "Bluetooth: Add missing newline to bt_dev_{err,warn}_ratelimited()" is mainline `f51ee3bb5fbe` (2026-10-06, in v7.4-rc1, two `Fixes:` tags). It is in none of 7.3.5, 6.18.64, 6.12.118, 6.6.162, 6.1.192, and it **is** in the stable queue for 6.18, 6.12, 6.6, 6.1 and 5.15 (checked: `git grep` in `stable-queue.git`). Its message describes the same teardown tail as BT-6 on another chip. Bugzilla 219992 is a public report of the same line. The handling itself is unchanged | no request needed; the register cites the fix as `f3d041ec63f7`, which is not in mainline: the id is `f51ee3bb5fbe` |

Not in the register and worth a line: Zijun Hu's `3efdadae3a` (SCO/eSCO transport unit size,
applied 2026-11-02) is the only other accepted change near these lines; it does not touch ours.
Jeremy Dean Clifton's `1f150a0bb8` and `56abe5c17b` (2026-11-17, accepted) change
`hci_conn_add()` and `hci_conn_add_unset()` only.

Not checked: lore (the maintainer's reply of 2026-10-09 on CO-01, replies to our cover letter),
the Sashiko site, BlueZ issue 2562.

### 3.2 BlueZ

Upstream state: newest release **5.88** (tagged 2026-11-05); master `1adfe662e` (2026-11-16),
103 commits later. None of our pending BlueZ patches is applied.

| item | verdict | what decides it | proposed register text |
|---|---|---|---|
| CO-23 / U22 (`a2dp_reconfig()` use-after-free) | **still ours** | master still sets `setup->reconfigure = TRUE` after `avdtp_close()`/`avdtp_abort()` (`profiles/audio/a2dp.c:2173`, checked); no patch for it on patchwork | unchanged; re-apply on master before sending |
| CO-37, U23 (`clear_endpoint` at exit) | **still ours** | `path_free()` still frees the applications before releasing the endpoints | unchanged; re-run the exit tests on master |
| CO-37, U24 | **fixed by others, backport candidate** | Pauli Virtanen's `7e3212fa233e`, first in 5.88 (checked) | only the 5.72 backport remains (the Ubuntu bundle, 3.5) |
| CO-37, U25, U26, U27 | **still ours** | nothing upstream touches `a2dp_remove_sep` or `a2dp_sep_unlock` | no patch written yet; a design question for the maintainers |
| CO-39 (non-discoverable reports keep a temporary device) | **still ours** | the `device_update_last_seen()` call before the drop is unchanged; Simon Mikuel's 15010040 touches `advertising.c` only | unchanged |
| CO-41 (emulator ignores the refusal reason) | **overlap, mild** | `cmd_io_cap_negative_reply()` unchanged; Luiz Augusto von Dentz's pending series 1217494 (15006058, 15006061) edits `emulator/btdev.c` nearby | rebase after that series lands, then send |
| CO-27 / U13, U18 | **still ours** | the Flags test, `select_conn_bearer()` and `dev_connect()` are unchanged; no patch. GitHub issue 2700 (the sibling report) was labelled stale on 2026-11-22 and has no reply | a comment on 2700 before it closes; then the reproducer |
| U16 (search stops after a failed Connect) | **still ours** | Kevin Dewald's two patches are applied as `4f3428e9d` and `cad7a98e7` (2026-10-27, in 5.88; checked) and do not touch the start path | the register calls that pair "pending"; it is applied |
| CO-16 / U9 (no reconnect after rfkill) | still ours, wait | `policy.c` has no commit since August; Dylan MacKenzie's 15009074 and 15009075 (2026-11-21, `new`) stop HID reconnect after a deliberate disconnect and add a disconnect-reason helper | unchanged; note the helper |
| U12 (A2DP lost when the microphone opens) | **fixed by others, backport candidate** | `a14d59725`, first in 5.80 (checked) | upstream: nothing; Ubuntu: 3.5 |
| CO-40 ("refused" instead of "unknown") | **fixed by others, backport candidate** | `a6ac17f0e393`, first in 5.78 (checked) | upstream: nothing; Ubuntu: 3.5 |
| BT-4 (btmon aborts) | **fixed by others, backport candidate** | `fdbfe0018` first in 5.80; `dca0f10fd` (Chad Spensky, patchwork 14750981) first in 5.88 (checked) | upstream: nothing; Ubuntu: 3.5 |
| U28 (btmon overflow at 2048 columns or more) | **still ours** | the unbounded append after the clamp is still on master; no fix posted | reproduce with the real binary first |
| CO-11b (the flaky functional test) | **obsolete** | Pauli Virtanen's 14879847 is superseded by 14928110 (`new`); `a994cab0e` (in 5.88) fixes the underlying Busy in the daemon | drop the Tested-by; the register cites the superseded id |
| CO-34 | **delivered** | `3e5b0da969c2`, in 5.88 | closed |
| the mgmt-tester tests of CO-44 and CO-38 | **still ours** | no equivalent upstream; Weihong Guan's "single advertising set tests" (applied 2026-11-12) touch the same area as CO-38's test | re-apply check for CO-38's test |
| the sco-tester test of CO-02 | **still ours** | 14919269 `new`, no reply (checked); `e37f17751` (2026-10-29) ported sco-tester after our posting | port to `e37f17751` (already known) |

A lead, not confirmed: `70197a083` (a use-after-free in `shared/timeout`, on master, not in
5.88) may explain the master `l2cap-tester` abort noted in CO-37; to look at when its tests
are re-run.

### 3.3 Kernel: mesh, MGMT, advertising

Two accepted changes by other authors decide most of this group. Both are in bluetooth-next
and **not yet in mainline** (`4843f6873f`, 2026-11-21) **nor in any stable queue** (checked by
subject in `mainline.git` and `stable-queue.git`):

- `1d7a52778858`, Luiz Augusto von Dentz, "Bluetooth: mgmt: Fix mesh transmission locking and
  lifetime" (patchwork 14998382, `accepted`, 11/17 of series 1215366; `Fixes: b338d91703fa`,
  three Sashiko links, no `Cc: stable`, no syzbot tag; checked).
- `d7e77168da`, Cen Zhang, "Bluetooth: hci_sync: Fix remaining advertising instance UAFs", and
  `a7d2c94ba2` (2026-11-19). Patchwork still shows the series (1215537, 14999296/14999297) as
  `new`; the commits are in the tree (checked). **The readiness report of this morning says the
  series is `new` and "in conflict" with CO-12; it is applied, and it contains CO-12's fix.**

| item | verdict | what decides it | proposed register text |
|---|---|---|---|
| CO-04 (the `mesh_send_sync()` use-after-free, syzbot) | **fixed by others** | `1d7a52778858` looks the transmission up by handle under `hdev->lock` instead of passing a raw pointer | not to send. Run our cancel, backlog and removal cases on the tip and report the result as a test of the applied fix; the syzbot bug needs a `#syz fix` once the commit is in mainline (the commit has no syzbot tag, so it will not close by itself). syzbot's page was not reachable |
| CO-05 1/2 (`hdev->lock` in `mesh_send_sync()`) | **fixed by others** | the same lock, taken in the same place, in `1d7a52778858`; `c592dfe963` and `d7e77168da` cover the other advertising paths | drop |
| CO-26 (a failed add is lost, the missing instance is scheduled) | **still ours**, low value | the tip still has `else err = PTR_ERR(adv);` and carries on (`net/bluetooth/mgmt.c:2478-2479`, checked); neither commit touches it | optional: rebase onto the tip as a single patch; mainline only |
| CO-06 (review reply on Jiale Yao's power-off patch) | **fixed by others** | 14864878 is still `new` (checked) with only the bot's reply; `1d7a52778858` covers the queue-failure completion, the flush at power-off and at removal | no reply to send; close |
| CO-14 / M-4, M-5 (sends leaked at controller removal; the lockdep cycle) | **fixed by others** (M-5 by reading the diff) | `1d7a52778858` flushes the pending sends in `mgmt_index_removed()` and from `hci_dev_close_sync()`, and `mesh_next()` returns early on `-ECANCELED` | not to send; the 10-boot kmemleak run and the 35-boot unregister sweep on the tip would confirm both |
| CO-12 / M-2 (the `u16` duration overflow) | **fixed by others** | on the tip `hci_sync.c:1745` is `u32 duration` and `:1786` is `min_t(u32, duration / 10, U16_MAX)`: the same clamp as ours (checked). Mainline still has the `u16` line (`:1747`) | not to send ours. Left: the BlueZ AdvDur tests are still ours (no equivalent upstream); a stable request for the clamp once `d7e77168da` is in mainline, if it applies or as a reduced backport |
| CO-13 (the mesh "Count" question) | **still ours** | the `cnt * interval` arithmetic is unchanged; no thread found | unchanged: hold |
| CO-38 (Read Advertising Features hides instances) | **still ours** | the tip still tests `adv_instance->instance <= hdev->adv_instance_cnt` (`mgmt.c:9077`, checked); no competing patch | rebase and re-test on the tip; compare our BlueZ cases with Weihong Guan's single-advertising-set tests (BlueZ `923d95d0c`, `58e111cc9`) |
| CO-44 / BT-21 (a timeout reported as Authentication Failed) | **still ours** | the tip still maps `-ETIMEDOUT` to `MGMT_STATUS_AUTH_FAILED` (`mgmt.c:297-298`, checked); six patchwork searches found nothing | apply-check both patches on the tip (`mgmt.c` moved), then send |
| the Tested-by on Hui Peng's leak patch | **delivered**, overtaken | our reply of 2026-10-06 is on patchwork; his 14831271 is `new` and covered by `1d7a52778858` | nothing owed |

What `1d7a52778858` does **not** cover: CO-26; CO-13; and Cen Zhang's 14880941 (`new`,
checked): `mgmt_cleanup()` still walks the pending list without `hdev->lock`, although the new
comment on `mesh_send_complete()` says the lock is required.

The other authors' mesh patches today: Hui Peng 14831271, Jiale Yao 14864878, Igor Putko
14888791, Wentao Liang 14942650: all `new`, all overtaken. Cen Zhang 14927631: `superseded`
(`docs/STATUS.md` lists it as `new`).

**Backport question for this group.** Once `1d7a52778858` is in mainline it fixes a
use-after-free that syzbot reproduces, on every line that has the mesh code (per the dossiers
6.1 and later). It has `Fixes:` and no `Cc: stable`, so the stable team's scripts may or may
not pick it up. It depends on `71af682ba4` (in 7.3.y, 6.18.y, 6.12.y) and on `kzalloc_obj`,
so 6.6.y and 6.1.y would need a hand backport. This is the largest backport candidate found,
and the one where our existing harnesses (the mesh-tester runs, the kmemleak and lockdep
sweeps) are the homework already half done. Not to be requested before the commit is in
mainline.

### 3.4 Ubuntu 24.04 (noble): what it ships today and what is reported

Published today (Launchpad `getPublishedSources`, checked for the first two):

| package | noble today | development release |
|---|---|---|
| `bluez` | **5.72-0ubuntu5.8** in Updates (2026-10-21) and Security (2026-10-13); nothing in Proposed, nothing in the unapproved queue | 5.88-1 (2026-11-07) |
| `linux-hwe-7.0` | **7.0.0-43.43~24.04.1** in Updates (2026-11-11) and Security (2026-11-12); **7.0.0-44.44~24.04.1 in Proposed since 2026-11-20** | — |
| `pipewire` | 1.0.5-1ubuntu3.3 | 1.6.x |
| `wireplumber` | 0.4.17-1ubuntu4.1 | 0.5.x |
| `gnome-control-center` | 46.7 (…24.04.6) | 51.0 |
| `gnome-bluetooth3` | 46.0-1ubuntu1 | — |
| `systemd` | 255.4-1ubuntu8.19 in Updates since 2026-11-19 (CO-46's dossier says it is in Proposed) | 262.1 |

The noble kernel, from its changelog's subject lines (an inference from subjects, not from the
diff): the stable base is v7.2.9 for `-42`, v7.2.11 for `-43`, v7.2.15/v7.3.1 for `-44`.

| fix | `-42` | `-43` (installed on the laptop) | `-44` (proposed) |
|---|---|---|---|
| `dc16388d45ec`, the QCA9377 entry (CO-09) | no | yes | yes |
| `96d006ae6445`, discovery that never stops (BT-9) | yes | yes | yes |
| `86ef0f58bdec`, our MGMT fix (BT-8) | no | yes | yes |
| the L2CAP pair `32d86e048d8e` + `608e0b7a675b` (CO-35) | no | no | no |
| the xHCI ep0 fix (CO-45) | no | no | no |

| item | verdict | what decides it | proposed register text |
|---|---|---|---|
| CO-09 | **delivered** | in noble-updates since `-43` | closed (already so) |
| CO-03 (U12 for noble) | **fixed by others, backport candidate** | `a14d59725` + `664a5d3785a1` are in BlueZ 5.80 and in the development release's 5.88-1; absent from noble 5.8; **no Launchpad bug exists** for "A2DP lost when the microphone opens" (searches with zero results are kept in the companion file) | the fixed-in-development rule of an Ubuntu stable update is met; the bug is to be filed by the operator from the bundle's text |
| CO-11a (btmon for noble) | **fixed by others, backport candidate** | `fdbfe0018` (5.80) and `dca0f10fd` (5.88, not "master" as the dossier says) are both in 5.88-1; no Launchpad bug for the btmon abort. The version numbers the dossier's debdiffs used for the two newer series were taken on 2026-11-10 by an unrelated `mpris-proxy` fix (LP #2172906) | renumber the two debdiffs; the one for the development release is obsolete (5.88-1 has both fixes) |
| CO-37's 5.72 backport of U24 | **fixed by others, backport candidate** | `7e3212fa233e` is in 5.88-1; absent from noble; no bug | with the bundle |
| CO-37's U23 fix for noble | not yet eligible | U23 is not fixed upstream (3.2), so it is not in the development release | BlueZ first; noble only after acceptance. The bundle should not carry it until then |
| CO-40 | **fixed by others, backport candidate** | `a6ac17f0e393` is in 5.78 and 5.88-1; absent from noble; no bug for `br-connection-unknown` | with the bundle or alone |
| our own BlueZ fixes (`a734b06059cb`, `0bed9886cff3`, `ae23df052290`) | **backport candidates**, optional | all three are in 5.88-1; none in noble; the nearest Launchpad bug is #1689448 (a `transport_cb` crash of 2017) | the two crash fixes are real user-visible crashes on 5.72 (`EX-032`, `EX-041`) and qualify; the `shared/mgmt` one is a leak |
| the bundle `5.72-0ubuntu5.9` | version still free | the base 5.8 is still current and no `5.9` exists in any pocket; a security upload could take the number first | re-check the base on the day of filing; the stable-update team may ask for one bug per fix |
| CO-07 / U6 (input meter) | **fixed by others, backport candidate**, held | noble's 46.7 lacks the six commits; no Launchpad bug for the dead meter | after CO-32, as planned |
| CO-19 / U1 (codec line) | **fixed by others, backport candidate** | noble's PipeWire 1.0.5 lacks `805e5cf9c`; no bug | after the laptop test |
| CO-32 / U19 (Ubuntu's own WirePlumber patch) | **still ours** | LP #2122640 is Fix Released for noble (2025-10-09), with no regression note and no follow-up bug | a new bug against `wireplumber` in noble with the one-line change, after the laptop test |
| CO-29 / U14 | no action available | noble stays at 0.4.17; upstream fixed it only by the 0.5 rewrite | unchanged |
| CO-46 (journalctl) | **fixed by others, backport candidate** | noble's systemd reached 8.19 in Updates on 2026-11-19 without the fix; no Launchpad bug | the request's upload number becomes 8.20; the dossier's "in Proposed" is out of date |
| CO-45 / BT-22 (xHCI ep0) | **not yet fixed anywhere** | patchwork 14964105 (linux-usb, 2026-11-09) is `new` (checked); in no kernel. The register says "queued upstream 2026-11-09" | correct the row: posted, not applied |
| X1 (gvfs) | cannot tell | LP #1967258, which the dossier cites, is a bug against `totem` (New, 2022) with the same symptom and no `gvfs` task | link it when the upstream change is merged |

Adjacent Launchpad bugs found, not the same defects: #2056196 (headset disconnected on a
remote A2DP to HSP change, noble), #2159829 (an A2DP regression in 5.72-0ubuntu5.5, Fix
Released), #2173777 (PipeWire: headset microphone stops after a profile switch with
WirePlumber 0.5.17; newer series only), gnome-control-center #2167667 (no input selectable on
A2DP, New).

Not checked: the Ubuntu CVE tracker for the btmon CVE the bundle's notes mention; any kernel
diff; GNOME's tracker.

### 3.5 PipeWire, WirePlumber, GNOME, gvfs, systemd

For PipeWire and WirePlumber the project's rule stands: the operator writes any report
himself; "next step" is evidence for him. PipeWire master read at `20128216d` (2026-11-22),
WirePlumber at `c6a331d2` (2026-11-21).

| item | verdict | what decides it | proposed register text |
|---|---|---|---|
| CO-36 / U15 (the delayed HFP volume resend outlives the link) | **still ours** | master still arms the 1.5 s resend in `sco_ready()` and stops it neither on release nor on hang-up; no issue or merge request | unchanged: the operator's duplicate search, then his report |
| CO-31 / U17 (a refused SCO connect is retried at once) | **still ours** | `backend-native.c:2699` on master still retries `ECONNABORTED` immediately (checked); an issue search for the word returns nothing; open issue 5533 (a stall on a Bluetooth profile switch) is adjacent | unchanged; name 5533 and CO-02 in the report |
| U7 (codec switch under a live SCO link), the PipeWire side | **overlap, adjacent** | issue 5506 is **closed** (2026-11-19, checked) by Pauli Virtanen's `710136cc7`, "reject AT+BCC while SCO setup is in progress" (2026-11-07; master only, in no release tag). It does not cover a switch while a link is live. Another author's merge request 3083 for 5506 is still open | the U7 row says "adjacent open report 5506": it is closed; the kernel part stays CO-02 |
| CO-33 / U20 and the quirk for U15 | **still ours** | `bluez-hardware.conf` on master has no Shure or Sennheiser entry (checked); the one `hw-volume-mic` precedent is "Air 1 Plus" | unchanged: the local test, then the operator's entry |
| CO-08 / U10 (Tronsmart T8 silent on SBC-XQ) | **still ours** | no Tronsmart entry or issue; open issue 5545 (another headset one-sided on SBC-XQ) is the same class | unchanged |
| U30 (HFP gains outside 0 to 15) | still ours, cause inferred | no report; the send path has no range check | reproduce first |
| CO-19 / U1 | **fixed by others, backport candidate** | `805e5cf9c`, first in 1.1.81 (checked) | 3.4 |
| CO-15 / U11 | still ours, a configuration note | WirePlumber issues 352 and 1036 closed, 914 open as a design discussion | unchanged |
| CO-29 / U14 | fixed by the 0.5 rewrite | 0.4 is not developed | 3.4 |
| CO-24 / U5 | dropped | nothing upstream | unchanged |
| CO-07 / U6, U4 | still ours for the Ubuntu bug | gnome-control-center's main branch has no meter or codec-row fix beyond what 47.0 had; merge request 3536 (2026-11-13) and issues 3710, 3715 are adjacent | 3.4 |
| CO-42 / U13 / U29 (a failed setup shows nothing) | **still ours**, a comment only | gnome-bluetooth merge request 137 is open and unchanged since 2025-02-23; issue 18 is open; issue 176 (LE passkey) is a new neighbour | unchanged; add issue 176 |
| U31 | cannot tell | commits of early 2026 in libgnome-volume-control handle port-less Bluetooth streams; which version noble bundles was not checked | check the bundled version |
| X1 (gvfs, two merge requests) | **still ours, waiting** | merge requests 368 and 369 and issues 893 and 894 are open with no comment since 2026-11-07; no `cdda` commit upstream since 2026-02-25 | unchanged: wait, or a polite reminder, the operator's choice |
| X2 to X4 | still ours | nothing upstream | unchanged |
| CO-46 (journalctl and the number of journal files) | **fixed by others, backport candidate**; one part still open upstream | the two commits the dossier names (`99e6f682d3`, `51b2bcf835`, Yu Watanabe, 2024-01-03) are in systemd v256; noble has 255.4. Upstream pull request 44579, which the dossier measures the remaining growth against, is open, with rework requested (last push 2026-11-02); issue 31486 is open | the noble request stays ours (3.4) |
| BlueZ issue 1554 (our reply of 2026-10-09) | no change | open; one tester's reply of 2026-10-14; nothing later | unchanged |

Not checked: comment threads on PipeWire issues and on gnome-bluetooth 137 and 18 (a login is
needed); WirePlumber's suspend script at its tip.

