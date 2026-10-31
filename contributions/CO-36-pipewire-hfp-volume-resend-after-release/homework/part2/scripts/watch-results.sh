#!/bin/sh
# Emits each test outcome line and each run's final summary line of the
# given pytest stdout logs, as they appear (for a monitor).
# Usage: watch-results.sh <log>...
tail -n 0 -F "$@" 2>/dev/null | grep --line-buffered -E "PASSED|FAILED|SKIPPED|ERROR at|[0-9]+ (passed|failed)|Killed|Traceback"
