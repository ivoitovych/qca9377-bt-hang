# Five kernel submissions: five outside reviews, and our checks (2026-11-23)

**What these answers are.** Reviewers 1, 2, 3, 6 and 7 answered
`2026-11-22T1513Z-five-kernel-submissions-for-outside-review.md`, which covers:
1. btusb: anchor a deferred URB under txlock (CO-43 E);
2. MGMT: timeout reported as Authentication Failed (CO-44);
3. MGMT: Read Advertising Features hides instances (CO-38);
4. the stable request for two ASUS QCA ROME IDs (CO-22);
5. the btusb deferred-URB series on item 1 (CO-43 BT-24/25).

The answers were relayed by the operator on 2026-11-23. The full texts are stored privately; this
file keeps their findings. They are opinions to weigh, not verdicts.
- **What the reviewers did.** Reviewers 2, 3, 6 and 7 read the current kernel and BlueZ source,
  and the list traffic of October and November. None of them built or ran the patches.
- **How checked.** "Checked" below means re-read in our trees on 2026-11-23: bluetooth-next
  `cf357cfc025e`, BlueZ master `1adfe662efef`, and the 2017–2026 history in `cache/linux`.

## 1. Verdicts

| item | R1 | R2 | R3 | R6 | R7 |
|---|---|---|---|---|---|
| 1 btusb anchor (E) | send | send after minor changes | send, as one series with item 5 | send after a message addition | send after small changes; one series with 5 |
| 2 MGMT timeout | send | send after minor changes | send after small changes | send after edits | send after message edits |
| 3 kernel | send | ready | send after minor changes | send | send after small edits |
| 3 BlueZ test | send | **revise** | **revise** | **rewrite (~30 lines)** | **hold and simplify** |
| 4 ASUS stable request | send after the date refresh | send after a refresh | send after refresh and pruning | send after the date refresh, trimmed | send after an accurate refresh |
| 5 deferred-URB series | send with item 1 | **hold** | **merge into one series with 1** | **hold, restructure** | **one series with 1, after a multi-packet test** |

**No reviewer found a correctness defect in any of the five kernel diffs.** The changes asked for
are in the tests, the messages, the trailers and the packaging.

## 2. Findings and checks

