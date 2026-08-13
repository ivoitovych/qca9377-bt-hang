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
| **Confirm the SCO localisation reproduces** | `EX-006`/`EX-009` localise the failure to synchronous-audio link transitions — setup unanswered in one incident, teardown in the other, and **three SCO setups survived**. There is no single identified triggering opcode; `EX-007`'s causal claim was refuted. What needs reproducing is the localisation, not a command. |

---

## 2a. Submit the separable issues separately

[`issues.md`](issues.md) tracks six distinct defects. They must not be bundled: a small,
deterministic, well-evidenced bug is far more likely to be fixed than a large intermittent
one, and bundling means the weakest member sets the pace for all.

| Issue | Ready? |
|---|---|
| `BT-2` panel-triggered 16.0 s HCI desync | ✅ deterministic, reproducible in seconds, cross-tabbed |
| `BT-4` `btmon` aborts mid-capture (bluez 5.72) | ✅ minimal reproducer found (`hciconfig hci0 name`, EX-011); still needs a backtrace |
| `BT-3` missing `13d3:3503` quirks entry | ⚠️ patch trivial, justification missing |
| `BT-1` the hang | ❌ blocked on the gates above |
| `BT-5` SCO link silent after setup | ❌ one observation |

## 2b. The controlled environment for A/B/C/D

Every trial that compares kernel builds must change **only the kernel build**. On this
machine that is not the current state: since 2026-08-10 it has run a stock kernel inside a
mitigated environment (`EX-013`).

Before the first controlled trial, set the treatment to the least behaviour-changing
configuration that still yields evidence, and keep it identical for stock and for every
build:

| | Setting | Why |
|---|---|---|
| watchdog | **off** | it can recover a controller that would otherwise have hung, concealing the difference the kernel change is meant to make — and with `BT_EARLY=1` it can act *before* any timeout, censoring the outcome entirely |
| USB autosuspend | **restored to `Y`** | disabling it changes the controller's operating conditions from boot onward; it is a workaround under test, not a constant |
| `power/control` | **restored to `auto`** | same |
| periodic health probes | **off** | they inject real HCI exchanges (`EX-011`) and demonstrably perturb one observer already; passive capture plus the protocol's own liveness checks are sufficient |
| passive capture | **on** | `bt-capture`, `bt-trace`, `usbmon`, dyndbg — observation, not intervention |

If autosuspend is worth testing as a factor, make it an explicit row in the design rather
than a silent background condition:

```text
kernel   autosuspend   result
stock    Y (default)   ...
stock    N             ...
A        Y (default)   ...
```

`bt-trial` records the treatment per trial and the report refuses to pool differing
treatments, so a mistake here is visible rather than silent — but it is still a mistake.

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
