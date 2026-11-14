#!/bin/bash
# wait-for.sh <file> <extended regex> <deadline seconds>: polls every 15 s until the file has a
# matching line or the deadline passes; prints the last matching lines (exit 0) or "deadline" (exit 1).
set -u
f=${1:?usage}
re=${2:?usage}
d=${3:?usage}
end=$((SECONDS + d))
while ((SECONDS < end)); do
	if grep -q -E "$re" "$f" 2>/dev/null; then
		grep -E "$re" "$f" | tail -n 5
		exit 0
	fi
	sleep 15
done
echo "deadline"
exit 1
