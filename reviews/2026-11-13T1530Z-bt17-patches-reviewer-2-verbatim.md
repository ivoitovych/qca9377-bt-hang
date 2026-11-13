# BT-17 patches — the second outside reviewer's assessment

*Received 2026-11-13, after the CO-43 and CO-44 dossiers and before
`2026-11-13T1100Z-bt17-patches-intermediate-review.md` (the review cites `6f4204f` as the newest
commit). The text is kept as received, except for the reviewer's tooling marks, which
`scripts/review-text-clean.py` removes (tracking parameters in links, among others).*

*No finding was added or changed. What we checked on 2026-11-13, and what holds:*

- **Patch D, both concerns hold** (bluetooth-next `da3cc0258` plus the series, `btusb_main.c`).
  - A `reset_resume` callback gets no PM message, so it cannot tell a runtime resume from a
    system resume. `btusb_suspend()` does get one (`PMSG_IS_AUTO(message)`). So the narrower
    variant the review prefers can record the kind of suspend there and queue the reset only
    after a runtime suspend. The CO-43 dossier already listed this variant as "to weigh".
  - The reset is queued whatever `btusb_resume()` returns. That is true of the code; the
    message does not discuss it.
  - **`suspend_count`:** `btusb_suspend()` returns early for every interface but the first
    (`if (data->suspend_count++) return 0;`), and `btusb_resume()` returns early for every
    interface but the last.
    - So with the isochronous interface claimed, the first `btusb_reset_resume()` may do no
      resume work, while the queued reset depends only on `intf == data->intf`.
    - The queued work runs later, after both callbacks, so the order looks harmless. It is
      not tested: the emulated device has the laptop's two interfaces, but we did not check
      the callback order.
- **Patch E and B:** the review's reading matches the code and the dossier. B's own message has
  a wording error the review did not mention, already noted in the intermediate review
  document: its last line omits the `!pm_runtime_active()` half of the condition.
- **The laptop tools, both points hold** (`scripts/bt17-arm-usb-debug.sh`):
  - **The usbmon capture stops at 500 MB.** It uses ten 50 MB parts with `split`'s one-digit
    suffix and does not rotate, so a long wait could end the capture before a recurrence.
  - **`--off` does not restore the earlier state.** It writes `-p` for all of `hub.c` and
    `driver.c`. Today nothing else enables those two files (`bt-dyndbg` enables `btusb.c`,
    `hci_core.c`, `hci_sync.c` and `hci_conn.c`), so off is the previous state. A saved and
    restored state would still be the safer design.
- **The `-43` remark holds:** the port check was a dry run on `-42`'s source. No `-43` module
  was built.
- **"One commit ahead at `6f4204f`":** true when the review was written. `main` has moved on
  since (the U12 occurrence of 14:19 and its recovery, `381c50f`).
- **Terms:** "the maintainer" in the text means this project, and "you" means its operator.

---

# **Assessment of the maintainer's BT-17 work**

I've checked the actual patches, the CO-43 and CO-44 dossiers, the emulator's test matrix, and both laptop scripts in the GitHub repository.

**The work has uncovered genuine kernel-side problems beyond the original BT-17 incident.** Most importantly, the emulator appears to have reproduced the USB-core failure sequence convincingly enough to validate H1 and H2 as explanations of what the kernel *would do* when a controller fails to resume.

That does not prove why the physical QCA9377 stopped responding. The maintainer makes that distinction correctly.

## **My assessment of the patches**

| Patch                                                    | Assessment                                                                                               | Recommendation                                 |
| -------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| **CO-43 A / BT-20** — Log failed autoresume              | Small, well-supported diagnostic improvement                                                             | Ready for an independent upstream review       |
| **CO-43 B / BT-19** — Avoid blocking reset during resume | Demonstrated improvement; command recovery semantics deserve further review                              | Promising, with some remaining questions       |
| **CO-43 D / BT-18** — Recover after reset-resume         | Fixes a real emulated failure, but changes system-resume behavior for many devices                       | **Do not send this version yet**               |
| **CO-43 E / BT-23** — Fix deferred-URB race              | Strong source-level race analysis and deterministic reproduction                                         | Strong candidate for a separate upstream patch |
| **CO-43 C / BT-17** — Ryzen/QCA workaround               | Correctly scoped as a hypothesis; emulator only proves that preventing suspend avoids the injected fault | Keep RFC-only                                  |
| **CO-44 / BT-21** — Correct MGMT timeout status          | Clear API correctness fix, regression test and broad test coverage                                       | Strongest candidate for submission             |

