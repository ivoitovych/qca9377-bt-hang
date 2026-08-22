# Related reports — the same *phenotype* elsewhere

Prior art gathered 2026-08-11, after the operator observed the same behaviour across
multiple laptops over several years and asked how widespread it is.

**The same failure phenotype** — `hci0: command tx timeout` during A2DP activity, adapter
unusable afterwards — is reported across Qualcomm and Intel controllers, on multiple
distributions, over at least seven years.

> <!-- REVIEWED-KEEP 2026-08-15T1752Z §1.11: this file's value is holding the
>      phenotype/cause line under a pile of similar-looking reports. Edits that
>      promote "same symptom" to "same bug" undo it. -->
> ⚠️ **Phenotype, not proven common cause.** `command tx timeout` is an endpoint symptom,
> roughly like "disk I/O timeout": it says the controller stopped answering, not why.
> Intel 7260 and this QCA9377 may have entirely different underlying bugs that converge
> on the same visible signature:
>
> ```
> audio state change → controller stops answering HCI → command tx timeout
> ```
>
> An earlier revision of this file asserted "this is not specific to this chip or vendor"
> and "the underlying fault has been open since 2019 across vendors". That overstated the
> causal claim on the strength of a shared symptom, and has been corrected. Conservative
> language matters here: a maintainer will discount a report that claims more than its
> evidence supports.

---

## The closest match: kernel bug 203535

