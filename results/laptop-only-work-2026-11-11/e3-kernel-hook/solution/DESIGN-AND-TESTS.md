# btusb E3 kernel hook: design, safe failure path, test results

Date of work: 2026-11-11. Everything below was run in Docker containers from `ubuntu:24.04` (no privileges, no devices
passed, no host changes). Evidence tags: **measured** = in a log under `logs/`; **quoted** = from a project file or a
Launchpad answer; **inferred** = reasoning, not run; **not tested** = said so.

## 1. What it is

One program, `/usr/local/sbin/btusb-e3` (Python 3 standard library plus tools every Ubuntu has: make, gcc, patch, gpgv,
kmod, zstd), linked into three kernel hook directories as `50-btusb-e3`:

| directory | runs | role |
|---|---|---|
| `/etc/kernel/postinst.d` | after a kernel image is configured (Ubuntu runs it from a dpkg trigger) | main trigger |
| `/etc/kernel/header_postinst.d` | when `linux-headers-<krel>` is configured | second chance: the headers often arrive after the image |
| `/etc/kernel/postrm.d` | after a kernel is removed | only re-evaluates the default boot entry |

plus `/etc/cron.daily/btusb-e3` (retry of a kernel that failed; does nothing otherwise).

Step by step for the kernel `<krel>` named by the hook (**measured**, scenarios S1 to S6):

1. **Retire check.** The kernel's STOCK `kernel/drivers/bluetooth/btusb.ko*` is tested with the same byte test as
   `scripts/btusb-has-device.py` (USB_DEVICE prefix 0003, vid, pid). Entry present: nothing is built; a module this tool
   placed earlier for that kernel (recorded sha256) is removed and `depmod -a <krel>` run; a module not placed by this
   tool is left alone (with a warning if it shadows stock and is unusable).
