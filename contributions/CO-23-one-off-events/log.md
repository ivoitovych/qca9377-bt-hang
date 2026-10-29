# CO-23 log

Append-only. Newest last.

## 2026-10-28: opened and investigated, read-only
Asked to find the records of three events that were each seen once (the bluetoothd bad `free()` of
2026-09-08, BT-6, and the Shure AONIC 50 drop) and say whether a cause can be found. Nothing was run
against the controller; nothing was committed or sent.

- **Event 1, bad `free()`.**
  - The core is gone (`coredumpctl list bluetoothd`: "No coredumps found."; none in
    `/var/lib/systemd/coredump` or `/var/crash`).
  - The journal archive still holds the kernel fault line and the complete `bluetoothd -d` log of the
    last minute of PID 2841 (`boot-3caa9acf`), and the debug binary that ran is still installed.
  - Decoding the fault: `ip ...ade55` is the first load of `__libc_free`, fault address `-7`, so
    `free((void *)1)`.
  - The log reads as: a `SetConfiguration` call arrives while a Close is pending, and the abort path frees
    the call's `a2dp_setup`. `a2dp_reconfig()` then runs `setup->reconfigure = TRUE;` on it
    (`a2dp.c:1899`; the binary has `movl $0x1,0x50(%rbx)`).
  - `reconfigure` is at offset 80 of the 112-byte setup. GLib's 112-byte timeout source (the 2 s Abort timer
    allocated in the same call) has its `name` at offset 80, and GLib frees `name` when the timer ends:
    `g_free(1)`, 2.7 s later. That reproduces the fault address, the instruction, the stack shape and the delay.
  - The use-after-free is established. The handing of the freed chunk to the timer is [inference].
  - BlueZ master `b0bf49270d44` has the same code. Not fixed upstream.
- **Event 2, BT-6.**
  - Not "observed once": 15 lines in 4 archived boots (2026-08-12 to 08-19), 12 distinct instants.
  - Every one is 17 to 32 ms after a connection was marked closed during `bluetooth.service` stopping (adapter power-off);
    10 of 12 were the watchdog's reset of 2026-08-12.
  - `rx_work` takes the data frame after the Disconnection Complete and finds no connection.
  - Benign race. The HCI captures of those days are gone (pruned before the archive began).
- **Event 3, AONIC 50 drop.**
  - Read for the first time (the 10-13 note said "not read further").
  - BlueZ refused the headset's three profile requests because a local disconnect was already pending;
    the disconnect was requested in the 1.7 s after the link came up, by a caller that is not logged.
  - No HCI capture or system-bus record exists for it. The cause cannot be found; it needs a recurrence.
- **Written:** `README.md`, this file, `investigation-2026-10-28.md`. Helper scripts in `tmp/co23/`.
- **Next:** reproduce event 1 under AddressSanitizer in the BlueZ emulator, then write and send the fix.
  Correct the BT-6 entry and the "unrelated crash" wording in the records listed in `README.md`.

## 2026-10-29: event 1 reproduced, fixed, send package written (worktree branch, nothing sent)
Everything ran in the BlueZ CI bot's Docker image and its QEMU guests; nothing touched the laptop or
this machine's Bluetooth. Detail and every command: `experiments/results-2026-10-29.md`.
- **Defect confirmed at BlueZ master `82667d713949`** (`a2dp.c:2162-2173`); introduced by
  `5071fadb97b8` (5.51). No fix or report on patchwork (since 08-01) or lore (since 09-10).
- **A second ending of the same chain** found while writing the fix: when the Abort cannot be sent
  after the Close was canceled, `a2dp_reconfig()` frees the already-freed callback and
  `set_configuration()` replies a second time.
- **Fix** (hold a setup reference across close/abort; on a failed abort free and fail the request only
  if still pending, by callback id) and **test** in BlueZ's functional suite,
  `test_a2dp_reconfigure_during_close` (peer `bluetoothd` stopped with `SIGSTOP` so the Close stays
  pending; two endpoint switches; reconnect), with its `doc/functional-a2dp.rst` entry.
- **Results:** master + test → ASan heap-use-after-free at `a2dp.c:2173`, after the laptop's exact log
  sequence; master + fix + test → A2DP functional 5/5, new case 5 of 5 runs, `make check` 41/42 (1
  skip) on both sides, no sanitizer report; both reachable failure branches seen in the log.
- **Learned:** BlueZ's `bootstrap-configure` enables ASan/LSan/UBSan, so the bot's functional runs are
  sanitizer builds; the bot fails a CheckPatch *warning* (an 81-column comment, fixed).
- **CI bot's own checks** on the final mails (`tmp/co23/bot-ci-3`): all PASS on base and base + series,
  exit 0; TestFunctional 48 → 49 passed. (An earlier run failed CheckPatch on an 81-column comment.)
- **Package:** `patch/send/` (two mails, `SHA256SUMS`, `send.sh`, README); To the list, Cc Luiz
  Augusto von Dentz. `send-email`, a dry run included, is the coordinator's (guard, 10-29).
- `scripts/bot-ci-local.sh` now runs from a worktree (`--cache`; root from its own location).
