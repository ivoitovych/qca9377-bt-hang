# scripts/ — helper scripts, tracked

Small scripts written during the work and kept: proofs that a fix does what it
says, one-off extractions, glue between two tools. They are tracked because
scripts kept under `/tmp` vanished with a reboot on 2026-09-19, and because a
reviewed file in a known place can be rerun and cited where a typed command
cannot.

Rules:

- **One file per job, a comment at the top saying what it proves or extracts.**
- **Read-only unless the name says otherwise.** Anything that writes outside
  `tmp/` names the target in its header.
- **Outputs go to `tmp/`** (ignored), never here and never into `evidence/`
  directly — an exhibit is made with `tools/bt-exhibit`, which runs the command
  itself.
- If a script is run more than twice it is promoted to `tools/` or `devtools/`
  with a test; this directory is where that promotion starts, not a substitute
  for it.
- **A verdict that was not measured is not a verdict.** A script that could not
  read its input (a journal, a capture, a store, a decompressor, a tool) exits
  non-zero or prints `NOT RUN` / `NOT READ` / `NOT CHECKED`; it never prints a
  count of zero or a pass for what it did not look at, and a `|| true` is
  allowed only where the status it hides is named in a comment next to it.
- **No machine's paths.** A script finds the checkout from its own location
  (`$(dirname "${BASH_SOURCE[0]}")/..`) and the desktop user from
  `BT_DESKTOP_USER`; a path under one person's home or a deleted work area is
  an environment variable with no default of that kind.
- The scripts are not installed on a user's machine, but several published
  exhibits are produced by them (`sco-ledger.sh`, `sco-ledger-boots.sh`,
  `boot-bt-summary.sh`, `build-btusb-stable-matrix.sh`), and they are tracked
  for that reason. Of those four, `sco-ledger.sh` and `sco-ledger-boots.sh`
  have tests in `tests/run-tests` (an unreadable boot, a boot with no call);
  `boot-bt-summary.sh` and `build-btusb-stable-matrix.sh` have none (the second
  needs a kernel tree and a build). `repo-scan` covers them like any other
  tracked text, so no addresses, names or journal excerpts in the scripts
  themselves.
