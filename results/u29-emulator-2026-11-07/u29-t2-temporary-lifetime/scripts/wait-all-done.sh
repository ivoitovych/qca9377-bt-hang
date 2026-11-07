#!/bin/sh
# Wait (max <seconds>, default 540) until no u29t2- run container is alive.
# usage: wait-all-done.sh [seconds]
max=${1:-540}
i=0
while [ "$i" -lt "$max" ]; do
    n=$(docker ps --filter name=u29t2- --format '{{.Names}}' | grep -c .)
    [ "$n" -eq 0 ] && { echo "no u29t2- container running"; exit 0; }
    sleep 10
    i=$((i + 10))
done
echo "still running: $(docker ps --filter name=u29t2- --format '{{.Names}}' | tr '\n' ' ')"
