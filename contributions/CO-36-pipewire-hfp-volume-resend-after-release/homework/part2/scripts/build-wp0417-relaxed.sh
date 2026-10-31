#!/bin/sh
# T308, second attempt: the same tree and options as build-wp0417.sh, plus
# -Wno-error=incompatible-pointer-types for the wireplumber subproject only
# (the first build stopped at wp/node.c:634, pw_node_send_command() now
# taking struct pw_node *, src/pipewire/node.h:227).  A build flag, no
# source change; recorded as a deviation from CI's options.
# Usage: build-wp0417-relaxed.sh <log file>
set -eu
w=/root/exp/agent-work/co36
echo "$(date +%H:%M:%S) T308 relaxed build start" >> "$w/progress.log"
set +e
docker run --rm --name co36-wp0417-build2 \
    -v "$w/pw-wp0417:/src" \
    -v "$w/ci:/ci:ro" \
    -w /src \
    co36-pw-ci:f44 \
    /bin/sh /ci/build-only-inside.sh build-wp0417-relaxed-asan \
    -Dwireplumber:c_args=-Wno-error=incompatible-pointer-types > "$1" 2>&1
rc=$?
echo "$(date +%H:%M:%S) T308 relaxed build end rc=$rc" >> "$w/progress.log"
exit $rc
