#!/bin/sh
# Wait until <file> has at least <n> lines matching <pattern>, then run the
# rest of the arguments as a command.
# Usage: after-count.sh <file> <pattern> <n> <command> [args...]
f=$1
p=$2
n=$3
shift 3
until [ "$(grep -cE "$p" "$f" 2>/dev/null || echo 0)" -ge "$n" ]; do
    sleep 5
done
exec "$@"
