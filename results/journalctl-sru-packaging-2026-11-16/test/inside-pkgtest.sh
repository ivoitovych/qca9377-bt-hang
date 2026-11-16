#!/bin/bash
# Runs INSIDE a fresh ubuntu:24.04 container as root (mounts: /work = work dir, /repro = reproducer dir, read only).
#  1. the archive's systemd and systemd-journal-remote are installed (the "before" state of a user)
#  2. stock 8.18 and 8.19 journalctl are unpacked under /opt (never installed) for the byte comparison
#  3. the built debs are installed with apt over it (the upgrade test)
#  4. the unprivileged part runs as user "tester" (inside-pkgtest-user.sh)
set -u
export DEBIAN_FRONTEND=noninteractive
O=/work/pkg/out
T=/work/pkgtest
mkdir -p $T/result
exec > >(tee $T/result/pkgtest-output.txt) 2>&1

cat > /etc/apt/sources.list.d/proposed.sources <<'EOT'
Types: deb
URIs: http://archive.ubuntu.com/ubuntu
Suites: noble-proposed
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOT
cat > /etc/apt/preferences.d/proposed <<'EOT'
Package: *
Pin: release a=noble-proposed
Pin-Priority: 1
EOT
apt-get update -qq
echo "== 1. the archive's systemd, as a user has it before the update"
apt-get install -y -qq python3 systemd systemd-journal-remote > /dev/null 2>&1
dpkg-query -W -f='${binary:Package} ${Version} ${source:Package}\n' | awk '$3 == "systemd" { print $1, $2 }'
useradd -m tester

echo "== 2. stock debs, downloaded and unpacked (not installed)"
for v in 255.4-1ubuntu8.18 255.4-1ubuntu8.19; do
    short=${v##*ubuntu}
    d=/tmp/dl-$v; mkdir -p $d; (cd $d && apt-get download systemd=$v libsystemd-shared=$v systemd-journal-remote=$v > /dev/null 2>&1)
    echo "downloaded: $(ls $d | tr '\n' ' ')"
    n=/opt/stock-$short; mkdir -p $n
    for f in $d/*.deb; do dpkg-deb -x $f $n; done
    mkdir -p /opt/jc/stock-$short
    printf '#!/bin/bash\nLD_LIBRARY_PATH=%s/usr/lib/x86_64-linux-gnu/systemd:%s/usr/lib/systemd exec %s/usr/bin/journalctl "$@"\n' $n $n $n > /opt/jc/stock-$short/journalctl
    chmod +x /opt/jc/stock-$short/journalctl
    echo "stock $short: $(/opt/jc/stock-$short/journalctl --version | head -1)"
done

echo "== 3. upgrading every installed package of this source to the built debs, with apt"
list=""
for p in $(dpkg-query -W -f='${binary:Package} ${source:Package}\n' | awk '$2 == "systemd" { print $1 }'); do
    p=${p%%:*}
    f=$(ls $O/${p}_*.deb 2>/dev/null | head -1)
    [ -n "$f" ] && list="$list $f"
done
echo "built debs used:"; for f in $list; do echo "  $(basename $f)"; done
apt-get install -y $list 2>&1 | tail -n 25
echo "apt-get install exit status: ${PIPESTATUS[0]}"
dpkg-query -W -f='${binary:Package} ${Version} ${source:Package}\n' | awk '$3 == "systemd" { print $1, $2 }'
echo "installed journalctl: $(journalctl --version | head -1)"
echo "dpkg --audit: $(dpkg --audit | wc -l) lines"
mkdir -p /opt/jc/patched
printf '#!/bin/bash\nexec /usr/bin/journalctl "$@"\n' > /opt/jc/patched/journalctl
chmod +x /opt/jc/patched/journalctl

echo "== system journal state before the unprivileged part"
ls -la /var/log/journal /run/log/journal 2>&1 | head

chmod -R a+rX /opt
chown -R tester /work/pkgtest/result
runuser -u tester -- /work/pkgtest/inside-pkgtest-user.sh
