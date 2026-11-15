#!/bin/bash
# inside-quick.sh V1 V2 DIR : sha of full export output of two variants
W=/work
for v in a b c d e f g h; do
    [ -f $W/bins/$v/journalctl ] && printf '#!/bin/bash\nLD_LIBRARY_PATH=%s/bins/%s exec %s/bins/%s/journalctl "$@"\n' $W $v $W $v > $W/bins/$v/jc && chmod +x $W/bins/$v/jc
done
for v in $1 $2; do
    $W/bins/$v/jc --directory=$3 --no-pager -o export ${4:-} 2>&1 | sha256sum
done
