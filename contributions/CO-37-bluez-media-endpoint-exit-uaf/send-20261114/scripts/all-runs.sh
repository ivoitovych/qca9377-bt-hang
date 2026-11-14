#!/bin/bash
# After builds.sh: the test runs, one guest at a time.
W=/root/exp/agent-work/lane4-bluez-20261114/co37
L=$W/scripts/lane.sh
# series B tests (standalone test) on its own binaries, and on master's binaries
$L seriesB seriesB co37
$L master seriesB co37
# the six patches' tests: on master's binaries and on the series
$L master series co37 rel co23 file
$L series series co37 rel co23 file
echo all-runs done