| # | finding (reviewers) | check on 2026-11-23 | action |
|---|---|---|---|
| 1 | **Item 3's BlueZ test is too large** (388 added lines; R2, R3, R6, R7). It couples a listing fix to duration timing (50 ms early / 1000 ms late, a fixed 2.5 s check); its membership check allows extra or duplicate entries (R7); its name says "Ext" while the case uses Add Advertising (R2). R6: the bug needs no timeout at all. With only instance 2 added, `adv_instance_cnt` is 1 and `2 <= 1` hides it. | **Confirmed in code.** The kernel's test is `adv_instance->instance <= hdev->adv_instance_cnt`. One added instance numbered 2 is excluded. Weihong Guan's "mgmt-tester: Add single advertising set tests" (BlueZ `923d95d0c`, 2026-11-16) is in master. Its subject is 56 characters, over BlueZ's 50 (R7; CO-44's subject is 46 and fits). | **Rewrite the test**: add only instance 2 (or add 1 and 2, then remove 1 explicitly), read features, and assert exactly one instance, ID 2, and the exact length. Use a new subject of at most 50 characters. Rerun base against patched. |
| 2 | **A user-visible consequence for item 3's message** (R6): bluetoothd clears leftover instances at start-up only `if (feat->num_instances)`, so a lone hidden instance survives a restart. | **Confirmed in code**: BlueZ `src/advertising.c` l.2043. Not shown by a test. | Add one sentence to the kernel message once a test or a laptop run shows it. |
| 3 | **`Cc: stable` on item 3** (R2, R3, R6, R7; R1 optional). | The precedent D12 of 11-02 recommended the same. | **Add**, subject to the operator's word. |
| 4 | **Item 2's message is too long.** Cut "if it was deliberate, please say" (R2, R3, R7; R6 would keep it as one line; R1 would keep it). Cut the LE-connection paragraph (R7). Move the user-visible change above `---` (R6). Drop "the two HCI statuses", since another posting maps a third status to `-ETIMEDOUT` (R6). | Notes measured: 235 words below `---`. R6's third-status patch was **not found** in the patchwork lists read; the count is cut either way. | **Shorten** the body and the notes. Reviewer 7 offers a core text. |
| 5 | **`Cc: stable` on item 2**: R2, R3 and R7 for; R1 and R6 against. R6 cites the precedent "MGMT: Return RFKILLED for Set Powered on a blocked controller". | **Checked**: the precedent is bluetooth-next `7eac806143005` (2026-11-02). It carries `Fixes: cf75ad8b41d2` and **no** `Cc: stable`, the same shape as item 2. | The operator's call; the precedent favours none. |
| 6 | **Item 2's `Link:`** (2022): drop it (R2, R6), or keep it only if verified (R3, R7). | Nobody could retrieve it, us included. | **Drop** unless verified on the send day. |
| 7 | **Item 2's subject**: "Bluetooth: MGMT: Report command timeouts correctly" (R7). | — | The operator's choice. |
| 8 | **When to send item 2's BlueZ test**: the same day after the kernel mail's lore link (R1, R3, R7), or only once the kernel fix is accepted (R2, to keep BlueZ's CI green on unfixed kernels). | — | The operator's call; the same-day form is ready. |
| 9 | **Items 1 and 5 as one three-patch series** (R3, R6, R7; R2: send 1 alone, then 5 dependency-safe). The leak fix goes first, since it needs nothing (R2, R3, R6). | **Checked**: the leak fix conflicts unless the race fix is under it, on E and on the bare tip (F-45). | **Regenerate**: leak fix rebased to stand first, then item 1, then the failed-resume patch. One cover: "Bluetooth: btusb: Fix deferred URB leaks and races" (R3) or "… Fix deferred transmit handling" (R7). |
| 10 | **Item 5's `base-commit` is private** (R6, R7), and the cover uses an internal label "E" (R6, R7). | **Confirmed**: no public remote has `04b58d680611` ("not our ref"); it is not item 1's commit `d4b60eb0fcf7` either. | Regenerate with `--base=<public commit>` and drop the label. |
| 11 | **The leak patch's second `Fixes: 19cfe912c37b`** is an incomplete earlier repair, not an origin (R2, R7). | **Confirmed in its diff** (2017). Before it, `play_deferred()` scuttled the anchor, freeing neither setup packet nor skb. It added the setup and URB frees, and still no skb free. The leak dates from `7bee549e197c`. | **Keep one `Fixes: 7bee549e197c`**; name `19cfe912c37b` in prose. |
| 12 | **"runs under txlock … in two of them" is wrong** (R7): three of the four discard sites run locked. | **Confirmed on the tip**: `play_deferred()` is called only under `txlock` (`btusb_main.c` l.5067–5070). With patch 1 the failed-resume scuttle is under it too. Only `btusb_close()` (l.2238) is unlocked. | Reword: "The resume paths run with txlock held and interrupts disabled." |
| 13 | **Multi-URB discard is reachable** (R2, R7): ACL and ISO packets are also deferred through `submit_or_queue_tx_urb()`, so "the command credit allows one" describes the harness, not the driver. This also covers the NULL `setup_packet` (bulk) case. | Not re-read in code today. The finding stands on the driver's send paths. | **Add a test**: two or more deferred URBs, with a command plus ACL; fail the first submission; check every skb and URB is freed and the anchor empties. Name the kmemleak allocation sites. |
| 14 | **`btusb_close()` "nothing can anchor" is overstated** (R6). `__hci_cmd_send()` and `hci_send_vendor_frame()` reach `hci_send_frame()` from driver context, and its `HCI_RUNNING` test is lockless. R1, R3 and R7 find the argument sound for the core's works. | Not re-read in code today. | Reword it to the core's works being stopped, with the worst case a parked URB, as today. |
| 15 | **Patch-level testing notes**: item 3 has none, and item 5's commits rely on the cover (R7). | Confirmed by reading the files. | One or two sentences per commit, below `---` or in the body. |
| 16 | **Item 1's consequence is undersold** (R6): `hci_cmd_timeout()` calls `hdev->reset`, which on QCA ROME is `btusb_reset()` ("Resetting usb device"). The parked command is also sent stale at the next resume. | Not checked in the logs today. | Add it only if the widened-window logs show the reset line. |
| 17 | **`Cc: stable` on item 1**: against (R1, R2, R3, R6, since the race was seen only with a widened window); for (R7). | — | Keep none, as packaged. |
| 18 | **Item 4: shorten.** Drop the code block, the rename-detection note and the `btmtk.h` detail (R6; R2 condense). Remove the QCA9377 precedent sentence, because the Qualcomm reply disputes that classification (R3; R2 and R7 would shorten it to one sentence; R6 would keep one line; R1 would keep it). Keep the apply-check date and the build date separate (R2, R7). | The apply check is of 2026-11-22. The builds are of 11-14, on older tips. | **Rewrite**: commit IDs, trees, reason, the apply check (11-22) and a fresh build on the send day. The precedent is cut, or reduced to one sentence (the operator's choice). |
| 19 | **Item 2 and item 3 tester numbers are stale** (R6): `mgmt.c` changed by +294/−83 since the base. | **Confirmed**: `git diff --shortstat da3cc02587c6 cf357cfc025e -- net/bluetooth/mgmt.c` gives 294 insertions and 83 deletions. `btusb_main.c` is unchanged. | **Rerun** mgmt-tester (and mesh-tester for item 3) on the tip, and update the base hash in the notes. |
| 20 | **Hardware.** A short no-regression soak of the btusb series on the laptop: runtime and system suspend, commands in a loop (R2, R3, R6, R7). Item 3's bug should show on the laptop with `btmgmt add-adv` of instance 2 alone, then `btmgmt advinfo` (R6). | Not run. Both touch the laptop's Bluetooth. | **The operator's word** before either. |
| 21 | **Add the Signed-off-by in git, and re-run the checks on the exact bytes sent** (R6, R7). | The packages carry none on purpose: the operator adds his own. | On the send day, run checkpatch, the bot's sign-off checks and the dry run **after** his line is in. |
| 22 | **Bookkeeping**: the document says "four kernel patches", and there are five kernel diffs (R7). Every test count should name its patch stack (R7). | Confirmed. | Fix in the next build of the document. |
| 23 | **Item 1's code comment** could be shorter (R2), and item 3's wording "whenever the instance numbers are not 1 to n" should be narrowed (R2, R7). | — | Small edits. |

**Not taken over**:
- Reviewer 2's advice to post BlueZ tests only after the kernel fix is accepted, as a general
  rule (finding 8, the operator's).
- Reviewer 1's "send all five as is".

## 3. What the reviewers found about recent list practice

Reviewer 6 counted 268 Bluetooth patches posted between 15 October and 22 November, with 120 of
them applied under the same subject. The median from first post to commit was 4 days, the 75th
percentile 11 days, and the longest 23 days. By that measure, CO-02 v1 (at 26 days) is past the
longest wait of anything applied, which agrees with the CI bot's request to resend.

Reviewers 2, 3 and 7 sampled about a dozen recent efforts each. The pattern they agree on:
- **What succeeds:** a single-purpose fix with an observable before and after, a stated invariant
  and a short message.
- **What falls behind:** larger patches and patches that add machinery, such as an oversized test
  framework.
- **Duplicates:** a duplicate posted later can still win over one left waiting (R6).

These are their surveys, not ours.

## 4. The work that follows, in order

1. **Item 3.** Rewrite the BlueZ test (finding 1). Rerun base against patched on today's tips.
   Shorten the kernel message (23), add a testing note (15) and the start-up sentence (2), and
   decide `Cc: stable` (3).
2. **Item 2.** Trim the message (4, 6), rerun the testers on the tip (19), and redo the dry run.
3. **Item 4.** Rewrite the mail (18), and build on the send day.
4. **Items 1 + 5.** Regenerate as one three-patch series on a public base, with the leak fix
   first (9–12, 14, 15). Add the multi-URB test (13), then the laptop soak if the operator agrees
   (20).
5. **On each send day:** the Signed-off-by, the checks and the dry run (21). One mail at a time,
   several days apart.

Nothing was changed in any package by this file, and nothing was sent.
