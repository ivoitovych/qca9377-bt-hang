#!/bin/bash
# Inside ubuntu:22.04 (jammy, systemd 249): journal files in the OLD format, written by 249's systemd-journal-remote.
set -u
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq systemd-journal-remote python3 > /dev/null 2>&1
R=$(ls /lib/systemd/systemd-journal-remote /usr/lib/systemd/systemd-journal-remote 2>/dev/null | head -1)
echo "writer: $(dpkg-query -W -f='${Package} ${Version}' systemd-journal-remote), $R"
D=/work/verify/data/4D
rm -rf $D/old-249; mkdir -p $D/old-249
python3 -I /work/verify/bin/make4D.py $R $D/old-249 0 12 archived
python3 -I /work/verify/bin/header-info.py $D/old-249/system[@]00000.journal $D/old-249/system[@]00011.journal
chmod -R a+r $D
