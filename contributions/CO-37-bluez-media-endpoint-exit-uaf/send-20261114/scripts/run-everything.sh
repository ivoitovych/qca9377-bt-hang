#!/bin/bash
W=/root/exp/agent-work/lane4-bluez-20261114/co37
"$W/scripts/builds.sh" || exit 1
"$W/scripts/all-runs.sh"
