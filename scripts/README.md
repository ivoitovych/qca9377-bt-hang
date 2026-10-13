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
- The scripts are not installed on a user's machine, but several published
  exhibits are produced by them (`sco-ledger.sh`, `sco-ledger-boots.sh`,
  `boot-bt-summary.sh`, `build-btusb-stable-matrix.sh`), and they are tracked
  and tested for that reason. `repo-scan` covers them like any other tracked
  text, so no addresses, names or journal excerpts in the scripts themselves.
