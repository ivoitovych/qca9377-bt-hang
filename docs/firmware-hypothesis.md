# The firmware hypothesis

**Status:** untested, but it reframes the whole investigation
**Raised:** 2026-08-11, after the operator pointed out the hardware is flawless under Windows

---

## The observation that forced this

The same silicon, in the same laptop, **never exhibits this fault under Windows**. The
operator has also seen the same behaviour on several other laptops across years of use.

That single fact invalidates a conclusion this project had drifted toward — that the
QCA9377 is simply a weak part and should be replaced. If the chip is capable of running
indefinitely without stalling under one OS, the hardware is not the explanation.
**Something Linux does, or fails to do, puts it in that state.**

## What we already knew and mis-filed

`BTUSB_QCA_ROME` in `driver_info` makes `btusb_probe()` install **two** things:

1. `hdev->cmd_timeout = btusb_qca_cmd_timeout` — the reset-on-timeout handler
2. **`btusb_setup_qca()` — download `qca/rampatch_usb_*.bin` and `qca/nvm_usb_*.bin`
   to the controller**

Earlier work established, and verified three ways, that this device matches no quirks
entry — so neither runs. Item 1 was investigated exhaustively: a reset issued after the
first HCI timeout fails, five for five, so installing that handler would not have helped.

**From that, the project concluded the patch would not help. That was a non-sequitur.**
Item 2 was never tested. Item 1 is about *recovery*. Item 2 is about *prevention*.

The absence of firmware loading had been recorded since the second hour of the
investigation — as *corroborating evidence that the device is unmatched*. The obvious
follow-up question was never asked: **what is the controller running instead?**

## The hypothesis

> This controller runs its **factory ROM firmware** under Linux, on every boot, because
> btusb does not match it and therefore never downloads the rampatch. Windows loads
> Qualcomm's firmware patch — that is most of what the vendor driver package contains.
> The two operating systems are not running the same firmware on the same silicon.
>
> The stall may well be a ROM-firmware defect that the rampatch fixes.

This also fits the operator's cross-laptop experience: any QCA device absent from
btusb's table runs unpatched on every Linux machine it is ever installed in.

## Supporting facts already in evidence

| Fact | Where established |
|---|---|
| Device matched by no quirks entry | `evidence/diagnosis/root-cause-evidence.txt` — upstream source and shipped binary |
| Zero `using rampatch file` / `nvm_usb` messages in any boot | 34 boots examined |
| `btusb_setup_qca()` and the rampatch strings **are** compiled into the running `btusb.ko` | `strings` on the module |
| The firmware files are **present and unused** on this system | `/lib/firmware/qca/rampatch_usb_00000302.bin.zst`, `nvm_usb_00000302.bin.zst` |
| Bluetooth works well enough to pair and stream | so the ROM firmware is functional, just possibly buggy |

## What would confirm or refute it

Ordered by increasing risk. **Nothing here requires modifying code.**

1. **Read the controller's firmware identity under Linux.** `HCI_Read_Local_Version`
   returns HCI revision and LMP subversion. Record it.
2. **Read the same identifiers under Windows.** If they differ, the two OSes are
   demonstrably running different firmware on the same chip — which would move this from
   hypothesis to fact without a single line of code being changed.
3. **Enable btusb / bluetooth dynamic debug** and capture a full probe sequence, to see
   exactly what the driver decides at bind time.
4. Only then: build btusb out-of-tree with the ID added, confirm
   `using rampatch file: qca/rampatch_usb_00000302.bin` appears, and test whether the
   stall still reproduces.

Step 2 is the decisive one and costs nothing but a reboot into Windows.

## Consequence for the bug report

If confirmed, the report changes shape again — and improves:

- **now:** "this device gets no `cmd_timeout` handler, and that handler would not have
  helped anyway"
- **would become:** "this device is never given its firmware patch, and the resulting
  stall does not occur under an OS that does load it"

The second is a far stronger case for adding the device ID, and it explains *why* the
addition matters rather than merely asserting that something is missing.

⚠️ Unconfirmed. Written down so the reasoning is visible and can be attacked.
