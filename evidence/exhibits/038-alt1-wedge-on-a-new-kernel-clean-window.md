# EX-038 — alt1-wedge-on-a-new-kernel-clean-window

**Claim.** Fourth instance of the `EX-033`/`036`/`037` signature, on a **new kernel**
(`7.0.0-31-generic`), with **682 × `len 27 mtu 9`** in the 2.06 s before the fault and a
setup-to-fault interval of **2.191 s**. The window is **fully uncensored**: four hours,
zero interventions, and — unlike `EX-037` — **not one USB-layer line** since the fault.

**Relevance.** Three things the record did not have.

⚠️ **A second direct observation of alt 1.** `tools/bt-usbstate`, written during `EX-037`'s
window for exactly this, read the wedged interface again:

```
/sys/bus/usb/devices/3-3:1.1/bAlternateSetting      1
/sys/bus/usb/devices/3-3:1.1/ep_03/wMaxPacketSize   0009   Isoc
/sys/bus/usb/devices/3-3:1.1/ep_83/wMaxPacketSize   0009   Isoc
```

`n = 2` on the observation that was an inference in every exhibit up to `EX-036`.

**A kernel change that did not help.** `EX-033` ran on `-29`, `EX-036`/`EX-037` on `-30`,
this on **`-31`**. Three kernels, same fault, same interval to within 115 ms.

**And a boot with no CVSD at all.** `SCO pkts mtu>9: 0` for the entire boot against
64,459 on alt-1. Every previous capture mixed the two; this one is the alt-1 path alone.

## Extraction method

One call. At capture time the fault was in boot 0; the machine has since been power
cycled, so **re-derive with `--boot -1`** — and check the index against boot id
`f5de8066` first, because indices shift on every reboot:

```console
$ tools/bt-fault-window              # at capture time
$ tools/bt-fault-window --boot -1    # after the 2026-09-13 05:13 power cycle
```

Also replayable from the archive, which holds the boot in full (87,102 records,
64,457 alt-1 packet lines):

```console
$ journalctl --file /root/bt-journal-archive/boot-f5de8066.export.zst …
```

## Output

Verbatim, trimmed to the sequence and the counts (full output in the session directory).

```
bt-fault-window — boot 0, anchored on 2026-09-13T00:54:57.690511+02:00
  window: 2026-09-13 00:54:53 … 2026-09-13 00:55:00  (−4s / +3s)

  SCO packets in this window
    alt-1  (mtu 9)       1452   of which 27-byte mSBC: 1450
    wider  (mtu >9)         0   (CVSD — the healthy path)
    ⚠️  27-byte frames on a 9-byte endpoint — the BT-1 condition.

    2026-09-13T00:54:55.335799+02:00 n kernel: hci0 opcode 0x0804 plen 2
    2026-09-13T00:54:55.499618+02:00 n kernel: hci0 opcode 0x0428 plen 17
    2026-09-13T00:54:55.635523+02:00 n kernel: hci0: hcon 00000000dafaec91 handle 0x0004
    2026-09-13T00:54:55.635611+02:00 n kernel: hci0 evt 5
    2026-09-13T00:54:55.635634+02:00 n kernel: Looking for Alt no :6
    2026-09-13T00:54:55.635654+02:00 n kernel: Looking for Alt no :3
    2026-09-13T00:54:55.670591+02:00 n kernel: hci0 cmd_cnt 1 cmd queued 1
    2026-09-13T00:54:57.690511+02:00 n kernel: Bluetooth: hci0: command tx timeout
    2026-09-13T00:54:57.690569+02:00 n kernel: hci0 cmd_cnt 1 cmd queued 0

  0x0428 setup → fault: 2.191 s
```

The window-scoped count is 1450 because the window opens 4 s before the fault and the
stream was already running. **In the interval that matters — link-up `.635523` to fault
`.690511` — it is 682**, which is the figure the table below uses:

```console
$ journalctl -k -b 0 --since '2026-09-13 00:54:55.63' --until '2026-09-13 00:54:57.70' --no-pager | grep -c 'len 27 mtu 9'
682
```

## The signature, `n = 4`

| | `EX-033` | `EX-036` | `EX-037` | **this** |
|---|---|---|---|---|
| date | 08-22 | 08-25 | 09-01 | **09-13** |
| kernel | `-29` | `-30` | `-30` | **`-31`** |
| `0x0428` answered | ✔ +72.8 ms | ✔ +74.9 ms | ✔ +88.6 ms | ✔ **+135.9 ms**, handle `0x0004` |
| `evt 5` transparent | ✔ | ✔ | ✔ | ✔ |
| `:6` then `:3` | ✔ | ✔ | ✔ | ✔ |
| **27-byte frames on mtu 9** | **835** | **87** | **680** | **682** |
| what timed out | bare | bare | bare | **bare** |
| setup → fault | 2.076 s | 2.152 s | 2.151 s | **2.191 s** |
| alt 1 read from sysfs | — | — | ✔ | ✔ |

