#!/bin/bash
# Inside the container (co46-build:1). Fetch 8.18 and 8.19 sources, clone the packaging repository, compare.
set -u
P=/work/pkg
mkdir -p $P/src818 $P/src819
# noble-proposed as a source of packages (this container only)
cat > /etc/apt/sources.list.d/proposed.sources <<'EOT'
Types: deb deb-src
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
apt-get update -qq 2>&1 | tail -3
echo "== available source versions"
apt-cache showsrc systemd | grep -E '^Version:' | head -8
cd $P/src818 && apt-get source --download-only systemd=255.4-1ubuntu8.18 > /dev/null 2>&1; ls $P/src818
cd $P/src819 && apt-get source --download-only systemd=255.4-1ubuntu8.19 > /dev/null 2>&1; ls $P/src819
cd $P
for v in 818 819; do
    rm -rf x$v; mkdir x$v
    (cd x$v && dpkg-source -x --no-check ../src$v/systemd_*.dsc s > /dev/null 2>&1)
done
ls $P/x818 $P/x819
if [ ! -d $P/packaging ]; then
    git clone -q --branch ubuntu-noble https://git.launchpad.net/~ubuntu-core-dev/ubuntu/+source/systemd $P/packaging 2>&1 | tail -3
fi
cd $P/packaging && git log -1 --format='head: %H %cd %s' && git branch -a | head -5 && git tag -l '*8.19*' '*8.18*' '*8.20*' | head
head -12 debian/changelog
