#!/bin/bash
# Deletes the copies of the laptop's archived journal files made for 4A (real12) and lists what was deleted.
D=<work dir>/verify/data/4A/real12
echo "deleting $(ls $D | wc -l) files, $(du -sh $D | cut -f1):"
ls -l $D | awk 'NR>1 {print $5, $9}'
rm -r $D
echo "exists after: $([ -e $D ] && echo yes || echo no)"
