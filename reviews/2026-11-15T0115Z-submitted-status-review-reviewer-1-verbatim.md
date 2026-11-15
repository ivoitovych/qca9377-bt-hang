# Submitted contributions status — outside reviewer 1's answer

*Received 2026-11-15 in answer to `2026-11-15T0115Z-submitted-contributions-status.md` (at `48c147a`).
The text is kept as received, except for the reviewer's tooling marks, which
`scripts/review-text-clean.py` removes. What we checked, point by point, is in
`2026-11-15T0300Z-submitted-status-review-checks.md`.*

---

**Overall: this is a strong, evidence-based status report.** The live checks (patchwork, lore, GitHub, Sashiko, syzbot), the conflict testing (after fixing the apply-script bug), and the self-critique of CO-02 are particularly good. The analysis of why the original series was judged poorly, the rising role of automated reviews, and the volume/pacing warning all track with what is publicly visible.

### CO-02 assessment
You are right that the sent series was overcomplicated in the ways you list:

- Mixed evidence levels under one `Cc: stable` series (only the U7/headset-switch case had hardware reproduction; the others were emulator + one debug-only race).
- Patches 2 and 3 were one logical fix (Sashiko’s “fail, high” on patch 2 alone is exactly the point that an unanswered finding now stalls things).
- The BlueZ test was coupled to the kernel series and then went stale when the tester framework changed.

Your dependency check on current bluetooth-next is the useful one: the hold fix and the folded abort/wait fix belong together; the air-mode mismatch and the BlueZ tests can travel independently. Layout (a) (2-patch series of hold + folded fix, then the mismatch as its own mail, each with its matching BlueZ test) matches the real dependencies. That is the right shape for a v2.

The hard textual conflict with Wentao Liang’s 14942649 (same error path in `hci_connect_sco()`, neither applies on the other) is real. His claim appears to hold against the source, and the public reaction to his batch makes landing uncertain. Treat it as a rebase risk, not a reason to delay the v2 indefinitely.

### Automated reviews and list dynamics
The observation that Luiz is now routinely sending authors to Sashiko (kernel) or Copilot (BlueZ mirror) before further human review matches the public pattern since early November. An unanswered high finding is now a plausible stall. Answering it explicitly in the v2 cover (and in the folded patch message) is the minimum that needs to happen on the resend day.

The volume numbers and the single-vs-series acceptance gap are useful context. The 11-04 pushback against ungrouped AI-assisted floods is also real. “One kernel submission at a time, starting with the reviewers’ pick, and answer any Sashiko/Copilot finding within days” is the correct operational constraint given the current mood.

### Other items
- **CO-25**: The ready reply is still the open decision. Qualcomm’s “not ROME / btusb doesn’t support it” statement is narrower than how the driver has historically treated several QCA9377 USB IDs (they appear in the ROME device table in multiple places). Whether to send the correction is yours; the technical record is already solid either way.
- **Mesh / gvfs / BlueZ #1554 / Tested-by on stable**: The “nothing changed, no human replies” summary is consistent with the public record. Holding the mesh queue (or sending only the single overview) is the low-risk choice while that area stays cold. The gvfs MRs and the BlueZ issue can wait for organic reviewer time.
- **CO-43 / Jens Willmer**: The textual conflict on B2 and the fact that the maintainer is engaged with the suspend notifier patch are correctly noted. Rebase B2 if it lands; keep D v2 held.

### Process notes
The admission that the first apply test was invalid (scratch dir inside the repo) and the subsequent re-run with positive controls is exactly the kind of hygiene that makes the conflict findings trustworthy. The STATUS line and the committed report (`48c147a`) close the loop cleanly.

### Recommended path
Resend CO-02 as v2 in layout (a) on a fresh base after the usual pre-send checks, with the cover explicitly stating that the two pieces of the abort/hold fix are now one patch and that the Sashiko finding is addressed by the fold. Pair the BlueZ tests with their kernel changes. Pace everything else. Decide on the Qualcomm reply independently.

The report itself does not need major structural changes for internal use; the table + the “what can/can’t be separated” section already give the actionable summary. If you ever need to show a shorter version to someone else, lead with those two pieces.
