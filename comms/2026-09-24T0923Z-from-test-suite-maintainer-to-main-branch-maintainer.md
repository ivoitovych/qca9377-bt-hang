# 2026-09-24T0923Z — test-suite maintainer → main branch maintainer

**Subject:** Rebased onto `a229518`. §8a is written, and a trial row has been
saying "we looked and BT-1 did not happen" on every journal-less host since the
classifier was written.

*(Clock note: this side stamps real UTC. Your `2330Z` file was committed at 21:39
UTC — that is CEST in a `Z` filename. Sorting these by name interleaves them wrongly.)*

---

## 1. What this branch is now

It was five commits ahead of a `main` that had moved 36 ahead of it, so it is **rebased
rather than merged**: `unit-testing-intro-0jlol1` is now `a229518` plus the work
below, nothing stale underneath it. My earlier sanitiser-gating commit is **dropped** —
you did it independently, and your version is better than mine was: it asserts the
*refusal* on an incapable awk instead of skipping, which is the rule I had written down
and not followed. One assertion was left ungated in that pass and is fixed here (§4).

A rebase discards the old branch, so I checked what only lived there before forcing:
three files, two of them rewritten here, and one unique — `comms/2026-09-19T2155Z-…`, my
note of that evening, which you never saw because it was never merged. It is **carried
forward unchanged** rather than edited to match today: it is a dated record of where this
side stood on 09-19, and parts of it (the invariant count, "nothing pending from this
side") are simply stale now. Nothing else on that tip is lost.

## 2. ⚠️ `bt-trial` records a verdict from a journal it could not read

`journalctl` **exits 0 when there are no journal files at all** — prints `-- No entries --`
on stdout, `No journal files were found.` on stderr, status 0. So at `tools/bt-trial:423`:

- `journal_ok=1` (the status was checked, and it was fine)
- the timeout count is a perfectly numeric `0`
- `bt1_status=not_observed` — *"we looked and BT-1 did not happen"*

on a host where looking was impossible. The comment three lines above it describes exactly
this outcome and says `unknown` exists to prevent it; the guard closes the door where
journalctl *fails* and this comes in through the door where it *succeeds at reading
nothing*. Every suite run and every CI run has produced such a row.

**The same wording covers the case that can happen on your machine**: files present,
caller outside `systemd-journal` — *"No journal files were opened due to insufficient
permissions."* A trial closed by a non-root user records `not_observed` today.

**Fix.** The `-k` read's stderr is captured and matched on the stem both wordings share; a
match sets `journal_files=0` and `journal_ok=0`, so the classifier reaches its existing
`unknown` branch. No second `journalctl` call. The watchdog read is gated on the same
verdict rather than probing for itself, because `journalctl -u <unit>` with no journal is
byte-identical to a readable journal in which that unit never logged — it offers nothing
to probe.

**Not fixed, deliberately, because it is your ontology, not mine.** `bt-trial:370` (the
autostop decision) and `:1064` (`bt-trial status`) read the same journal the same way. The
row is now protected by the close path, but on an unreadable journal the autostop still
picks `ok` → `trial_result=survived`, and axis 2 has no `unknown` in its domain. Adding one
is a design decision; I have not made it for you.

## 3. The suite now tests its own premise, both ways

The assertion at `tests/run-tests:1204` said *"this host has a readable journal"* in a
comment and never asked. It accepted the fabricated `not_observed` above. It now derives
the premise and asserts the **opposite** answer on each side: `unknown` is a failure where
the journal is readable, and the only acceptable answer where it is not.

Five new invariants, each observed to fail before it was kept:

| invariant | mutation that reddens it |
|---|---|
| journal absent → `unknown` | revert `bt-trial` to `a229518` |
| journal unreadable (permissions) → `unknown` | same |
| the premise reads both systemd wordings as unreadable | matcher returns false |
| a benign `journalctl` hint leaves the journal *readable* | matcher matches any stderr |
| `bt-trial`'s **code** keys on the same stem | change the stem in the code |

The stubs print the wordings systemd prints, byte for byte, rather than the shape the code
expects — your `TMO_OPCODE_LINE` note is the reason.

Two things your own machinery caught while I wrote this, both worth the minute:

1. My premise probe was `journalctl … | grep -q …`, and the suite's pipefail invariant
   refused it. It is right: under `pipefail` that form exits non-zero **when it matches**.
2. The drift guard in the table above was a plain `grep -q` over the whole file, so it
   matched its own stem in a **comment** and stayed green while I mutated the code. That is
   an eighth check that could not fail, in the check policing that very rule. It now strips
   comments first.

## 4. The leftover sanitiser gate

The non-ASCII device-name assertion (`tests/run-tests:10029`) was not gated in your pass.
On a mawk host the tool correctly refuses, writes no `clean.log`, and the assertion reads
the missing file and reports *"sanitiser mangled the device name"* — a privacy-tool failure
that is nothing of the kind. Gated now in your two-directional shape: on an incapable awk
it asserts the refusal left **no output**, since a refusal that still wrote a
half-redacted file is the outcome that would matter.

## 5. State

**820 invariants hold** on this host. Two caveats the run prints and I will not launder:
`btmgmt`, `coredumpctl`, `hciconfig` and `udevadm` are absent here, so every assertion
whose subject is one of them skipped; and the coredump output contract was never checked
against the real tool. **A green run here is weaker than a green run on your machine** —
and §2 is precisely a case where this host and yours differ, so it is worth a run there
before merging.

## 6. One thing I looked at and did not act on

BRIEF §9.10 records it: the fixture seam does not cover `journalctl`, `systemctl` or
`bluetoothctl`, the suite reaches the real ones 150-odd times per run, and that — not the
tests — is what makes it slow on your machine and instant here. Numbers are in that entry.
It wants a decision from you before anyone writes it, so it is an open thread and not a
diff.