2. **Source.** Package name and version come from `dpkg-query` on `linux-modules-<krel>`. The Release file of
   `<codename>-security`, `-updates`, release, `-proposed` is fetched and checked with `gpgv` against
   `/usr/share/keyrings/ubuntu-archive-keyring.gpg`; its SHA-256 of `main/source/Sources.xz` is checked; the stanza of
   that exact package version gives the SHA-256 of the `.diff.gz` and the `.orig.tar.gz`; both are fetched and checked.
   (The project's `scripts/prepare-ubuntu-ksrc.sh` does not check the `.dsc` signature; this chain does check a signature.)
   Only `drivers/bluetooth` and `include/net/bluetooth` are extracted from the orig tarball and only those sections of the
   Ubuntu diff are applied (`patch --fuzz=0`). The orig tarball (255 MB, `sha256 c6343795...f149536`) is the same for every
   `7.0.0-N`; it is downloaded once and cached under `/var/cache/btusb-e3`.
3. **Entry.** `usr/local/lib/btusb-e3/entry-dc16388d45ec.patch` is the diff part of upstream `dc16388d45ec`, byte for byte.
   **Measured:** `git patch-id --stable` of it and of the full upstream file are both `2caa69bd1c1377d518de1e164835cc1587e8b9af`
   (`logs/patch-id.log`; the same id the project records). Applied with `--fuzz=0 --forward`; afterwards the entry must occur
   exactly once in the compiled `btusb.c`. The mail header and sign-off lines are left out of the copy.
4. **Build.** `make -C /lib/modules/<krel>/build M=<dir> KCFLAGS=-I<tree>/include modules`, the project's recipe.
5. **Verify before placing:** vermagic starts with `<krel> `; module name; entry exactly once (byte test); every symbol CRC
   against the kernel's `Module.symvers` (`modprobe --dump-modversions`); `depends` and `alias` lines equal to the stock
   module's.
6. **Place:** copy to `/lib/modules/<krel>/updates/.btusb.ko.new`, atomic rename to `btusb.ko`, `depmod -a <krel>`, then
   `modinfo -k <krel> -n btusb` must name the `updates/` file, else the file is removed again and depmod re-run.
7. **initramfs:** `50-` sorts before `initramfs-tools` and `zz-update-grub` (**measured**, `run-parts --test`, S1), so an
   initrd built in the same step already sees `updates/`. If the build happens later (header hook, cron retry) and the
   existing initrd contains btusb, `update-initramfs -u -k <krel>` is run for that kernel only.
8. **reconcile()** (always, success or failure): see section 2.

Never done, in any path: `modprobe`, `rmmod`, `insmod`, rebinding, `systemctl`, restarting anything. The running kernel
(`uname -r`) is never touched: its hook run only reports (S8a). `depmod` is always called with the target kernel name.
**Exit status:** as a hook it always exits 0, also on an internal exception (S8c) and when the state directory cannot be
created; a non-zero exit from `run-parts --exit-on-error` would stop `initramfs-tools` and `zz-update-grub` and leave the
kernel package half-configured (**inferred** from the `--exit-on-error` call seen in the linux-image postinst, S1 debug).

Locking: one `flock` on `/var/lib/btusb-e3/lock`; the whole hook has a time cap (fetch deadline 1500 s plus 900 s).

## 2. Safe failure path: which kernel boots by default, and how that undoes itself

**Rule (stateless, recomputed at every hook run):** look at all installed kernels (`/boot/vmlinuz-*` with
`/lib/modules/<k>`). A kernel "has E3" when what a boot would load has the entry: a valid `updates/btusb.ko` (vermagic and
entry checked) or a stock module with the entry. If the NEWEST installed kernel has it, there is no pin. If not, the default
boot entry is pinned to the newest installed kernel that has it.

**Mechanism:** the file `/etc/default/grub.d/90-btusb-e3-pin.cfg` with one line
`GRUB_DEFAULT="gnulinux-advanced-<uuid>>gnulinux-<krel>-advanced-<uuid>"` (submenu id and entry id taken from the existing
`/boot/grub/grub.cfg`). `/etc/default/grub` (the laptop's `GRUB_DEFAULT=0` per the project notes, **quoted**) is not edited.
`update-grub` regenerates `grub.cfg` (in the `postinst.d` run `zz-update-grub` does it after the hook; elsewhere the program
calls `update-grub` itself).

**Measured (S2, S4, S5):** grub-mkconfig 2.12 as shipped by Ubuntu "Sourcing file `/etc/default/grub.d/90-btusb-e3-pin.cfg`"
and wrote `set default="gnulinux-advanced-...>gnulinux-7.0.0-38-generic-advanced-..."`; both ids exist as menu entries in
the same `grub.cfg`. **Not tested:** that a real GRUB boots that entry (grub-probe was a fixed stub in the container, GRUB
itself was not run). The id syntax is the documented `GRUB_DEFAULT` form and the ids are copied from the generated menu
(**inferred**).

**What is recorded when a build fails** (all four of these exist after S2/S5, **measured**):
- `/var/log/btusb-e3.log`, one timestamped line per step, including `FAILED (<kind>): <reason>` and `PINNED ...`
- the same lines on stdout of the hook, so they are in apt's terminal log and unattended-upgrades' dpkg log
  (`/var/log/unattended-upgrades/unattended-upgrades-dpkg.log`, **inferred** from how it captures dpkg output) and the journal
  (`logger -t btusb-e3`)
- `/var/lib/btusb-e3/kernels/<krel>.json` (status failed / pending-headers, reason, attempts, time)
- `/var/lib/btusb-e3/STATUS`, rewritten at every run and by `btusb-e3 status`

**Undoing itself:**
- retry: `/etc/cron.daily/btusb-e3` runs `btusb-e3 retry` for every kernel recorded failed or pending-headers (skips while
  dpkg holds its lock); S3 shows the whole cycle: failed offline, then a later retry with network builds, the pin file is
  removed, `update-grub` rewrites `set default="0"`.
- the header hook completing a half-finished install (S4): image installed without headers gives `pending-headers`, a pin to
  the older kernel, apt exit 0; installing the headers builds E3, removes the pin and regenerates grub.cfg by itself.
- the stock module gaining the entry (S6: kernel 7.0.0-43) gives no pin.
- removal of the pinned kernel: `postrm.d` re-evaluates; a dangling pin is not possible because the target must be an
  installed kernel with a menu entry (**inferred** from the code, not run).
- manual: `btusb-e3 unpin` (removes the file, runs `update-grub`), or the full rollback in `INSTALL-AND-ROLLBACK.md`.

**Limits (inferred):** if no installed kernel has E3 there is nothing to pin to; the log says so. A kernel picked by hand in
GRUB's menu or by `grub-reboot` still boots without E3. If grub.cfg has no menu entry for the target kernel the pin is not
written and the log says "CANNOT PIN". Only GRUB is handled.

## 3. Test results (Docker, `ubuntu:24.04` + real kernel packages, real dpkg maintainer scripts)

Base image `e3-test-base:1` (Dockerfile in `docker/`): build tools, initramfs-tools, grub2-common, and the kernel packages
of 7.0.0-38, -42 and -43 downloaded but not installed. Scenarios chain through committed images; `run-chain.sh` runs all.
Each scenario installs the hook with the operator's install commands verbatim (`tests/lib.sh: setup_hook`). Test-harness
stand-ins (not part of the solution): `grub-probe` returns a fixed fake disk; `systemd-detect-virt` returns "not a container"
(Ubuntu's `zz-update-grub` otherwise skips containers); `BTUSB_E3_RUNNING` names a fake running kernel (7.0.0-30), because
the container shares the host's kernel `7.0.0-42-generic`; `btusb` is listed in `/etc/initramfs-tools/modules` so the initrd
carries it.

| # | scenario | result (measured) | log |
|---|---|---|---|
| S1 | first install of 7.0.0-38 by `apt-get install` | E3 built by the hook, srcversion `D1DEA96A0C95BFAB05CEE01` = the srcversion the project recorded for the laptop's -38 E3; vermagic `7.0.0-38-generic SMP preempt mod_unload modversions`; entry FOUND x1 (project script); CRCs 134 used, 0 mismatched; `modinfo -k -n btusb` = `updates/btusb.ko`; initrd btusb = the updates copy (same sha256) | `logs/s1-install-38.log` |
| S2 | 7.0.0-42 installed with no network (`--network none`) | hook logs FAILED, apt exit 0, packages `ii`, default pinned to 7.0.0-38, grub.cfg `set default` names it; offline `retry` leaves state unchanged | `logs/s2-install-42-nonet.log` |
| S3 | later `/etc/cron.daily/btusb-e3` with network | downloads diff.gz and orig (hash-checked), builds, srcversion `DDB92562D1890FC3D262993` = the laptop's loaded E3 srcversion; vermagic ok; CRCs 139/0; pin removed, `set default="0"`, initrd refreshed | `logs/s3-retry-online.log` |
| S3b | same -42 module vs the laptop-built one (`tmp/runtime-e3-7.0.0-42/btusb.ko`) | srcversion equal, vermagic equal, entry FOUND x1 both; bytes differ (1439000 vs 1439008 bytes, sha256 `c55c98e4...ec824` vs `7463a56b...750f4b`) as the tooling index warns | same |
| S4 | image installed without headers, then headers | image hook: `pending-headers`, pinned; header hook: built, `update-initramfs -u -k` run, pin removed, grub.cfg regenerated by the hook | `logs/s4-noheaders.log` |
| S5 | entry patch does not apply (patch file with changed context; stands for a table change in a future kernel) | `Hunk #1 FAILED`, recorded failed, pinned, apt exit 0; with the real patch restored `btusb-e3 run` builds and unpins | `logs/s5-patch-fails.log` |
| S6 | 7.0.0-43 (noble-proposed) | stock btusb FOUND `13d3:3503` x1 (project script on the unpacked stock module), hook builds nothing, no `updates/`, no pin; run twice more: same; synthetic retire (dummy file with matching record) removes it and runs depmod; foreign file is left alone with a WARNING | `logs/s6-present-43.log` |
| S7 | dpkg-reconfigure of the kernel and a manual second run | same sha256 and mtime before and after, "already built ... nothing to do" | `logs/s7-twice.log` |
| S8 | running-kernel guard; kill switch; internal crash; missing gcc | running kernel untouched (no `updates/`); disabled file respected; exceptions give exit 0; `build tools missing: gcc` recorded, exit 0 | `logs/s8-running-and-killswitch.log` |
| S9 | full rollback commands verbatim | pin file removed, `set default="0"`, hooks, cron script, program, patch gone; module for 38 untouched; state/cache/log left | `logs/s9-rollback.log` |

Control for the "already present" path: the project's stock-module control `0cf3:e300` is FOUND in every stock module
checked (`control FOUND` lines), and a real stock module that carries `13d3:3503` exists (-43), so the already-present path
was tested with a genuine module, not a stand-in. -38 and -42 stock: `ABSENT 13d3:3503 x0`.

**Ordering versus initramfs (measured, S1/S4):** in `postinst.d` the order is `50-btusb-e3`, `initramfs-tools`,
`xx-update-initrd-links`, `zz-update-grub`. In the real apt run the header hook ran first (during "Setting up
linux-headers"), the `postinst.d` run came later from "Processing triggers for linux-image". With btusb forced into the
initrd, the initrd of -38 held the updates module (same sha256). What the default initramfs configuration includes was not
measured here; the project notes record no Bluetooth module in the laptop's initramfs (**quoted**).

**One real finding:** the archive no longer lists the SOURCE of 7.0.0-38 in any signed index (the binary packages are
still in noble-proposed), so a fetch of -38 fails (**measured**, first S1 run, `logs-run1-superseded/`). For the tests, -38's
source tree was seeded from the project's cached diff and the orig tarball, both checked against the project's `.dsc`
(`tests/seed-tree.py`). For the laptop this means: build E3 for a new kernel while its source is current. The new kernel's
source is listed as long as that kernel is the current one (7.0.0-42 is listed now, measured).

## 3b. Is there a kernel newer than 7.0.0-42.42~24.04.1? (read-only, 2026-11-11)

Launchpad `getPublishedSources` for `linux-hwe-7.0` (answer kept in `lp-published-hwe70.json`, **quoted**):
`7.0.0-43.43~24.04.1` is **Published in noble-proposed since 2026-11-05 11:33 UTC**; not yet in noble-updates or
noble-security. `7.0.0-42.42~24.04.1` is Published in Updates (2026-10-28) and in Security (2026-11-02), the newest there.
Does -43's btusb carry 13d3:3503? **Yes, measured two ways:** (a) its diff.gz (sha256 `f377aaed...5df794`, equal to the
value in its .dsc, which was fetched from the pool) adds `{ USB_DEVICE(0x13d3, 0x3503), .driver_info = BTUSB_QCA_ROME |
BTUSB_WIDEBAND_SPEECH }` after the 0x3501 entry; (b) the stock module of the real `linux-modules-7.0.0-43-generic` package
(noble-proposed) gives `FOUND 13d3:3503 x1` with the project's `btusb-has-device.py`, srcversion
`4B2BD2C14BA4918C28E7208` (`logs/s6-present-43.log`). Consequence (inferred): when -43 reaches noble-security and is installed
by unattended upgrades, the hook finds the entry in stock and does nothing; the existing manual `updates/` modules for -38 and
-42 are not touched by it. Proposed packages can still change before release.

## 4. Not tested, or limits

- A real GRUB boot of the pinned entry; the unattended-upgrades code path (only `apt-get install` and `dpkg-reconfigure`).
- Secure Boot / module signature: the module is unsigned like the hand-built E3 modules already on the laptop. If the laptop
  ever enforces signatures this fails the same way; not checked.
- Other kernel flavours or architectures; kernels not from `linux-hwe-7.0` (the code takes the source package from
  `dpkg-query`, but only linux-hwe-7.0 was run; its diff format `1.0 orig.tar.gz + diff.gz` is assumed and checked, any other
  layout is a recorded failure).
- Source changes in a future kernel that make `btusb.c` unbuildable or the table different: covered only by the patch-fails
  and make-fails recording paths (patch tested; make failure itself not injected).
- Disk: the cache keeps the 255 MB orig tarball and the 6 MB diff per kernel (`/var/cache/btusb-e3`); `/var/lib/btusb-e3/build`
  keeps the last build tree per kernel.
- Cron: `/etc/cron.daily/btusb-e3` was run by hand, not by cron/anacron.
