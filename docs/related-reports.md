# Related reports — the same *phenotype* elsewhere

Prior art gathered 2026-08-11, after the operator observed the same behaviour across
multiple laptops over several years and asked how widespread it is.

**The same failure phenotype** — `hci0: command tx timeout` during A2DP activity, adapter
unusable afterwards — is reported across Qualcomm and Intel controllers, on multiple
distributions, over at least seven years.

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

On the Intel hardware, reloading `btusb` restores the adapter. On this QCA9377 it does
not: driver unbind/rebind, xHCI port power-cycle, and warm reboot were all tested and all
failed (`evidence/sessions/20260810-072445-first-real-hang/`). Only a full power-off
recovers it. The usual explanation — that only a power-off drops the M.2 rail — is an untested inference here (EX-017, EX-019).

So the *same trigger class* produces a *more severe outcome* on this device — consistent
with it running unpatched ROM firmware while the Intel part loads its firmware normally.

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
