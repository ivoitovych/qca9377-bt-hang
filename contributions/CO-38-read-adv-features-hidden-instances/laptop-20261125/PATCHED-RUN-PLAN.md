# CO-38: the patched kernel on the laptop. Plan and state (2026-11-26)

**Goal:** run the CO-38 fix on the real QCA9377, so the patch's notes can say the bug is gone on hardware, not only
that it shows there.

**Kernel, checked 2026-11-26:**
- running `7.0.0-43.43~24.04.1` (upstream 7.0.14);
- `GRUB_DEFAULT=0` and `/boot/vmlinuz` → 7.0.0-43, with no kernel upgrade pending;
- unattended upgrades are ON, so re-check `/boot` just before the reboot. A newer kernel would boot first and the
  module would not load.

**Steps:**
1. Fetch Ubuntu's exact 7.0.0-43 kernel source (linux-hwe-7.0, `Ubuntu-hwe-7.0-7.0.0-43.43_24.04.1`) into `cache/`.
   `cache/ubuntu-7.0.0-42` exists; 7.0.0-43 does not.
2. **Control:** build `bluetooth.ko` from it, unpatched, against `/lib/modules/7.0.0-43-generic/build`
   (`scripts/build-bluetooth-module.sh --ksrc … --krel 7.0.0-43-generic`). Its srcversion must equal the running
   module's, `585A17E26A09081072E4FEC`.
3. **Patched:** the same build plus CO-38's one-line change. Record srcversion, vermagic and SHA-256.
4. **Operator's yes only:** install into `/lib/modules/7.0.0-43-generic/updates/` and run `depmod`, with no module
   reload (EX-046). Re-check `/boot`; the operator cold-boots.
5. **After the boot:**
   - check that `modinfo -n bluetooth` points to `updates/` and that the srcversion is the patched one;
   - run `co38-laptop-repro.py`; expect instance 2 in the reply;
   - mark the trial before and after (`bin/bt-mark`).
6. **Rollback:** remove the file from `updates/`, `depmod`, reboot.
7. **Then:** replace the last sentence of the patch's hardware paragraph with the result, re-run checkpatch and the
   dry run, and update the recheck document.

**State:** steps 1–3 were given to an agent on 2026-11-26. Its work area is the machine-local `co38-laptop-module`
folder. Nothing is installed yet.

**2026-11-26, after steps 1-2 (the agent stopped at the gate, as told):**
- **The source:** `cache/ubuntu-7.0.0-43` comes from the Launchpad librarian `.dsc`/`.diff.gz`, via
  `scripts/prepare-ubuntu-ksrc.sh`. The control build has vermagic OK, but srcversion `9C7EE8D0C3BC3EC8243BE14`, not
  `585A17E…`. `hardware-run-plan.md:67` already records that a self-built module never matches stock, so the
  srcversion gate is unreachable and needs replacing: diff the net/bluetooth sources against the Ubuntu diff.
- **The Ubuntu archive pool already holds 7.0.0-44:** unattended upgrades will likely install it, and GRUB 0 would
  boot it. Decide with the operator: build for -44 once it is installed, or keep -43 (hold, or pick it in GRUB).
- **Not done yet:** the patched build: `build-variant.sh patched` in the machine-local `co38-laptop-module` folder.

**2026-11-26, later: the operator installed 7.0.0-44 (not yet booted).** `/boot` and `/lib/modules/7.0.0-44-generic`
exist; GRUB 0 will boot -44. **Next:**
1. Build the control and patched `bluetooth.ko` for **7.0.0-44**, from its Ubuntu source
   (`scripts/prepare-ubuntu-ksrc.sh 7.0.0-44…`, `--krel 7.0.0-44-generic`).
2. Gate by a source comparison, not srcversion.
3. Before the reboot, check that the stock -44 btusb still has `13d3:3503` (`scripts/btusb-has-device.py`, BT-1
   safeguard).
4. On the operator's yes: install into `/lib/modules/7.0.0-44-generic/updates/`, `depmod -a 7.0.0-44-generic`, cold
   boot.

The -43 builds can stay unused. The operator is relaying the reviewers' rechecks of `2026-11-26T0100Z` (reviewer 7
unavailable).
