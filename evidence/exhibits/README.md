# Evidence exhibits

Each exhibit states a claim, the exact command that produced the
supporting output, that output verbatim, and why it is relevant.
The command and the output were captured in a single pass by
`tools/bt-exhibit`, so the command shown is provably the command
that produced the output shown.

Regenerate this index with `bt-exhibit index`.

| # | exhibit | claim |
|---|---|---|
| EX-001 | [device-absent-from-qca-quirks](001-device-absent-from-qca-quirks.md) | USB ID 13d3:3503 is matched by no entry in the btusb quirks table, so it receives neither the QCA firmware setup path nor a hdev->reset callback, while its immediate ID neighbours 3491/3496/3501 do. |
| EX-002 | [panel-triggers-desync-metronome](002-panel-triggers-desync-metronome.md) | Opening the GNOME Bluetooth settings panel deterministically drives this controller into an HCI command-pipeline desync that then repeats at an exact 16.0 second cadence for as long as the panel remains open. |
| EX-003 | [desync-is-not-the-cause](003-desync-is-not-the-cause.md) | The HCI desync signature is a companion symptom of this controller, NOT the cause of the hang: it appears in boots that never hang, and boots hang without it. |
| EX-004 | [early-reset-does-not-prevent-recurrence](004-early-reset-does-not-prevent-recurrence.md) | A USB-level reset applied 133 s BEFORE any HCI command timeout successfully re-enumerated the controller and brought the HCI stack back up 315 ms later — and the controller nevertheless went on to hang completely 132 s after that and leave the USB bus. |
| EX-005 | [late-reset-fails-device-leaves-bus](005-late-reset-fails-device-leaves-bus.md) | Once HCI command timeouts have begun, no software recovery succeeds: USBDEVFS_RESET fails, USB unbind/bind fails, and the device leaves the USB bus entirely, after which only a cold power-off restores it. |
