# Investigation plan — data before code

Agreed with the operator 2026-08-11: **collect and understand before changing anything.**
Patching the driver first would change a variable before the baseline exists, and after
fifteen phases in which "it worked for a while" meant nothing, we would not be able to
tell a fix from luck.

Ordered by risk. Everything in phases A and B is reversible and touches no code.

---

## Phase A — zero risk, no code, no rebuild

### A0. Confirm Ubuntu's own `hci_cmd_timeout()` ⭐ do this first

The whole interpretation of the recovery experiments now rests on one source fact, so do
not infer it. Upstream v7.0 `net/bluetooth/hci_core.c` reads:

```c
	if (hdev->reset)
		hdev->reset(hdev);
```

with no threshold — verified. And `tools/bt-verify-kernel-mechanism` confirms the shipped
`btusb.ko` exports `btusb_qca_reset`, not `btusb_qca_cmd_timeout`. What remains is to read
**Ubuntu's `7.0.0-28` source** and confirm it is not patched here. Requires enabling
`deb-src` and `apt-get source`; changes nothing on the running system.

### A1. Firmware identity under both operating systems — strong, not decisive

The controller reports HCI revision and LMP subversion. Read them under Linux, then under
Windows 11 on the same machine.

- **If they differ**, that is strong evidence the controller reports a different
  firmware/version state under the two systems.
- ⚠️ It does **not** establish that the difference *causes* the hang, and equal version
  fields would not prove identical binary firmware either. An earlier revision called
  this "decisive"; that was too strong.
- Costs one reboot. Changes nothing.

Linux: `hciconfig -a` / `HCI_Read_Local_Version`.
Windows: Device Manager → Bluetooth adapter → Details → *Firmware/LMP version*, or the
vendor tool.

**More direct, and QCA-specific:** `btusb_setup_qca()` asks the controller for its
Qualcomm target version and patch status before deciding whether to load the rampatch.
Getting that answer out of the device tells us far more than a version-field comparison —
and Build B in [`fix-proposal.md`](fix-proposal.md) §5a produces it as a side effect,
including if it refuses to proceed.

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

### A4. Codec / transmission-mode switching ⭐ the gate

The operator reports that changing transmission mode (HQ ↔ XQ) kills the controller
**immediately**. Independent reporters point at the same class of event — kernel bug
203535 is triggered by *pausing and playing* A2DP.

This must become a **quantified protocol**, not an anecdote:

```
cold boot
start btmon + kernel log capture      (bt-trace is already running)
bt-mark "trial N start"
connect Momentum 4
perform operation X
perform operation Y
perform operation Z
record: hang / no hang
```

Run it on **stock** first and establish a failure rate — target something like **5/5**.
Without a denominator, "the patched build ran for an hour" means nothing, and this
project has already mistaken absence of observed failure for a fix more than once.

Nothing in Phase C should be built until this exists.

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

## Phase C — after A0 and A4, not necessarily after all of B

**Revised 2026-08-11.** An external review argued for bringing the builds forward, and
that is right: with the mechanism correction in hand, the A/B experiment is the sharpest
instrument available, and waiting on the remaining Phase-B items would not sharpen it.

The gating prerequisites are **A0** (confirm Ubuntu's timeout path) and **A4** (a
deterministic reproducer — without one, neither build can be evaluated).

### C1. The four-step ladder — see [`fix-proposal.md`](fix-proposal.md) §5a

**Not** a two-build A/B. `BTUSB_QCA_ROME` installs six distinct behaviours, so toggling it
wholesale would show a cure without isolating a cause:

- **A** — `hdev->reset = btusb_qca_reset` only
- **B** — A + `data->setup_on_usb = btusb_setup_qca`
- **C** — full `BTUSB_QCA_ROME`
- **D** — C + `BTUSB_WIDEBAND_SPEECH` (production candidate; held back so it cannot
  confound an audio-transition reproducer)

Each step attributes the effect to one added behaviour. Confirm
`using rampatch file: qca/rampatch_usb_00000302.bin` appears at B, and record which reset
path fires at A (`bt_en gpio` vs `Resetting usb device.`).

Note that B may bind successfully and then fail at **HCI open**, not at probe —
`setup_on_usb` runs from `btusb_open()`. An `-ENODEV` there, with the reported ROM
version, is a result worth capturing rather than a failed experiment.

⚠️ Risk, unchanged from [`fix-proposal.md`](fix-proposal.md) §4: if this module is not a
true ROME variant, `btusb_setup_qca()` may fail — at **HCI open**, not at probe (the
device stays enumerated and bound; bring-up is what fails) — and leave the machine with
**no Bluetooth**. Recoverable with `modprobe -r btusb; modprobe btusb` — no reboot — and
the test module is loaded with `insmod`, never installed.

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
