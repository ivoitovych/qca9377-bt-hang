# Kernel patches ready to send — outside reviewer 6's answer

*Received 2026-11-14 in answer to `2026-11-14T0300Z-kernel-patches-ready-to-send-for-outside-review.md`.
The text is kept as received, except for the reviewer's tooling marks, which
`scripts/review-text-clean.py` removes, and one remark outside the patches (reviewer 6), marked
where it stood. What we checked, point by point, is in
`2026-11-14T1400Z-kernel-patches-review-answers-checks.md`.*

---

I'll pull the review request and the repo, then check the patches against the upstream kernel tree and list conventions.

**Verdict:** ten of the twelve items are fit to send, most with small edits. Item 11's patch 3 would break system resume and should not go as written, and item 4's BlueZ tests should be split.

What I checked: all 51 quoted files match their SHA-256 and the repo text; every kernel and BlueZ patch applies to `da3cc02587c6` / `20ffd285b58f`, alone and combined; the three stable backports apply strictly to their tags. I read the touched code at the base. I built and ran nothing, and could not reach lore, patchwork or syzbot, so thread and queue states rest on your records.

| # | Verdict |
|---|---|
| 1 CO-44 | Send |
| 2 E | Send |
| 3 A | Send, rate-limited |
| 4 CO-38 | Kernel: send. BlueZ 1/3: split |
| 5 CO-04 | Send after two wording fixes |
| 6 CO-05/26 | Send, as one series with 5 |
| 7 CO-35 | Send |
| 8 CO-22 | Send |
| 9 CO-21 | Send, no stable |
| 10 CO-20 | 1/2 send; 2/2 optional |
| 11 | Do not send 3/5, and so 2/5 |
| 12 CO-02 v2 | Send after one cover fix |

**11, patch 3.** "The system resume path is meant to stay as it is" does not hold.
- **System resume:** `usb_resume_interface()` marks an interface for rebinding only when the driver has no `reset_resume`; with one, it calls it and nothing is re-probed. btusb depends on that rebind: `btusb_suspend()` sets `udev->reset_resume = 1` for Realtek so firmware is reloaded. Your callback only runs `btusb_resume()` there.
- **Autosuspend:** `autosuspend_check()` refuses autosuspend on `USB_QUIRK_RESET_RESUME` devices whose driver lacks the callback. Adding it enables autosuspend on the three Dell models in `btusb_needs_reset_resume_table`, each resume then being a reset and rebind.
- **Direction:** ask linux-usb first, as drafted. Patch 5 is the clearest fix in the series; rebase 4 and 5 off `BTUSB_CMD_DEFERRED` and send them alone.

**11, patch 2.**
- The parked command stays on the anchor after the core has timed it out. With the credit restored, several stale commands can be replayed back to back on a slow successful resume, and no reset follows. Discard the parked URB in the `deferred` branch.
- The sysfs reset attribute also goes through `hdev->reset`, so a manual reset is refused with "Command not sent".

**5.**
- "only completes the request, as before": before, it also cleared `HCI_MESH_SENDING`. Now the flag stays set on that path. That is harmless at unregister, but say so.
- The new comment "is handed over by mesh_send_done_sync()" is wrong in effect. After an on-air cancel, the list head is the next, unsent request, and it gets `MESH_PACKET_CMPLT` without being transmitted. This is pre-existing; fix it or reword the comment.
- Send the patch to syzbot with `#syz test` rather than stating "Not tested with syzbot's reproducer", and Cc the authors of the competing patches.

**4, BlueZ.** "fail on current kernels until the separate fix … lands": that fix (CO-12) is not posted. Merged, those eight cases turn mgmt-tester red for every kernel series the bot runs. Send the infrastructure and passing cases now; hold the eight.

**Smaller points**
- **1:** drop the `Link:` trailer. `@KERNEL_PATCH_LINK@` is still literal in the BlueZ mail.
- **2:** the `failed:` path of `btusb_resume()` still scuttles outside `txlock`; only 11's patch 4 closes it. The message is accurately scoped.
- **3:** once `runtime_error` is set, every deferred packet logs a line; use `bt_dev_err_ratelimited()`. Send A standalone or as 1/5, not both.
- **6:** the `Fixes:` on 2/2 will get a self-described cleanup backported.
- **9:** per-link air mode in the core is right, since `notify()` carries no connection. Set `air_mode` before `state = BT_CONNECTED`.
- **10:** 2/2 adds driver state for a log line and is the one likely to be questioned.
- **12:** "6.18.y and 7.2.y" should read 7.3.y; 7.2.y is EOL and v7.3.4 has the kref. Three patches and the errno split are fine.

**Outside the patches**
- [A remark on the contribution process, for the operator, is left out of this copy.]
- About twenty patches in one day, with v1 of CO-02 unanswered since 27 October, invites triage by volume. I would lead with 1 and 4.
