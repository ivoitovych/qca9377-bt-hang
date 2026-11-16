#!/bin/bash
W=<work dir>
mkdir -p $W/verify/results
$W/verify/bin/vk.sh inside-4A.sh > $W/verify/results/4A.txt 2>&1
echo 4ADONE
