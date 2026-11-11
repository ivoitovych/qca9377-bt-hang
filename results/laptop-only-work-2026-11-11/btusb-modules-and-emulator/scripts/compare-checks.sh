#!/bin/bash
# compare-checks.sh <run dir> <check name>
# The bot's own "LINE:" findings of one check on the base side and on the patched side, line numbers
# dropped, as a diff: nothing printed after "== diff" means the same findings on both sides.
set -u
d=${1:?usage}
c=${2:?usage}
f() { grep -h "LINE:" "$d/$1/$c.log" | sed -E 's/:[0-9]+:[0-9]+:/:/' | sort; }
echo "== base: $(f base | grep -c .) findings; patched: $(f patched | grep -c .) findings"
echo "== diff (< base only, > patched only)"
diff <(f base) <(f patched)
echo "== diff end"
