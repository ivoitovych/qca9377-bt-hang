#!/bin/sh
# U12 / CO-03 trigger: a playback stream to the default output starts and, <delay> ms later,
# a recorder named like Chrome's dictation stream opens.  WirePlumber 0.4.17 then switches the
# headset to Handsfree, which releases the A2DP transport while its Acquire may still be pending.
#
# Usage: u12-trigger.sh <delay-ms>      (0, 40 and 90 are the delays seen in the two real cases)
# Precondition: the headset is the default output, in A2DP, and nothing has played for 10 s.
# It plays one short sound, records for 6 s into /tmp/kit-u12.wav and then stops both.
# It does not touch any setting.  The journal line "bt-mark" it writes is the only trace it leaves.
d=${1:-0}
case "$d" in
  ''|*[!0-9]*) echo "usage: u12-trigger.sh <delay-ms, 0-999>"; exit 2;;
esac
f=/usr/share/sounds/alsa/Front_Center.wav
[ -r "$f" ] || { echo "missing $f"; exit 2; }
logger -t bt-mark -p user.notice "U12 trigger run, recorder delay ${d} ms (u12-trigger.sh)"
pw-play "$f" &
P=$!
if [ "$d" -gt 0 ]; then
  sleep "0.$(printf %03d "$d")"
fi
pw-cat --record -P '{ application.name="Google Chrome input" media.name=kit-u12 }' /tmp/kit-u12.wav &
R=$!
sleep 6
kill $R $P 2>/dev/null
wait 2>/dev/null
logger -t bt-mark -p user.notice "U12 trigger run ended (u12-trigger.sh)"
echo "done; now answer in the journal: ask after-session.py about the U12 marks"
