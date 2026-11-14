#!/bin/bash
# load.sh <seconds> : four busy loops at nice 10 for <seconds> (host load while a guest runs, to test whether the rare
# guest hangs depend on host load)
if [[ -z "${L7_LOWPRIO:-}" ]]; then
	export L7_LOWPRIO=1
	exec nice -n 10 ionice -c 2 -n 7 "$0" "$@"
fi
S=${1:?usage}
for i in 1 2 3 4 5 6; do
	python3 -I -c "
import time
t = time.time()
while time.time() - t < $S:
    pass
" &
done
wait
