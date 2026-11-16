#!/bin/bash
# Inside the container: 8.19 against 8.18 (debian/patches, changelog), and whether our patches apply to 8.19.
set -u
P=/work/pkg
A=$P/x818/s; B=$P/x819/s
echo "== series diff 8.18 -> 8.19"
diff -u $A/debian/patches/series $B/debian/patches/series
echo "== files in debian/patches: added / removed / changed"
diff -rq $A/debian/patches $B/debian/patches
echo "== changelog: entries above 8.18"
awk '/^systemd \(255.4-1ubuntu8.18\)/ { exit } { print }' $B/debian/changelog
echo "== patches (8.18 and 8.19) that touch the journal sources"
for d in $A $B; do
    echo "-- $d"
    grep -l -E 'src/libsystemd/sd-journal/(journal-file\.c|journal-file\.h|sd-journal\.c|journal-internal\.h)' $d/debian/patches/*.patch 2>/dev/null
done
echo "== LP: #2088163 in either changelog"
grep -n "2088163" $A/debian/changelog $B/debian/changelog
echo "== difference of the non-debian part of the two unpacked trees"
diff -rq --exclude=debian $A $B | head
R=/repo/patches/systemd/journal-file-scaling
for v in x818 x819; do
    echo "== $v: 0001 then 0002, GNU patch, applied for real in a copy (look for fuzz / offset / FAILED)"
    rm -rf $P/t-$v; cp -a $P/$v/s $P/t-$v
    cd $P/t-$v
    patch -p1 --no-backup-if-mismatch < $R/0001-*.patch
    patch -p1 --no-backup-if-mismatch < $R/0002-*.patch
    echo "== $v: git apply --check, 0001 applied then 0002"
    rm -rf $P/g-$v; cp -a $P/$v/s $P/g-$v
    cd $P/g-$v
    git apply -p1 $R/0001-*.patch && echo "$v 0001 applies (git apply, strict)"
    git apply -p1 --check $R/0002-*.patch && echo "$v 0002 applies after 0001 (git apply, strict)"
done
