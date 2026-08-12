# Pre-submission checklist

Everything that must be settled **before** anything from this repository is sent to
`linux-bluetooth@vger.kernel.org`. Items are recorded here rather than in the document
they came from, because each was discovered in a different place and would otherwise be
found only by chance.

Nothing here is optional. A maintainer's time is the scarce resource; a patch that arrives
with a known-unfinished item in it costs more than one that arrives late.

---

## 1. Privacy — purge Bluetooth addresses from git history

**Status: deferred by decision, must happen before submission.**

Twenty occurrences of the operator's headset address, plus a second device address, were
committed and pushed publicly before the sanitiser understood underscore-separated MACs.
The working tree is clean and the sanitiser is fixed (`tools/sanitize-logs.sh`), but the
addresses remain reachable in **git history**.

Assessed as low severity and deliberately deferred: these are Bluetooth device addresses,
not Wi-Fi BSSIDs, so they are not indexed by the public geolocation databases that make a
BSSID leak serious. That justifies deferring the cleanup. It does not justify skipping it —
a kernel patch submission draws attention to the repository, which is exactly when a
leaked identifier stops being theoretical.

What to do:

```bash
# verify the working tree is still clean first
grep -rhoEi "[0-9a-f]{2}([:_-][0-9a-f]{2}){5,}" --include="*.md" --include="*.log" \
     --include="*.txt" --include="*.tsv" . | grep -viE "^AA[:_-]BB[:_-]CC|^11:11:11" | sort -u
# expect: no output

# then rewrite history (git-filter-repo preferred over filter-branch)
git filter-repo --replace-text <(printf '%s==><MAC>\n' 80:C3:BA:9D:26:95 80_C3_BA_9D_26_95 \
                                                       41:42:FF:F2:08:BD 41_42_FF_F2_08_BD)
git push --force-with-lease
```

⚠️ This rewrites every commit hash and requires a force-push to a public repository. Do it
deliberately, on a day with time to check the result, not immediately before sending a
patch.

---

## 2. Evidence gates — none of these are met yet

| Gate | Why it blocks submission |
|---|---|
| **A4 — quantified reproducer** | Until stock has a measured failure rate under a fixed protocol, no build result means anything. There is no denominator. See `tools/bt-trial`. |
| **A0 — read Ubuntu's own 7.0.0-28 source** | The mechanism is verified against upstream v7.0 and the shipped binary, but not against the distribution's actual tree. |
| **Builds A/B/C/D** | The report currently asserts a cause that has never been tested. See `fix-proposal.md` §5a. |
| **Confirm the SCO finding reproduces** | `EX-007` identifies `HCI_Setup_Synchronous_Connection` (0x0428) as the wedging command, from **one** occurrence in one boot. One observation is a lead, not a finding. |

---

## 3. Content that must NOT be sent

- **`fix-proposal.md` §7** — the proposal that all unmatched Bluetooth devices receive a
  default `hdev->reset`. That is an assertion about every controller Linux supports, drawn
  from evidence about one. Raise it separately, afterwards, if the A/B/C/D result supports
  it. Mixing it in risks losing a well-evidenced three-line patch inside an
  under-evidenced large one.
- **Any claim about what firmware the controller runs.** What is established is only that
  Linux never performs the QCA rampatch/NVM download for this ID. What it runs instead was
  never measured.
- **`13d3:3563` as a QCA comparator.** It is `BTUSB_MEDIATEK`. It has been removed from
  every document; do not let it back in.

---

## 4. Mechanical

- [ ] Regenerate the patch anchor against the actual target tree — the hunk context in
      `fix-proposal.md` §1 was written against a different revision.
- [ ] Re-verify `13d3:3503` is still absent from mainline **on the day of submission**.
      Last checked 2026-08-11.
- [ ] Remove the "under active revision" banner from `bug-report.md` once the firmware
      question is resolved either way.
- [ ] Confirm every exhibit cited in the report is still re-runnable, or is annotated as
      not being so. `EX-003` is already annotated — its source boots were destroyed by a
      journald retention accident.

---

## 5. Attribution — an open decision for the author

Commits in this repository deliberately carry no AI attribution. That was a decision about
this repository, taken because anti-AI sentiment could distract from the technical content.

Whether to disclose tooling in the **kernel submission** is a separate decision and belongs
to Iaroslav alone. Worth knowing before choosing: the `Signed-off-by:` line is a legal
statement under the Developer's Certificate of Origin about the right to submit the code —
it is not a claim of unassisted authorship. Some maintainers appreciate a note under the
`---` line (where it does not enter the permanent commit message); others consider it
noise. Either choice is defensible.

The legal name for `Signed-off-by:` is **Iaroslav Voitovych**, which differs from the
email spelling for transliteration reasons.
