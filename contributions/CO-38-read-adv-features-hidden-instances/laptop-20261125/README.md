# CO-38 reproduced on the laptop, stock kernel (2026-11-25)

**What:** the bug of CO-38, shown on the real controller with the stock Ubuntu kernel. Nothing was built,
installed or rebooted. It ran on the operator's yes ("please test on the available kernel", 2026-11-25),
during the open E3 trial #14, with marks before and after in the trial's timeline (`bin/bt-mark`).

**Machine:**
- kernel `7.0.0-43-generic`; `bluetooth` module srcversion `585A17E26A09081072E4FEC`, btusb srcversion
  `4B2BD2C14BA4918C28E7208` (both stock);
- the controller: QCA9377, USB `13d3:3503`, on the ROME setup (rampatch build 0x3e8), hci0 `UP RUNNING`;
- user space: bluetoothd running. It had no advertising instance registered (step 1 lists none).

**Method:** `co38-laptop-repro.py` (beside this file) talks MGMT on `HCI_CHANNEL_CONTROL`, index 0. It
adds only instance 2, with a 60 s timeout as a safety net, reads, then removes it. btmgmt 5.72 was tried
first and printed nothing without a terminal, so it was stopped and not used.

## Output, verbatim

```console
$ python3 -I contributions/CO-38-read-adv-features-hidden-instances/laptop-20261125/co38-laptop-repro.py
2026-11-25T10:10:22+0100 step 1: Read Advertising Features
2026-11-25T10:10:22+0100 > opcode 0x003d index 0 params []
2026-11-25T10:10:22+0100 < Command Complete opcode 0x003d status 0x00 reply [7ff001001f1f0500]
    supported_flags 0x0001f07f max_adv_data_len 31 max_scan_rsp_len 31 max_instances 5 num_instances 0 instances []
2026-11-25T10:10:22+0100 step 2: Add Advertising, instance 2 only, timeout 60 s
2026-11-25T10:10:22+0100 > opcode 0x003e index 0 params [020000000000003c000000]
2026-11-25T10:10:22+0100 < Command Complete opcode 0x003e status 0x00 reply [02]
2026-11-25T10:10:22+0100 step 3: Read Advertising Features with instance 2 added
2026-11-25T10:10:22+0100 > opcode 0x003d index 0 params []
2026-11-25T10:10:22+0100 < Command Complete opcode 0x003d status 0x00 reply [7ff001001f1f0500]
    supported_flags 0x0001f07f max_adv_data_len 31 max_scan_rsp_len 31 max_instances 5 num_instances 0 instances []
    RESULT: BUG REPRODUCED: instance 2 missing
2026-11-25T10:10:22+0100 step 4: Remove Advertising, instance 2
2026-11-25T10:10:22+0100 > opcode 0x003f index 0 params [02]
2026-11-25T10:10:22+0100 < Command Complete opcode 0x003f status 0x00 reply [02]
2026-11-25T10:10:22+0100 > opcode 0x003d index 0 params []
2026-11-25T10:10:22+0100 < Command Complete opcode 0x003d status 0x00 reply [7ff001001f1f0500]
    supported_flags 0x0001f07f max_adv_data_len 31 max_scan_rsp_len 31 max_instances 5 num_instances 0 instances []
```

## What it shows

- **Add Advertising for instance 2 succeeds** (status 0, reply `02`), and so does Remove Advertising of it.
  So the instance existed between the two.
- **Read Advertising Features lists no instance** while it exists: `num_instances 0`.
- **The reply bytes are exactly the unpatched emulator's:** `7ff001001f1f0500`, 8 bytes. The BlueZ test
  expects 9 with the fix: `…05 01 02`.
- **The instance was on air.** The kernel's debug log (dynamic debug was on; `dmesg`, 10:10:24) shows LE
  Set Random Address (0x2005), LE Set Advertising Parameters (0x2006) and LE Set Advertising Enable
  (0x200a), each with status 0x00. Then, at the removal, Set Advertising Enable again (off). So on real
  hardware the instance was advertised but not reported, as the commit message says.

**After:**
- hci0 `UP RUNNING`, with TX `commands` 569 → 573 and `errors:0` (`hciconfig hci0`, which reads only the
  kernel's device record);
- no Bluetooth error in the kernel log;
- the USB link back in runtime suspend.

**Not done:** the patched kernel on the laptop. It needs a `bluetooth.ko` built for 7.0.0-43, installed in
`updates/`, and a cold boot. Planned with the operator, not yet run.
