# EX-035 — patched-bluetoothd-runtime-observation

**Claim.** A `bluetoothd` built from this machine's own `5.72-0ubuntu5.5` source with both
`patches/bluez/` fixes applied has run **7 h 56 m** across deliberate reproduction attempts
— four rfkill toggle cycles in four minutes — with **zero crashes**. Neither patch's guard
fired.

**Relevance.** Until now the patches had **no runtime evidence at all**: they applied,
compiled, and matched a coredump, but no patched binary had ever executed. This is the
first. ⚠️ It is **weak** evidence and this exhibit exists partly to say so precisely —
absence of a crash that was never reproducible on demand is close to uninformative, and the
guards firing zero times means the *specific* code paths the patches protect were never
reached.

## Extraction method

Re-runnable as-is on the affected machine, while boot `c8342e9b` is retained:

```console
$ ls -l /proc/$(systemctl show bluetooth -p ExecMainPID --value)/exe | awk '{print $(NF-2), $(NF-1), $NF}'; journalctl -u bluetooth -b 0 --since '2026-08-25 03:38' --no-pager | grep -cE 'segfault|core-dump'; journalctl -b 0 --since '2026-08-25 03:38' --no-pager | grep -cE 'has no stream|Wrong size of start discovery return parameters'; journalctl -b 0 --since '2026-08-25 03:38' --no-pager | grep -cE 'name hci0 blocked 1'
```

## Output

Verbatim, 4 line(s), exit status 0.

```
/proc/196730/exe -> /usr/local/libexec/bluetooth/bluetoothd
0
0
4
```

Line 1 is the identity of the **running** process, not of an installed file. Line 2 is
crashes since the patched daemon started. Line 3 is guard firings. Line 4 is rfkill blocks
— the operator's reproduction attempts.

## What is being tested

| | |
|---|---|
| base | `bluez 5.72-0ubuntu5.5`, the machine's own version — **not** upstream master |
| source | archive pool, both tarballs verified against `Checksums-Sha256` in the `.dsc` |
| distro delta | all 31 Ubuntu patches applied |
| our patches | both, applied on top, landing at offsets −22 and −203 lines |
| install | `/usr/local/libexec/bluetooth/bluetoothd` + a systemd drop-in |
| distro binary | **untouched** — `dpkg -V bluez` clean |

Built against the machine's own version deliberately, so anything observed is attributable
to the two patches rather than to a version change.

## Against the recorded crash rate

| | unpatched | patched |
|---|---|---|
| window | 2026-08-18 18:46 → 2026-08-19 15:25 | 2026-08-25 03:38 → 11:34 |
| span | ~20 h 39 m | **7 h 56 m** |
| `bluetoothd` crashes | **3** | **0** |
| all at offset `367e5` / `a6986` | yes | — |

**This comparison is not evidence and is included to show why.** The three crashes were
never provoked deliberately; they arrived during ordinary use. A 7 h 56 m span with no
crash is entirely consistent with the patches working, and equally consistent with the
conditions simply not recurring. There is no reproducer, so there is no denominator — the
same defect this project has named repeatedly.

## The guards did not fire, and that is the informative part

```
$ … grep -cE 'has no stream|Wrong size of start discovery return parameters'
0
```

Both patches log before they bail, so a firing would be **positive** evidence that a crash
was prevented. Zero means the protected paths were not reached at all. So this run does not
test the patches' behaviour — it only shows the patched daemon is not obviously broken.

`tools/bt-snapshot` now cuts `f-guard.log` for exactly this line, and prints the zero case
labelled `0 = no crash prevented AND none occurred`, so the ambiguity is not silently read
as success.

## An apparent behaviour change, checked and NOT attributable

The operator reported the daemon "appears unusual but more stable". The unusual part is
visible:

```
bluetoothd[196730]: src/service.c:btd_service_connect() a2dp-source profile connect failed
                    for <peer>: Device or resource busy
```

Seven occurrences since the patched daemon started, and **zero earlier in this boot or in
the previous boot** — which looks like a regression introduced by the patches.

