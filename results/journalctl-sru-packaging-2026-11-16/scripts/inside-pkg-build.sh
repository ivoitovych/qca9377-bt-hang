#!/bin/bash
# Inside the container (co46-build:1). Source package and binary build of the packaging branch, as the archive would.
set -u
P=/work/pkg
O=$P/out
rm -rf $O $P/build $P/srcpkg; mkdir -p $O $P/build $P/srcpkg
export DEBIAN_FRONTEND=noninteractive

echo "== 1. source package (dpkg-source -b) from the packaging branch"
cd $P/srcpkg
tar xf $P/src819/systemd_255.4.orig.tar.gz
cp $P/src819/systemd_255.4.orig.tar.gz .
mv systemd-stable-255.4 systemd-255.4
d=systemd-255.4
git -C $P/packaging archive HEAD debian | tar x -C $d
cd $d
dpkg-parsechangelog | head -4
dpkg-source -b . 2>&1 | tail -8
cd ..
ls -la *.dsc *.debian.tar.xz
cp -a systemd_255.4-1ubuntu8.20.dsc systemd_255.4-1ubuntu8.20.debian.tar.xz $O/
cp $P/src819/systemd_255.4-1ubuntu8.19.dsc $P/src819/systemd_255.4-1ubuntu8.19.debian.tar.xz $P/src819/systemd_255.4.orig.tar.gz $O/

echo "== 2. build dependencies of the new source"
cd $P/build
tar xf $P/src819/systemd_255.4.orig.tar.gz
mv systemd-stable-255.4 systemd-255.4
d=systemd-255.4
git -C $P/packaging archive HEAD debian | tar x -C $d
cd $d
apt-get build-dep -y -qq . 2>&1 | tail -3

echo "== 3. dpkg-buildpackage -b -uc -us (parallel=4, nice 19, ionice idle)"
export DEB_BUILD_OPTIONS=parallel=4
s=$(date +%s)
nice -n 19 ionice -c 3 dpkg-buildpackage -b -uc -us > $P/build.log 2>&1
rc=$?
e=$(date +%s)
echo "dpkg-buildpackage exit $rc after $((e - s)) s"
tail -n 25 $P/build.log
cp -a $P/build/*.deb $P/build/*.buildinfo $P/build/*.changes $O/ 2>/dev/null
ls -la $O