Four occasions, three kernels, two peripherals. The interval spans **115 ms**.

And the one recorded **survival** of the same path — 2026-09-01 daytime, three transparent
links established — carries **8** alt-1 packets and zero 27-byte frames. Every death has
hundreds; the survival has none.

## What is new

**`0x0804 Exit Sniff Mode` precedes the setup** by 163.8 ms. Present here, and worth
checking against the other three — the ACL link is being pulled out of sniff mode to carry
SCO, which is ordinary, but it is the first time this exhibit series has recorded what came
immediately *before* `0x0428`.

**The dying command is again unnamed in the log.** A command is queued at `.670591`, **35
ms** after link-up, and `2.020 s` later the timeout fires — `HCI_CMD_TIMEOUT` exactly. Same
shape as `EX-033` (36 ms). `EX-036` remains the only instance where the log names it
outright: `0x0406 Disconnect, handle 0x05, reason 0x13`.

**Then 25 named timeouts on `0x0c1a`** (Write Scan Enable) at 2.048 s intervals — the stack
retrying into a dead controller. The first timeout is bare; everything after is ordinary.

## Terminator — the cleanest in the record

```
first timeout   2026-09-13T00:54:57.690511+02:00
checked         2026-09-13T04:55:25+02:00     elapsed 14427.3 s (4 h 00 m)
interventions   0        neither tooling nor operator
USB-layer lines 0        ✓ bus silent
```

⚠️ **`EX-037`'s two `USBDEVFS_CONTROL … ret -110` lines came from our own tracing reaching
for the descriptor.** This window has none at all, so the USB layer's silence here is the
device's, not an artefact of being probed. The `-110` finding in `EX-037` stands — it shows
the device fails control transfers when asked — but this window is the clean baseline.

## The patched daemon, fourth time, still not the subject

`bluetoothd` is the local build carrying both `patches/bluez/` fixes. **Guards fired 0, zero
daemon crashes.** `BT-1` has now occurred **three times** with the patches installed
(`EX-036`, `EX-037`, this). They remain two correct fixes for two unrelated BlueZ NULL
dereferences.

## ⚠️ A treatment comparison that this exhibit FALSIFIES

`bt-trial report` during the 11-day gap showed:

```
observational_boot stock  0/4 BT-1   autosusp=N,power=on,wd=off,probes=off
observational_boot stock  3/4 BT-1   autosusp=Y,power=auto,wd=off,probes=off   75%
```

which reads as the autosuspend mitigation working. **This boot ran under
`autosusp=N, power=on` and wedged anyway** — verified live: `enable_autosuspend=N`,
`power/control=on`. So the `0/4` is now `0/5` with a hang in it, and the apparent effect is
better explained by *when* the boots happened than by the treatment: every `autosusp=Y` boot
is from August, every `autosusp=N` boot later. Recorded here because the rate table is
persuasive and wrong, and nobody re-derives a number that already agrees with them.

## ⚠️ A provenance correction, made the same night

The first version of this exhibit recorded the boot id as `c128a59a`. **That is a different
boot — 2026-09-02, eleven days earlier.** The value was copied forward from a
`bt-archive --check` listing earlier in the same working session rather than read from the
boot that actually faulted, which is `f5de8066`.

This is the second time this exact error has been made here: five exhibits once recorded
kernel `7.0.0-28` on machines running `-29` and `-30`, for the same reason — a provenance
field typed from memory of a previous output. A wrong boot id is worse than a missing one,
because it makes the exhibit look re-derivable while pointing at the wrong evidence. Every
number in the tables above was re-checked against `f5de8066` and stands.

## What this does not establish

**Still not a mechanism.** Four deaths with sustained alt-1 traffic and one survival without
it is a strong correlation. It does not show *how* the traffic wedges the controller.

**Still not a controlled comparison.** Nobody has yet forced this controller onto alt 1 with
a sustained stream on demand, or blocked alt 1 and shown survival under otherwise identical
use. The survival was the peripheral's choice, not an intervention.

## Provenance

| field | value |
|---|---|
| captured | `2026-09-13T04:55:59+02:00` |
| kernel | `7.0.0-31-generic` |
| bluez | `5.72-0ubuntu5.5` + 31 Ubuntu patches + `patches/bluez/0001`, `0002` |
| device | `13d3:3503` QCA9377 (ROME); peer `MOMENTUM 4` |
| boot id | `f5de8066` — 2026-09-12 00:07:00 → 2026-09-13 05:12:48 |
| archived | `boot-f5de8066.export.zst`, 87,102 records, read back and verified |
| treatment | `autosusp=N, power=on, wd=off, probes=off` |
| exit status | `0` |
| redacted | `no` |
| session | `evidence/sessions/20260913-045559-alt1-wedge-fourth-instance-clean-window` |
| confirms | `EX-033`, `EX-036`, `EX-037` |
