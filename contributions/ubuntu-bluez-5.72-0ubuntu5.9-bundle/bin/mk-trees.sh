#!/bin/bash
# fresh, patched source trees unpacked from the two source packages (base 5.72-0ubuntu5.8, bundle 5.72-0ubuntu5.9)
B=/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle
rm -rf "$B/fresh"; mkdir -p "$B/fresh/base" "$B/fresh/bundle"
docker run --rm -v "$B:/w" -w /w/fresh/base co03-noble-build:1 dpkg-source -x --no-check /w/src/bluez_5.72-0ubuntu5.8.dsc > "$B/logs/fresh-base.log" 2>&1
docker run --rm -v "$B:/w" -w /w/fresh/bundle co03-noble-build:1 dpkg-source -x --no-check /w/srcbuild/bluez_5.72-0ubuntu5.9.dsc > "$B/logs/fresh-bundle.log" 2>&1
tail -n 2 "$B/logs/fresh-base.log" "$B/logs/fresh-bundle.log"
for v in base bundle; do
  docker run --rm -v "$B/fresh/$v/bluez-5.72:/b" -w /b co03-noble-build:1 sh -c './configure --enable-library --enable-tools --enable-experimental --enable-deprecated --disable-manpages --enable-external-ell >/dev/null 2>&1; ls config.h'
done
