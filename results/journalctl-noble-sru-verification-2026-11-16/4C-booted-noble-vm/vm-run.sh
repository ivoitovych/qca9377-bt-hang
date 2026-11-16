#!/bin/bash
# 4C, inside the noble cloud-image VM (as root, started by cloud-init). Stock 255.4-1ubuntu8.19, then the 8.20 test debs.
# Reads /mnt/data (a read-only ISO with the debs and the writer); results go to /root/results and, as a tar, to /dev/vdc.
set -u
export DEBIAN_FRONTEND=noninteractive
R=/root/results; mkdir -p $R
log() { echo "[$(date +%T)] $*" | tee -a $R/log; }
D=/mnt/data
N=${N:-24000}                      # messages per stream per phase
RATE_SLEEP=${RATE_SLEEP:-0.005}    # seconds between messages (about 200 per second per stream)

log "uname: $(uname -r); image systemd: $(dpkg-query -W -f='${Version}' systemd)"
log "cpu count $(nproc), memory $(free -m | awk '/Mem/{print $2}') MB, user ubuntu: $(id ubuntu 2>&1)"

# ---- stock 255.4-1ubuntu8.19 from noble-proposed (apt over the VM's user-mode network)
cat > /etc/apt/sources.list.d/proposed.sources <<'EOT'
Types: deb
URIs: http://archive.ubuntu.com/ubuntu
Suites: noble-proposed
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOT
printf 'Package: *\nPin: release a=noble-proposed\nPin-Priority: 1\n' > /etc/apt/preferences.d/proposed
apt-get update -qq 2>&1 | tail -2
apt-get install -y -qq -t noble-proposed --allow-downgrades systemd systemd-sysv systemd-dev libsystemd0 libsystemd-shared libudev1 udev libpam-systemd libnss-systemd systemd-resolved systemd-timesyncd systemd-journal-remote > $R/apt-stock.log 2>&1
log "after the stock install: $(dpkg-query -W -f='${Package} ${Version}\n' systemd libsystemd-shared | tr '\n' ' ')"
log "journalctl: $(journalctl --version | head -1)"
# the unpacked stock 8.19 for the comparison at the end
mkdir -p /opt/s819 && for f in $D/stock819/*.deb; do dpkg-deb -x $f /opt/s819; done

# ---- journald: small files so that it rotates often, persistent, no rate limit
mkdir -p /etc/systemd/journald.conf.d /var/log/journal
cat > /etc/systemd/journald.conf.d/50-verify.conf <<'EOT'
[Journal]
Storage=persistent
SystemMaxUse=400M
SystemMaxFileSize=1M
SystemMaxFiles=1000
RateLimitIntervalSec=0
RateLimitBurst=0
ForwardToSyslog=no
EOT
systemctl restart systemd-journald
sleep 2
log "journald running: $(systemctl is-active systemd-journald); journal dir: $(ls /var/log/journal)"

install -m 755 $D/writer.py /usr/local/bin/writer.py
loginctl enable-linger ubuntu
sleep 5
log "user manager: $(systemctl is-active user[@]1000.service)"
cp $D/analyse.py /root/analyse.py

run_phase() {
    local ph=$1
    log "=== phase $ph: $(journalctl --version | head -1)"
    local mid; mid=$(ls /var/log/journal | head -1)
    rm -f /root/follow-$ph.txt
    # the follower starts first and runs through the whole load
    journalctl -f -o cat -a --no-pager -n 0 > /root/follow-$ph.txt 2> /root/follow-$ph.err &
    local fpid=$!
    sleep 1
    systemd-run --quiet --unit=writer-sys-$ph --collect python3 -u /usr/local/bin/writer.py sys$ph $N $RATE_SLEEP
    systemd-run --user --machine=ubuntu@.host --quiet --unit=writer-usr-$ph --collect python3 -u /usr/local/bin/writer.py usr$ph $N $RATE_SLEEP || log "user-session writer failed to start"
    # rotations by hand while the writers run
    for t in 30 40 40; do sleep $t; journalctl --rotate; log "manual rotation, files now: $(ls /var/log/journal/$mid | wc -l)"; done
    while systemctl is-active --quiet writer-sys-$ph || systemctl --user --machine=ubuntu@.host is-active --quiet writer-usr-$ph; do sleep 3; done
    log "writers finished; files: $(ls /var/log/journal/$mid | wc -l) ($(ls /var/log/journal/$mid | grep -c '^user-') user)"
    journalctl --sync
    sleep 8
    kill -TERM $fpid; wait $fpid; log "follower exit status $? (143 = stopped by us)"
    journalctl -o cat -a --no-pager > /root/full-$ph.txt 2> /root/full-$ph.err
    log "full read exit status $?, $(wc -l < /root/full-$ph.txt) lines, stderr: $(head -c 200 /root/full-$ph.err)"
    python3 /root/analyse.py $ph $N /root/full-$ph.txt /root/follow-$ph.txt | tee -a $R/summary.txt
    journalctl --verify > /root/verify-$ph.txt 2>&1
    log "journalctl --verify: exit status $?, $(grep -c '^PASS' /root/verify-$ph.txt) PASS, $(grep -c '^FAIL' /root/verify-$ph.txt) FAIL"
    cp /root/verify-$ph.txt /root/full-$ph.err /root/follow-$ph.err $R/ 2>/dev/null
    journalctl -u systemd-journald --no-pager -o cat -n 40 | grep -i -E "error|fail|corrupt|rotat" | head -5 > $R/journald-msgs-$ph.txt
}

run_phase stock

# ---- the 8.20 test debs
log "=== installing the 8.20 test debs"
apt-get install -y -qq --allow-downgrades $D/test/*.deb > $R/apt-patched.log 2>&1
log "install exit status $?; now: $(dpkg-query -W -f='${Package} ${Version}\n' systemd libsystemd-shared | tr '\n' ' ')"
sleep 3
log "journald after the upgrade: $(systemctl is-active systemd-journald)"
run_phase patched

# ---- both journalctl builds on the final, static journal (journald stopped)
log "=== final comparison on the static journal"
systemctl stop systemd-journald.service systemd-journald.socket systemd-journald-dev-log.socket systemd-journald-audit.socket 2>/dev/null
mid=$(ls /var/log/journal | head -1)
J=/var/log/journal/$mid
echo "files: $(ls $J | wc -l) ($(ls $J | grep -c '^user-') user, $(ls $J | grep -c '~$') .journal~)" | tee -a $R/summary.txt
for q in "-o export" "-o export -r" "-o cat -a"; do
    a=$(journalctl --directory=$J --no-pager $q 2>/dev/null | sha256sum | cut -c1-16); ea=${PIPESTATUS[0]}
    b=$(LD_LIBRARY_PATH=/opt/s819/usr/lib/x86_64-linux-gnu/systemd /opt/s819/usr/bin/journalctl --directory=$J --no-pager $q 2>/dev/null | sha256sum | cut -c1-16); eb=${PIPESTATUS[0]}
    echo "FINAL	$q	patched $a (exit $ea)	stock $b (exit $eb)	$([ "$a" = "$b" ] && echo SAME || echo DIFFERENT)" | tee -a $R/summary.txt
done
dmesg | grep -i -E "segfault|journal" | head -5 > $R/dmesg.txt
cp /root/follow-*.txt /root/full-*.txt $R/ 2>/dev/null
tar cf /dev/vdc -C /root results
log "done"
