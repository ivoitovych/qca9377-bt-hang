#!/bin/bash
# Inside a fresh ubuntu:24.04 container, as root: a default noble install (the archive's systemd 255.4-1ubuntu8.18),
# the 8.20 test debs unpacked (not installed) as the "patched" journalctl, then the user part as uid 1000.
# The journal set is bind-mounted read-only at /var/log/journal/<machine id>, where a real system keeps it.
# inside-noble-root.sh SETNAME
set -u
export DEBIAN_FRONTEND=noninteractive
SET=$1
MID=6f1c2a9d4b8e4f3aa1c5d7e9b0a2c4e6
apt-get update -qq
apt-get install -y -qq systemd > /dev/null 2>&1
echo "# installed: $(dpkg-query -W -f='${Version}' systemd), journalctl $(/usr/bin/journalctl --version | head -1)"
mkdir -p /opt/p820
for f in /work/pkg/out/systemd_255.4-1ubuntu8.20_amd64.deb /work/pkg/out/libsystemd-shared_255.4-1ubuntu8.20_amd64.deb; do dpkg-deb -x $f /opt/p820; done
mkdir -p /opt/jc/patched
printf '#!/bin/bash\nLD_LIBRARY_PATH=/opt/p820/usr/lib/x86_64-linux-gnu/systemd:/opt/p820/usr/lib/systemd exec /opt/p820/usr/bin/journalctl "$@"\n' > /opt/jc/patched/journalctl
chmod +x /opt/jc/patched/journalctl
echo "# patched: $(/opt/jc/patched/journalctl --version | head -1)"
echo $MID > /etc/machine-id
usermod -a -G systemd-journal,adm ubuntu
echo "# user: $(id ubuntu)"
echo "# journal files visible: $(ls /var/log/journal/$MID | wc -l) ($(ls /var/log/journal/$MID | grep -c '^user-') user)"
echo "# /run/systemd/system exists: $([ -e /run/systemd/system ] && echo yes || echo no)"
echo "# systemctl status in this container: $(runuser -u ubuntu -- systemctl status cron.service --no-pager 2>&1 | head -2 | tr '\n' ' ')"
echo "# the boot of the newest journal files is this container's boot: $(runuser -u ubuntu -- /usr/bin/journalctl --list-boots --no-pager | tail -1 | awk '{print ($2 == "" ? "?" : "yes")}')"
chmod +x /work/bin/noble-user-part.sh
runuser -u ubuntu -- env CAP=${CAP:-600} /work/bin/noble-user-part.sh $SET
