#!/bin/bash
# Inside co46-build:1 (deb-src enabled): which journalctl commands do apport and sos run in noble?
set -u
export DEBIAN_FRONTEND=noninteractive
mkdir -p /work/tools && cd /work/tools
for p in apport sosreport; do
    rm -rf $p; mkdir $p; (cd $p && apt-get source --download-only $p > /dev/null 2>&1; dpkg-source -x --no-check *.dsc src > /dev/null 2>&1; ls)
    apt-cache policy $p | sed -n 1,3p
done
echo "=== apport: journalctl in the source"
grep -rn "journalctl" apport/src --include=*.py --include=*.sh | head -30
echo "=== apport: the function that collects it"
grep -n -B3 -A25 "def attach_journal_errors" apport/src/apport/hookutils.py | head -60
echo "=== sos: journal commands in the logs plugin"
grep -n "journalctl\|timeout\|journal" sosreport/src/sos/report/plugins/logs.py | head -40
echo "=== sos: default command timeout"
grep -rn "cmd_timeout\|plugin_timeout\|timeout=" sosreport/src/sos/report/__init__.py sosreport/src/sos/options.py sosreport/src/sos/report/plugins/__init__.py 2>/dev/null | head -20
echo "=== sos: other plugins that call journalctl"
grep -rln "journalctl" sosreport/src/sos/report/plugins/ | head -20
