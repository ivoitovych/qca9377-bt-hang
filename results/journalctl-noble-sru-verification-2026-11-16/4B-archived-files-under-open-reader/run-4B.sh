#!/bin/bash
W=<work dir>
mkdir -p $W/verify/results
$W/verify/bin/vk.sh inside-4B.sh > $W/verify/results/4B.tsv 2> $W/verify/results/4B.err
echo 4BDONE
