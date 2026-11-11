# C. Is the controller powered when the laptop is off? What sysfs and procfs can say

Reads only: `/proc/acpi/wakeup`, `/sys/bus/usb/devices/3-3` and its parents, `/sys/class/dmi/id`, `/sys/class/power_supply`,
`/sys/power`. Full values with commands' paths: `E-hardware-facts.txt` (made by `hardware-facts.py`). The device was not
opened and no HCI or USB request was made by me. No address or serial is in this file.

## What was read [measured, 2026-11-11]

- Topology: `/sys/devices/pci0000:00/0000:00:08.1/0000:03:00.4/usb3/3-3`: the controller is on **port 3 of root hub usb3**, which is
  the AMD xHCI function `0000:03:00.4` (vendor 0x1022, device 0x1639, ACPI name XHC1) behind bridge `0000:00:08.1` (GP17).
- `/proc/acpi/wakeup`: `XHC0 S3 *enabled pci:0000:03:00.3`, `XHC1 S3 *enabled pci:0000:03:00.4`, `GP17 S4 *enabled
  pci:0000:00:08.1`, `LID0 S3 *enabled`, `GPP3 S4 *enabled pci:0000:00:02.1`, `GPP5 S4 *enabled pci:0000:00:02.3` (the
  root port of the Wi-Fi function at `0000:02:00.0`), the rest disabled. The file has only an S-state column with S3 or S4; no S5 entry exists.
- The controller: `bmAttributes e0` (self-powered and remote-wakeup capable), `bMaxPower 100mA`, `removable fixed`,
  `power/wakeup disabled`, `power/control auto`, `autosuspend_delay_ms 2000`, `runtime_status suspended`.
  The port: `usb3-port3/connect_type: not used`, `state suspended`, `over_current_count 0`, no `power` switch attribute.
- The USB capture of 2026-11-05 (see B5) shows the device answering GET_STATUS with `0x0001` = "self powered". [measured]
- PCI Wi-Fi function of the same module: `power/wakeup disabled`, `d3cold_allowed 1`; parent port wake `enabled`.
- DMI: `sys_vendor`, `product_name`, `board_vendor`, `board_name`, `product_family` all read `Default string`;
  `product_version` / `board_version` `Version 1.0`; BIOS American Megatrends International `1.16`, `10/19/2024`;
  chassis type 10 (notebook). The model cannot be identified from DMI.
- Power supply now: `ADP1` mains online 1; `BAT0` Li-ion present, capacity 100, status Full. `/sys/power/state` `freeze mem disk`.

## What can be concluded

1. The wake table is a **sleep-state (S3/S4) wake** table. It says which devices may wake the machine from S3 or S4;
   it carries nothing about S5, and nothing about whether a rail stays powered when the machine is off.
2. The controller's own descriptor claims it is self-powered. That is a descriptor bit on an internal module; it says
   nothing about the supply behind it, and `bMaxPower 100mA` is the bus-powered budget the descriptor declares.
3. The only host-side power controls in sysfs for this device are runtime-PM files (`control`, `autosuspend`) and the port
   `disable`/`state`; there is no per-port power switch (`usb3-port3` has none), and the module sits on a port ACPI marks
   "not used", the usual encoding for a hidden internal device. Runtime power management is a host-side state that ends with the OS.
4. **Cannot be concluded from sysfs/procfs:** whether the module (3.3 V) is supplied in S5, whether the chip's RAM survives
   a power-off, or what the embedded controller does. Nothing in these files is readable after the OS has stopped.
5. **What the journal adds** [measured, A]: the chip had lost its patch after 74 s, 4 m and 13 m of off-time (it was
   freshly patched at those boots), so any retention of chip state through S5 is at most conditional; only the 29 h 38 m
   boot found it patched. This weighs against a plain "the slot always stays powered" and leaves "powered under some
   condition, or a read problem" open (H1/H2 in B6).

## What would settle it, without touching the device

- A record taken before the driver binds (control transfers of the status read and `patch_version`) at every start: the
  one thing the existing recorders miss (B5).
- AC and battery state recorded at power-off and next start; the off-time is in the journal already.
- Operator-side facts that cost nothing: whether the charger was connected during the 29 h and for the short off-times
  (not in any record: [not found]).
