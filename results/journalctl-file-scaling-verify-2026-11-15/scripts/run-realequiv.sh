#!/bin/bash
export DKOPTS="-v /var/log/journal:/rj:ro"
$WORKDIR/bin/dk.sh inside-realequiv.sh > $WORKDIR/realequiv-results.txt 2>&1
