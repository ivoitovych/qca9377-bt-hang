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
