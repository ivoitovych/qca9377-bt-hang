# Plan of further actions (2026-11-27)

**What this is.** A proposed order of work from the state of 2026-11-27, written from the working session's knowledge,
for the operator to consider. Each step says what to do and why. Nothing here is decided. It follows the operator's
rules:
- one item at a time;
- focused review rounds until clean;
- the operator sends and signs;
- the laptop only on his word;
- replies before new work.

Companion pages: [`2026-11-27T0330Z-project-considerations.md`](2026-11-27T0330Z-project-considerations.md) and the
outside reviewer's [`2026-11-23T1757Z-project-considerations.md`](2026-11-23T1757Z-project-considerations.md).

## Stage 0: every session, before anything else

1. **Reconcile upstream state.**
   - **How:** read lore for replies to every sent Message-ID, patchwork states and CI checks, the Launchpad bugs,
     GNOME through its notification mail and its GitHub mirror, and BlueZ and kernel tips by tree.
   - **Why:** three same-day replies were missed on 2026-11-26 because they came through tracker notifications.
     Replies outrank new work.
2. **Record each finding in its STATUS row the same hour,** with who decided what.
   - **Why:** facts kept in many places drift. One home, written at once, is the cure.

## Stage 1: answer what upstream already gave us

3. **gvfs !369: answer the four review points** (`contributions/X1-gvfs-cdda-readahead/review-369-2026-11-26.md`).
   - **Points 1 to 3** are direct: also check `first_track` for `CDIO_INVALID_TRACK`; one validation helper shared by
     `do_open_for_read()` and `do_query_info()`; an error message naming libcdio.
   - **Point 4 first needs facts:** may an audio CD's first track number be other than 1, and does libcdio report it
     so?
     - If it can, `do_enumerate()` and `set_info_for_track()` must follow; this overlaps X3.
     - If not, drop `first_track` from the check.
   - **Then:** rebuild, rerun the test program and gvfs's CI locally, and update the existing MR (a force-push to the
     fork branch, done by the operator). Reply on each discussion in the operator's words.
   - **Why:** a maintainer has spent his time; a prompt, careful answer is the best use of ours.
4. **CO-25: send the short acknowledgement to Zijun Hu**
   (`contributions/CO-25-qualcomm-rom-report/drafts/reply-2-zijun-hu-ack-v1.eml`).
   - **Steps:** one focused review round, a dry run, then the operator sends.
   - **Why:** the vendor offered to upstream the intended firmware. A light, thankful note with an offer to test
     keeps that door open without pressure.
