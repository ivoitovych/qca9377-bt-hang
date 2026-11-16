#!/bin/bash
# 4A, host side: independent COPIES (cp, not hard links) of a fixed set of archived journal files.
#   synth-seq     the first 30 files of the sequential synthetic set (archived, 5 files per boot)
#   synth-int3m   the 30-file part of the interleaved three-machine set (all files cover the same time range)
#   noble-mixed25 copies of the 25 newest files of the noble-default model (system and user files)
#   real12        copies of 12 archived files of the laptop's journal (never the active system.journal / user-*.journal);
#                 deleted again by cleanup-4A.sh; only counts and digests leave the machine
W=<work dir>
D=$W/verify/data/4A
rm -rf $D; mkdir -p $D/synth-seq $D/synth-int3m $D/noble-mixed25 $D/real12
for f in $(ls $W/data/synth/all/*.journal | sort | head -n 30); do cp $f $D/synth-seq/; done
for f in $(ls $W/data/inter-sets/int3m/50/*.journal | sort | head -n 30); do cp $f $D/synth-int3m/; done
for f in $W/data/noble-default/mixed-25/*.journal; do cp $f $D/noble-mixed25/; done
dir=$(ls -d /var/log/journal/*/ | head -1)
# archived files only: the names with an '@' (the active ones have none); the newest 12 by mtime that are older than a day
n=0
for f in $(ls -t "$dir"*@*.journal 2>/dev/null); do
    [ $n -ge 12 ] && break
    [ -n "$(find "$f" -mmin -1440 2>/dev/null)" ] && continue
    h1=$(sha256sum "$f" | cut -c1-64)
    cp "$f" $D/real12/real-$(printf '%02d' $n).journal
    h2=$(sha256sum $D/real12/real-$(printf '%02d' $n).journal | cut -c1-64)
    if [ "$h1" != "$h2" ]; then echo "copy $n differs from its source, dropped"; rm -f $D/real12/real-$(printf '%02d' $n).journal; continue; fi
    n=$((n + 1))
done
echo "real copies: $n"
chmod -R a+r $D
# the record of the fixture: copy names (real ones renamed) and sha256 of every copy
( cd $D; for s in synth-seq synth-int3m noble-mixed25 real12; do ( cd $s; sha256sum *.journal | sed "s#  #  $s/#" ); done ) > $D/FIXTURE-SHA256.txt
wc -l $D/FIXTURE-SHA256.txt
du -sh $D/*
