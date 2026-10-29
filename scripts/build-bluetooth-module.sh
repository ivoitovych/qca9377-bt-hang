#!/bin/bash
# build-bluetooth-module.sh — compile net/bluetooth from cache/linux against the
# RUNNING kernel's headers, optionally with a patch applied first. A compile
# test for a kernel patch on a machine that has headers but no full tree.
#
#   scripts/build-bluetooth-module.sh                 unpatched (control)
#   scripts/build-bluetooth-module.sh <patch-file>    patched
#   scripts/build-bluetooth-module.sh --ksrc DIR [--krel <release>] [<patch-file>]
#
# --krel builds against /lib/modules/<release>/build instead of the running kernel's
# headers (as build-btusb-module.sh does; added 2026-10-29 for the CO-02 module for
# 7.0.0-42 before that kernel boots), and the vermagic is checked against it.
#
# Writes only under tmp/bt-build/. Does NOT install or load anything: the
# resulting bluetooth.ko is left in tmp/bt-build/net/bluetooth/ for inspection.
# Loading it on this machine is a separate, deliberate step — this laptop is the
# investigation machine and also in daily use.
#
# Needs: cache/linux with net/bluetooth and include/net/bluetooth checked out
# (a sparse checkout at the tag matching `uname -r`'s upstream base), and
# /lib/modules/$(uname -r)/build.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${BT_KSRC:-$HERE/cache/linux}"   # --ksrc DIR (or BT_KSRC): another checkout
# Options as FLAGS, not an `env VAR=…` prefix: a command that starts with `env`
# does not match the granted scripts/* rule and prompts every time (2026-09-24).
if [[ "${1:-}" == "--ksrc" ]]; then SRC="${2:?--ksrc needs a directory}"; shift 2; fi
[[ "${1:-}" == "--ubuntu" ]] && { SRC="$HERE/cache/ubuntu-7.0.0-31"; shift; }
KREL="$(uname -r)"
if [[ "${1:-}" == "--krel" ]]; then KREL="${2:?--krel needs a release}"; shift 2; fi
OUT="$HERE/tmp/bt-build"
KBUILD="/lib/modules/$KREL/build"
PATCH="${1:-}"

[[ -d "$SRC/net/bluetooth" ]] || { echo "no $SRC/net/bluetooth — clone the kernel into cache/linux first" >&2; exit 2; }
[[ -d "$KBUILD" ]] || { echo "no $KBUILD — kernel headers not installed" >&2; exit 2; }
[[ -z "$PATCH" || -r "$PATCH" ]] || { echo "cannot read patch $PATCH" >&2; exit 2; }

rm -rf "$OUT"; mkdir -p "$OUT/net"
cp -r "$SRC/net/bluetooth" "$OUT/net/bluetooth"
echo "source: $(git -C "$SRC" describe --tags --always 2>/dev/null)   headers: $KBUILD"
if [[ -n "$PATCH" ]]; then
    echo "── applying $(basename "$PATCH")"
    patch -p1 -d "$OUT" < "$PATCH" || { echo "patch did not apply" >&2; exit 1; }
fi
echo "── make M=net/bluetooth"
# The tree's own include/net/bluetooth headers take precedence over the
# distribution's, so the module compiles against the source it came with.
make -C "$KBUILD" M="$OUT/net/bluetooth" KCFLAGS="-I$SRC/include" modules 2>&1 | tail -25
rc=${PIPESTATUS[0]}
echo "── result: make rc=$rc"
ls -la "$OUT/net/bluetooth/"*.ko 2>/dev/null | awk '{print "   " $5 " " $9}'
if [[ $rc -eq 0 && -f "$OUT/net/bluetooth/bluetooth.ko" ]]; then
    case "$(modinfo -F vermagic "$OUT/net/bluetooth/bluetooth.ko")" in
        "$KREL "*) echo "   ✓ vermagic matches $KREL$([[ "$KREL" == "$(uname -r)" ]] && echo ' (the running kernel)')" ;;
        *) echo "   ✗ vermagic does not match $KREL"; rc=1 ;;
    esac
fi
exit "$rc"
