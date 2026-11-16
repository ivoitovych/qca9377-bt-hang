#!/bin/bash
# Inside the container: debdiff of the 8.19 source package against our 8.20 source package.
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq --no-install-recommends devscripts patchutils diffstat > /dev/null 2>&1
cd /work/pkg/out
debdiff systemd_255.4-1ubuntu8.19.dsc systemd_255.4-1ubuntu8.20.dsc > /work/pkg/debdiff-8.19-8.20.txt 2>&1
echo "debdiff exit $?"
wc -l /work/pkg/debdiff-8.19-8.20.txt
diffstat /work/pkg/debdiff-8.19-8.20.txt | tail -n 8
