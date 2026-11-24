# CO-43 three-patch series of 2026-11-23

This is the work order `../SERIES-PLAN-20261123.md`, carried out. It replaces `../send-20261113/E/` and
`../send-bt24-bt25-20261114/` (both marked SUPERSEDED on 2026-11-23, after the reruns below).

**Base:** bluetooth-next `cf357cfc025e`, a public commit. The export has `base-commit:` set to it, and the
local-only `04b58d680611` is gone.

| # | patch | was | message changes |
|---|---|---|---|
| 1/3 | Free the skb of a deferred URB that is discarded | `send-bt24-bt25-20261114/0002` (BT-25) | Rebased to stand first: the resume failure path keeps its unlocked `failed:` label, and its scuttle becomes `btusb_discard_deferred()`. Only `Fixes: 7bee549e197c`; `19cfe912c37b` is named in prose as the 2017 repair that left the skb out. The lock sentence now reads "play_deferred() runs with txlock held and interrupts disabled". In this order that is the only locked site: the failure path's discard is unlocked until 3/3. The close argument was checked on the tip's `hci_sync.c`: `hci_dev_close_sync()` flushes `tx_work` and `rx_work` (l.6245–6246) and drains the workqueue (l.6287); `hci_dev_drop_last_cmd_req_and_close()` clears `HCI_RUNNING` (l.6049) before `hdev->close()` (l.6053). The message also names the driver-context direct send as a lockless edge whose worst case is a parked URB, as today. |
| 2/3 | Anchor a deferred URB under txlock | `send-20261113/E/0001` (E, BT-23) | Code unchanged. After the rerun (and reviewer 6 of the 11-23 recheck) the body adds the consequence the logs show: on controllers with a vendor reset callback, such as QCA, the command timeout resets the device ("Resetting usb device." in 3 of 3 runs). btusb sets that callback only for Intel, MediaTek, QCA and Realtek. No stale send was seen, so none is claimed. |
| 3/3 | Drop deferred URBs under txlock on a failed resume | `send-bt24-bt25-20261114/0001` (BT-24) | "the waker … finds an active device" softened to: the sender anchors after the only point where this resume drops deferred URBs. It says it relies on 2/3. On top of 1/3 the locked section calls `btusb_discard_deferred()`, and the message says that it may run with interrupts disabled. |

**Cover:** "[PATCH 0/3] Bluetooth: btusb: Fix deferred URB leaks and races" (R3's title). The label "E" is gone.

**Checked 2026-11-23:**
- **Same code as before.** Applying the old three patches in the old order (E, BT-24, BT-25) on `cf357cfc025e`
  gives the same `btusb_main.c` as this series. The only difference is one comment word, "drop" for "scuttle",
  because the scuttle call is gone.
- **checkpatch:** `checkpatch.pl --strict --no-tree --no-signoff` on each patch gives 0 errors, and only the
  "unknown commit id" warning that `--no-tree` gives for `7bee549e197c`.
- **W=1 builds** of `drivers/bluetooth/` (tester config) at the base and after each patch: all succeed,
  `btusb_main.c` is compiled at each step, and no warning comes from it. The full bzImage of the series also
  builds. Script: `tmp/kernel-queue-20261123/build-co43-steps.sh` (machine-local).

## Reruns, 2026-11-23 (QEMU, 4 CPUs, KASAN, lockdep, kmemleak, hung-task; emulated 13d3:3503 over usbip)

The test kernels are the base `cf357cfc025e`, 1/3, 1–2/3 and 1–3/3, each with a debug-only commit
(`evidence-summaries/apply-debug-co43.py.txt`; it is in no patch). There were 105 guest runs. Summaries are in
`evidence-summaries/`; the raw logs stay machine-local, because they carry the emulated devices' addresses.

| case | base | 1/3 | 1–2/3 | 1–3/3 |
|---|---|---|---|---|
| kmemleak objects: failed resume, command deferred (3 runs) | 1, 1, 2 | 0, 0, 0 | | 0, 0, 0 |
| kmemleak: `play_deferred()` submission fails | 0, 0, 1 | 0, 0, 0 | | 0, 0, 0 |
| kmemleak: dead device, then close | 2, 5, 2 | 0, 0, 0 | | 0, 0, 0 |
| kmemleak: dead device, hci0 powered off | 2, 3, 2 | 0, 0, 0 | | 0, 0, 0 |
| kmemleak: healthy suspend and resume (1 run) | 0 | 0 | | 0 |
| **new:** command + 2 ACL deferred, first submission fails (5 runs) | 2, 6, 6, 6, 6 | | | 0 ×5 |
| widened anchoring window, command sent inside it (3 runs) | | parked, timed out (0x05 after ~2.0 s), then "Resetting usb device" ×3 | sent at that resume (0x00 after 0.399 s) ×3 | |
| failed resume with a second sender: deferred anchor afterwards (3 runs) | not empty ×3 | not empty ×3 | not empty ×3 | empty ×3 |
| six other emulated cases (2 runs each) | as 1–3/3 | | | identical to base (the power-off-during-resume case fails on both) |
| stress, 100 cycles, 3 seeds | 95/95 ok, 0 parked, 24–26 leaked objects | | | 95/95 ok, 0 parked, 0 leaked |

- **The multi-URB test:** the debug line reads, in all ten runs on both kernels, "deferred before 3 (2 with NULL
  setup_packet), tx_in_flight before 0 after 0, anchor after empty". Base's kmemleak sites are all
  `alloc_skb_with_frags <- sock_alloc_send_pskb <- hci_sock_sendmsg`: the command skb and both ACL skbs, 208 + 640
  bytes each. The setup packet and the URBs are freed already. So the cleanup loop at the end of `play_deferred()`
  is now covered.
