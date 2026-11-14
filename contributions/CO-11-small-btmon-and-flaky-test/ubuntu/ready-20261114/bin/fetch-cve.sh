#!/bin/bash
F=/root/exp/agent-work/lane5-status-stable-20261114/task4/fetched
g() { curl -s -L -m 60 -A "qca9377-bt-hang/check" -o "$F/$1" -w "$1 %{http_code}\n" "$2"; date -u +"%FT%TZ $1" >> "$F/times.txt"; }
g debian-tracker-cve.html "https://security-tracker.debian.org/tracker/CVE-2026-105460"
g debian-bug-1150900.html "https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1150900"
g ubuntu-cve.html "https://ubuntu.com/security/CVE-2026-105460"
g ubuntu-cve.json "https://ubuntu.com/security/cves/CVE-2026-105460.json"
g mitre-cve.json "https://cveawg.mitre.org/api/cve/CVE-2026-105460"
g nvd.json "https://services.nvd.nist.gov/rest/json/cves/2.0?cveId=CVE-2026-105460"