**It is not.** Widening the search finds the same message on the **unpatched** daemon:

```console
$ for b in -2 -3 -4 -5; do printf '%s: ' "$b"; journalctl -u bluetooth -b $b --no-pager | grep -c 'Device or resource busy'; done
-2: 0
-3: 0
-4: 0
-5: 2
```

and in 6 archived `bt-snapshot` cuts. It predates the patch.

⚠️ **The frequency has two candidate causes and this exhibit distinguishes neither.** What
it establishes is only that the message is **not new**, which is the question that mattered.

## Why the usage pattern changed — and what the logs say about it

The operator's account, which is the reason the pattern changed at all:

> my testing pattern may be changed because I did not encounter the crash and bt death on
> the usual place, so tried many times

That is not a confounding variable that happened to coincide with the new daemon. It is a
*consequence* of the observation, and it would be the strongest signal in this exhibit —
if the logs supported it. **They only partly do**, and the part they do not support is the
important one.

**HFP was exercised hard.** Since the patched daemon started:

```console
$ journalctl -b 0 --since '2026-08-25 11:10' --no-pager \
    | grep -oE 'Hands-Free Voice gateway state changed: [a-z]* -> [a-z]*' | sort | uniq -c
      9 … disconnected -> connecting
      5 … connecting -> connected
      4 … connecting -> disconnected
      6 … connected -> disconnected
```

Nine connection attempts, five reaching `connected`, four failing outright.

**But the trigger was never reached:**

```console
$ journalctl -k -b 0 --since '2026-08-25 03:38' --no-pager | grep -cE 'opcode 0x0428|opcode 0x043d'
0
$ journalctl -k -b 0 --since '2026-08-25 03:38' --no-pager | grep -cE 'Looking for Alt no'
0
```

**Zero synchronous-link setups and zero alternate-setting switches.** HFP connected at the
RFCOMM/profile level nine times and **never established a SCO audio link** — so
`0x0428`, the alt-setting fallback and the controller wedge were all out of reach for the
whole run.

**That is the correct explanation for "it did not die", and it is not the patches.** `BT-1`
requires the SCO path; the SCO path was not taken; therefore `BT-1` could not occur. This
run is silent about the controller fault, and the patched daemon's survival is not evidence
about it either way.

⚠️ It also means the operator's "usual place" did not behave usually **before** reaching
the point where the fault lives. Why nine HFP connections produced no SCO setup at all is
unexplained and is the most interesting thing here — it may be the four
`connecting -> disconnected` failures and the seven `Device or resource busy` refusals
preventing the audio path from ever opening. That is a question for the next session, not a
finding.

## Reading

**What this establishes.** A patched `bluetoothd` built from the machine's own source runs
normally: it starts, powers the adapter, completes discovery, connects and disconnects
peers, and survives repeated rfkill toggling for nearly eight hours without crashing. The
patches do not obviously break anything.

**What it does not establish.** That the patches fix the crash. Nothing exercised either
guarded path. The right description for a submission is still *a static defect with crash
forensics*, now with the addition that the fix has been built and run without regression —
which is worth stating and is not worth overstating.

**And it does not establish anything about `BT-1`.** The controller fault needs the SCO
path, and the SCO path was never taken in this run. "Bluetooth did not die" here has a
simpler explanation than the patches: it was never asked to do the thing that kills it.

**What would settle it.** A reproducer for either path. Failing that, a long observation
window: the unpatched daemon crashed three times in roughly twenty hours on 2026-08-18/19,
so a patched daemon surviving substantially longer under comparable use would begin to
mean something. It has not yet run that long.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-25T11:34:31+02:00` |
| kernel | `7.0.0-30-generic` |
| bluez | `5.72-0ubuntu5.5` + 31 Ubuntu patches + `patches/bluez/0001`, `0002` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `yes` — peer address omitted from the quoted log line |
| revert | `rm /etc/systemd/system/bluetooth.service.d/20-patched-bluetoothd.conf` |
