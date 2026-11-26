# CO-38 on the laptop with the patched kernel (2026-11-26)

**Result:** with CO-38's one-line change, Read Advertising Features lists instance 2 on the real QCA9377. With the
stock kernel, on 2026-11-25 (`README.md` here), it listed none.

## The kernel

- Ubuntu `7.0.0-44-generic` (linux-hwe-7.0 7.0.0-44.44~24.04.1), cold boot at 2026-11-26 05:41 +0100, after a full
  power-off by the operator.
- `bluetooth.ko` from `/lib/modules/7.0.0-44-generic/updates/`: CO-38's build, srcversion `CA64890CE90A328C6EAC1BF`,
  SHA-256 `63ebc95780c49f3ebedf1c2094fbcfb37c0fe462279fc1ec7c7968824d0327e9`. It was built from Ubuntu's -44 source, and
  differs from the unpatched control build by the one line in `read_adv_features()` (`PATCHED-RUN-PLAN.md`).
- `scripts/module-updates.sh status`: loaded srcversion `CA64890CE90A328C6EAC1BF`.
- btusb is the stock -44 one: srcversion `4B2BD2C14BA4918C28E7208`, equal to `modinfo` on
  `kernel/drivers/bluetooth/btusb.ko.zst`.
- Ubuntu's `net/bluetooth/mgmt.c` is byte-identical in -43 and -44 (`cmp`). So the stock -43 run of 11-25 is the
  "before" for the same code.

## Before the test (05:55)

- `hciconfig hci0`: `UP RUNNING`, commands 115, errors 0.
- Boot log: `QCA: patch rome 0x302 build 0x3e8, firmware rome 0x302 build 0x111`, the rampatch and NVM loaded.
- Kernel warnings this boot: only the expected `bluetooth: loading out-of-tree module taints kernel`, and the stock
  "Enhanced Setup Synchronous Connection … not supported" line.

## The run

```
$ python3 -I contributions/CO-38-read-adv-features-hidden-instances/laptop-20261125/co38-laptop-repro.py
2026-11-26T05:55:49+0100 step 1: Read Advertising Features
2026-11-26T05:55:49+0100 > opcode 0x003d index 0 params []
2026-11-26T05:55:49+0100 < Command Complete opcode 0x003d status 0x00 reply [7ff001001f1f0500]
    supported_flags 0x0001f07f max_adv_data_len 31 max_scan_rsp_len 31 max_instances 5 num_instances 0 instances []
2026-11-26T05:55:49+0100 step 2: Add Advertising, instance 2 only, timeout 60 s
2026-11-26T05:55:49+0100 > opcode 0x003e index 0 params [020000000000003c000000]
2026-11-26T05:55:49+0100 < Command Complete opcode 0x003e status 0x00 reply [02]
2026-11-26T05:55:49+0100 step 3: Read Advertising Features with instance 2 added
2026-11-26T05:55:49+0100 > opcode 0x003d index 0 params []
2026-11-26T05:55:49+0100 < Command Complete opcode 0x003d status 0x00 reply [7ff001001f1f050102]
    supported_flags 0x0001f07f max_adv_data_len 31 max_scan_rsp_len 31 max_instances 5 num_instances 1 instances [2]
    RESULT: instance 2 listed (no bug)
2026-11-26T05:55:49+0100 step 4: Remove Advertising, instance 2
2026-11-26T05:55:49+0100 > opcode 0x003f index 0 params [02]
2026-11-26T05:55:49+0100 < Command Complete opcode 0x003f status 0x00 reply [02]
2026-11-26T05:55:49+0100 > opcode 0x003d index 0 params []
2026-11-26T05:55:49+0100 < Command Complete opcode 0x003d status 0x00 reply [7ff001001f1f0500]
    supported_flags 0x0001f07f max_adv_data_len 31 max_scan_rsp_len 31 max_instances 5 num_instances 0 instances []
```

- **Step 3** replies `7ff001001f1f050102`: 9 bytes, `num_instances 1`, instance 2. These are the bytes the BlueZ
  test expects with the fix (`…05 01 02`). The stock kernel's reply was `7ff001001f1f0500` (8 bytes, none listed).
- **The controller's side**, from the kernel's debug log (dynamic debug on), 05:55:49:
  - LE Set Random Address (`0x2005`), LE Set Advertising Parameters (`0x2006`) and LE Set Advertising Enable
    (`0x200a`), each `status 0x00`;
  - at the removal, Set Advertising Enable again, `status 0x00`.

  This is the same sequence as on the stock kernel. It shows that the controller accepted the commands; nothing
  here observed the radio.

## After the test

- `hciconfig hci0`: `UP RUNNING`, commands 119, errors 0.
- No new kernel warning or error.
- Trial `stock-fixed` #01 (opened at this boot) carries a `bt-mark` before and after the run. E3 #14 closed at the
  shutdown before this boot (`state-after.txt`).

## Not covered here

- No discovery or scan check was run.
- The daily-use check is the normal use of the laptop on this boot: headset calls and music.
- One controller, one kernel, one run; the multi-tree QEMU tests are the breadth (the patch's notes).