The strongest results, in my view, are **BT-18 and BT-23**. BT-23 is a concrete locking race. BT-18 reveals a more fundamental problem: successful USB-level recovery can leave btusb in a state where Bluetooth remains unusable.

### **A useful new development in the repository**

The maintainer's reported last commit was `b85cea3`, but I checked GitHub's current `main`. It is now **one commit ahead**, at [`6f4204f`](https://github.com/ivoitovych/qca9377-bt-hang/commit/6f4204fadb2bb9adfbd5ead517541c180b81679a).

That commit documents a third occurrence of **BT-16** on 13 November, with Ubuntu `7.0.0-43` and the stock btusb driver. It involves a firmware-loading/enumeration failure, followed by the disappearance of Bluetooth.

This is separate from BT-17, but it strengthens the case for investigating the QCA controller's firmware and power sequencing, rather than assuming that the out-of-tree btusb module is responsible. The approximately five-minute power-off preceding that occurrence also shows that off-time alone is not a reliable predictor of successful firmware initialization.

## **The technical issues I would raise before submission**

### **1. Patch D needs a narrower design**

I inspected the implementation:

```
static int btusb_reset_resume(struct usb_interface *intf)
{
    struct btusb_data *data = usb_get_intfdata(intf);
    int err;

    err = btusb_resume(intf);
    if (intf == data->intf)
        usb_queue_reset_device(intf);

    return err;
}
```

There are two concerns.

**First**, the callback cannot distinguish runtime reset-resume from system reset-resume. On the system-resume path, drivers such as Realtek may already have appropriate rebinding behavior. Scheduling another reset introduces additional disconnection and re-enumeration, potentially affecting devices that never experienced BT-17.

**Second**, the queued reset is unconditional with respect to `err`. Even if `btusb_resume()` reports an error, the callback queues another reset. That may be desirable in some recovery situations, but the patch should explain and test it.

My preference is to record the type of suspend and restrict the additional reset/rebind recovery to **runtime reset-resume**, preserving the existing system-resume behavior. The multi-interface `suspend_count` ordering must also be considered.

I would ask the maintainer to prototype and test this narrower implementation before proposing it upstream.

### **2. Patch E is more important than its size suggests**

The original `submit_or_queue_tx_urb()` checks `BTUSB_SUSPENDING` under `txlock` but anchors the deferred URB after dropping the lock.

Meanwhile, `btusb_resume()` drains deferred URBs and clears `BTUSB_SUSPENDING` under that same lock.

That produces a real interleaving where a command can be queued **after the final deferred-queue drain**. It may then remain there until the next suspend/resume, potentially timing out.

Patch E puts both the decision and anchoring under `txlock`, making the critical ordering atomic.

The artificially widened race window is an appropriate deterministic test technique. The fact that the test uses a 400 ms delay does not make the underlying race artificial.

This is arguably the cleanest CO-43 patch to send independently, once the lock ordering and teardown cases receive a final review.

### **3. Patch B improves responsiveness, but not USB recovery**

The distinction is important:

- B prevents the HCI timeout handler from blocking for several seconds on a USB device that is still resuming.
- B does **not** stop USB core from attempting reset-resume.
- B does **not** prevent a genuinely unresponsive controller from disappearing.
- B may allow multiple outstanding HCI commands to time out individually, because the generic HCI timeout path restores command credit.

The maintainer acknowledges the last issue in the README.

I'd want a focused review of `hci_cmd_timeout()` and `cmd_work()` behavior when B returns early, particularly when the USB device is about to be unregistered. That is not a reason to discard B, but it is a reason not to call it finished solely on the emulator's successful runs.

### **4. CO-44 is substantially better established**

The CO-44 test directly verifies the error mapping:

Unpatched kernel

# **0x05**

Authentication Failed

New regression test fails as expected.

Patched kernel

# **0x08**

Timeout

Regression test passes.

The modified mapping has been traced to commit `161510ccf91c`. That also resolves the historical attribution question left open in my original investigation.

The test results are persuasive: 527/527 MGMT tests on the patched kernel, plus the L2CAP and SMP regressions. I also appreciate that the maintainer identified the existing fail-tolerant `Get Conn Info - Power off` test rather than silently claiming that every test checks its expected status.

I'd favor sending the kernel change and corresponding BlueZ test as separate but clearly cross-referenced submissions, after your explicit approval and final commit-message review.

## **Laptop tools**

I examined both scripts. They are not equivalent in risk.

`bt17-arm-usb-debug.sh` is appropriate for normal passive observation with no arguments. It only enables USB-core dynamic debug. Its optional `--usbmon` mode captures bus traffic and can accumulate up to 500 MB of potentially sensitive data. The capture could fill its quota before a rare recurrence, so I would improve its retention/rotation policy before leaving it running for long periods. Also, `--off` should ideally restore the previous debug settings rather than blindly disabling all matching debug sites.

`bt17-provoke.py` is a different category. It repeatedly wakes the actual controller from runtime suspend by sending HCI Read Local Name. I independently checked the v7.0 HCI socket code: normal raw HCI commands of this type enter the kernel command queue. The command itself is ordinary, but repeated runtime suspend/resume transitions deliberately exercise the suspected failure.

Given that BT-17 recovery requires a full power-off, **I would not run the provoking script on your daily-use laptop now**. The emulator has already demonstrated the kernel behavior. Deliberately causing another hardware failure adds comparatively little diagnostic value unless passive tracing has failed to establish the cause.

The passive script, after a brief review of logging scope, is the sensible first action.

## **Decisions I would make**

| Maintainer's decision                | My recommendation                                                                  |
| ------------------------------------ | ---------------------------------------------------------------------------------- |
| Send CO-43 patches 1–4               | Not as one series yet. Separate A and E; review B; redesign D                      |
| Send CO-44 kernel patch and test     | Yes, after final review and your authorization                                     |
| Run USB debug tool                   | Reasonable, passive mode first                                                     |
| Run provoking tool                   | No, not on the daily-use laptop                                                    |
| Test `power/control=on`              | Reasonable as a later, controlled A/B experiment                                   |
| Build patched `-43` btusb module     | Prepare only; no installation until D is resolved and the `-43` source is verified |
| CO-02 v2 resend                      | Separate decision; not assessed here                                               |
| CO-03 installation and archive timer | Separate operational decisions; not assessed here                                  |

One integration detail: the CO-43 patches currently target the newer upstream `btusb_main.c`, whereas Ubuntu `7.0.0-42` uses `btusb.c`. The dossier reports a successful port-check dry run for `-42`, but that is not verification of a build against the currently running `-43`. Any test module must be constructed and reviewed against the exact installed source and configuration, without relying on a filename or line-offset adjustment alone.

## **Final judgment**

The maintainer has done something valuable here: **a single physical failure has been converted into reproducible kernel-side test cases**, and the tests uncovered additional defects that can be addressed independently of the uncertain hardware root cause.

I agree with the maintainer's technical direction, but I would make one important distinction in the project's conclusions:

- **BT-17:** a real hardware failure whose precise initiating cause remains unknown.
- **BT-18, BT-19, BT-20 and BT-23:** kernel behaviors exposed by a controlled model of a failed USB resume, with independently testable fixes.
- **BT-21:** a confirmed management-status mapping defect.

That distinction protects the credibility of the upstream submissions. None of those patches needs to claim that Linux caused the QCA9377 firmware to hang.

**My priority would be CO-44 first, BT-23/E second, BT-20/A third, BT-19/B after another review, and BT-18/D only after a safer design.** Keep the Ryzen quirk as an RFC until the laptop yields stronger evidence.

And I would leave the physical controller untouched. The investigation has reached the point where more source-level work is likely to be productive, without taking additional risks with your laptop.
