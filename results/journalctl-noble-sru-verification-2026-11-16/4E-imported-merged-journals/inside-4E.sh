#!/bin/bash
# 4E inside co46-verify:1: imported/merged journals, stock 8.19 against the 8.20 test build.
source /work/verify/bin/cmp-lib.sh
D=/work/verify/data/4E
rm -rf $D; mkdir -p $D
python3 -I /work/verify/bin/make4E.py /work/pkgx/remote-s819 $D
chmod -R a+r $D
echo "# the earlier 'two machine IDs' fixture (make-sets.py, twomachines): header IDs and entry IDs"
python3 -I /work/pkgtest/make-sets.py /work/pkgx/remote-s819 /tmp/ts > /dev/null 2>&1
python3 - <<'EOF'
import glob, re
ids_h, ids_e = set(), set()
for p in sorted(glob.glob("/tmp/ts/twomachines/*.journal")):
    b = open(p, "rb").read(512)
    ids_h.add(b[40:56].hex())
import subprocess
out = subprocess.run(["/work/pkgx/jc-s819", "--directory=/tmp/ts/twomachines", "-o", "export", "--no-pager"], capture_output=True, text=True).stdout
ids_e = set(re.findall(r"^_MACHINE_ID=(\S+)$", out, re.M))
print(f"twomachines: {len(glob.glob('/tmp/ts/twomachines/*.journal'))} files, distinct header machine IDs {len(ids_h)}, distinct entry _MACHINE_ID {len(ids_e)}")
EOF
for fx in E1-header-same E2-header-eq-entry E3-header-unrelated E4-header-only E5-header-swapped; do
    dir=$D/$fx
    echo "# $fx: $(ls $dir | wc -l) files"
    id=$(newest_boot $dir)
    runq $fx "-o export (forward)" nonempty $dir -o export
    runq $fx "-o export -r" nonempty $dir -o export -r
    runq $fx "-o cat" nonempty $dir -o cat
    runq $fx "-o cat -r" nonempty $dir -o cat -r
    runq $fx "--list-boots" nonempty $dir --list-boots
    runq $fx "-b <newest boot id>" nonempty $dir --boot=$id
    runq $fx "-k" nonempty $dir -k
    runq $fx "-n 100" nonempty $dir -n 100
    runq $fx "--since/--until a 60 s window" nonempty $dir --since=@1700000060 --until=@1700000120
    for b in s819 p820; do
        $P/jc-$b --directory=$dir --no-pager -o cat > /tmp/o.$b 2>/dev/null
        echo "ORDER	$fx	$b	$(python3 -I /work/verify/bin/order-check.py /tmp/o.$b $D/$fx.true-order.txt)"
    done
done
