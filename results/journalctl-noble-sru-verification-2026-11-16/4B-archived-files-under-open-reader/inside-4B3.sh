#!/bin/bash
# 4B, the api-fwd / truncate / current case: 50 runs per build, then gdb-wrapped runs that show the SIGBUS stops.
set -u
cd /work/verify/bin
gcc -O1 -o reader reader.c -lsystemd || exit 1
mkdir -p /work/pkgx/p820dbg
dpkg-deb -x /work/pkg/out/libsystemd0-dbgsym_255.4-1ubuntu8.20_amd64.ddeb /work/pkgx/p820dbg
dpkg-deb -x /work/pkg/out/libsystemd-shared-dbgsym_255.4-1ubuntu8.20_amd64.ddeb /work/pkgx/p820dbg
echo "build	reader	mode	victim	rep	K	removed	rc	entries	missing_surviving	dups	from_removed	order	messages"
for b in s819 p820; do python3 -I run4B.py $b api-fwd truncate current 50 4242; done
for b in s819 p820; do python3 -I run4B.py $b api-fwd unlink current 20 4243; done
for b in s819 p820; do GDBBT=1 python3 -I run4B.py $b api-fwd truncate current 12 4244; done
