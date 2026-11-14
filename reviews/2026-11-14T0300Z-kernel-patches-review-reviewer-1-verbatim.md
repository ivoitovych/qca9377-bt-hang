# Kernel patches ready to send — outside reviewer 1's answer

*Received 2026-11-14 in answer to `2026-11-14T0300Z-kernel-patches-ready-to-send-for-outside-review.md`.
The text is kept as received, except for the reviewer's tooling marks, which
`scripts/review-text-clean.py` removes, and one remark outside the patches (reviewer 6), marked
where it stood. What we checked, point by point, is in
`2026-11-14T1400Z-kernel-patches-review-answers-checks.md`.*

---

**Review of the 2026-11-14T0300Z “kernel patches ready to send” document**

This is a well-structured, self-contained pre-send package. The testing methodology (local CI-bot runs, BlueZ testers in QEMU, usbip-driven real btusb with KASAN/lockdep) is appropriate given the laptop constraint, and the per-item SHA-256s + full diffs make independent verification straightforward. Items 1–10 and 12 look ready; item 11 correctly stays in review.

### Per-item assessment (as a maintainer would)

**1. CO-44 (MGMT timeout → `MGMT_STATUS_TIMEOUT`)**  
No objection. Correct, precise, and well-tested (new mgmt-tester case fails on base, passes after; other testers unchanged). `Fixes: 161510ccf91c` is right.  
- `Cc: stable`: yes. The mapping has been wrong for years and produces actively misleading logs.  
- `Link:` to the 2022 BlueZ posting is useful context, not noise.  
- Subject is fine.

**2. CO-43 E (anchor deferred URB under `txlock`)**  
No objection. The race is real, the lock move is correct and matches the existing order in `play_deferred()`, and the stress + delayed-window tests cover it. `Fixes: 7bee549e197c` holds. `Cc: stable` is reasonable.

**3. CO-43 A (`btusb_waker()` logs failed resume)**  
No objection. Small, correct, and the emulator confirms the log appears. The `-EACCES` exception is right. No `Fixes:` needed.

**4. CO-38 (Read Advertising Features hides instances)**  
No objection. The off-by-one / wrong limit is clear, the BlueZ tests cover it, and the rebase checks look clean.

**5. CO-04 (mesh_send_sync use-after-free)**  
No objection to sending. The flag-lifetime fix under `hdev->lock` closes the window the syzbot trace shows, avoids the lock-order problem of the competing patch, and the unregister-sweep lockdep improvement is a nice side-effect.  
- Mentioning the unreproduced status below `---` is honest and fine.  
- The circular-dependency note can stay below `---` (or move into the message if you prefer; either is acceptable).  
- `Cc: stable` is correct.

**6. CO-05 + CO-26 (mesh_send_sync lock + lost error)**  
No objection. Both defects are real; the lock is taken at the right points and dropped before HCI commands. They apply cleanly in either order relative to CO-04. Keeping them as a two-patch series is fine; they can also be sent independently if you prefer smaller mails. The cover letter’s notes about the other unlocked callers and the withdrawn/pending patches are useful.

**7. CO-35 (L2CAP ECRED deferred-accept hang, stable backports)**  
No objection. The retest on current stable tips, the option-2/3 framing, and the covers look correct. Send the request first, then the three series newest-first.

**8. CO-22 (ASUS QCA ROME entries, stable request)**  
No objection to the request. The recheck against current tips is sufficient for a “please apply these two entries” mail.

**9. CO-21 (btusb SCO alt-setting selection)**  
No objection. The change from “last notification” to “count of currently-up links of each mode” is the right fix for the race that leaves the interface on alt 0 while a SCO link is still active. The two-patch split is clean and the usbip scenarios cover the important cases.

**10. CO-20 (btusb logs closed-SCO data as corruption)**  
No objection from the description and checks. (I did not re-read the full diff in this pass, but the problem statement and testing notes are consistent with the rest of the package.)

**11. CO-43 rest (failed-resume paths)**  
Correctly held back. From the previous open-work document, patch B is still wrong as written (`dropcmd-wedge` leaves the device unrecovered) and D’s queued reset can be lost / interacts poorly with the core’s `needs_binding` behaviour. Do not send until T1/T2 from the earlier brief are resolved.

**12. CO-02 v2 (SCO connect reuses closing link)**  
No objection to posting v2. The earlier v1 is already on the list; folding the review comments and updating the BlueZ test is the normal next step.

### Overall form and process notes

- Missing `Signed-off-by` is expected and correctly called out; the author adds it on send.  
- Recipients from `get_maintainer.pl` look right for each item.  
- The local CI-bot runs (difference-only) are a good proxy and match what the list bot will do.  
- No over-claiming in the messages I checked; the “not reproduced” and “KCSAN quiet this run” notes are appropriately placed below `---`.

**Recommendation:** Send items 1–10 and 12. Hold item 11. The package is in excellent shape for the list.
