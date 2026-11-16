#!/bin/bash
# Inside the container (co46-build:1): the checks after the header and changelog change.
set -u
export DEBIAN_FRONTEND=noninteractive
P=/work/pkg
apt-get install -y -qq --no-install-recommends quilt devscripts patchutils diffstat > /dev/null 2>&1

echo "== 1. dpkg-source -b on the branch (fresh directory)"
rm -rf $P/srcpkg2; mkdir -p $P/srcpkg2; cd $P/srcpkg2
tar xf $P/src819/systemd_255.4.orig.tar.gz
cp $P/src819/systemd_255.4.orig.tar.gz .
mv systemd-stable-255.4 systemd-255.4
git -C $P/packaging archive HEAD debian | tar x -C systemd-255.4
cd systemd-255.4
dpkg-parsechangelog | head -3
dpkg-source -b . > $P/dpkg-source-b.log 2>&1
echo "dpkg-source -b exit status $?"
grep -v "unapplying\|applying" $P/dpkg-source-b.log
echo "patches applied by dpkg-source: $(grep -c 'info: applying' $P/dpkg-source-b.log), last two:"
grep 'info: applying' $P/dpkg-source-b.log | tail -2
cd ..
ls -la systemd_255.4-1ubuntu8.20.dsc systemd_255.4-1ubuntu8.20.debian.tar.xz
cp -a systemd_255.4-1ubuntu8.20.dsc systemd_255.4-1ubuntu8.20.debian.tar.xz $P/out/

echo "== 2. quilt push -a on a fresh 8.19 tree (pristine orig tarball + 8.19's debian/, then our patches, series and changelog from the branch)"
rm -rf $P/qt; mkdir -p $P/qt; cd $P/qt
tar xf $P/src819/systemd_255.4.orig.tar.gz
mv systemd-stable-255.4 systemd-255.4
cd systemd-255.4
tar xf $P/src819/systemd_255.4-1ubuntu8.19.debian.tar.xz
echo "patches in 8.19's series: $(grep -c . debian/patches/series)"
git -C $P/packaging archive HEAD debian/patches debian/changelog | tar x
echo "patches in the new series: $(grep -c . debian/patches/series)"
export QUILT_PATCHES=debian/patches
quilt push -a > $P/quilt-push.log 2>&1
echo "quilt push -a exit status $?"
tail -n 4 $P/quilt-push.log
echo "lines mentioning fuzz, FAILED or rejects: $(grep -c -E 'fuzz|FAILED|reject' $P/quilt-push.log)"
echo "our two patches in the quilt log:"
grep -A8 "Applying patch debian/patches/lpNNNNNNN" $P/quilt-push.log
echo "quilt applied: $(quilt applied | wc -l) of $(quilt series | wc -l)"

echo "== 3. debdiff, standard output only in the file; standard error kept apart"
cd $P/out
debdiff systemd_255.4-1ubuntu8.19.dsc systemd_255.4-1ubuntu8.20.dsc > $P/debdiff-8.19-8.20.txt 2> $P/debdiff-8.19-8.20.stderr.txt
echo "debdiff exit status $? (1 means differences found)"
wc -l $P/debdiff-8.19-8.20.txt $P/debdiff-8.19-8.20.stderr.txt
echo "--- what went to standard error:"
cat $P/debdiff-8.19-8.20.stderr.txt
echo "--- diffstat of the debdiff file"
diffstat $P/debdiff-8.19-8.20.txt
