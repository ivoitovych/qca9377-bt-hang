#!/bin/bash
# Standalone proofs for the five gaps in the 2026-09-20 follow-up review
# (F1 passive close is not "survived", F2 zero-valued opt-in, F3 pre-existing
# file preserved and restored, F4 missing sanitiser is unpublishable, F5 abort
# keeps the directory), runnable while an open trial keeps the suite closed.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$REPO" || exit 2
P=0; F=0
ok()  { printf '  PASS  %s\n' "$1"; P=$((P+1)); }
bad() { printf '  FAIL  %s\n' "$1"; F=$((F+1)); }

echo "── F1/F2/F5 bt-trial"
TL=$(mktemp -d); mkdir -p "$TL/bin" "$TL/state" "$TL/sysfs/3-3/power" "$TL/sysfs/3-3/3-3:1.0/bluetooth/hci0" "$TL/evidence/trials"
echo 13d3 > "$TL/sysfs/3-3/idVendor"; echo 3503 > "$TL/sysfs/3-3/idProduct"; echo on > "$TL/sysfs/3-3/power/control"
printf '#!/bin/sh\necho "$*" >> %s/hciconfig-calls\n[ -e %s/dead ] && exit 1\nexit 0\n' "$TL" "$TL" > "$TL/bin/hciconfig"
printf '#!/bin/sh\nexit 3\n' > "$TL/bin/systemctl"
printf '#!/bin/sh\necho "up 1 hour"\n' > "$TL/bin/uptime"
printf '#!/bin/sh\nexit 0\n' > "$TL/bin/bt-incident"
ln -sf "$REPO/bin/bt-mark" "$TL/bin/bt-mark"; ln -sf "$REPO/tools/bt-state" "$TL/bin/bt-state"
: > "$TL/kjournal"
printf '#!/bin/sh\ncase "$*" in *"-b -1"*) exit 0 ;; *bt-health-snapshot*) exit 0 ;; *"-u bt-trace"*) exit 0 ;; *"-u bt-hang-watchdog"*) exit 0 ;; esac\n[ -e %s/journal-unreadable ] && exit 1\ncat %s/kjournal\nexit 0\n' "$TL" "$TL" > "$TL/bin/journalctl"
chmod +x "$TL/bin"/*
tl() { PATH="$TL/bin:$PATH" BT_REPO="$TL" BT_EVIDENCE_REPO="$TL" BT_STATE="$TL/state" BT_SYSFS_USB="$TL/sysfs" tools/bt-trial "$@" 2>&1; }
f() { tail -1 "$TL/evidence/trials/results.tsv" 2>/dev/null | cut -f"$1"; }
calls() { cat "$TL/hciconfig-calls" 2>/dev/null | wc -l; }
tl autostart stock >/dev/null; rm -f "$TL/hciconfig-calls"; tl autostop >/dev/null
[[ "$(f 9)" == ended_unprobed && "$(f 8)" == not_observed && $(calls) == 0 ]] && ok "F1 no timeout → ended_unprobed/not_observed, 0 commands" || bad "F1 no-timeout: $(f 8)/$(f 9) calls=$(calls)"
touch "$TL/dead"; tl autostart stock >/dev/null; rm -f "$TL/hciconfig-calls"; tl autostop >/dev/null
[[ "$(f 9)" == ended_unprobed && $(calls) == 0 ]] && ok "F1 silent dead controller → ended_unprobed, not survived" || bad "F1 dead: $(f 9) calls=$(calls)"
rm -f "$TL/dead"; touch "$TL/journal-unreadable"; tl autostart stock >/dev/null; rm -f "$TL/hciconfig-calls"; tl autostop >/dev/null
[[ "$(f 8)" == unknown && "$(f 9)" == ended_unprobed && $(calls) == 0 ]] && ok "F1 unreadable journal → unknown/ended_unprobed" || bad "F1 journal: $(f 8)/$(f 9) calls=$(calls)"
rm -f "$TL/journal-unreadable"
printf 'Bluetooth: hci0: command 0x0406 tx timeout\n' > "$TL/kjournal"; tl autostart stock >/dev/null; rm -f "$TL/hciconfig-calls"; tl autostop >/dev/null
[[ "$(f 9)" == failed && "$(f 8)" == confirmed && $(calls) == 0 ]] && ok "timeout → failed/confirmed, 0 commands" || bad "timeout: $(f 8)/$(f 9) calls=$(calls)"
: > "$TL/kjournal"; tl autostart stock >/dev/null; rm -f "$TL/hciconfig-calls"; BT_TRIAL_PROBE=0 tl autostop >/dev/null
[[ $(calls) == 0 && "$(f 9)" == ended_unprobed ]] && ok "F2 BT_TRIAL_PROBE=0 does not probe" || bad "F2: calls=$(calls) result=$(f 9)"
tl autostart stock >/dev/null; rm -f "$TL/hciconfig-calls"; BT_TRIAL_PROBE=1 tl autostop >/dev/null
[[ $(calls) -ge 1 && "$(f 9)" == survived ]] && ok "BT_TRIAL_PROBE=1 probes and may say survived" || bad "probe=1: calls=$(calls) result=$(f 9)"
tl autostart stock >/dev/null; d=$(grep '^dir=' "$TL/state/current" | cut -d= -f2-); printf 'fresh capture\n' > "$d/capture.log"
o=$(tl abort); rc=$?; kept=$(ls -d "$d".aborted-* 2>/dev/null | head -1)
(( rc == 0 )) && [[ -n "$kept" && -e "$kept/ABORTED" && -e "$kept/capture.log" && ! -e "$TL/state/current" ]] && ok "F5 abort keeps untracked evidence ($(basename "$kept"))" || bad "F5 abort: rc=$rc kept='$kept' $o"
git -C "$TL" init -q; tl autostart stock >/dev/null; d=$(grep '^dir=' "$TL/state/current" | cut -d= -f2-); printf 'tracked\n' > "$d/e.log"
git -C "$TL" -c user.name=test -c user.email=test@example.com add "$d/e.log"
o=$(tl abort --discard); rc=$?
(( rc == 1 )) && [[ "$o" == *REFUSED* && -d "$d" ]] && ok "F5 --discard refuses tracked files" || bad "F5 discard tracked: rc=$rc"
git -C "$TL" rm -q --cached "$d/e.log"; o=$(tl abort --discard); rc=$?
(( rc == 0 )) && [[ ! -d "$d" ]] && ok "F5 --discard deletes once untracked" || bad "F5 discard untracked: rc=$rc"
rm -rf "$TL"

echo "── F4 bt-incident with no sanitiser"
INCS=$(mktemp -d); mkdir -p "$INCS/repo"
BT_EVIDENCE_REPO="$INCS/repo" BT_SANITIZER=none tools/bt-incident f4-check --since '5 minutes ago' >/dev/null 2>&1; rc=$?
man=$(grep sanitised "$INCS"/repo/evidence/sessions/2*/MANIFEST.txt 2>/dev/null)
(( rc != 0 )) && [[ "$man" == "sanitised=NO-SANITISER" ]] && ok "F4 no sanitiser → rc=$rc, $man" || bad "F4: rc=$rc $man"
rm -rf "$INCS"

