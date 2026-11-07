#!/bin/bash
# run-track-test.sh <outdir> — run gvfs-cdda-track-test.py for every case below against
# every backend source in src/*.c, in a throwaway ubuntu:26.04 container with the
# distribution's libcdio, libcdio-paranoia and the matching libcdio source (apt-get source).
# Output: <outdir>/results.tsv (case, source, exit code, last line) and <outdir>/run.log.
set -euo pipefail
HERE="$(dirname "$(realpath "$0")")"
OUT="$(realpath "$1")"
mkdir -p "$OUT"
docker run --rm -v "$HERE:/r:ro" -v "$OUT:/out" ubuntu:26.04 bash -c '
set -e
export DEBIAN_FRONTEND=noninteractive
sed -i "s/^Types: deb$/Types: deb deb-src/" /etc/apt/sources.list.d/ubuntu.sources
apt-get update -qq > /dev/null
apt-get install -y -qq gcc pkg-config libglib2.0-dev libcdio-dev libcdio-paranoia-dev python3 dpkg-dev > /dev/null 2>&1
mkdir /w && cd /w
apt-get source -qq libcdio > /dev/null 2>&1
LIB=$(find /w -maxdepth 1 -type d -name "libcdio-*" | head -1)
{
echo "gcc $(gcc -dumpfullversion), glib $(pkg-config --modversion glib-2.0), libcdio $(pkg-config --modversion libcdio), libcdio_paranoia $(pkg-config --modversion libcdio_paranoia), source $LIB"
printf "case\tsource\texit\toutput\n" > /out/results.tsv
while read -r label args; do
  [ -z "$label" ] && continue
  for s in /r/src/*.c; do
    set +e
    # shellcheck disable=SC2086
    res=$(python3 -I /r/gvfs-cdda-track-test.py "$s" "$LIB" $args 2>&1)
    rc=$?
    set -e
    echo "=== $label $(basename "$s" .c) exit $rc"
    echo "$res"
    printf "%s\t%s\t%s\t%s\n" "$label" "$(basename "$s" .c)" "$rc" "$(echo "$res" | tail -1)" >> /out/results.tsv
  done
done <<CASES
tracks-2-4_open-4 2 4
tracks-97-99_open-99 97 99
tracks-2-4_open-1 2 1
tracks-2-4_open-5 2 5
tracks-1-3_open-3 1 3
tracks-1-3_data-3_open-3 1 3 --data 3
tracks-1-3_data-3_open-2 1 2 --data 3
CASES
} > /out/run.log 2>&1
'
cat "$OUT/results.tsv"
