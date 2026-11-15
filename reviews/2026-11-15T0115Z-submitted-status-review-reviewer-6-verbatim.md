# Submitted contributions status — outside reviewer 6's answer

*Received 2026-11-15 in answer to `2026-11-15T0115Z-submitted-contributions-status.md` (at `48c147a`).
The text is kept as received, except for the reviewer's tooling marks, which
`scripts/review-text-clean.py` removes. What we checked, point by point, is in
`2026-11-15T0300Z-submitted-status-review-checks.md`.*

---

I'll read the project notes and spot-check a few of the upstream claims before reviewing.
The report holds up as a status snapshot, but it is not yet a sound basis for the CO-02 v2 decision. I spot-checked the CI mirror: Wentao Liang's patch matches the report, and v1's contents and CI results are as described, with one discrepancy (point 8).

1. The air-mode mismatch patch comes from nowhere. v1 on the mirror is three kernel patches: hold a reused SCO connection, don't reuse an aborting one, and synchronize with the disconnect work. Layout (a) is hold + folded + mismatch, so v2 adds a fix the report never introduces or gives evidence for. A series diagnosed as overcomplicated comes back with the same number of kernel patches and more tests.
2. Layout (a) doesn't cure diagnosis 1. The folded fix, which has the hardware evidence, depends on the hold fix, which is emulator-only. The series still leads with the weak patch, and the strong one can't land without it. The report doesn't say which patches keep their stable tags.
3. Diagnosis 3 contradicts the plan. Tying the BlueZ test to the kernel series is called a mistake, yet the plan says "each BlueZ test goes with its kernel change".
4. The Wentao Liang clash is treated as textual only. His patch is about refcount ownership on that error branch: a connection created in the call gets deleted, one found in the hash is still dropped. Your hold fix changes accounting on the same branch, and the report says his bug is real. So does v2 fix, keep or worsen his bug?
   * "Rebase if it lands" doesn't answer that, and the plan never says to name his patch in the v2 cover letter.
   * The report doesn't say whether a 3-way apply was tried.
   * Zijun Hu's SCO patch gets a promised check, but its result appears only in the CO-25 row, where it is irrelevant.
5. "Why is it silent" is not answered. By the report's own numbers, 152 of 383 patches are still "new", so silence is the default. The Sashiko finding dates from 10-29, but the gate behaviour rests on six mails in four days, which doesn't support "routinely". "You were right, partly" never says which part was wrong.
6. Sequencing is ducked. You wanted the simplest patch first. The plan lists CO-02 v2 first and "one at a time, starting with CO-44 or CO-38" third, without saying which goes out first. Twelve packages sent serially at 19+ days each would take most of a year.
7. The apply-test bug needs two follow-ups. If the same script produced earlier results (the 11-14 checks, the CO-38 refresh), those are suspect too. A false "applies" also needs a negative control, meaning a patch known to conflict must fail.
8. Recheck the "closed 11-11" claim. My fetch of mirror PR #1009 shows it still open, with its last event on 10-30. That may be a stale page, but the must-resend rule rests on it.
9. Bookkeeping is loose.
   * The count goes six, then four, then seven, and the seven include a finished item and an issue comment.
   * "Nobody from the maintainer side answered" sits beside Zijun Hu's reply.
   * "Not taking any mesh fixes" sits beside two accepted.
   * "57 days" sits against a send date 40 days back.
   * D1/D2 and the CO-25 decision are requested without restating the options or giving a recommendation.

Sources:

* [bluez/bluetooth-next PR #1009 (CO-02 v1 CI copy)](https://github.com/bluez/bluetooth-next/pull/1009)
* [bluez/bluetooth-next PR #1057 (Wentao Liang's SCO patch)](https://github.com/bluez/bluetooth-next/pull/1057)
