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

**2026-11-26: built for 7.0.0-44 (linux-hwe-7.0 7.0.0-44.44~24.04.1, from the archive pool, with the .dsc hash checked).**
- **Source check:** all 30 net/bluetooth files differing from v7.0.14 are in Ubuntu's diff.
- **Vermagic:** `7.0.0-44-generic SMP preempt mod_unload modversions` for both.
- **Patched against control:** exactly the one line in `read_adv_features()`.
- **Patched module:** srcversion `CA64890CE90A328C6EAC1BF`, SHA-256 `63ebc957…0327e9`. Control `9FF259F9F22159F1DBD28F0`.
- **BT-1 safeguard:** the stock -44 btusb prints `FOUND 13d3:3503 x1`.
- **Next, on the operator's yes:**
  1. copy the patched `bluetooth.ko` to `/lib/modules/7.0.0-44-generic/updates/`;
  2. `depmod -a 7.0.0-44-generic`, with no reload;
  3. check `modinfo -k 7.0.0-44-generic -n bluetooth` points to `updates/`;
  4. re-check `/boot`; the operator cold-boots.

**2026-11-26, installed on the operator's yes** ("I'm okay to test and install and reboot whatever is needed now"):
- `scripts/module-updates.sh --krel 7.0.0-44-generic --module bluetooth install …/patched/src-net-bluetooth/bluetooth.ko
  --trial-open-ok`. The open trial (E3 #14, on the running -43) is not changed by a file for -44; it closes at
  shutdown as usual.
- **CRC check:** all 33 dependants of `bluetooth.ko` in -44 accept the build, 0 mismatched (btusb uses 22 symbols).
- **Next boot resolves** `/lib/modules/7.0.0-44-generic/updates/bluetooth.ko`, srcversion `CA64890CE90A328C6EAC1BF`,
  SHA-256 `63ebc957…`. The initramfs has no `bluetooth.ko`, so `updates/` + `depmod` is enough.
- **`/boot`:** -44 is the newest kernel; `vmlinuz` → -44.
- **Trial label:** the boot's trial will say `BT_BUILD=stock-fixed` (the drop-in is unchanged); this boot runs CO-38's
  `bluetooth.ko`, to be recorded with `bt-mark` after the boot.
- **Rollback:** `sudo scripts/module-updates.sh --krel 7.0.0-44-generic remove`, then a reboot; or pick 7.0.0-43 in
  GRUB's advanced options (its stock btusb has `13d3:3503`).
