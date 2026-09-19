# scripts/ — helper scripts, tracked

Small scripts written during the work and kept: proofs that a fix does what it
says, one-off extractions, glue between two tools. They are tracked because a
script that lived in the session's `/tmp` scratchpad vanished with a reboot on
2026-09-19, and because a script under a granted directory runs without a
permission prompt while the same commands typed inline prompt every time and
can leave an unattended session stuck for hours.

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
- Nothing here is part of the deliverable. `repo-scan` covers it like any other
  tracked text, so no addresses, names or journal excerpts in the scripts
  themselves.

The permission rule that lets these run without a prompt is
`Bash(/root/exp/qca9377-bt-hang/scripts/*)` beside the existing `tools/*` and
`devtools/*` rules.
