#!/bin/sh
# Build and run the CO-03 L1 harness (tests/l1/test-co03-transport.c)
# against the configured tree build/<name>, with ASan and UBSan, in
# co03-noble-build:1. Output: logs/l1-<name>.log
# Usage: run-l1.sh <name>
set -u
top=/root/exp/agent-work/co03
name=$1
docker run --rm -v "$top/build/$name:/b:ro" -v "$top/tests/l1:/t:ro" \
    -v "$top/logs:/logs" -w /tmp co03-noble-build:1 sh -c '
set -e
gcc -g -O1 -fno-omit-frame-pointer -fsanitize=address -fsanitize=undefined \
    -fno-sanitize-recover=undefined -DHAVE_CONFIG_H \
    -I/b -I/b/lib $(pkg-config --cflags glib-2.0 dbus-1) \
    -Wall -Wno-unused-function -Wno-unused-variable \
    -o /tmp/test-co03-transport /t/test-co03-transport.c \
    $(pkg-config --libs glib-2.0 dbus-1)
ASAN_OPTIONS=detect_leaks=1:abort_on_error=0:halt_on_error=1 \
UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1 \
    /tmp/test-co03-transport
echo "harness exit $?"
' > "$top/logs/l1-$name.log" 2>&1
echo "exit $?"
grep -E "^(RESULT|SUMMARY|harness exit)|ERROR: AddressSanitizer|runtime error|LeakSanitizer" "$top/logs/l1-$name.log"
