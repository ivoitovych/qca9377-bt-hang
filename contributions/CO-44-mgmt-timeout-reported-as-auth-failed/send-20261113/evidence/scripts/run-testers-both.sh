#!/bin/bash
W=/root/exp/agent-work/co44-send-20261113
$W/scripts/run-testers.sh base
$W/scripts/run-testers.sh patched
echo all-done > $W/logs/testers/ALL-DONE
