Title: bluetoothd: use-after-free of a device in discovery_cleanup() when the adapter is removed or bluetoothd exits

Bug: https://bugs.launchpad.net/ubuntu/+source/bluez/+bug/<LP-U24> (placeholder)
Package: bluez 5.72-0ubuntu5.8 (Ubuntu 24.04 LTS, noble); fix in 5.72-0ubuntu5.9 (one upload with four other bugs)

[Impact]

discovery_cleanup() resets the RSSI of the devices in adapter->discovery_found. When it is called from adapter_remove(), for
example when bluetoothd exits while discovery has found devices, the list holds only stale pointers because the devices are
already freed, which is a use-after-free in the exiting daemon (seen with an AddressSanitizer build):

    ERROR: AddressSanitizer: heap-use-after-free  READ of size 1
        #0 device_set_rssi_with_delta src/device.c
        #1 device_set_rssi src/device.c
        #2 invalidate_rssi_and_tx_power src/adapter.c
        #3 g_slist_foreach
        #5 discovery_cleanup src/adapter.c
        #6 adapter_remove src/adapter.c
        #7 adapter_cleanup src/adapter.c
        #8 main src/main.c
    freed by thread T0 here: device_free src/device.c

The same report was found at bluetoothd exit in an earlier project run of the 5.72-0ubuntu5.8 tree (device.c:6167 in the Ubuntu
tree, device.c:6161 in the upstream 5.72 tree).

[Patches]

One patch, upstream 7e3212fa233e ("adapter: clear discovery_found list before discovery_cleanup()", Pauli Virtanen, 2026-09-04,
first in BlueZ 5.88, released 2026-11-05): adapter-clear-discovery_found-list-before-discovery_cleanup.patch. It frees the list
in adapter_remove() before discovery_cleanup().

[Test Plan]

Setup (no hardware): QEMU/KVM guests with an emulated controller, BlueZ's functional-test harness from master driving the 5.72
bluetoothd built with AddressSanitizer and UBSan; the test starts discovery and stops the bus under bluetoothd
(test_exit_discovering, "bus" variant) and requires a clean exit.

1. 5.72-0ubuntu5.8 built with --enable-asan --enable-ubsan, ten runs. Before: the report above (10 of 10 in our run on upstream
   5.72; the Ubuntu tree: see the results).
2. 5.72-0ubuntu5.9 built the same way, ten runs. After: no report.

Results on the candidate 5.72-0ubuntu5.9 (2026-11-14), before and after:
- 5.72-0ubuntu5.8 (Ubuntu tree): 10 of 10 runs fail with three AddressSanitizer reports each, the first
  `heap-use-after-free src/device.c:6167 in device_set_rssi_with_delta`;
- 5.72-0ubuntu5.9: 0 of 10 runs fail, no report.

[Where problems could occur]

The change is three lines in adapter_remove() (src/adapter.c): it frees the g_slist of discovered devices (not the devices) and
clears the pointer before discovery_cleanup(). A mistake would show as a leak or a crash when an adapter is removed (unplug,
rfkill, daemon exit). discovery_cleanup() still resets every device's RSSI where devices exist; at adapter removal there are none
left to reset.

[Other Info]

- Upstream: 7e3212fa233edbdcfd69f93e2a7418819172c599, in BlueZ 5.88 and in no Ubuntu release yet (26.04: 5.85, 26.10 and 27.04:
  5.87): the development release comes first for an SRU (see BUNDLE.md).
