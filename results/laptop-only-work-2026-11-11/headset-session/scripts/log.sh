#!/bin/sh
# Append "<UTC time> <START|END> <text>" to progress.log.  Usage: log.sh START|END text...
top=/root/exp/agent-work/laptop-headset-session-20261111
kind=$1
shift
printf '%s %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$kind" "$*" >> "$top/progress.log"
