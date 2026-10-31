#!/bin/sh
# Exit once <file> has a line matching the extended regex <pattern>.
# Usage: wait-for.sh <file> <pattern>
until grep -qE "$2" "$1" 2>/dev/null; do
    sleep 5
done
grep -E "$2" "$1" | tail -3
