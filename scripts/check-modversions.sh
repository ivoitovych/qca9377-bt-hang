#!/bin/bash
# check-modversions.sh — before replacing a module through updates/: will every
# installed module that uses its exports accept it? Compares the CRC each
# installed dependant expects (modprobe --dump-modversions) with the CRC the new
# build exports (its Module.symvers). A mismatch means "disagrees about version
# of symbol" and a module that refuses to load at boot.
#
#   scripts/check-modversions.sh <Module.symvers> <installed-module>...
#
# Exit 0 when every symbol the dependants take from the new build matches.
set -uo pipefail
SV="${1:?usage: check-modversions.sh <Module.symvers> <module.ko[.zst]>...}"; shift
(( $# )) || { echo "no modules given" >&2; exit 2; }
declare -A NEW
while IFS=$'\t' read -r crc sym _rest; do NEW[$sym]=$crc; done < "$SV"
(( ${#NEW[@]} )) || { echo "no exports read from $SV" >&2; exit 2; }
echo "exports in new build: ${#NEW[@]}"
rc=0
for m in "$@"; do
	used=0 bad=0
	while IFS=$'\t' read -r crc sym; do
		[[ -n "${NEW[$sym]:-}" ]] || continue
		used=$((used + 1))
		if [[ "$((crc))" != "$((NEW[$sym]))" ]]; then
			bad=$((bad + 1)); echo "   MISMATCH $sym  expects $crc  new ${NEW[$sym]}"
		fi
	done < <(modprobe --dump-modversions "$m" 2>/dev/null)
	printf '%-60s uses %3d  mismatched %d\n' "$(basename "$m")" "$used" "$bad"
	(( bad == 0 )) || rc=1
done
(( rc == 0 )) && echo "OK — every dependant accepts the new build" || echo "DO NOT INSTALL"
exit $rc
