#!/bin/bash
# Inside co46-verify:1: stock 255.4-1ubuntu8.19 (noble-proposed) and the 8.20 test debs, unpacked (never installed) under /work/pkgx.
set -u
P=/work/pkgx
rm -rf $P/s819 $P/p820 $P/dl819; mkdir -p $P/s819 $P/p820 $P/dl819
apt-get update -qq
cd $P/dl819
v=255.4-1ubuntu8.19
for pkg in systemd libsystemd-shared libsystemd0 systemd-journal-remote; do
    apt-get download $pkg=$v 2>&1 | tail -1
done
ls -la $P/dl819
sha256sum $P/dl819/*.deb > $P/dl819/SHA256
for f in $P/dl819/*.deb; do dpkg-deb -x $f $P/s819; done
for pkg in systemd libsystemd-shared libsystemd0 systemd-journal-remote; do
    dpkg-deb -x /work/pkg/out/${pkg}_255.4-1ubuntu8.20_amd64.deb $P/p820
done
for t in s819 p820; do
    printf '#!/bin/bash\nLD_LIBRARY_PATH=%s/%s/usr/lib/x86_64-linux-gnu/systemd:%s/%s/usr/lib/x86_64-linux-gnu exec %s/%s/usr/bin/journalctl "$@"\n' $P $t $P $t $P $t > $P/jc-$t
    printf '#!/bin/bash\nLD_LIBRARY_PATH=%s/%s/usr/lib/x86_64-linux-gnu/systemd:%s/%s/usr/lib/x86_64-linux-gnu exec %s/%s/usr/lib/systemd/systemd-journal-remote "$@"\n' $P $t $P $t $P $t > $P/remote-$t
    chmod +x $P/jc-$t $P/remote-$t
    echo "$t: $($P/jc-$t --version | head -1)"
done
