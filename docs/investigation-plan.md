# Investigation plan — data before code

Agreed with the operator 2026-08-11: **collect and understand before changing anything.**
Patching the driver first would change a variable before the baseline exists, and after
fifteen phases in which "it worked for a while" meant nothing, we would not be able to
tell a fix from luck.

Ordered by risk. Everything in phases A and B is reversible and touches no code.

---

## Phase A — zero risk, no code, no rebuild

### A1. Firmware identity under both operating systems ⭐ decisive

The controller reports HCI revision and LMP subversion. Read them under Linux, then under
Windows 11 on the same machine.

- **If they differ**, the two systems are demonstrably running different firmware on the
  same silicon, and [`firmware-hypothesis.md`](firmware-hypothesis.md) stops being a
  hypothesis.
- Costs one reboot. Changes nothing.

Linux: `hciconfig -a` / `HCI_Read_Local_Version`.
Windows: Device Manager → Bluetooth adapter → Details → *Firmware/LMP version*, or the
vendor tool.

### A2. Driver dynamic debug

`btusb` and the Bluetooth core support runtime debug via `dyndbg` — verbose logging of
probe decisions and the stall itself, with **no rebuild and no code change**, reversible
by writing to the same file.

This is the "better logging before touching code" step. It should show exactly what
`btusb_probe()` decides for this device, and what the driver is doing when the controller
stops answering.

### A3. The two-headset comparison ⭐ best reproducer available

The operator's most useful observation: a **Sennheiser Momentum 4 provokes the hang
almost immediately**, while **Lenovo thinkplus GM2 pro buds run for hours or days** —
same host, same stack, same controller.

That is the first controlled variable this investigation has had. Capture a full HCI
trace of connecting each, and diff them. Whatever the Sennheiser does differently is
already visible in traces we are recording.

### A4. Codec / transmission-mode switching

The operator reports that changing transmission mode (HQ ↔ XQ) kills the controller
**immediately**. Independent reporters point at the same class of event — kernel bug
203535 is triggered by *pausing and playing* A2DP.

If mode switching is reliable, it is a **deterministic reproducer**, which this
investigation has never had and which is worth more to maintainers than any analysis.

---

## Phase B — still no code change

### B1. Windows-side HCI capture

Windows can log Bluetooth HCI traffic. A Momentum 4 connect + mode switch captured on
both operating systems, diffed, would show exactly where the two stacks diverge — and
whether Windows sends something Linux does not, or vice versa.

### B2. Frequency measurement of the existing mitigation

Whether `enable_autosuspend=0` reduces hang *frequency*, even though recovery never
works. Requires running with it off for a period and comparing. Lower value than A1–A4.

---

## Phase C — only after A and B

### C1. Build `btusb` out-of-tree with the device ID added

Confirm `using rampatch file: qca/rampatch_usb_00000302.bin` appears, then test whether
the reproducer from A4 still triggers the hang.

⚠️ Risk, unchanged from [`fix-proposal.md`](fix-proposal.md) §4: if this module is not a
true ROME variant, `btusb_setup_qca()` may fail at probe and leave the machine with **no
Bluetooth**. Recoverable with `modprobe -r btusb; modprobe btusb` — no reboot — and the
test module is loaded with `insmod`, never installed.

By this point we would know what we expect it to change, which is the difference between
an experiment and a guess.

---

## Why this order

The operator's reasoning, which is correct:

> First data collection. First we should understand the situation at all, understand what
> is going on. Even before patching the driver — actually changing the logic inside — we
> may need to rebuild it with a better logging level, so we could see what is actually
> going on before we do code changes, which is high price and dangerous.

A1 and A4 are the two that could each independently transform the submission: one proves
the firmware divergence, the other supplies a deterministic reproducer. Neither requires
building anything.
