# Follow-up to the comprehensive review, at `e19fd61` — verification and disposition, 2026-09-20T00:00Z

**Source.** The comprehensive reviewer's re-check of the response to their review, at
`c99dd7d`/`e19fd61`. Verbatim:
[`2026-09-20T0000Z-comprehensive-review-followup-at-e19fd61-verbatim.md`](2026-09-20T0000Z-comprehensive-review-followup-at-e19fd61-verbatim.md).
Five functional gaps `F1`…`F5` reproduced by execution, a list of narrative residuals, and a
deployment note. Register: `reviews/README.md` §DR (rows amended) and §DRF.

**Verdict as given.** "Substantial, verified progress; the review is not fully closed." All
14 of this side's standalone checks passed in the reviewer's environment; edge cases beyond
them exposed incomplete fixes. Nothing new against the two BlueZ patches.

**What this side did with it.** Every one of the five gaps is real; each is fixed with a
behavioural test and a standalone proof (`scripts/prove-dr-followup.sh`). Every named
residual sentence is corrected. The deployment note is adopted into `docs/install.md`. The
dispositions in the previous verification that said "fixed" for DR-06/07/08 were, as the
reviewer says, narrower than the findings; the register rows now say what was and was not
done, and this file is the record of the difference.

## F1 — a passive close is not "survived": fixed

The passive autostop closed with `ok`, and the closer wrote `trial_result=survived` ("alive,
untouched") although nothing had asked the controller anything. The reviewer's two rows —
a silent dead controller recorded `survived`, an unreadable journal recorded `survived` with
`bt1_status=unknown` — reproduce here. New outcome value **`ended_unprobed`**: the trial
closed without a probe; no command timeout was seen (or, with `bt1_status=unknown`, the
journal could not be read); liveness was not measured. `trial-summary.awk` accepts it; no
rate keys on `trial_result` for a non-confirmed row, so the BT-1 rate is unchanged. The
closer's verdict line says "trial ended without a probe: no command timeout observed;
liveness not measured". Tests: no-timeout, silent-dead, unreadable-journal, all
`ended_unprobed`, zero HCI commands; timeout still `failed`/`confirmed`.

## F2 — `BT_TRIAL_PROBE=0` probed: fixed

`[[ -n "$BT_TRIAL_PROBE" ]]` → `== 1`; likewise `BT_TRIAL_PASSIVE == 1` at both sites.
Test: `BT_TRIAL_PROBE=0` sends nothing and records `ended_unprobed`; `=1` probes.

## F3 — a colliding pre-existing file was overwritten and then deleted: fixed

`install_file()` now copies a destination that exists and differs from the source to
`<dst>.pre-qca9377-bt-hang` (once; a later re-deploy of our own file is identical and needs
none; an existing backup is never overwritten, so the first foreign file survives).
`uninstall.sh` moves the copy back and counts it; its summary says how many were restored,
or that none had been replaced, instead of the unconditional "no pre-existing file was ever
modified". `mv` joins the uninstaller's command allowlist for that one purpose. `install.sh`'s
header and `docs/install.md` carry the same conditional statement. Test: a foreign
`usr/local/bin/bt-mark` survives `install.sh --tools-only` as the backup and is back in
place, byte for byte, after `uninstall.sh --apply`. Not done: the same treatment for the
*generated* files (the two udev rules, the modprobe drop-in) — they are written by redirect
and have no source to compare against; recorded as open (`DRF-01`).

## F4 — no sanitiser was still exit 0: fixed

`bt-incident` exits 1 with "NOT PUBLISHABLE: no sanitiser was available" when none is
found; `BT_SANITIZER=none` is the test seam for that host. Manifest `NO-SANITISER` as before.

## F5 — abort deleted untracked evidence: fixed, and the policy is the reviewer's

`bt-trial abort` now keeps the directory, renamed `<dir>.aborted-<stamp>` with an `ABORTED`
file (timestamp, reason, "no results row was written"), and deletes nothing. `bt-trial abort
--discard` is the deliberate deletion of scratch and still refuses tracked files. The two
suite tests that asserted deletion are replaced. The previous disposition called the
tracked-only refusal "fixed"; it was the narrower half, as the reviewer says.

## Narrative residuals: every named sentence corrected

| where | was | now |
|---|---|---|
| README | "the assumption this hardware falsifies" | the fallback *applies* to this part (alts 1–5, no 6); compatibility is the question; a device using alt 1 does not falsify the author's observation |
| README reproduction | "issue any HCI command. It dies" | "issue an HCI command — in both recorded cases `Disconnect`; whether *any* command does it is untested … whether the command wedged the controller or found it already wedged is not established" |
| README | "not in v7.0 or a stable release yet" | "not in v7.0 nor in the 6.6.y and 6.12.y stable heads as checked on 2026-09-19" |
| README / BRIEF | "every tested recovery failed" | "every recovery tried on an already-wedged controller failed; the one reset issued before any timeout recovered it, and it failed again 132 s later (`EX-004`)" |
| bug report | "finds no alternate setting 6 or 3" | "does not select alternate setting 6 or 3 … selecting alt 3 also requires a sufficient `sco_mtu` and `BTUSB_USE_ALT3_FOR_WBS`, so the fallback alone does not prove alt 3 is absent — the device's own descriptors, listed in `dc16388d45ec`, show alts 1–5 and no 6" |
| bug report | "zero commands in flight and no harm" | "zero commands in flight (whether the command path was healthy during that interval was not measured — nothing asked it)" |
| bug report reproduction | "issue any HCI command" | "issue an HCI command … the only one the record has seen die; whether any other command does the same is untested" |
| bug report / BRIEF | "CVSD is safe" | "The CVSD controls survived" — a statement about the observed controls, not a safety guarantee |
| `docs/issues.md` | "no harm" | "command-path health unmeasured" |

## Deployment

The reviewer's note is right and is now in `docs/install.md`: `--tools-only` skips
`systemctl daemon-reload` by design, so the unit's new `TimeoutStopSec=30` is not in effect
until a reload or a reboot; check with `systemctl show bt-trial-auto -p TimeoutStopUSec`. The
changed tools are **still not deployed** to the investigation machine; that is the operator's
step and it changes every shutdown.

## Open, carried forward

`DR-10`, `DR-11`, `DR-12` as before; `DRF-01` (generated files not covered by the
backup/restore); the hardware experiments (a build with the upstream quirks entry; command
causation vs prior loss of responsiveness); BlueZ callback regressions (`TP-06`/`TP2-06`).
