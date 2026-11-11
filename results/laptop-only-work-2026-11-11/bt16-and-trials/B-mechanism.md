# B. Mechanism, from source and from the capture of boot 7323fc85

Sources: Ubuntu 7.0.0-42 Bluetooth sources (`cache/ubuntu-7.0.0-42`), upstream bluetooth-next as cached at
2026-10-04 (`cache/full-bt-next`, HEAD `8abc0fb874926b1fc4cda2291b6a866d3899d76a`), the journal, the boot's HCI capture
and its USB capture. Nothing was sent to the controller. No device address is reproduced here (the capture's
"New Index" line carries one; it is shown as `<addr>`). Marks: [quoted] source text, [measured], [inferred], [not found].

## B1. Where QCA_PATCH_UPDATED comes from  [quoted source, drivers/bluetooth/btusb.c, -42]

- `:3413-3418`: `QCA_GET_TARGET_VERSION 0x09`, `QCA_CHECK_STATUS 0x05`, `QCA_SYSCFG_UPDATED 0x40`, `QCA_PATCH_UPDATED 0x80`.
- `btusb_setup_qca()` `:3745-3818` runs from **`btusb_open()`** (`:2012`, `data->setup_on_usb`), i.e. inside
  `hci_dev_open_sync()` → `hdev->open()`, before any HCI command, over USB control transfers:
  1. `:3755` vendor request 0x09 → `struct qca_version {rom_version, patch_version, ram_version, chip_id, platform_id, flag}`.
  2. `:3762-3776` match `rom_version` in `qca_devices_table` (0x302 = "Rome 3.2"); **no match and any high ROM bit set =
     `return 0` silently** (no firmware, and the end-of-function quirk below is not set); no match and low = `-ENODEV`.
  3. `:3778` vendor request 0x05 → one status byte.
  4. `:3783` `if (!(status & QCA_PATCH_UPDATED))` → `btusb_setup_qca_load_rampatch()`: logs `using rampatch file` (`:3636`),
     then `QCA: patch rome <file> build <file>, firmware rome <ROM> build <chip's patch_version>` (`:3649`), then
     downloads. The chip's own `patch_version` is the "build 0x111" of the healthy lines (ROM default); a patched chip
     would report the patch's build (0x3e8) instead.
  5. `:3789` version read again; `:3799` `if (!(status & QCA_SYSCFG_UPDATED))` → `btusb_setup_qca_load_nvm()`, which logs
     `using NVM file` (`:3724`) and downloads.
  6. `:3815` `hci_set_quirk(BROKEN_ENHANCED_SETUP_SYNC_CONN)`. This is the only place that sets it for this driver
     path (`grep` finds one other site, `:4375`, in the MediaTek path). It is what makes the core print
     `HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.` after setup
     (`hci_sync.c:5162-5165`).
- **Where the status comes from:** only from the controller (vendor request 0x05). The host never sets the bits in
  software; the bits are set by the chip after the host downloads (`QCA_DFU_DOWNLOAD`, `:3562`) a rampatch and an NVM.
- **Upstream comparison:** bluetooth-next (`btusb.c:3768-3843`) has the same function body: same checks, same order, same
  silent `return 0`, same skip logic (`:3806`, `:3824`), and the same "allow equal rampatch version" rule
  (`:3676-3683` vs Ubuntu `:3653-3660`). Ubuntu -42 and upstream do not differ for this question. [measured by reading both]

## B2. What the journal of the failing boot says about the status byte  [inferred from B1 + measured log]

`journalctl -b -3 -k -o short-iso-precise --since "2026-11-05 19:33:04" --until "2026-11-05 19:33:20" --grep "usb 3-3|Bluetooth|btusb|hci0: [A-Za-z]|xhci|QCA"`:

```
19:33:05.291133 usb 3-3: new full-speed USB device number 2 using xhci_hcd
19:33:05.291291 usb 3-3: New USB device found, idVendor=13d3, idProduct=3503, bcdDevice= 0.01
19:33:05.732325 btusb: loading out-of-tree module taints kernel.
19:33:05.734290 usbcore: registered new interface driver btusb
19:33:05.745307 Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
19:33:05.794471 ath10k_pci 0000:02:00.0: enabling device (0000 -> 0002)
19:33:05.903286 Bluetooth: hci0: unexpected cc 0x2007 length: 1 < 2
19:33:05.903332 Bluetooth: hci0: Opcode 0x2007 failed: -38
19:33:05.925284 usb 3-3: USB disconnect, device number 2
19:33:06.017709 ath10k_pci 0000:02:00.0: firmware ver WLAN.TF.2.1-00021-QCARMSWP-1 api 6 features wowlan,ignore-otp crc32 42e41877
19:33:06.299291 usb 3-3: new full-speed USB device number 4 using xhci_hcd
19:33:06.459284 Bluetooth: hci0: using NVM file: qca/nvm_usb_00000302.bin
19:33:06.485282 Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
19:33:07.162301 Bluetooth: hci0: unexpected cc 0x202f length: 1 < 9
19:33:07.162386 Bluetooth: hci0: Opcode 0x202f failed: -38
```
(Selected lines of the command's output, times as printed; unrelated xhci and cfg80211 lines left out.)

- First enumeration: the `:3815` quirk line appears at .745, 11 ms after the driver registered, with **no rampatch and no
  NVM line**. From B1: setup ran to its end (so the early silent `return 0` for an unknown ROM, which would not set the quirk,
  did not happen), found `QCA_PATCH_UPDATED` **and** `QCA_SYSCFG_UPDATED` both set, and downloaded nothing. [inferred]
- Second enumeration (after the disconnect): `using NVM file` and no rampatch line: `PATCH_UPDATED` set, `SYSCFG_UPDATED` clear.
  That is exactly the state a healthy boot reaches between its two downloads (healthy 2026-11-10 00:37:20.709 rampatch,
  00:37:21.083 NVM, 374 ms later). [measured, inferred]
- The status byte and the chip's `patch_version` are **not logged on the skip path**: whether the chip said build 0x3e8 (a
  patch really present) or something else is [not found] in any record.

## B3. Why 0x2007 and 0x202f fail "with length 1", and why -38  [quoted source]

- `hci_event.c:4239-4248` `hci_cc_func()`: a Command Complete shorter than the table's `min_len` logs
  `unexpected cc 0x%4.4x length: %u < %u` and returns `HCI_ERROR_UNSPECIFIED` (0x1f). 0x2007 (`LE Read Advertising Channel
  TX Power`) needs 2 bytes (status + level), 0x202f (`LE Read Maximum Data Length`) needs 9. A length of 1 is a
  **status-only reply**: the controller answered with an error status instead of data. [quoted]
- `hci_sync.c:269-273` `__hci_cmd_sync_status_sk()` logs `Opcode 0x%4.4x failed: %ld`; the status 0x1f falls into the
  default of `lib.c:153-154` `bt_to_errno()`, which returns `ENOSYS` = 38. So `-38` is "unspecified error, unknown status", not
  a kernel "not supported". [quoted]
- What status the chip really returned is [not found]: the capture started after these commands (B5).
- Both opcodes are LE commands sent in the core's init (`hci_init_sync`), after reset and the first read commands had already
  succeeded (no earlier failure logged). The controller answered the common commands and refused or failed LE ones: a
  firmware that reports "patched" but is not in the state the patch expects (inferred), or a chip in mid-reset (see B6).

## B4. Why the index stayed out of bluetoothd's list  [quoted source]

- `hci_dev_open_sync()` (`hci_sync.c:5314-5374`): `hdev->open()` ran `btusb_open`/`btusb_setup_qca` (fine), then
  `hci_dev_init_sync()` returned the error from `hci_init_sync()` (the -38); the failure branch flushes, calls
  `hdev->close()` and returns the error.
- `hci_power_on()` (`hci_core.c:960-966`; same in upstream `hci_core.c:923-929`): on `err < 0` it calls
  `mgmt_set_powered_failed()` and **returns before** the block at `:983-997` that clears `HCI_SETUP` and calls
  `mgmt_index_added()`.
- `mgmt.c:459-461` (and `:513-515`, `:567-569`): the index lists skip every device with `HCI_SETUP`.
  So `Read Controller Index List` returns 0 controllers; no `Index Added` is ever sent; bluetoothd has nothing to
  register. [quoted; matches capture `Controllers: 0`]
- Nothing retries: the next open attempt would come from a management `Set Powered` or a raw open on hci0, and
  bluetoothd (and any client) addresses the index through management, which hides it. Only a raw socket user such as
  `hciconfig` saw `hci0` (RAW open at 19:38:16).
- Open point (flagged in BT-16): whether the index sat "in setup" or was "unconfigured" is answered by the source:
  `HCI_SETUP` (an unconfigured index would be in the separate list and would have `HCI_UNCONFIGURED`, set only after a
  successful `hci_dev_setup_sync`). [inferred; `btmgmt info` not run, by rule]

## B5. The HCI capture `hci-20261105-193308.btsnoop` (11,599 bytes)

Command: `btmon -T --columns=200 -r /var/log/bt-health/capture/hci-20261105-193308.btsnoop` (stdout only; no decode saved;
no key records: the file holds no pairing or link-key traffic, only the management exchange below).
[measured] Content, in order:

