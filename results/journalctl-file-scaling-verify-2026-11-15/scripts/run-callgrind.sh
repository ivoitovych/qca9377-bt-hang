#!/bin/bash
B=$WORKDIR/bin
for v in d b e g; do
    $B/dk.sh inside-callgrind.sh $v 400 3000
done
