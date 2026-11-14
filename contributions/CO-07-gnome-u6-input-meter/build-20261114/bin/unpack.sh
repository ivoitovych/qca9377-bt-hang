#!/bin/bash
T=/root/exp/agent-work/lane5-status-stable-20261114/task5
mkdir -p "$T/wp" "$T/gcc"
cp "$T/fetched/src-wireplumber"/* "$T/wp/"
cp "$T/fetched/src-gnome-control-center"/* "$T/gcc/"
docker run --rm -v "$T/wp:/w" -w /w co03-noble-build:1 dpkg-source -x --no-check wireplumber_0.4.17-1ubuntu4.1.dsc base > "$T/logs/unpack-wp.log" 2>&1
docker run --rm -v "$T/gcc:/w" -w /w co03-noble-build:1 dpkg-source -x --no-check gnome-control-center_46.7-0ubuntu0.24.04.6.dsc base > "$T/logs/unpack-gcc.log" 2>&1
tail -n 3 "$T/logs/unpack-wp.log" "$T/logs/unpack-gcc.log"