```
= Note: Linux version 7.0.0-42-generic (x86_64)                                  2026-11-05 19:33:08.500256
= New Index: <addr> (Primary,USB,hci0)                                [hci0]     2026-11-05 19:33:08.500294
@ MGMT Open: bluetoothctl (privileged) version 1.23                   {0x0001}   2026-11-05 19:33:09.598402
@ MGMT Close: bluetoothctl                                            {0x0001}   2026-11-05 19:33:17.595022
= bluetoothd: Bluetooth daemon 5.72                                              2026-11-05 19:33:17.673634
@ MGMT Open: bluetoothd (privileged) version 1.23                     {0x0001}   2026-11-05 19:33:17.675948
@ MGMT Command: Read Controller Index List (0x0003) plen 0            {0x0001}   2026-11-05 19:33:17.681562
@ MGMT Event: Command Complete (0x0001) plen 5 ...  Read Controller Index List  Status: Success  Controllers: 0
@ RAW Open: hciconfig (privileged) version 2.22                       {0x0002}   2026-11-05 19:38:16.442960
@ RAW Close: hciconfig                                                {0x0002}   2026-11-05 19:38:16.443067
```
(bluetoothd's plugin and supported-commands lines between are omitted.)

- The capture holds **no HCI command or event at all**. Its first record is 19:33:08.500, three seconds after the failed
  commands (19:33:05.9 to 19:33:07.2); `New Index` there is the monitor's replay of an index that already existed
  when the capture service attached, [inferred]. So the capture **cannot** show the status of 0x2007/0x202f nor any
  USB-level read; the question "what did the controller answer" is [not found] in this boot's records.
- The other two files of the boot, `bt-20261105-193317.btsnoop` (3,786 bytes) and
  `usbmon-20261105-193308.pcap` (5,349 bytes), start at 19:33:17 and 19:33:08 too. The USB capture (read with
  `pcap-summary.py`, output in this report only; 62 records) shows descriptor reads of the controller (device number 4)
  at 19:33:08.447-.458 (reader not identified) and then the root hub **port 3 suspended at 19:33:10.649** (SET_FEATURE PORT_SUSPEND,
  `2303020003000000`, 2.0 s autosuspend after the open failed), and at 19:38:11 to 19:38:18 a resume (CLEAR_FEATURE,
  `2301020003000000`) and GET_STATUS of the device answering `0x0001` (self-powered). No vendor request 0x09/0x05, no
  download. [measured]
- Consequence for the next occurrence: the existing recorders start too late. A recorder that is running before the
  driver binds is needed to see the version and status reads.

## B6. Hypotheses and what would separate them

| H | statement | for | against | what separates it |
|---|---|---|---|---|
| H1 | The chip kept its RAM (patch + NVM from the previous session) through the 29 h 38 m off-time: module powered in S5 | both status bits set at first read, patch bit still set after the self-reset (B2); the longest off-time of all | 4 m and 13 m of off-time (and 74 s) did not keep it; would need retention only under some condition (AC, EC, battery state, how power was cut) | read the chip's `patch_version` and status at the first enumeration (0x3e8 = a real patch, build 0x111 = not); log AC/battery state at power-off and at the next start; compare boots after known off-times (not to be induced on this machine) |
| H2 | The status read is stale or wrong because the module was being reset at that moment (the Wi-Fi function's reset, ath10k `enabling device` .794 and the USB drop .925; the same drop occurs on 2 of 55 stock boots) | same order of events in 3 boots; error status-only replies to LE commands look like a chip in reset; the stock boots show the drop without any patch | the status read is at ~.735, about 60 ms before ath10k's first log line (the probe could still be earlier); no stock boot shows what the status was | the same early USB capture; a diagnostic btusb build that logs status and `patch_version` (like E3, installed only on the operator's word); order of btusb vs ath10k probe in each boot |
| H3 | Something other than this kernel patched the chip before this boot (firmware, a previous OS session) | none | the journal shows exactly one btusb registration and no earlier host in this boot; the previous boot ended 29 h before | the same early capture; not testable otherwise |
| H4 | The loss of a rampatch download earlier in the same boot, silent | none | `using rampatch` is logged before any download; no earlier attempt in the journal | excluded by the journal |

What is established: the setup reached its end with nothing downloaded at the first enumeration; LE commands failed with
a status-only reply; the device dropped off USB 22 ms later and came back; the second pass loaded only the NVM; the index
never reached the management list because of `hci_power_on()`'s early return. What is not established: the status byte
itself, why it was set, and why the device dropped.
