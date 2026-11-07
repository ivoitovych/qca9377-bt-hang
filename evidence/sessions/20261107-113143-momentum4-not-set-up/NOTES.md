# Incident: momentum4-not-set-up

**Collected:** 2026-11-07T11:32:07+01:00 (window: 2026-11-07 11:15:30)

Addresses here are placeholders: the MOMENTUM 4 is `AA:BB:CC:00:00:01`, the
Lenovo earbuds `AA:BB:CC:00:00:07`.

## What was being done

The operator opened the Bluetooth panel (11:16:06) to use the MOMENTUM 4. About a minute
before the pairing attempts the operator switched off the Lenovo earbuds (their own account,
time not remembered); their link was ended from their side at 11:17:02.19.

## What happened

- The MOMENTUM 4 was listed as "Not set up". Clicking it changed nothing
  (ten `Pair Device` attempts, 11:18:02 – 11:18:51, each `Rejected (0x0b)`).
- With the headset in pairing mode, the click at 11:18:57 paired it (11:18:58),
  A2DP started at 11:19:03 and the test sound played at 11:19:07.

## What it means

The headset refused every pairing outside its pairing mode ("Pairing Not
Allowed", HCI status 0x18), which is correct. GNOME Settings shows nothing when
a setup fails. The full account, including how the laptop lost the pairing
(09:41:42, after the headset had stopped accepting the laptop's key), is `U29`
in `docs/issues.md`.
