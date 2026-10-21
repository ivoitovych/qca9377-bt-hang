# Review request — a Tested-by reply to the 6.6.160-rc2 stable review

**The deadline is upstream's:** responses to the release candidate are due **Thu 22 Oct 2026
07:53 UTC**. Please send comments in time for the reply to go out before then. Nothing is sent
without the project author's word.

## What we want to send, and why

Greg Kroah-Hartman posted "[PATCH 6.6 0000/1651] 6.6.160-rc2 review" to the stable list on
2026-10-20. Anyone may reply with test results and a `Tested-by`. Three of rc2's patches came
from this project's work:

| in rc2 | what | ours? |
|---|---|---|
| [`4124ec5afa39`](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git/commit/?id=4124ec5afa39726fcf689a707ec40bec3d516c14) "Bluetooth: hci_event: fix simultaneous discovery stuck in FINDING" | Jiajia Liu's `96d006ae6445` | the 6.6 backport and its request are ours (BT-9) |
| [`9e665c9f2123`](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git/commit/?id=9e665c9f21238) "Bluetooth: MGMT: Fix status of pending commands flushed on power off" | `86ef0f58bdec` | ours (BT-8) |
| [`c1d19f19c937`](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git/commit/?id=c1d19f19c9372) "Bluetooth: btusb: Add IMC Networks QCA9377 to quirks table" | Tibor Harcsa's `dc16388d45ec` | the stable request is ours (BT-1) |

The reply says what was built, what was run, and what came out, and ends with a `Tested-by`.
It is the ordinary way to help a stable review. It is short, and it creates no work for
anyone.

rc2 carries 41 Bluetooth commits, 38 of them by other authors. We ran the BlueZ CI
TestRunner suites on rc2 and on 6.6.159:
- four fixes visible: our two, plus two by Pauli Virtanen;
- no other case that ran on both kernels passes on one and not on the other;
- one l2cap case hangs identically on both.

The draft is now **version 6**, after four outside reviews and two rechecks (in `reviews/`;
how each point was handled: `log.md`). If you review now, please read version 6. It differs
from version 5 in one sentence.

## What to read

All are in the public repository `ivoitovych/qca9377-bt-hang`. The links below are relative,
so they stay at the commit you opened this file from:

1. **The draft reply:** [`drafts/reply-6.6.160-rc2.txt`](drafts/reply-6.6.160-rc2.txt)
2. **The results, with every number and command:** [`experiments/results-2026-10-21.md`](experiments/results-2026-10-21.md)
3. **The scripts that produced them:**
   - [`experiments/build-and-test.sh`](experiments/build-and-test.sh)
   - [`experiments/all-testers.sh`](experiments/all-testers.sh)
   - [`scripts/compare-tester-verdicts.py`](../../scripts/compare-tester-verdicts.py)
4. **The tests behind the two fixes:**
   - BT-9's mgmt-tester cases, which BlueZ applied on 2026-10-12, and how they force the race:
     [`patches/kernel/bt9-stable/README.md`](../../patches/kernel/bt9-stable/README.md)
   - BT-8's vhci reproducer:
     [`patches/kernel/repro-mgmt-flush-status.py`](../../patches/kernel/repro-mgmt-flush-status.py),
     and its exhibits
     [`EX-049`](../../evidence/exhibits/049-vhci-flush-patched-returns-not-powered.md)
     and [`EX-050`](../../evidence/exhibits/050-vhci-flush-stock-returns-wrong-status.md)
5. **The whole dossier:** [`contributions/CO-10-stable-6.6.160-rc2/`](.),
   with its `log.md`.
6. **The project's current state,** for context:
   - [`docs/STATUS.md`](../../docs/STATUS.md)
     (the three patches' submission rows);
   - [`BRIEF.md`](../../BRIEF.md) §0.

**Source trees:**
- linux-stable-rc `linux-6.6.y` at
  [`c578c158a368`](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git/commit/?id=c578c158a36845a2b642bd491adaa7e4a479e04f);
- BlueZ master (the testers).

The rc2 announcement:
[lore, `<20261020075535.084584701@linuxfoundation.org>`](https://lore.kernel.org/stable/20261020075535.084584701@linuxfoundation.org/).

The complete mail as it would be sent, with all headers and recipients:
[`drafts/reply-6.6.160-rc2-v6.eml`](drafts/reply-6.6.160-rc2-v6.eml).

## What we ask of you

1. **Is the reply right?**
   - Is every claim in it supported by the results file?
   - Is anything overstated? For example, "No regressions in Bluetooth" from emulator testers
     only.
   - Is anything missing that a stable maintainer would expect: the architecture, the config,
     the base?
2. **Is our homework complete?** Is there a test we can still run before the deadline that a
   careful tester would run, and that would make the reply more useful or catch a problem?
   - The laptop: Ryzen 7 5825U, 16 threads, 32 GB, NVMe; a kernel build takes about 2 minutes.
   - The tests run in QEMU/KVM.
   - The laptop's own Bluetooth cannot be used for rc2: it runs Ubuntu's kernel, and a reboot
     into rc2 is the operator's decision.
3. **The QCA9377 entry** cannot be exercised without the controller on this kernel. Leave it
   unmentioned, as the draft does, or say it was not tested?
4. **Form:** the quoted header, the length, the `Tested-by` name and address
   (`Iaroslav Voitovych <yaroslav.voytovych@gmail.com>`, as on the stable backports), the
   reply-all recipients.
5. **Anything that would make this noise rather than help.** Say so plainly.

Please answer in any form: numbered points, an edited draft, or "send as is".
