#!/bin/bash
cd $WORKDIR/pkg/precedent
grep -o 'href="[^"]*"' sru.html | sort -u | grep -i -E "requirement|acceptable|reference" | head
for u in https://documentation.ubuntu.com/project/SRU/reference/requirements/ https://documentation.ubuntu.com/project/SRU/reference/ https://ubuntu.com/project/docs/SRU/reference/requirements/ https://ubuntu.com/project/docs/SRU/reference/what-is-acceptable-to-sru/; do
    code=$(curl -sSL --max-time 60 -w '%{http_code} %{url_effective}' "$u" -o req.html)
    echo "$u -> $code"
    if [ "${code%% *}" = 200 ] && grep -q -i "acceptable" req.html; then
        python3 -I $WORKDIR/bin/html2text.py req.html > req.txt
        echo "saved req.txt ($(wc -c < req.txt) bytes)"
        break
    fi
done
grep -n -i -E "performance|speed|slow" req.txt | head
