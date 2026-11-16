#!/bin/bash
# Inside the container (co46-build:1).
#  A. unpatched 8.19 built the same way: do the same two tests fail without our patches?
#  B. our packaging branch again, with the build-time tests skipped (nocheck), to obtain the debs.
set -u
P=/work/pkg
O=$P/out
export DEBIAN_FRONTEND=noninteractive

echo "== A. unpatched 255.4-1ubuntu8.19, dpkg-buildpackage -b -uc -us, tests on"
rm -rf $P/base819; mkdir -p $P/base819; cd $P/base819
cp $P/src819/systemd_255.4* .
dpkg-source -x --no-check systemd_255.4-1ubuntu8.19.dsc s > /dev/null 2>&1
cd s
apt-get build-dep -y -qq . 2>&1 | tail -2
export DEB_BUILD_OPTIONS=parallel=4
s0=$(date +%s)
nice -n 19 ionice -c 3 dpkg-buildpackage -b -uc -us > $P/build-baseline819.log 2>&1
echo "baseline 8.19: dpkg-buildpackage exit $? after $(( $(date +%s) - s0 )) s"
grep -E "^(Ok|Expected Fail|Fail|Unexpected Pass|Skipped|Timeout):" $P/build-baseline819.log
grep -E "FAIL " $P/build-baseline819.log | cut -c1-110

echo "== B. packaging branch, DEB_BUILD_OPTIONS='parallel=4 nocheck'"
rm -rf $P/build; mkdir -p $P/build; cd $P/build
tar xf $P/src819/systemd_255.4.orig.tar.gz
mv systemd-stable-255.4 systemd-255.4
git -C $P/packaging archive HEAD debian | tar x -C systemd-255.4
cd systemd-255.4
export DEB_BUILD_OPTIONS="parallel=4 nocheck"
s0=$(date +%s)
nice -n 19 ionice -c 3 dpkg-buildpackage -b -uc -us > $P/build-nocheck.log 2>&1
echo "ours (nocheck): dpkg-buildpackage exit $? after $(( $(date +%s) - s0 )) s"
tail -n 5 $P/build-nocheck.log
cp -a $P/build/*.deb $P/build/*.ddeb $P/build/*.buildinfo $P/build/*.changes $O/ 2>/dev/null
ls -la $O | head -60
