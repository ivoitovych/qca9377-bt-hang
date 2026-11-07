#!/bin/sh
# Wait until <file> has at least <n> lines matching <pattern>, then run the
# rest of the arguments as a command. (after-count.sh, with the count
# fixed: grep -c prints 0 and exits 1 when nothing matches.)
# Usage: after-count2.sh <file> <pattern> <n> <command> [args...]
f=$1
p=$2
n=$3
shift 3
while :; do
    c=$(grep -cE "$p" "$f" 2>/dev/null)
    [ -n "$c" ] && [ "$c" -ge "$n" ] && break
    sleep 5
done
exec "$@"
