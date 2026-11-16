#!/bin/bash
# Fetch the SRU policy page (the documentation site redirects with a script from /SRU/ to stable-release-updates).
W=$WORKDIR/pkg/precedent
cd $W
for u in 'https://documentation.ubuntu.com/project/SRU/stable-release-updates' 'https://documentation.ubuntu.com/project/SRU/stable-release-updates/'; do
    curl -sSL --max-time 120 -w '%{url_effective} %{http_code}\n' "$u" -o sru.html
done
python3 -I $WORKDIR/bin/html2text.py sru.html > sru.txt
wc -c sru.txt
grep -n -i -E "performance|what kind|qualif|criteria|high.impact|regression|bug fix" sru.txt | head -40
