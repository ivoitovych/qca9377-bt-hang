# btusb E3 kernel hook: install and rollback (operator commands; NOT run by anyone yet)

Files (paths are relative to the work directory `/root/exp/agent-work/laptop-e3-autobuild-20261111/solution`):

| file | installs to |
|---|---|
| `usr/local/sbin/btusb-e3` | `/usr/local/sbin/btusb-e3` (program and hook) |
| `usr/local/lib/btusb-e3/entry-dc16388d45ec.patch` | `/usr/local/lib/btusb-e3/entry-dc16388d45ec.patch` (the upstream diff only) |
| `etc/cron.daily/btusb-e3` | `/etc/cron.daily/btusb-e3` (daily retry, only acts when a kernel is waiting) |
| symlinks | `/etc/kernel/postinst.d/50-btusb-e3`, `/etc/kernel/header_postinst.d/50-btusb-e3`, `/etc/kernel/postrm.d/50-btusb-e3` |

## Prerequisites (check, nothing to install if all print a path)

    command -v make gcc patch gpgv modinfo modprobe depmod zstd python3 update-grub

`/usr/share/keyrings/ubuntu-archive-keyring.gpg` must exist (it does on every Ubuntu).

## Install (root)

    install -d -m 755 /usr/local/lib/btusb-e3
    install -m 755 /root/exp/agent-work/laptop-e3-autobuild-20261111/solution/usr/local/sbin/btusb-e3 /usr/local/sbin/btusb-e3
    install -m 644 /root/exp/agent-work/laptop-e3-autobuild-20261111/solution/usr/local/lib/btusb-e3/entry-dc16388d45ec.patch /usr/local/lib/btusb-e3/entry-dc16388d45ec.patch
    install -m 755 /root/exp/agent-work/laptop-e3-autobuild-20261111/solution/etc/cron.daily/btusb-e3 /etc/cron.daily/btusb-e3
    install -d -m 755 /etc/kernel/postinst.d /etc/kernel/header_postinst.d /etc/kernel/postrm.d
    ln -s /usr/local/sbin/btusb-e3 /etc/kernel/postinst.d/50-btusb-e3
    ln -s /usr/local/sbin/btusb-e3 /etc/kernel/header_postinst.d/50-btusb-e3
    ln -s /usr/local/sbin/btusb-e3 /etc/kernel/postrm.d/50-btusb-e3

Check (read-only; the running kernel is reported and not touched):

    btusb-e3 status
    btusb-e3 check 7.0.0-42-generic

Installing changes nothing about boot: the hook acts only when a kernel package is installed or removed.

## Full rollback (root)

    rm /etc/kernel/postinst.d/50-btusb-e3 /etc/kernel/header_postinst.d/50-btusb-e3 /etc/kernel/postrm.d/50-btusb-e3
    rm /etc/cron.daily/btusb-e3
    btusb-e3 unpin
    rm /usr/local/sbin/btusb-e3
    rm -r /usr/local/lib/btusb-e3

`btusb-e3 unpin` (run before deleting the program) removes `/etc/default/grub.d/90-btusb-e3-pin.cfg` and runs `update-grub`.
If the program is already gone: `rm -f /etc/default/grub.d/90-btusb-e3-pin.cfg` then `update-grub`.

Modules this tool built stay in place (they are what makes a kernel work). To remove one for a kernel, as with the
manual recipe: `scripts/module-updates.sh --krel <krel> --module btusb remove`, or `rm /lib/modules/<krel>/updates/btusb.ko`
then `depmod -a <krel>`. The record of what the tool built: `/var/lib/btusb-e3/kernels/<krel>.json`; the whole state
(`/var/lib/btusb-e3`, `/var/cache/btusb-e3`, `/var/log/btusb-e3.log`) can be deleted at any time.

Kill switch without uninstalling: `touch /etc/btusb-e3.disabled` (the hook then does nothing; `rm` it to re-enable).

## Alternative: hold the kernel (one command, no code)

    apt-mark hold linux-generic-hwe-24.04 linux-image-generic-hwe-24.04 linux-headers-generic-hwe-24.04

Release: `apt-mark unhold linux-generic-hwe-24.04 linux-image-generic-hwe-24.04 linux-headers-generic-hwe-24.04`.

Cost (inference from how the metapackages work): the machine stays on 7.0.0-42 until released; every later
kernel security fix, including the ones unattended-upgrades would install from noble-security, is not installed.
Nothing warns about it, and 7.0.0-43 (below) is in proposed already. Other packages still update.
