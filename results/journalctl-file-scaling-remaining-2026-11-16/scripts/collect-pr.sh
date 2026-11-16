#!/bin/bash
# Gather the 2026-11-16 results into the worktree (host paths scrubbed, counts and times only).
W=$WORKDIR
R=$REPO
D=$R/results/journalctl-file-scaling-remaining-2026-11-16
mkdir -p $D/data $D/scripts $D/test
cd $W
for f in pr-synth-seq pr-synth-int1 pr-synth-int3m pr-synth-seq-queries pr-synth-int1-queries pr-real pr-synth-seq-full; do
    cp $f.tsv $D/data/$f.tsv
done
bin/analyse-pr.sh pr-synth-seq.tsv pr-synth-seq-full.tsv pr-synth-int1.tsv pr-synth-int3m.tsv pr-real.tsv pr-synth-seq-queries.tsv pr-synth-int1-queries.tsv > $D/data/rates-summary.txt 2>&1
python3 -I bin/summarize-pr.py pr44579 > $D/data/pr44579-digest.txt
git -C src/main show pr44579 > $D/data/pr44579-f26f6637ac-commit.diff
cp proto-g2.diff $D/data/g2-on-32d75628c4.diff
cp pkgtest/pr-correct.stdout $D/test/correctness-pass1-output.txt
cp pkgtest/pr-correct2.stdout $D/test/correctness-pass2-output.txt
cp pkgtest/pr-unit-tests.txt $D/test/unit-tests-output.txt
cp pkgtest/result-pr/seqmix-output.txt pkgtest/result-pr/live-output.txt $D/test/
for f in midread-e2 midread-p2 midread-g2 midread-e2-vs-g2.diff midread-e2-vs-p2.diff midread-rising-e2 midread-rising-p2 midread-rising-g2; do
    case $f in *.diff) cp pkgtest/result-pr/$f $D/test/$f ;; *) cp pkgtest/result-pr/$f.txt $D/test/$f.txt ;; esac
done
cp pkgtest/cmp-sets-pr.sh pkgtest/make-sets.py pkgtest/make-seqnum-set.py pkgtest/midread-test.py pkgtest/live-test.py pkgtest/inside-pr-correct.sh pkgtest/inside-pr-correct2.sh pkgtest/inside-seqmix.sh pkgtest/inside-live.sh $D/test/
cp bin/fetch-pr.sh bin/summarize-pr.py bin/inside-build-pr.sh bin/inside-build-lib.sh bin/make-interleaved-sets.py bin/inside-mkint.sh bin/measure-runs.sh bin/run-host-pr.sh bin/run-host-pr2.sh bin/run-pr-after-host.sh bin/run-correct2.sh bin/inside-tests-pr.sh bin/analyse-pr.sh bin/analyse.py bin/dk.sh bin/collect-pr.sh $D/scripts/
cd $D
sed -i 's#$WORKDIR#$WORKDIR#g; s#$REPO#$REPO#g' scripts/* test/*.sh test/*.py
sed -i 's#$WORKDIR#<work dir>#g; s#$REPO#<repo>#g' data/*.txt test/*.txt
grep -rln "agent-work" . | head
echo collected
