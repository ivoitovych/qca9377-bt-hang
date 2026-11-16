#!/bin/bash
# 4G: read-only fetches of public pages about journal file counts; text saved under verify/data/4G
D=<work dir>/verify/data/4G
mkdir -p $D
get() { curl -sSL --max-time 90 -A 'Mozilla/5.0 (X11; Linux x86_64)' -w '%{http_code} %{url_effective}\n' "$1" -o $D/$2.html; python3 -I <work dir>/bin/html2text.py $D/$2.html > $D/$2.txt; wc -c $D/$2.txt; }
get 'https://lists.freedesktop.org/archives/systemd-devel/2024-February/049980.html' empty-journal-files-2024
get 'https://lists.freedesktop.org/archives/systemd-devel/2025-May/051391.html' slowness-2025
get 'https://man7.org/linux/man-pages/man5/journald.conf.5.html' journald-conf-man
grep -n -i "SystemMaxFiles\|MaxFileSec\|MaxRetentionSec\|SystemMaxFileSize\|SystemMaxUse" $D/journald-conf-man.txt | head -20
