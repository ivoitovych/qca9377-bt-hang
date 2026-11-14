#!/bin/bash
T=/root/exp/agent-work/lane5-status-stable-20261114/task5
rm -rf "$T/gcc/chk"; cp -a "$T/gcc/base" "$T/gcc/chk"
{
for p in $(cat "$T/patches-gcc/series.fragment"); do
  echo "== $p"
  patch -d "$T/gcc/chk" -p1 --fuzz=0 -i "$T/patches-gcc/$p"; echo "rc=$?"
done
} > "$T/logs/gcc-apply-check.log" 2>&1
cat "$T/logs/gcc-apply-check.log"
