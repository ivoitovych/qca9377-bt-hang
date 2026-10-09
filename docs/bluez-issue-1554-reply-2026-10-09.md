The event ordering in the [attached btmon capture](https://github.com/user-attachments/files/22617184/btmon-capture.log) matches a kernel race that has since been fixed upstream: [96d006ae6445](https://git.kernel.org/torvalds/c/96d006ae6445) "Bluetooth: hci_event: fix simultaneous discovery stuck in FINDING" (Jiajia Liu).

The discovery cycle that starts at 09:53:44 UTC ends like this:

- 09:53:54.432 — LE Set Scan Enable (disable), sent when the kernel's LE scan timer expires
- 58.5 ms after that command — Inquiry Complete
- 62.5 ms after that command — Command Complete for the LE Set Scan Enable

During combined BR/EDR and LE discovery on controllers whose drivers set `HCI_QUIRK_SIMULTANEOUS_DISCOVERY`, an Inquiry Complete that arrives between that command and its Command Complete, with no remote-name resolution pending, leaves the kernel in `DISCOVERY_FINDING`: the inquiry-complete handler still sees LE scanning as active, and without the fix the scan-disable completion clears that flag but does not mark discovery stopped.

No `Discovering: Disabled` event appears in the remaining 24 s of the capture, and no further Start Discovery either, where the earlier cycles restarted every 16 s (09:53:12, :28, :44). In this normal discovery loop, bluetoothd relies on that event to schedule the next cycle (`discovering_callback()` in `src/adapter.c`). Without it, scanning stays inactive while bluetoothd still considers discovery enabled, and temporary devices eventually expire from the list.

While the kernel stays in that state, a new MGMT Start Discovery would be answered Busy, which bluetoothd reports as `org.bluez.Error.InProgress`. That fits the error reported above, although `InProgress` alone does not identify this race. An adapter power cycle restores discovery; a successfully completed MGMT Stop Discovery also clears the stuck state, so discovery can be started again, which fits the reported stop/start workaround.

The fix is in v7.2-rc1 and was backported in v7.1.5 and v6.18.40. It is absent from the upstream tags v6.1.189, v6.6.158, v6.12.112 and v7.0.14; distribution kernels may carry their own backports. Ubuntu 24.04's `linux-hwe-7.0` [7.0.0-38.38~24.04.4](https://launchpad.net/ubuntu/+source/linux-hwe-7.0/7.0.0-38.38~24.04.4) includes it (see its changelog).

Could you retest with a kernel that contains the fix and share `uname -r`? If discovery still stalls, a fresh btmon capture would show whether the same ordering is involved.