echo "── F3 install/uninstall pre-existing file"
SS=$(mktemp -d); mkdir -p "$SS/bin"
for s in systemctl udevadm modprobe; do printf '#!/bin/sh\nexit 0\n' > "$SS/bin/$s"; chmod +x "$SS/bin/$s"; done
SR=$(mktemp -d); mkdir -p "$SR/usr/local/bin"; printf 'original bt-mark, not ours\n' > "$SR/usr/local/bin/bt-mark"
o=$(env PATH="$SS/bin:$PATH" BT_MODE_STAMP=/nonexistent/mode BT_STATE="$SR/no-such-trial" BT_DESTDIR="$SR" ./install.sh --tools-only 2>&1); rc=$?
(( rc == 0 )) && grep -q "original bt-mark" "$SR/usr/local/bin/bt-mark.pre-qca9377-bt-hang" && ! grep -q "original bt-mark" "$SR/usr/local/bin/bt-mark" \
    && ok "F3 install keeps the original as .pre-qca9377-bt-hang (rc=$rc)" || bad "F3 install: rc=$rc $(grep -E 'not ours|OVERWRITTEN' <<<"$o")"
o=$(env PATH="$SS/bin:$PATH" BT_DESTDIR="$SR" ./uninstall.sh --apply 2>&1); rc=$?
(( rc == 0 )) && grep -q "original bt-mark" "$SR/usr/local/bin/bt-mark" && [[ ! -e "$SR/usr/local/bin/bt-mark.pre-qca9377-bt-hang" && "$o" == *"1 pre-existing file(s)"* ]] \
    && ok "F3 uninstall restores the original and says so (rc=$rc)" || bad "F3 uninstall: rc=$rc $(grep -E 'pre-existing|COMPLETE' <<<"$o" | tr '\n' ' ')"
rm -rf "$SR" "$SS"
printf '\n  %s passed, %s failed\n' "$P" "$F"; (( F == 0 ))
