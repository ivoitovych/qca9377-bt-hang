# The kernel CI bot's `mesh-tester` failure — investigation task

**Branch `diag/mesh-tester-ci`, private remote only.** Separate from the QCA9377 work: it
touches neither the laptop's Bluetooth stack nor the held patches.

## The fact

The `linux-bluetooth` CI bot (`bluez.test.bot`, `bluez/action-ci` on GitHub, PRs under
`bluez/bluetooth-next`) runs BlueZ's `tools/mesh-tester` against every kernel patch. On
**every kernel patch since 2026-06-01** its check `TestRunner_mesh-tester` is `fail`:

```
Total: 10, Passed: 8 (80.0%), Failed: 2, Not Run: 0
Mesh - Send cancel - 1                               Timed out    2.421 seconds
Mesh - Send cancel - 2                               Timed out    1.999 seconds
```

Measured with `scripts/patchwork-checks.sh --rate TestRunner_mesh-tester 250 [BEFORE]`
(2026-09-29): 20/20 fail 09-19 → 09-28, 18/18 fail 07-10 → 07-21, 28/28 fail 06-01 → 06-19;
**18 of 20 pass 04-28 → 05-14.** The cached bot comments under `tmp/patchwork/survey/`
(07-22 → 09-21) show 122/122 fail, 119 naming the same two cases. Our own patch (`14845586`,
2026-09-24) carries it. Nobody has fixed it in four months.

## What is asked

**Phase 1 — read-only diagnosis.** No experiment, no host Bluetooth, no builds.

1. **Pin the flip.** Between the last passing and the first failing kernel patch (window
   2026-05-14 → 2026-06-01): the patchwork ids and dates (`--rate … 250 2026-06-01` reaches
   back into the window; `--patch ID` for one). Then: which BlueZ commit (the bot builds the
   testers from BlueZ master: `cache/bluez-upstream`, `tools/mesh-tester.c`, `emulator/`,
   `src/shared/tester.c`, `tools/test-runner.c`, `doc/tester.config`) and which kernel commit
   (`cache/linux`, remote `bluetooth-next`, `net/bluetooth/mgmt.c` `mesh_send`,
   `send_cancel`, `mesh_send_complete`, `mesh_next`; `hci_sync.c` advertising) land in that
   window, and which of them changes what "Mesh - Send cancel" expects
   (`mesh_send_mesh_cancel_1`: status success, `MGMT_EV_MESH_PACKET_CMPLT` with the cancelled
   handle, then `LE_SET_ADV_ENABLE` with `mesh_cancel_rsp_param_mesh`). Read the bot's own
   configuration too (`gh api` on `bluez/action-ci`: `config.json`, `ci.py`, the tester
   list and kernel config it uses) for a change in the same window.
2. **Decide what is wrong**: the test's expectation, the kernel's behaviour, or the bot's
   environment (timeouts, config, emulator). Say which with the evidence; if it cannot be
   decided by reading, say exactly what a run would show.
3. **Check the record**: any list thread, BlueZ issue or bot comment where a human mentions
   `mesh-tester` failing (the cached survey `tmp/patchwork/survey/`, `scripts/kernel-bt-survey.py`
   output, `gh` search in `bluez/bluez` issues and `bluez/bluetooth-next` PR comments).
4. **Draft the fix and the reproduction plan**: a patch to `tools/mesh-tester.c` or to the
   kernel, with its commit message; and the steps to reproduce with `tools/test-runner`
   (qemu, the bot's kernel config) — costed, for the operator to approve as phase 2.

Write everything to `tmp/mesh-tester-ci/phase1-findings.md`: every claim with the command
that shows it and its output quoted, and marked **quoted** / **inferred** / **not found**.

**Phase 2 — reproduction and patch**, only after the operator approves the plan.

## Constraints

- **Never touch the host's Bluetooth**: no `bluetoothctl`, `hciconfig`, `btmon` on the live
  adapter, no `modprobe`, `systemctl`, `install.sh`, no writes under `/lib/modules`,
  `/etc`, `/usr/local`. The laptop carries a live experiment.
- Write only under `cache/mesh-tester-ci/` (this worktree), `cache/` (fetches into the
  existing clones are fine), and `tmp/mesh-tester-ci/`.
- Nothing is posted, mailed or commented anywhere; the operator sends.
- The operator's identity is `Iaroslav Voitovych <yaroslav.voytovych@gmail.com>` for any
  draft patch.
