#!/bin/bash
# lane.sh <tree> <test source tree name> <question>...
#   co37  the two exit tests (app exit with acquired transport, bus loss), one pytest session, 10 runs
#   rel   test_a2dp_release_on_exit[app|endpoint] (SIGTERM, Release counted), 10 runs
#   co23  test_a2dp_reconfigure_during_close, 5 runs
#   file  the whole test_a2dp.py, 3 runs
W=/root/exp/agent-work/lane4-bluez-20261114/co37
S=$W/scripts/tree.sh
tree=$1
tsn=$2
shift 2
ts=$W/runs/$tsn/src
F=$ts/test/functional
for q in "$@"; do
	case "$q" in
	co37) $S run "$tree" "$tree" co37 10 "$ts" "$F/test_a2dp.py" -k "acquired_transport" ;;
	rel) $S run "$tree" "$tree" rel 10 "$ts" "$F/test_a2dp.py" -k "release_on_exit" ;;
	co23) $S run "$tree" "$tree" co23 5 "$ts" "$F/test_a2dp.py" -k "reconfigure_during_close" ;;
	file) $S run "$tree" "$tree" file 2 "$ts" "$F/test_a2dp.py" ;;
	*) echo "unknown question $q" ;;
	esac
	(( $? == 3 )) && { echo "lane $tree stopped: disk"; exit 3; }
done
echo "lane $tree done: $*"
