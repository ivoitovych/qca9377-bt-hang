# CO-22 stable request, v4 (2026-11-23)

It replaces `../refresh-20261114/mail/stable-request-asus-rome-v3.eml` after the outside review of
2026-11-23 (`../../../../reviews/2026-11-23T0404Z-five-kernel-submissions-review-findings-and-checks.md`,
finding 18).

**Changed:**
- Removed:
  - the code block of the two entries;
  - the rename-detection note;
  - the sentence on the earlier QCA9377 request (`dc16388d45ec`). Qualcomm's reply to CO-25
    disputes that device's classification, which would invite a side discussion here.
- The apply check (2026-11-22, on the tips of that day) and the builds (2026-11-14, on that
  day's tips) are stated with their own dates, instead of one date for both.

**Checked 2026-11-23:** `scripts/mail-lint.sh` is clean.

**Facts behind it:**
- **Queue, 2026-11-22 12:47 UTC:** neither commit is in any queue (`scripts/stable-queue-check.sh
  bluetooth-btusb-add-asus …`).
- **Apply, 2026-11-22:** in order, onto 7.3.5 … 5.10.274, with the path renamed as a cherry-pick
  would (`tmp/kernel-readiness-20261122/apply-check.sh`, a machine-local helper).
- **Builds, 2026-11-14:** `../refresh-20261114/CHECKS.md`.

**On the send day:**
1. Re-read the queues and the tips.
2. Rebuild `btusb.o` on them, and then either update the build sentence to that day or keep it as
   dated.
3. Make the send commands and a dry run (none exists yet).
