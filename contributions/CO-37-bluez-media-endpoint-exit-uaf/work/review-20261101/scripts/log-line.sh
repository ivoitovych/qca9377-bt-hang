#!/bin/bash
# Append one timestamped line to progress.log.
echo "$(date '+%H:%M:%S') $*" >> /root/exp/agent-work/co23-co37-review-20261101/progress.log
