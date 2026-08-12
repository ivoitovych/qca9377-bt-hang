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
| EX-006 | [sco-setup-is-the-wedging-command](006-sco-setup-is-the-wedging-command.md) | `HCI_Setup_Synchronous_Connection` (opcode 0x0428, SCO/eSCO link setup for HFP) was submitted, never answered, and timed out 2.169 s later. The controller's loss of HCI responsiveness begins at that boundary. |
| EX-007 | [autonomous-profile-switch-triggers-hang](007-autonomous-profile-switch-triggers-hang.md) | The hang requires no operator action at the moment it occurs. In this incident BlueZ issued `HCI_Setup_Synchronous_Connection` 36 ms after the A2DP transport went idle, and **the controller never answered it**. What is established is the *consequence*; the claim originally made here about the *cause* of that command has been refuted. |
| EX-008 | [usb-healthy-when-hci-dies](008-usb-healthy-when-hci-dies.md) | At the moment HCI stops answering, the USB transport is entirely healthy — every URB completes with status 0. The first non-zero URB status appears 31.4 s LATER; USB descriptor-read failures later still. |
