# EX-042 — sixth-instance-and-the-treatment-stamp-was-wrong

**Claim.** Sixth instance of the alt-1 signature — `0x0428` answered in 83.8 ms, `evt 5`,
`:6 → :3`, **1,595 × `len 27 mtu 9`**, bare `command tx timeout` at **2.147 s** — with a
fourth direct `sysfs` read of `bAlternateSetting 1` and a fully uncensored window. And a
**correction to the provenance of every exhibit since `EX-036`**: the machine's mode stamp
has read *experiment* since 2026-08-15 while the autosuspend override and power pin were
**active on disk**, reinstalled by `install.sh --tools-only` on 08-19 and again — by this
side — on 09-01.

**Relevance.** The signature is now `n = 6` across three kernels; the interval spread is
unchanged at **115 ms**. The provenance finding is the reviewer's (`R2-58`, review
`2026-09-16T0420Z`), verified here on the live machine, and it changes what the
*treatment* row of `EX-036`–`EX-041` means: the values recorded were the **live** values and
are correct; the claim that trials under them were "directly comparable with the A/B/C/D
builds" was not.

## Extraction method

Re-runnable as-is while boot `3e8809d5` (started 2026-09-13 08:30:11) is retained:

```console
$ tools/bt-fault-window
$ tools/bt-usbstate | grep -E 'ALTERNATE SETTING|wMaxPacketSize 0009'
$ ls -l /etc/modprobe.d/btusb-qca9377.conf* /etc/udev/rules.d/50-bluetooth*
$ tools/bt-mode status | grep -E 'recorded mode|ACTIVE'
```

## Output

Verbatim, trimmed to the lines the claim rests on; full output in the session directory.

```
  SCO packets in this window
    alt-1  (mtu 9)       1597   of which 27-byte mSBC: 1595
    wider  (mtu >9)         0   (CVSD — the healthy path)
    2026-09-16T12:32:48.110908+02:00 n kernel: hci0 opcode 0x0428 plen 17
    2026-09-16T12:32:48.194697+02:00 n kernel: hci0: hcon 000000001a0d2947 handle 0x0003
    2026-09-16T12:32:48.194798+02:00 n kernel: hci0 evt 5
    2026-09-16T12:32:48.194832+02:00 n kernel: Looking for Alt no :6
    2026-09-16T12:32:48.194873+02:00 n kernel: Looking for Alt no :3
    2026-09-16T12:32:50.257681+02:00 n kernel: Bluetooth: hci0: command tx timeout
  0x0428 setup → fault: 2.147 s

  ⚠️  SCO interface is on ALTERNATE SETTING 1, isochronous endpoint 9 bytes
    wMaxPacketSize       0009

-rw-r--r-- 1 root root 2238 Sep  1 05:45 /etc/modprobe.d/btusb-qca9377.conf
-rw-r--r-- 1 root root 2013 Aug 15 09:35 /etc/modprobe.d/btusb-qca9377.conf.disabled
-rw-r--r-- 1 root root  545 Sep  1 05:45 /etc/udev/rules.d/50-bluetooth-no-autosuspend.rules
-rw-r--r-- 1 root root  545 Aug 15 09:35 /etc/udev/rules.d/50-bluetooth-no-autosuspend.rules.disabled

  recorded mode        experiment since 2026-08-15T09:36:06+02:00
  persistent overrides modprobe conf ACTIVE
                       udev pin ACTIVE
```

## The signature, `n = 6`

| | `033` | `036` | `037` | `038` | `040` | **this** |
|---|---|---|---|---|---|---|
| date | 08-22 | 08-25 | 09-01 | 09-13 | 09-13 | **09-16** |
| kernel | `-29` | `-30` | `-30` | `-31` | `-31` | **`-31`** |
| `0x0428` answered | +72.8 | +74.9 | +88.6 | +135.9 | +91.8 | **+83.8 ms** |
| 27-byte frames on `mtu 9` | 835 | 87 | 680 | 682 | 1562¹ | **1595¹** |
| setup → fault | 2.076 | 2.152 | 2.151 | 2.191 | 2.140 | **2.147 s** |
| alt 1 from `sysfs` | — | — | ✔ | ✔ | ✔ | **✔** |

¹ window-scoped (−4 s / +3 s). Spread across six: **115 ms**. `sysfs` reads: **4**.

## Terminator

```
first timeout   2026-09-16T12:32:50.257681+02:00
checked         2026-09-16T13:03:17+02:00     elapsed 1826.7 s (30 m)
interventions   0 since the fault
USB-layer lines 0
```

The boot's five earlier intervention lines all **predate** the fault — the last at
12:15:36, seventeen minutes before. Those are two USB resets on **bus 1** (`1-3`, `1-4`,
not our `3-3`) and an rfkill unblock at one timestamp: a resume-from-suspend signature.
⚠️ Noted, not claimed: this wedge came 17 min after a resume. `n = 1`.

## The treatment stamp — what was wrong and what was not

`bt-mode experiment` implements the baseline by renaming two files to `.disabled`.
`install.sh --tools-only` skips the mode guard *and* reinstalls both files under their
active names. So:

| date | event | files on disk |
|---|---|---|
| 08-15 09:35 | `bt-mode experiment` | `.disabled` — baseline |
| 08-19 | tools-only deploy (reviewer's finding) | **active** — mitigation |
| 09-01 05:45 | tools-only deploy, this side (`bt-archive` fixes) | **active**, re-stamped |
| 09-16 | `bt-mode status` | stamp *experiment*, files **ACTIVE** |

**What stays right.** `EX-036`, `EX-037`, `EX-038`, `EX-040`, `EX-041` each record
`autosusp=N, power=on` — read live from `/sys`, not from the stamp — and that is what the
machine was running. Their treatment rows are **correct**.

**What was wrong.** The mode stamp, `bt-mode`'s promise that trials from 08-15 are
"directly comparable with the A/B/C/D builds", and `HISTORY`'s account of the 08-19 deploy
(it checked the watchdog, not the power policy). And `BRIEF` §5 retracted the "0/4 vs 3/4"
treatment effect as *chronological* without naming what made the split: **this**.

⚠️ **This side did it too.** The 09-01 file dates are this side's own `--tools-only` run.
The rule that `--tools-only` "arms nothing" was believed here as well; the reviewer read
`install.sh` and the file dates instead.

## What this does not establish

**Not a mechanism**, still. Six deaths and one survival, all correlational.

**Not a treatment effect in either direction.** With the stamp unreliable from 08-19, the
comparison this project wanted — baseline vs mitigation — has no clean rows on the baseline
side after 08-19. The live-read rows are honest about what ran; they cannot say what
*would have* run.

## Provenance

| field | value |
|---|---|
| captured | `2026-09-16T13:04:42+02:00` |
| kernel | `7.0.0-31-generic` |
| bluez | `5.72-0ubuntu5.5` + 31 Ubuntu patches + `patches/bluez/0001`, `0002` |
| device | `13d3:3503` QCA9377 (ROME); peer `MOMENTUM 4` |
| boot id | `3e8809d5` — started 2026-09-13 08:30:11, still boot 0 at capture |
| treatment (live) | `autosusp=N, power=on, wd=off, probes=off` — **stamp says experiment** |
| guards fired | 0; daemon crashes 0 |
| exit status | `0` |
| redacted | `no` |
| session | `evidence/sessions/20260916-130442-alt1-wedge-sixth-instance` |
| confirms | `EX-033`, `EX-036`, `EX-037`, `EX-038`, `EX-040` |
| corrects | the *comparability* claim behind `EX-036`–`EX-041`'s treatment rows (`R2-58`) |
