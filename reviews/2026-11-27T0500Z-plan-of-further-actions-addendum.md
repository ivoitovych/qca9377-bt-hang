# Addendum to the plan of further actions (2026-11-27, 05:00 UTC)

**What this is.** Corrections and additions to [`2026-11-27T0345Z-plan-of-further-actions.md`](2026-11-27T0345Z-plan-of-further-actions.md),
from a re-read of the registers the same morning. The plan itself is left as written. Nothing here is decided: the
plan stays a proposal, and every open decision below is the operator's.

## 1. Step 9, CO-02 v2: the shape is settled in the register

- **What the register says** (`contributions/README.md`, "What to send"; STATUS, the CO-02 row):
  - v2 is 1/2 plus a folded 2/2. Sashiko's review of 10-29 rated patch 2 `fail` alone and asked to fold 3 into 2.
  - The folded 2/2 is the **non-sleeping** variant (`review-fixes-20261115/patches/alt-2of2/`). The sleeping one can
    deadlock, 3 of 3 runs with delays (2026-11-15).
  - The air-mode mismatch patch goes **later, alone** (`review-fixes-20261115/patches/standalone-3/`).
- **What this supersedes:** the 11-02 recommendation D1 (`review-2026-11-02/followups.md`) to send the fold, the test
  port and the mismatch patch together. That was a recommendation, not a decision, and the 11-15 deadlock finding
  overtook it. D2's conditions (-EBUSY on a live link, -ECONNABORTED on a closing one, a test of a setup already in
  flight) now belong to the later mismatch patch.
- **Left before v2:**
  - checkpatch and the list's CI locally;
  - an apply check on the tip, including Jeremy Dean Clifton's `hci_conn.c` patches of 11-17 (`1f150a0bb8a1`,
    `56abe5c17b4d`), and a read of another author's "Bluetooth: hci_conn: Don't leak hci_conn when dequeuing its
    create command" (posted 2026-11-26 23:48 UTC) for overlap;
  - the ported sco-tester tests copied into the candidate's directory;
  - the operator's choice of the stable trailer form.
- **Then:** CO-30's RFC must be re-tested on the non-sleeping 2/2, since it was tested only on the withdrawn one.

## 2. Step 11, the Ubuntu bundle: open questions, not conflicts

The bundle in `contributions/ubuntu-bluez-5.72-0ubuntu5.9-bundle/` merges CO-03, CO-11a, CO-37's 5.72 backports and
CO-40. The register already records that this differs from the 11-02 recommendation D6, and that "the operator has not
decided". Before filing, the operator decides:
- **D6:** one upload, or CO-03 + CO-11a now and CO-37's backports as a separate update (an outside reviewer's
  reason: different risk stories);
- **D3:** the reporting route for CO-23/CO-37's lifetime fixes, the list or BlueZ's private advisory;
- **C1 and C2** (the 11-16 list): a debdiff or a merge proposal, and when to file. C3 (a PPA build after filing) is
  decided.

**Also:** U27 (an ASan use-after-free in 5.72's `clear_endpoint()`) is not covered by CO-37's 5.72 backport (STATUS,
U27). An update that claims the endpoint exit path needs a 5.72 fix first.

## 3. Ready work the plan did not list

From `contributions/README.md`, "What to send":
- **Ready to send, each needing its send commands and a dry run:**
  - CO-21 (btusb SCO alternate setting; the mixed-mode question is in its cover);
  - CO-20 patch 1 alone;
  - CO-39 and CO-41 (BlueZ);
  - CO-43 A (after E);
  - CO-26 alone (variant A or B, the operator's choice).
- **To rebase:** CO-35's 6.18.y, 6.12.y and 6.6.y backports, onto the queued sibling L2CAP patches. The operator
  decides between the full and the reduced prerequisite, and whether to ask the stable team first.
- **Under review:** CO-46 (systemd's journalctl slowdown, a Noble update); a second review round was decided (C4).
- **Waiting on D3:** CO-23 and CO-37.
- **Registered, no package yet:** BT-29 (ISO broadcast: a user-supplied BIS number is not range-checked).

By the operator's rule of 2026-11-27, each still goes one at a time, in focused rounds.

## 4. Watches and deadlines the plan did not list

- **D-4** (the incident decisions of 11-21; BRIEF, "Earlier decision lists"): copy the text logs of 11-16 to 11-20
  before they rotate away.
  - Where they are: `/var/log/syslog.1` holds 2026-11-15 to 11-22 (read 2026-11-27).
  - Why the date: rsyslog rotates weekly and keeps four, so that file is removed at about the 2026-12-20 rotation.
    Inferred from the rotation policy, not observed.
  - Why it is the operator's: the decision includes a deletion.
- **The BlueZ CI closure** of CO-38's test (patchwork 15027599): about 2026-12-10 if it is unapplied; then resend once.
- **Each boot:** BT-16 (a boot without Bluetooth, seen three times, once on the stock `7.0.0-43`) and BT-17 (an idle
  controller lost at resume, once). Both happen with the patch loaded, so they are not BT-1.
- **CO-22's second mail**, the one to the device owners: the 11-02 recommendation D7 is short Launchpad comments
  first, in the operator's words. It is open, like the stable request itself (held).

## 5. Counting, for step 15 and any later BT-1 claim

The 74 links of E1 and E3 are **50 mSBC and 24 CVSD** (EX-058: 43 and 15; EX-057: 7 and 9). Only mSBC links on
alternate setting 1 ever died, so a test of new firmware counts mSBC links separately. The sent CO-25 report already
states the split; BRIEF §0's "74 links" is shorthand for it.

## 6. A tool note

`git -C cache/lore-linux-bluetooth-0.git fetch -q origin` updates only FETCH_HEAD, because the clone has no fetch
refspec. `scripts/lore-git-replies.py` reads `master`, so after a plain fetch it silently stops at the previous tip.
Fetch with `origin master:master`.