5. **Filelight SRU (LP #2084169):**
   - **Steps:** check that the Noble package still needs the debdiff; then one polite comment on the existing bug.
     Sponsors are already subscribed, so do not subscribe again. Also correct that repository's README ("not yet
     filed").
   - **Why:** finished work waiting only for a sponsor is the cheapest to move.
6. **CO-38: watch, do not touch.**
   - **Watch for:** replies, the BlueZ test's patchwork entry and CI, and the kernel fix landing in bluetooth-next.
   - **If the BlueZ CI closes the test after two weeks unapplied,** resend it once.
   - **If review renames the fix,** send the test as v2.
   - **Why:** both halves are out; any change now should be in answer to someone.

## Stage 2: the next sends, one at a time

7. **CO-44: a timed-out MGMT command reported as Authentication Failed.**
   - **Tests:** rerun its full suites on the current bluetooth-next and the stable tips, as CO-38's were, including
     6lowpan and the cases after the hangs.
   - **Then:** the list's CI locally; focused review rounds on that one patch and its test; checkpatch; the
     operator's sign-off.
   - **Send:** the operator sends, then the BlueZ test the same day.
   - **Why:** it is the next small, self-evident fix of the form that is applied unchanged.
8. **CO-43: the btusb series** (deferred transmit URBs: a leak fix first, then two races).
   - **How:** the same full standard. Consider an RFC first for the locking parts.
   - **Why:** larger and in driver locking, where the maintainers' preferred shape matters more than our polish.
9. **CO-02 v2: SCO connection reuse.**
   - **Rework on today's tree:**
     - fold patches 2 and 3;
     - use the non-sleeping variant;
     - recheck against the intervening `hci_conn` changes and the competing posting;
     - port the sco-tester test to the current tester API;
     - rerun everything.
   - **Send:** as v2 of the original series, with a changelog. The test is resent with it.
   - **Why:** the original has had no human review for a month, and the CI asked for a resend. A blind resend would
     waste the reviewers' time.
10. **CO-26:** the mesh failed-add error path, after the above. **Why:** small, but in the area the maintainer just
    reworked; check first that it still applies.

## Stage 3: work that reaches users of this laptop

11. **The Ubuntu 24.04 BlueZ bundle** (CO-03, CO-11a, CO-37 backports, CO-40):
    - **Steps:** file the Launchpad bugs, then the SRU, with the built and tested packages.
    - **Why:** every fix in it is released upstream. The outside reviewer judged it the most value per hour; it
      reaches users of the distribution the laptop runs.
12. **CO-03 laptop test (the operator's hour):** the staged `bluetoothd` build with the headset scenario.
    - **Why:** it is the step the bundle's claims rest on, and it needs only the laptop and a checklist.
13. **The patched CO-38 module on the laptop:** keep it until the operator wants stock back
    (`scripts/module-updates.sh --krel 7.0.0-44-generic remove`, then a reboot).
    - **Optional:** the bluetoothd start-up check that shows what the bug costs a user. **Why:** answers "what does
      it cost?" from hardware, if a maintainer asks.

## Stage 4: QCA firmware and the device table

14. **CO-22: decide.** Keep holding the stable request for the two ASUS entries until Qualcomm's firmware plan is
    clearer; or send it with a sentence on the vendor's view.
    - **Why:** the entries load the same files Qualcomm calls a workaround. Users still benefit today, but the request
      should not overstate what the files are.
15. **When Qualcomm posts QCA9377 firmware:** test it on `13d3:3503` with the original mSBC call test (timeouts
    counted per SCO link) and report the result on the thread.
    - **Why:** it is the natural end of the original investigation, and the help we offered.

## Stage 5: the testing sub-project

16. **First tool:** turn the CO-38 suite scripts (runner with hang watchdog, per-case comparison, report scan) into
    one maintained base-against-patched harness in `bt-test-suites/`.
    - **Why:** every future send needs it, and it is the design's "stable-line matrix" already half built.
17. **First upstream contributions,** small and in upstream's own form (part 3, §9 of the design):
    - a coverage table over the existing testers, with its script, replacing the outdated `doc/test-coverage.txt`;
    - management-tester cases for `CANCEL_PAIR_DEVICE` and `SET_WIDEBAND_SPEECH`;
    - two functional tests: voice-link set-up interrupted by disconnect, profile connection interrupted by power-off.

    **Why:** results that ask nothing of the maintainers, and each is checkable on their own machinery.
18. **Then the larger pieces, each proposed on the list before being written:**
    - a scripted failing answer in the emulator;
    - the failure walker;
    - the interleaving walker on simulated time;
    - sniff and role-switch emulation.

    **Why:** these change shared test infrastructure; agreement first saves work on both sides.

## Stage 6: the record itself, in the operator's time

19. **Records:** one home per fact; shorter STATUS rows; a hand-off that is rewritten rather than appended.
    **Why:** the drift of 2026-11-26 was structural. Smaller pages are read, and read pages stay true.
20. **Decide the long-open lists** (D1 to D14 of 11-02, D-1 to D-7 of the incident) and the reviewer branches, once,
    in writing. **Why:** an open decision is a decision not to act, renewed every day.
21. **Close dormant register items with one line each,** and reopen only when work resumes. Report the mesh harness
    results as a test report on the maintainer's applied fix. **Why:** an open item costs attention at every
    reconciliation.
22. **Housekeeping by rule:** each task cleans its own area at the end. A short survey when free space falls under
    50 GB. The remaining old candidates (older Ubuntu kernel trees, October worktrees) are listed for the operator.
    **Why:** it stops the 29 GB situation from recurring.

## Order at a glance

0 reconcile → 3 gvfs !369 → 4 CO-25 ack → 5 Filelight → 7 CO-44 → 8 btusb series → 9 CO-02 v2 → 11 Ubuntu bundle →
16 the harness → 17 first test contributions; with 6, 13 and 15 as watches, and 19 to 22 as the operator's time
allows.

*Written on 2026-11-27; a proposal, to be revised as replies arrive.*