- **The widened window on 1/3:** the stale send at the next resume was **not seen**. The command timeout leads to
  `btusb_reset()` ("Resetting usb device."), the device re-enumerates, and the parked command is lost, never sent.
  So 2/3's message keeps "times out" and claims no stale send; its note names the reset.
- **Differs from the 11-14 table:** base's `play_deferred()` row found 0, 0, 1 objects this time (2, 1, 2 then). The
  new multi-URB case shows the same leak reliably.
- **Kernel reports:** none in any of the 105 logs (BUG, WARNING, KASAN, lockdep, hung task, Call Trace; grep
  re-run by me).
- **Host check after the pass:** `dpkg --verify` of systemd, bluez, util-linux, coreutils and kmod is clean, and
  the journal holds the current boot. The only system files changed were Chrome's three apt files, rewritten by
  anacron's `cron.daily` at 07:36:57.

**Done the same day:** the testing notes below `---` in each patch and the cover's testing paragraph. Still 0
checkpatch errors, and the files apply in order to `cf357cfc025e` and give the series branch.

**Still to do:**
1. ~~Reruns~~ and ~~testing text~~: done (above).
2. **Replace the old packages:** add SUPERSEDED.md to `../send-20261113/E/` and `../send-bt24-bt25-20261114/` (done 2026-11-23).
3. ~~Recipients~~: done, `recipients.txt` (2026-11-23).
4. **Send day:** the operator's Signed-off-by, checkpatch, the bot checks and a dry run.
5. **`Cc: stable` on 1/3: added 2026-11-24**, now that the operator's bar is met (below). It goes in by the
   operator's word on the send day. There is none on 2/3 and 3/3.
   - Reviewers: 5 of 5 for it in the evidence round of 11-23.
   - 2026-11-24, ~02:40 UTC: 1/3's message gains one sentence below `---` naming the seven lines, and checkpatch is
     still clean.

## 1/3 on every affected stable line (2026-11-24)

`Fixes: 7bee549e197c` (2014) reaches every maintained line, so 1/3 alone was cherry-picked onto each current
tip. Each tip was built twice (with and without 1/3), with the same debug-only injection commit and config, and
run in QEMU with the emulated controller over usbip, under KASAN, lockdep and kmemleak. The tips were 7.3.6,
6.18.65, 6.12.119, 6.6.163, 6.1.193, 5.15.226 and 5.10.275 (`btusb.c` below 7.3, `btusb_main.c` on 7.3). The
evidence is in `evidence-stable-20261124/`: per-image `.versions`, summaries, scripts, and the SHA-256 of the
raw-log archives. The archives are in the private backup, `2026-11-24-co43-stable-runs/`.

- **The applied tree is the real cherry-pick.** On every line, `git merge-tree --write-tree
  --merge-base=888176e9a640^ <tip> 888176e9a640` is clean, and its `drivers/bluetooth` differs by 0 bytes from
  the tree tested.
- **kmemleak**, objects per run (3 runs each), recounted from the raw logs with `scripts/sum-kmemleak-verdicts.sh`:

  | line | failed resume | `play_deferred()` fails | dead, close | dead, powered off | cmd + 2 ACL |
  |---|---|---|---|---|---|
  | 7.3.6 | 3,3,3 | 2,2,2 | 4,1,6 | 1,5,2 | 6,3,3 |
  | 6.18.65 | 3,3,3 | 2,2,2 | 6,6,6 | 6,6,6 | 6,6,6 |
  | 6.12.119 | 3,3,3 | 2,2,2 | 9,8,9 | 6,6,5 | 6,6,6 |
  | 6.6.163 | 3,3,2 | 2,2,2 | 9,9,9 | 6,6,6 | 6,6,6 |
  | 6.1.193 | 3,3,3 | 2,2,2 | 9,9,9 | 6,6,6 | 6,6,6 |
  | 5.15.226 | 3,3,3 | 2,2,2 | 3,3,3 | 6,6,6 | 6,6,6 |
  | 5.10.275 | 3,3,3 | 2,2,2 | 3,3,3 | 3,3,3 | 6,6,6 |
  | **every line with 1/3** | **0** | **0** | **0** | **0** | **0** |

  The healthy control is 0 on both sides everywhere.
- **Behaviour matrix:** six cases, 2 runs each, identical with and without 1/3 on every line. Lines differ among
  themselves:
  - the answers-after-reset and wedge cases fail on 6.12 and older;
  - the dropped-event case also fails on 5.15 and 5.10;
  - close fails everywhere.

  These are the lines' own behaviour, not 1/3's.
- **Kernel reports:** none on 7.3 to 6.1. On 5.15 and 5.10, lockdep "BUG: Invalid wait context" (in
  `btusb_waker`, under KASAN's stack saving) appears in base and patched logs alike, including healthy runs.
  It is read as a config artifact of those lines (inferred, not traced).
- **Guest start on 5.15:** 13 of 56 first runs did not start ("page allocation failure: order:6" before Python
  could read its library). They were rerun (`summaries/stable-5.15-rerun.txt`), and the first logs are kept.
- **W=1 builds** of `drivers/bluetooth/`, tip and tip + 1/3, no debug code:
  - With `CONFIG_PM` on, there is no btusb warning, except one on 5.10, in the tip too (`btusb_match_table`
    defined but not used).
  - With `CONFIG_PM` off, there is none on all seven.
  - 6.6 with PM off needed `BT_HCIBTUSB_MTK` on, or `btmtk.h`'s stubs stop the build, on the tip as well.
- **Machine after the job:** no guest left, and `dpkg -V systemd bluez linux-firmware-qualcomm-wireless` is
  clean.
6. **Laptop soak:** only on the operator's word.
