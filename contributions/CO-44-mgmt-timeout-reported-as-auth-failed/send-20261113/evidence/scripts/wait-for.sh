#!/bin/bash
# wait-for.sh <file> <grep -E pattern> [seconds, default 570]: returns when the pattern appears
# in the file (exit 0) or the time is up (exit 1).
f=$1 p=$2 t=${3:-570}
end=$((SECONDS + t))
while (( SECONDS < end )); do
	grep -q -E "$p" "$f" 2>/dev/null && { echo "found: $(grep -m1 -E "$p" "$f")"; exit 0; }
	sleep 10
done
echo "not yet ($t s)"
exit 1
