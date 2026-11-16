#!/bin/bash
# Run the container checks, keep their output, and copy the regenerated files into the worktree.
W=$WORKDIR
R=$REPO
D=$R/results/journalctl-sru-packaging-2026-11-16
P=$R/packaging/noble-lp-NNNNNNN
$W/bin/dk.sh inside-pkg-verify.sh > $D/data/header-and-changelog-update-checks.txt 2>&1
cp $W/pkg/debdiff-8.19-8.20.txt $P/debdiff-255.4-1ubuntu8.19-to-8.20.txt
cp $W/pkg/debdiff-8.19-8.20.stderr.txt $P/debdiff-255.4-1ubuntu8.19-to-8.20.stderr.txt
cp $W/pkg/packaging/debian/patches/lpNNNNNNN-*.patch $P/debian-patches/
cp $W/pkg/out/systemd_255.4-1ubuntu8.20.dsc $P/
cd $W/pkg/packaging
git show HEAD~1:debian/changelog > /dev/null
python3 -I $W/bin/check-hunks.py 90a78feea721d7811dbad7cf04e2c7453aff3a1c > $D/data/code-hunks-identical-check.txt 2>&1
sed -i 's#$WORKDIR#<work dir>#g' $D/data/header-and-changelog-update-checks.txt
cp $W/bin/update-packaging.py $W/bin/update-packaging.sh $W/bin/check-hunks.py $W/bin/inside-pkg-verify.sh $W/bin/run-verify.sh $D/scripts/
sed -i 's#$WORKDIR#$WORKDIR#g; s#$REPO#$REPO#g' $D/scripts/update-packaging.py $D/scripts/update-packaging.sh $D/scripts/check-hunks.py $D/scripts/inside-pkg-verify.sh $D/scripts/run-verify.sh
echo copied
