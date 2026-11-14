#!/bin/bash
# Positive controls for check-queues.sh: the same cgit subject searches with subjects that must be found.
W=/root/exp/agent-work/lane4-bluez-20261114/stable-20261114
F=$W/fetched
UA="qca9377-bt-hang/check"
ST=https://git.kernel.org/pub/scm/linux/kernel/git/stable
stamp=$(date -u '+%Y%m%dT%H%M%SZ')
exec > "$W/logs/queue-check-controls-$stamp.txt" 2>&1
echo "controls started $(date -u '+%F %T') UTC"
ctl() { # repo branch query expected-note
	curl -s -A "$UA" -o "$F/control-$stamp.html" "$ST/$1/log/?h=$2&qt=grep&q=${3// /+}"
	hits=$(grep -c "class='commit-subject'" "$F/control-$stamp.html")
	echo "$1 $2 '$3': $hits commit(s)  [$4]  ($(date -u '+%F %T') UTC)"
}
ctl linux.git linux-7.3.y "Reject mode changes on connected channels" "must be found: in v7.3.4"
ctl linux.git linux-6.6.y "Fix corrupted list in hci_chan_del" "must be found: efc30877bd4b, the backport of ab4eedb790ca"
ctl linux-stable-rc.git linux-6.6.y "Fix corrupted list in hci_chan_del" "must be found: same, in the rc history"
ctl linux-stable-rc.git linux-7.3.y "Reject mode changes on connected channels" "must be found"
echo "controls finished $(date -u '+%F %T') UTC"
