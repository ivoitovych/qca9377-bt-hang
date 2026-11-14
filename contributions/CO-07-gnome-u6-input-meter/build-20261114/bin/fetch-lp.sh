#!/bin/bash
F=/root/exp/agent-work/lane5-status-stable-20261114/task5/fetched
g() { curl -s -L -m 60 -A "qca9377-bt-hang/check" -o "$F/$1" -w "$1 %{http_code}\n" "$2"; date -u +"%FT%TZ $1" >> "$F/times.txt"; }
g lp-bug-2122640.json "https://api.launchpad.net/devel/bugs/2122640"
g lp-bug-2122640-tasks.json "https://api.launchpad.net/devel/bugs/2122640/bug_tasks"
g lp-wp-search-meter.json "https://api.launchpad.net/devel/ubuntu/+source/wireplumber?ws.op=searchTasks&search_text=level%20meter&ws.size=20"
g lp-wp-search-sound-panel.json "https://api.launchpad.net/devel/ubuntu/+source/wireplumber?ws.op=searchTasks&search_text=Sound%20panel&ws.size=20"
g lp-gcc-search-meter.json "https://api.launchpad.net/devel/ubuntu/+source/gnome-control-center?ws.op=searchTasks&search_text=input%20level%20meter&ws.size=20"
g lp-gcc-search-input-meter.json "https://api.launchpad.net/devel/ubuntu/+source/gnome-control-center?ws.op=searchTasks&search_text=microphone%20level%20bar&ws.size=20"
