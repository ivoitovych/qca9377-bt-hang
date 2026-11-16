#!/bin/bash
# Copy the 2026-11-16 data, analysis output, reproducer test and scripts into the results directory (host paths scrubbed).
W=$WORKDIR
D=$REPO/results/journalctl-file-scaling-host-2026-11-16
cd $W
cp results-host.tsv $D/data/host-rates-run1.tsv
cp results-host-all.tsv $D/data/host-rates-real-all-rerun.tsv
cp results-synth.tsv $D/data/container-synthetic-rates.tsv
cp results-real.tsv $D/data/container-real-rates.tsv
cp results-queries-host.tsv $D/data/queries-host-synthetic.tsv.tmp
# the first host real-query attempt failed (a listed file was rotated away) and is kept apart
cp rq-host-real-first-attempt-files-vanished.tsv $D/data/queries-host-real-first-attempt-rotated-files.tsv
cp results-queries-host.tsv $D/data/queries-host.tsv
rm -f $D/data/queries-host-synthetic.tsv.tmp
cp results-queries-container.tsv $D/data/queries-container.tsv
cp results-queries-g25.tsv $D/data/queries-g-25-files.tsv
python3 -I bin/analyse-sidebyside.py results-synth.tsv results-real.tsv results-host.tsv results-host-all.tsv > $D/data/host-vs-container.txt
python3 -I bin/analyse.py host-synth.tsv > $D/data/host-synthetic-summary.txt
python3 -I bin/analyse.py host-real.tsv > $D/data/host-real-summary.txt
python3 -I bin/analyse-queries.py results-queries-host.tsv results-queries-container.tsv > $D/data/queries-summary.txt
python3 -I bin/analyse-queries.py results-queries-g25.tsv > $D/data/queries-g-25-files-summary.txt
cp repro-test/output.txt $D/reproducer/test/output.txt
cp repro-test/output-first-run.txt $D/reproducer/test/output-first-run-snapshot-too-strict.txt
cp repro-test/Dockerfile repro-test/inside-repro-test.sh $D/reproducer/test/
cp bin/measure-runs.sh bin/query-runs.sh bin/run-host.sh bin/run-host-all.sh bin/run-queries.sh bin/run-g25.sh bin/run-rest3.sh bin/run-rest2.sh bin/run-repro-test.sh bin/dk.sh bin/analyse-queries.py bin/analyse-sidebyside.py bin/collect-host.sh $D/scripts/
cd $D/scripts
sed -i 's#$WORKDIR#$WORKDIR#g; s#$REPO#$REPO#g' *.sh *.py
cd ../reproducer/test
sed -i 's#$WORKDIR#$WORKDIR#g' *
grep -rn "agent-work\|/root/" $D | head
