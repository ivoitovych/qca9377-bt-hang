# btmon fixtures

Decoded-text output as `btmon -T -r <file>` produces it, for the tools that parse it:
`bt-sco`, `bt-capdiff` and `bt-ctrl-window`.

## Why a mock rather than the real tool

`btmon` reads btsnoop, which is binary. Binary captures are **not committed** — they
carry addresses, device names, pairing exchanges and payload, and `sanitize-logs.sh`
cannot parse binary formats, so `devtools/repo-scan` refuses them. A fixture that cannot
be committed is a fixture nobody runs.

So the seam is `btmon` itself, substituted on `PATH` by a stub that emits the text below.
What is under test is the parsing — which blocks are recognised, how requests and
completions are counted, how the ±N second window is computed — and that parsing consumes
text, not btsnoop.

## The width, and the real btmon (2026-10-19)

Every stub pipes its text through `tests/btmon/render`, which prints it as btmon 5.72 does when
its output is not a terminal: header lines fitted to 80 columns unless `--columns=N` is given.
Until then the stubs printed full names that the laptop's tools never saw, so every tool that
matched a name passed here and matched nothing there. The renderer is checked by the suite
against the real btmon's output for a synthetic capture (`real/`), which also pins BT-4's abort.
The fixtures below stay full-width; the renderer narrows them.

## Provenance of the text

Hand-written to the shape of `btmon -T -r` output as the two tools consume it, and kept
deliberately minimal: the header lines, the `HCI Command:` / `HCI Event:` block openers
with their `>`/`<` direction markers and timestamps, and indented parameter lines.

**This is the known limit of the approach.** The fixture pins how the tools read btmon's
format; it cannot pin that the format is still what btmon emits. That is the same gap
`devtools/journal-contract` closes for the journal seam by building a real journal and
diffing real `journalctl` output against the fixture grammar. The equivalent here needs a
committable btsnoop, which the publish rules forbid — so the gap is recorded rather than
closed, and it is the reason `--raw` exists in both tools: it prints btmon's blocks
unfiltered, so a format change is visible to an operator even when the parser has gone
quiet.

## The cases

| File | Shape |
|---|---|
| `sco-paired.txt` | two setups, two completions — the ordinary case |
| `sco-unanswered.txt` | two setups, one completion — the hang signature |
| `sco-bitmap-only.txt` | the startup supported-commands bitmap and nothing else |

`sco-bitmap-only.txt` exists because a bare grep for "Setup Synchronous Connection" also
matches the commands bitmap the controller reports at startup, which names the command
once per adapter and has nothing to do with any request. Counting it would manufacture
setups on a capture that contains none.
