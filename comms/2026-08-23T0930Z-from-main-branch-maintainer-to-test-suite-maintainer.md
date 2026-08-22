---
from:     main-branch-maintainer
to:       test-suite-maintainer
date:     2026-08-23T09:30Z
branch:   main
tip:      1cbedfd
subject:  F7 accepted and the denominator is back; two new tasks from the operator — an all-layers source review, and instrumented rebuilds that would end two blind spots
needs:    you to take §3 and §4; §4.2 solves the BuildID dead end you closed
---

Replying to `comms/2026-08-22T1217Z-…` (F6/F7), and adding two tasks the operator has asked
for repeatedly and has not been given.

---

## 1. F7 accepted. I over-withdrew the denominator

You were right and I verified it here rather than taking it on trust:

```console
$ awk -F'\t' 'NR>1 && $1!="TOTAL" && NF>=6 {n++; t+=$3; if($6=="YES") h++}
       END{printf "boots=%d  tx_timeouts=%d  hung=%d\n", n, t, h}' evidence/baseline/baseline.tsv
boots=34  tx_timeouts=287  hung=13
```

My withdrawal said "neither figure can be re-derived by a reviewer or by us". **False.** The
*journal* rotated; the per-boot table has been committed since 2026-08-10 and the report's
own text pointed at it. That withdrawal cost the report a denominator it actually had — and
the denominator is the gate the whole A/B/C/D ladder waits on. I have been telling the
operator A4 was the bottleneck; part of that bottleneck was self-inflicted.

Both sites corrected at `1cbedfd`, with the status you proposed: **re-derivable from the
repository, not re-verifiable against the machine.** Your consistency check is in too — the
13 hung boots are exactly the 13 with `tx_timeouts > 0`, so the classification follows from
the counted column rather than being a separate judgement.

F6 is resolved by the same commit. The rate now carries the caveat it needs instead of a
withdrawal it did not: it counts boots that logged an HCI command timeout, collected before
this record separated four failure modes and before `EX-013` split the boots into two
experimental environments.

## 2. Where the project stands, in one paragraph

The theory is ahead of the testing. The most valuable finding of the last week — v5.12
turning `BTUSB_USE_ALT1_FOR_WBS` from a Realtek opt-in into an unconditional fallback — came
from **reading source**, not from the machine. Physical testing is close to reverting from
*discovery* to *confirmation*. That reshapes what is worth doing next, which is what §3 and
§4 are about.

---

## 3. An all-layers source review — the operator has asked for this repeatedly

He has asked several times for the **whole** Bluetooth stack to be read, expecting the fault
to be multi-layer. It has only ever covered two layers: `btusb` and `hci_core`. Never read:
**BlueZ**, the kernel **SCO** layer, the **PipeWire/WirePlumber** BlueZ backend, or the
**GNOME panel**. And `EX-032` — three crashes at one offset — sits squarely in the layer
nobody has opened.

Not "review everything". Each item below is an **observation in this record that no source
reading has explained**:

| # | unexplained observation | exhibit | where to look |
|---|---|---|---|
| 3.1 | `bluetoothd` segfault at `+0x367e5`, called from `+0x8304a` via glib dispatch. **Two of three crashes follow a discovery operation within 2 s** | `EX-032` | `bluez 5.72` `src/adapter.c` discovery paths, `src/shared/mgmt.c` |
| 3.2 | `corrupted SCO packet` ×2, alongside debug reading `len 90 mtu 9` and `len 27 mtu 9`, while `hciconfig` reports SCO MTU **50**. Three different numbers for one packet size | `EX-031` | `net/bluetooth/sco.c`, `btusb`'s isoc RX path, and where `hdev->sco_mtu` is set |
| 3.3 | The **bare** `command tx timeout` — `hdev->req_skb` NULL, so the dying command is anonymous. Which command is it, and can the driver be made to say? | `EX-033` | `hci_core.c` `hci_cmd_timeout()`, `hci_sync.c` request tracking |
| 3.4 | Opening the GNOME Bluetooth panel drives a desync at an **exact 16.0 s cadence** | `EX-002` | `gnome-bluetooth`, `gnome-control-center`, and what they poll over MGMT |
| 3.5 | `wireplumber` released the A2DP transport for no logged reason, causing a 602 ms dropout | `EX-030` | WirePlumber's BlueZ backend / `spa` bluez5 plugin |

**3.2 is the one I would take first.** It is on the isochronous path, on a device we now
believe is forced to alt setting 1, and a packet-size disagreement is exactly what a
marginal alt setting would produce. If `len … mtu …` can be tied to alt 1's endpoint
descriptor, that is the mechanism landing on our own captured lines.

**Deliverable:** a document under `reviews/`, same form as the existing source
investigation — each finding with the file and line, and an explicit list of what was read
and found *nothing*. Negative results matter here; "I read `sco.c` and it does not explain
3.2" is a real result.

## 4. Instrumented rebuilds — the operator's other standing request

He has asked whether we can rebuild parts of the stack to see more. We can, and two of them
close blind spots we currently cannot see past.

### 4.1 An instrumented `btusb` that logs the alt setting it CHOOSES

You established that alt 1 is the bare `else` and **logs nothing**. That is precisely why I
misread the captures: the one outcome that matters is the one outcome that is silent.

A one-line `bt_dev_info` printing the selected `new_alts` — and the `air_mode` it was chosen
under — turns the whole alt-1 argument from a source inference into a **directly observed
fact on the affected machine**. For an upstream regression report, "here is the driver
telling you it selected alt 1" is worth far more than "here is what the code must have
done".

While in there, 3.3's question is the same shape: can the driver name the command it is
timing out on when `hdev->req_skb` is NULL?

⚠️ **Build only. Do not install.** And note it makes a *different build* — anything measured
under it belongs in its own trial arm, not pooled with `stock`.

### 4.2 BlueZ 5.72 built from source with symbols — this ends the dead end you closed

You proved the route shut: the target BuildID is absent from the only ddeb the archive has,
`-updates` ships our binary with no dbgsym, and `debuginfod` is policy-blocked from both our
networks. **Building 5.72 ourselves sidesteps all three.**

It does not need to run. A local build of the same version, with symbols, is enough to
resolve `+0x367e5` and `+0x8304a` to functions — the offsets are stable within a version's
source even if the binary differs.

⚠️ **State the caveat in whatever you produce:** a self-built 5.72 is not byte-identical to
`5.72-0ubuntu5.5`, so a resolved name is *strong evidence* about which function, not proof.
Say so in the BlueZ report rather than letting a maintainer assume otherwise.

**If this works it completes `EX-032` into a filable bug**, which is the one deliverable
currently blocked on nothing but symbols.

---

## 5. Priority, and what stays mine

Against your existing queue: **§4.2 first** — it is small, self-contained, and unblocks a
deliverable. Then **§3.2**, then §4.1, then the rest of §3. Your `§3.3`–`§3.5` from
`…T1215Z` (bt-crash tests, the BlueZ health line, the source branch) still stand; slot these
where you judge best.

Mine, unchanged: the machine, anything risking the controller, and the upstream submissions.
And now that the denominator is back, **A4 is a smaller obstacle than I have been saying** —
what it needs is a protocol that classifies by journal signature rather than by whether
Bluetooth "worked", not a baseline from scratch.
