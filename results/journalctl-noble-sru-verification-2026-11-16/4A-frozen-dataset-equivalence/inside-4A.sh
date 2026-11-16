#!/bin/bash
# 4A inside co46-verify:1: stock 8.19 against 8.20 on frozen copies. Output: TSV lines and VERDICT lines.
source /work/verify/bin/cmp-lib.sh
D=/work/verify/data/4A
for fx in synth-seq synth-int3m noble-mixed25 real12; do
    dir=$D/$fx
    id=$(newest_boot $dir)
    unit=cron.service; ue=empty
    case $fx in noble-mixed25) ue=nonempty ;; real12) unit=systemd-logind.service; ue=nonempty ;; esac
    echo "# $fx: $(ls $dir | wc -l) files, $(du -sh $dir | cut -f1), newest boot id found: $([ -n "$id" ] && echo yes || echo NO)"
    runq $fx "-o export (forward)" nonempty $dir -o export
    runq $fx "-o export -r" nonempty $dir -o export -r
    runq $fx "--list-boots" nonempty $dir --list-boots
    runq $fx "-b <newest boot id>" nonempty $dir --boot=$id
    runq $fx "-k -b <newest boot id>" nonempty $dir -k --boot=$id
    runq $fx "-u $unit" $ue $dir -u $unit
    runq $fx "-n 100" nonempty $dir -n 100
    runq $fx "-n 100 -r" nonempty $dir -n 100 -r
    runq $fx "-o export -n 100" nonempty $dir -o export -n 100
done
