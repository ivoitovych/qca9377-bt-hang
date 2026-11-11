#!/bin/bash
# wait-for-file.sh <file> <ERE> <max seconds> - exits once the file has a line matching the pattern
# (prints it), or after <max seconds>.
set -u
f=${1:?usage}
pat=${2:?usage}
max=${3:?usage}
end=$(( $(date +%s) + max ))
while (( $(date +%s) < end )); do
	if grep -q -E "$pat" "$f" 2>/dev/null; then
		echo "DONE: $(grep -E "$pat" "$f" | tail -n 1)"
		exit 0
	fi
	sleep 5
done
echo "TIMEOUT after $max s waiting for: $pat"
exit 1