[Bug 203535 — *Bluetooth: command tx timeout with Intel Corporation Wireless 7260 in
A2DP mode*](https://bugzilla.kernel.org/show_bug.cgi?id=203535)
([mailing-list mirror](https://www.spinics.net/lists/linux-bluetooth/msg80004.html))

| | |
|---|---|
| Hardware | Intel Wireless 7260, Bluetooth `8087:07dc` — **a different vendor entirely** |
| Trigger | **"Pausing and playing audio over A2DP"** — a stream state transition |
| Symptom | `command tx timeout` on multiple HCI commands, failed USB resubmission |
| Recovery | does **not** recover on its own; requires removing and reinserting `btusb`/`btintel` |
| Also seen | `HCI reset during shutdown failed` when disabling Bluetooth |
| Kernels | 4.9 through 5.0.11 |
| Filed | May 2019, priority P1, **still open** |

The trigger is the same class of event we see: an **A2DP stream state change**. The
operator here reports that switching transmission mode/codec (HQ ↔ XQ) kills the
controller immediately — that is the same kind of AVDTP reconfiguration as a pause/play
cycle.

### One important difference — ours is worse

On the Intel hardware, reloading `btusb` restores the adapter. In the QCA9377 incidents,
driver unbind/rebind and xHCI port power-cycle failed after intervention and USB loss
(`evidence/sessions/20260810-072445-first-real-hang/`). A full power-off recovered it;
warm-reboot behavior and the M.2-rail explanation remain untested (`EX-017`, `EX-019`).

So the *same trigger class* has been followed by a more severe observed outcome on this
device, but only after intervention. That is compatible with the firmware hypothesis; it
does not prove firmware state or untreated USB-loss progression.

## Other reports of the same shape

- [Arch — *Bluetooth: hci0 command tx timeout*](https://bbs.archlinux.org/viewtopic.php?id=205092)
- [Arch — *Bluetooth randomly stops responding (hci0 link tx timeout)*](https://bbs.archlinux.org/viewtopic.php?id=198718): works initially, dies after 10–15 minutes
- [Arch — *Bluetooth down and hciconfig hci0 up timeout*](https://bbs.archlinux.org/viewtopic.php?id=171357)
- [Arch — *Random bluetooth speaker disconnects*](https://bbs.archlinux.org/viewtopic.php?id=263040&p=3): Intel **AX200/AX201**, A2DP drops every 5 minutes to a few hours
- [Arch — *Bluetooth randomly stops offering A2DP modes after connecting*](https://bbs.archlinux.org/viewtopic.php?id=291839)
- [Linux Mint — *hci0 command 0x0c03 tx timeout*](https://forums.linuxmint.com/viewtopic.php?t=374121)
- [Red Hat 2271784](https://bugzilla.redhat.com/show_bug.cgi?id=2271784), [Red Hat 519176](https://bugzilla.redhat.com/show_bug.cgi?id=519176)

Recurring details across these:

- the adapter is fine at first and dies during audio use
- some users report needing a **full power-off**, not a reboot
- others recover with a `btusb` module reload — so severity varies by controller
- **updating `linux-firmware` resolved it for some users** — which is direct third-party
  support for [`firmware-hypothesis.md`](firmware-hypothesis.md)

## What this changes about the submission

1. **Scope.** The device ID is real and worth fixing. Separately, a failure *of this
   shape* has been reported since 2019 on other vendors' hardware — useful context for
   why the symptom deserves attention, but not evidence that those reports share a cause
   with this one. Present them as prior art for the phenotype, nothing more.
2. **Trigger.** Multiple independent reporters point at **A2DP stream state transitions**
   — pause/play, codec/mode switching. That is far more specific than "Bluetooth
   sometimes hangs", and it matches this operator's most reliable reproducer.
3. **Firmware.** Third parties resolving it via `linux-firmware` updates strengthens the
   case that firmware state is central, and that a device never receiving its patch is a
   serious matter rather than a cosmetic omission.
4. **The Windows control.** None of the reports above appear to include a same-hardware
   comparison against another OS. The operator has one, verified deliberately on
   2026-08-11: Momentum 4 on Windows 11, repeated connect/disconnect/toggle, no fault.
   That is evidence most of these threads lack.

## Caveat

These are forum posts and bug trackers, not verified reproductions. They establish that
the *symptom* is widespread and long-standing. They do **not** establish that every
instance shares one root cause. Treat as context, not proof.

---

# Second gathering, 2026-08-22 — and a verification status per entry

An external adviser was asked to research this independently, without access to this
repository, and returned a set of reports with **no domain overlap at all** with the list
above: Ask Ubuntu, Ubuntu Discourse, a Launchpad bug via mail-archive, BunsenLabs, Unix
& Linux Stack Exchange, and the Arch wiki.

⚠️ **Almost none of it could be verified from the network this was assembled on.** Every
host below except `discourse.ubuntu.com` answers **403 at the proxy gateway**:

```console
$ curl -sS -o /dev/null --max-time 15 https://askubuntu.com/questions/1527530
curl: (56) CONNECT tunnel failed, response 403
```

**And the one entry that could be checked did not match its description.** That is the
reason this section carries a status column rather than a list of links.

| status | meaning |
|---|---|
| ✅ verified | fetched and read here; the summary is what the source says |
| ⚠️ relayed | supplied by the adviser, **not reachable from here**; summary is theirs |
| ❌ corrected | fetched, and it does **not** say what it was reported to say |

## The one that was checkable

❌ **corrected** — [Ubuntu Discourse: *24.04.2 seems to have broken bluetooth device
discovery*](https://discourse.ubuntu.com/t/24-04-2-seems-to-have-broken-bluetooth-device-discovery-eek/55768)

Relayed to us as "HCI command timeout → `Resetting usb device` → xHCI resets the USB
device → more vendor/HCI command timeouts". **The thread contains no such sequence.** All
sixteen posts were read; two carry any matching signature at all, and what they show is a
**Realtek** controller:

```
Bluetooth: hci0: command 0xfc61 tx timeout
Bluetooth: hci0: RTL: Failed to generate devcoredump
Bluetooth: hci0: RTL: RTL: Read reg16 failed (-110)
```

Its actual value is different and smaller: the reporter's symptom is **discovery finding
nothing while every diagnostic says the adapter is healthy**, and an older kernel did not
fix it. It also carries `unexpected event for opcode`, which is a signature this project
counts in its own tooling. Worth keeping as a *different* shape, not as a match.

**The general lesson, recorded because it will recur:** research relayed from a system
that cannot be asked to show its working needs the same treatment as any other claim
here — it ships with the command that produced it, or it ships marked as unverified.

## Relayed, unverified — grouped by what they would be worth

⚠️ Every entry in this subsection is **the adviser's summary**, not ours.

**A. "No default controller available" — the operator's own scenario 1.**
Bluetooth is toggled off and will not come back; `bluetoothctl` reports no controller
while `bluetoothd` is running normally. Reported on 20.04 and 22.04. *If verified this is
the most valuable group in the batch*, because it is the reproducer the operator hits
most often and the one this record has the least captured evidence for.

**B. HCI Reset failing at power-on.** `Bluetooth: hci0: Opcode 0x0c03 failed: -110` on
24.04 with the GNOME switch unable to enable Bluetooth. See the section below — this one
we can partly settle from our own logs.

**C. A regression report, April 2026** — Launchpad 2147694, Intel `8087:0037`, kernel
`6.17.0-1017-oem`: the controller initialises, then **leaves the USB bus and fails to
re-enumerate**, with BlueZ alive and controllerless; an older kernel does not show it.
*Different vendor, same shape, and framed as a regression* — which is the route this
project currently considers its only unblocked path upstream.

**D. Reboot does not recover it; power-off does.** Reports from 2017 and later, plus the
Arch wiki's own Bluetooth troubleshooting page stating that a normal reboot does not
reset the controller and power must be removed. **The wiki is the strongest citation
class in the batch** — third-party *documentation* rather than a forum thread — and it
corroborates `EX-027`/`EX-028` from outside this project.

**To verify:** all four need a network that is not this one. Any machine that can reach
`askubuntu.com`, `wiki.archlinux.org` and `bugs.launchpad.net` can settle them in
minutes, and each should then move to ✅ or ❌ above.

## `0x0c03 failed: -110` is in our own logs, and links group B to this record

Group B above is the one entry we do not have to take on trust. HCI Reset timing out is
**recorded on this machine, twice, in two separate sessions**:

```console
$ grep -rh '0x0c03 failed' evidence/sessions/*/kernel.log
Aug 13 05:14:59.836245 n kernel: Bluetooth: hci0: Opcode 0x0c03 failed: -110
Aug 13 05:15:03.228342 n kernel: Bluetooth: hci0: Opcode 0x0c03 failed: -110
Aug 22 11:19:41.798866 n kernel: Bluetooth: hci0: Opcode 0x0c03 failed: -110
Aug 22 11:20:47.718775 n kernel: Bluetooth: hci0: Opcode 0x0c03 failed: -110
```

And one of them follows an **rfkill unblock** — the operator's "I turned it off and it
would not come back", captured with dynamic debug on:

```console
$ grep -B2 -A2 '11:20:47.718775' evidence/sessions/20260822-112527-*/kernel.log
Aug 22 11:20:45.732507 n kernel: 00000000089df007 name hci0 blocked 0
Aug 22 11:20:47.718628 n kernel: hci0: end: err -110
Aug 22 11:20:47.718775 n kernel: Bluetooth: hci0: Opcode 0x0c03 failed: -110
Aug 22 11:20:47.718820 n kernel: hci0
Aug 22 11:20:47.718854 n kernel: hci0 urb 00000000272dcbee status -2 count 0
```

⚠️ Stated carefully, because the temptation here is to over-claim. What this shows is
that **the signature the public 24.04 reports quote is one this project has captured
under instrumentation** — 2.0 s from unblock to timeout, with the URB status alongside
it. It does not show that those reporters' controllers failed for our reason. It does
mean that if any of them is asked for more detail, we know exactly which lines to ask
for, and we can offer a fully instrumented instance of the same visible signature in
exchange. For a submission, that is a better position than either a lone laptop or an
unverified pile of links.
