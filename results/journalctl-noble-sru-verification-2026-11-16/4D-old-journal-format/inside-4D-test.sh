#!/bin/bash
# 4D inside co46-verify:1: files in the old format (no tail_entry_offset), stock 8.19 against the 8.20 test build.
source /work/verify/bin/cmp-lib.sh
D=/work/verify/data/4D
P=/work/pkgx
rm -rf $D/new-255 $D/mixed; mkdir -p $D/new-255 $D/mixed
python3 -I /work/verify/bin/make4D.py $P/remote-s819 $D/new-255 0 12 archived
cp $D/old-249/system[@]0000[0-5].journal $D/mixed/
python3 -I /work/verify/bin/make4D.py $P/remote-s819 $D/mixed 6 6 archived
chmod -R a+r $D
echo "# header check (header_size >= 272 means tail_entry_offset is present)"
for s in old-249 mixed new-255; do
    echo "## $s"
    python3 -I /work/verify/bin/header-info.py $D/$s/*.journal | awk '{ $1 = ""; print }' | sort | uniq -c
done
for fx in old-249 mixed new-255; do
    dir=$D/$fx
    echo "# $fx: $(ls $dir | wc -l) files"
    id=$(newest_boot $dir)
    runq $fx "-o export (forward)" nonempty $dir -o export
    runq $fx "-o export -r" nonempty $dir -o export -r
    runq $fx "--list-boots" nonempty $dir --list-boots
    runq $fx "-b <newest boot id>" nonempty $dir --boot=$id
    runq $fx "-k" nonempty $dir -k
    runq $fx "-n 100" nonempty $dir -n 100
    runq $fx "-n 100 -r" nonempty $dir -n 100 -r
done
echo "# which branch of journal_file_read_tail_timestamp() runs: gdb on the 8.20 build with its separate debug symbols (script: tail.gdb)"
rm -rf $P/p820dbg; mkdir -p $P/p820dbg
dpkg-deb -x /work/pkg/out/libsystemd-shared-dbgsym_255.4-1ubuntu8.20_amd64.ddeb $P/p820dbg
for fx in old-249 mixed new-255; do
    echo "## gdb, $fx: header_size seen at each call of journal_file_read_tail_timestamp()"
    LD_LIBRARY_PATH=$P/p820/usr/lib/x86_64-linux-gnu/systemd gdb -batch -nx -x /work/verify/bin/tail.gdb --args $P/p820/usr/bin/journalctl --directory=$D/$fx --no-pager -n 5 > /tmp/gdb.$fx 2>&1
    grep -o "hs=[0-9]* has_tail_entry_offset=[01]" /tmp/gdb.$fx | sort | uniq -c
    echo "(gdb output: $(wc -l < /tmp/gdb.$fx) lines; lines that are not hits:)"
    grep -v "^hs=" /tmp/gdb.$fx | head -6
done
