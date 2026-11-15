#!/bin/bash
# Host side: read-only runs against the laptop's real journal (mounted read-only into the container).
export VARS="${VARS:-a b c d e f g}"
export DKOPTS="-v /var/log/journal:/rj:ro"
exec $WORKDIR/bin/dk.sh inside-real.sh
