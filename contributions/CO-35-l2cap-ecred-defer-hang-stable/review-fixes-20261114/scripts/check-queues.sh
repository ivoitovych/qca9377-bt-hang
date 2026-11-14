#!/bin/bash
# check-queues.sh  (Task 4)
# Read-only web reads: for the seven CO-22 lines (7.3 6.18 6.12 6.6 6.1 5.15 5.10) and the CO-35 lines (7.3 6.18 6.12 6.6):
#   1. kernel.org releases.json: newest release of each line;
#   2. stable-queue.git queue-<v>/ listing: is any patch of ours in it;
#   3. stable/linux.git branch linux-<v>.y: the IDs / helpers in the branch tip's files, and a subject search of its log;
#   4. stable-rc linux-<v>.y: the same subject search (rc candidates).
# Every section is stamped with the UTC time. Pages go to fetched/.
set -u
W=/root/exp/agent-work/lane4-bluez-20261114/stable-20261114
F=$W/fetched
UA="qca9377-bt-hang/check"
ST=https://git.kernel.org/pub/scm/linux/kernel/git/stable
mkdir -p "$F"
now() { date -u '+%Y-%m-%d %H:%M:%S UTC'; }
stamp=$(date -u '+%Y%m%dT%H%M%SZ')
OUT=$W/logs/queue-check-$stamp.txt
exec > "$OUT" 2>&1
echo "queue check started $(now)"
echo
echo "== 1. releases.json $(now)"
curl -s -A "$UA" -o "$F/releases-$stamp.json" https://www.kernel.org/releases.json
grep -o '"version": *"[^"]*"\|"released": *{"timestamp": *[0-9]*\|"iso8601": *"[^"]*"' "$F/releases-$stamp.json" | head -60
echo
LINES="7.3 6.18 6.12 6.6 6.1 5.15 5.10"
echo "== 2. stable-queue.git queue-<v>/ $(now)"
for v in $LINES; do
	curl -s -A "$UA" -o "$F/queue-$v-$stamp.html" "$ST/stable-queue.git/tree/queue-$v"
	t=$(now)
	n=$(grep -o -E "[a-z0-9_.-]+\.patch" "$F/queue-$v-$stamp.html" | sort -u | wc -l)
	echo "queue-$v ($t): $n patch files listed"
	grep -o -E "[a-z0-9_.-]*(asus|rome|0b05|l2cap|connection-interval|btusb)[a-z0-9_.-]*\.patch" "$F/queue-$v-$stamp.html" | sort -u | sed 's/^/    /'
done
echo
echo "== 3. stable/linux.git branch tips $(now)"
for v in $LINES; do
	tip=$(git ls-remote "$ST/linux.git" "refs/heads/linux-$v.y" | cut -c1-12)
	echo "linux-$v.y tip $tip ($(now))"
	curl -s -A "$UA" -o "$F/btusb-$v-$stamp.c" "$ST/linux.git/plain/drivers/bluetooth/btusb.c?h=linux-$v.y"
	a=$(grep -c "0x0b05, 0x1868" "$F/btusb-$v-$stamp.c")
	b=$(grep -c "0x0b05, 0x1825" "$F/btusb-$v-$stamp.c")
	sz=$(wc -c < "$F/btusb-$v-$stamp.c")
	echo "    btusb.c ($sz bytes): 0b05:1868 x$a, 0b05:1825 x$b"
	case "$v" in 7.3|6.18|6.12|6.6)
		curl -s -A "$UA" -o "$F/l2cap_core-$v-$stamp.c" "$ST/linux.git/plain/net/bluetooth/l2cap_core.c?h=linux-$v.y"
		c=$(grep -c "l2cap_chan_lock_conn" "$F/l2cap_core-$v-$stamp.c")
		d=$(grep -c "l2cap_chan_close_unlocked" "$F/l2cap_core-$v-$stamp.c")
		sz=$(wc -c < "$F/l2cap_core-$v-$stamp.c")
		echo "    l2cap_core.c ($sz bytes): l2cap_chan_lock_conn x$c, l2cap_chan_close_unlocked x$d" ;;
	esac
	for q in "add ASUS 0b05" "l2cap_chan_close_unlocked" "__l2cap_ecred_conn_rsp_defer" "LE Read Connection Interval"; do
		curl -s -A "$UA" -o "$F/log-$v-$stamp.html" "$ST/linux.git/log/?h=linux-$v.y&qt=grep&q=${q// /+}"
		hits=$(grep -c "class='commit-subject'" "$F/log-$v-$stamp.html")
		echo "    log search '$q': $hits commit(s)"
	done
done
echo
echo "== 4. stable-rc linux-<v>.y (log search) $(now)"
for v in $LINES; do
	tip=$(git ls-remote "$ST/linux-stable-rc.git" "refs/heads/linux-$v.y" | cut -c1-12)
	echo "stable-rc linux-$v.y tip $tip ($(now))"
	for q in "add+ASUS+0b05" "l2cap_chan_close_unlocked" "__l2cap_ecred_conn_rsp_defer" "LE+Read+Connection+Interval"; do
		curl -s -A "$UA" -o "$F/rclog-$v-$stamp.html" "$ST/linux-stable-rc.git/log/?h=linux-$v.y&qt=grep&q=$q"
		hits=$(grep -c "class='commit-subject'" "$F/rclog-$v-$stamp.html")
		echo "    rc log search '$q': $hits commit(s)"
	done
done
echo
echo "queue check finished $(now)"
