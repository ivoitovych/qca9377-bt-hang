#!/bin/sh
# CO-36 L1: build the harness against the PipeWire tree and run it.
# Runs inside the co36-pw-ci:f44 image: /src = PipeWire tree (read-only),
# /unit = this directory (read-only). Arguments go to the test program:
# -v (debug log and every frame on stderr), test IDs (default: all).
set -eu

SRC=/src
B=$SRC/build-v0-asan
OUT=/tmp/co36-unit
mkdir -p "$OUT"

# flags of backend-native.c in $B/compile_commands.json, paths made absolute
CFLAGS="-I$B/spa/plugins/bluez5 -I$SRC/spa/plugins/bluez5 -I$B -I$SRC
	-I$B/spa/include -I$SRC/spa/include -I$SRC/spa/include-private
	$(pkg-config --cflags dbus-1 libusb-1.0)
	-fsanitize=address,undefined -fno-omit-frame-pointer -D_FILE_OFFSET_BITS=64
	-Wall -Winvalid-pch -Wextra -Wpedantic -std=gnu11 -Og -g -fvisibility=hidden
	-fno-strict-aliasing -fno-strict-overflow -DSPA_AUDIO_MAX_CHANNELS=128u
	-Werror=suggest-attribute=format -Wsign-compare -Wpointer-arith -Wpointer-sign
	-Werror=format -Wno-error=format-overflow -Wformat-security -Wimplicit-fallthrough
	-Wmissing-braces -Wtype-limits -Wvariadic-macros -Wmaybe-uninitialized
	-Wno-missing-field-initializers -Wno-unused-parameter -Wno-pedantic
	-Wdeprecated-declarations -Wunused-result -Werror=return-type -Werror=float-conversion
	-D_GNU_SOURCE -DFASTPATH -Werror=implicit-function-declaration
	-Werror=incompatible-pointer-types -Werror=int-conversion -Werror=old-style-declaration
	-Werror=old-style-definition -Werror=missing-parameter-type -Werror=strict-prototypes
	-Werror=discarded-qualifiers -fPIC -pthread"

# a variant's backend-native.c, mounted at /variant, is found before the tree's
if [ -f /variant/backend-native.c ]; then
	CFLAGS="-I/variant $CFLAGS"
	echo "# file under test: $(sha256sum /variant/backend-native.c)"
else
	echo "# file under test: $(sha256sum "$SRC/spa/plugins/bluez5/backend-native.c")"
fi
echo "# compiler: $(cc --version | head -n 1)"

for f in fakes stubs test-backend-native; do
	cc $CFLAGS -c "/unit/$f.c" -o "$OUT/$f.o"
done
cc -fsanitize=address,undefined -pthread -o "$OUT/test-backend-native" \
	"$OUT/fakes.o" "$OUT/stubs.o" "$OUT/test-backend-native.o" \
	$(pkg-config --libs dbus-1 bluez) -lm

ASAN_OPTIONS=detect_leaks=1:abort_on_error=0
UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1
export ASAN_OPTIONS UBSAN_OPTIONS
exec "$OUT/test-backend-native" "$@"
