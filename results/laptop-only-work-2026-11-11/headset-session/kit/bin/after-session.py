#!/usr/bin/env python3
"""Read-only: turn the marks typed during the headset session into one report.

For every journal entry tagged bt-mark in the time range, print the marker and, from
the desktop user's journal, the bluetooth daemon's journal and the kernel log, only the
lines that belong to that test. A mark is typed after what you saw, so its lines are those
since the previous mark (at most --window seconds back) up to 3 seconds after it.
Device addresses are masked.  Nothing is written anywhere; no service is contacted.

  after-session.py --session                                # from the mark "SESSION start" to "SESSION end"
  after-session.py --since "2026-11-12 14:00" --until "2026-11-12 16:30"
  after-session.py --since ... --until ... --only U19       # one test
  after-session.py --list-marks --since ... --until ...

Test mode (no journalctl): --marks-file FILE (lines "ISO-TIME text") and
--from-file FILE (journal text in `journalctl -o short-iso-precise` form), repeatable.
"""
import argparse
import datetime as dt
import re
import subprocess
import sys

UID = "1000"

WP_PROFILE = r"Setting profile|setting profile|Restoring profile|saved headset profile|Current profile has input route|not switching|SET_CARD_PROFILE|failed to switch codec|Found default profile"
VOL = r"RFCOMM (<<|>>) .*VG[MS]|volume changed|disabled by quirk|device quirks|hw-volume|HW volume"
METER = (r"Bluetooth device removed|CREATE_RECORD_STREAM|\]: ERROR|target not found|destroy node|"
         r"waiting reconnect|DELETE_STREAM|default audio\.source|policy-node|default target picked|link .* <-> ")
BLUEZ_A2DP = (r"a2dp_cancel|aborting setup|cancel_request|Abort|Disconnected from|connection_lost|"
              r"media_owner_(add|remove|free)|Operation canceled|cancel resume|a2dp-sink state changed|"
              r"avdtp_(start|suspend|abort)|Transaction label|session_cb|transport_a2dp|Acquire|Release")
SCO_K = r"corrupted SCO packet|SCO packet for unknown|sco_sock_connect|Bluetooth: hci0: .*(timeout|error)"
SBC = r"SelectConfiguration|SetConfiguration|sbc_xq|sbc-xq|codec:|a2dp-sink|Setting profile|setting profile"
DEFAULTS = r"default\.configured\.audio|switch-on-connect|default target picked|SET_DEFAULT_SINK|default audio\.sink"
CODEC_UI = (WP_PROFILE + r"|Selected '|moving to profile|Set profiles for|active_sink|EnumProfile|"
            r"headset-head-unit|a2dp-sink")

# first word of the marker text (upper case) -> regex of the lines that matter for it
BUNDLES = {
    "U19": METER + "|" + WP_PROFILE, "CO32": METER + "|" + WP_PROFILE,
    "CO07": METER + "|" + WP_PROFILE, "U6": METER + "|" + WP_PROFILE,
    "U15": VOL + "|" + WP_PROFILE, "U20": VOL + "|" + WP_PROFILE, "CO33": VOL + "|" + WP_PROFILE,
    "U2": VOL + "|" + WP_PROFILE,
    "U14": WP_PROFILE + "|CREATE_RECORD_STREAM|DELETE_STREAM", "CO29": WP_PROFILE + "|CREATE_RECORD_STREAM|DELETE_STREAM",
    "U12": BLUEZ_A2DP + "|" + WP_PROFILE, "CO03": BLUEZ_A2DP + "|" + WP_PROFILE,
    "U8": SCO_K + "|" + WP_PROFILE, "CO18": SCO_K + "|" + WP_PROFILE,
    "U10": SBC, "CO08": SBC,
    "U1": CODEC_UI, "U4": CODEC_UI, "U21": CODEC_UI, "CO17": CODEC_UI, "CO19": CODEC_UI,
    "CO15": DEFAULTS + "|" + WP_PROFILE, "U11": DEFAULTS + "|" + WP_PROFILE,
}
GENERIC = WP_PROFILE + "|" + BLUEZ_A2DP + "|" + SCO_K

LINE = re.compile(r"^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?[+-]\d\d:\d\d) (\S+) (.*)$")
ADDR = re.compile(r"(?<![0-9A-Fa-f])(?:[0-9A-Fa-f]{2}[:_]){5}[0-9A-Fa-f]{2}(?![0-9A-Fa-f])")
MARK = re.compile(r"(?:^|\s)bt-mark(?:\[\d+\])?: (.*)$")


def parse_time(s):
    return dt.datetime.fromisoformat(s)


def local_iso(s):
    """accept 'YYYY-MM-DD HH:MM[:SS]' as local time"""
    t = dt.datetime.fromisoformat(s)
    return t.astimezone() if t.tzinfo is None else t


def journal(args_list, since, until):
    cmd = ["journalctl", "--no-pager", "-o", "short-iso-precise",
           "--since", since.strftime("%Y-%m-%d %H:%M:%S"),
           "--until", until.strftime("%Y-%m-%d %H:%M:%S")] + args_list
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.stdout.splitlines()


def parse_lines(lines, source):
    out = []
    for raw in lines:
        m = LINE.match(raw)
        if m:
            out.append((parse_time(m.group(1)), source, m.group(3)))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--since", required=False)
    ap.add_argument("--until", required=False)
    ap.add_argument("--window", type=int, default=180,
                    help="how many seconds before a mark to look, at most (the previous mark ends it earlier)")
    ap.add_argument("--lead", type=float, default=3.0, help="seconds after a mark to include")
    ap.add_argument("--max-lines", type=int, default=60)
    ap.add_argument("--only", help="test name, e.g. U19 or CO08")
    ap.add_argument("--session", action="store_true",
                    help="use the range from the last 'SESSION start' mark to 'SESSION end' (or now)")
    ap.add_argument("--list-marks", action="store_true")
    ap.add_argument("--marks-file")
    ap.add_argument("--from-file", action="append", default=[])
    ap.add_argument("--no-mask", action="store_true")
    a = ap.parse_args()

    entries = []
    marks = []
    if a.marks_file or a.from_file:
        for f in a.from_file:
            entries += parse_lines(open(f, errors="replace").read().splitlines(), "file")
        if a.marks_file:
            for raw in open(a.marks_file):
                raw = raw.strip()
                if raw:
                    t, text = raw.split(" ", 1)
                    marks.append((parse_time(t), text))
        since = min([e[0] for e in entries] + [m[0] for m in marks])
        until = max([e[0] for e in entries] + [m[0] for m in marks])
    else:
        if a.session:
            # the last mark "SESSION start" up to the next "SESSION end" (or now)
            now = dt.datetime.now().astimezone()
            allm = []
            for t, _, msg in parse_lines(journal(["-t", "bt-mark"], now - dt.timedelta(days=3), now), "mark"):
                m = MARK.search(" " + msg)
                allm.append((t, m.group(1) if m else msg))
            starts = [t for t, x in allm if x.upper().startswith("SESSION START")]
            if not starts:
                ap.error("no 'SESSION start' mark in the last 3 days; use --since and --until")
            a.since = starts[-1].strftime("%Y-%m-%d %H:%M:%S")
            ends = [t for t, x in allm if x.upper().startswith("SESSION END") and t > starts[-1]]
            a.until = (ends[-1] if ends else now).strftime("%Y-%m-%d %H:%M:%S")
        if not (a.since and a.until):
            ap.error("--since and --until (or --session) are required")
        since, until = local_iso(a.since), local_iso(a.until)
        for t, _, msg in parse_lines(journal(["-t", "bt-mark"], since, until), "mark"):
            m = MARK.search(" " + msg)
            marks.append((t, m.group(1) if m else msg))
        if a.list_marks:
            for t, text in marks:
                print(t.strftime("%Y-%m-%d %H:%M:%S.%f")[:-3], text)
            return
        pat = "|".join("(%s)" % p for p in sorted(set(BUNDLES.values()) | {GENERIC}))
        entries += parse_lines(journal(["_UID=" + UID, "-g", pat], since, until), "user")
        entries += parse_lines(journal(["-u", "bluetooth", "-g", pat], since, until), "bluetoothd")
        entries += parse_lines(journal(["-k", "-g", pat], since, until), "kernel")
    entries.sort(key=lambda e: e[0])
    marks.sort()
    if not marks:
        print("no bt-mark entries in the range", file=sys.stderr)
        return 1
    print("marks: %d   journal lines kept: %d   range %s to %s" % (
        len(marks), len(entries), since.strftime("%H:%M:%S"), until.strftime("%H:%M:%S")))
    for i, (t, text) in enumerate(marks):
        key = re.split(r"[\s:,]+", text.strip(), 1)[0].upper()
        if a.only and key != a.only.upper():
            continue
        # a mark is typed AFTER what was seen: its window is from the previous mark (at most
        # --window seconds back) up to a few seconds after the mark itself
        end = t + dt.timedelta(seconds=a.lead)
        lo = t - dt.timedelta(seconds=a.window)
        if i > 0:
            lo = max(lo, marks[i - 1][0])
        rx = re.compile(BUNDLES.get(key, GENERIC))
        print("\n=== %s  [%s]  lines from %s to %s" % (t.strftime("%H:%M:%S.%f")[:-3], text,
                                                      lo.strftime("%H:%M:%S"), end.strftime("%H:%M:%S")))
        shown = 0
        total = 0
        for et, src, msg in entries:
            if et < lo or et >= end or not rx.search(msg):
                continue
            total += 1
            if shown < a.max_lines:
                body = msg if a.no_mask else ADDR.sub("<addr>", msg)
                print("  %s %-10s %s" % (et.strftime("%H:%M:%S.%f")[:-3], src, body[:200]))
                shown += 1
        if total == 0:
            print("  (no matching journal line in this window)")
        elif total > shown:
            print("  ... %d more matching lines, raise --max-lines" % (total - shown))
        window = [(et, src, msg) for et, src, msg in entries if lo <= et < end]
        print("  summary: " + summarize(key, window))
    return 0


def summarize(key, window):
    """one line of counts that answers the test's question; the lines above are the proof"""
    msgs = [m for _, _, m in window]

    def n(rx):
        return sum(1 for m in msgs if re.search(rx, m))
    if key in ("U12", "CO03"):
        adds = [t for t, _, m in window if "media_owner_add" in m and "Request Acquire" in m]
        rems = [t for t, _, m in window if "media_owner_remove" in m and "Request Acquire" in m]
        landed = any(0 <= (r - a).total_seconds() < 1.5 for a in adds for r in rems)
        return ("Acquire cancelled within 1.5 s of its start (trigger landed): %s; abort sent: %s; "
                "A2DP lost: %s" % ("YES" if landed else "no (test void if you expected a trigger)",
                                    "YES" if n(r"a2dp_cancel|aborting setup|Abort") else "no",
                                    "YES" if n(r"connected -> disconnected|connection_lost|Disconnected from") else "no"))
    if key in ("U19", "CO32", "CO07", "U6"):
        return ("meter streams created %d, destroyed by WirePlumber %d (target not found %d), errors sent to the panel %d"
                % (n(r"CREATE_RECORD_STREAM"), n(r"destroy node"), n(r"target not found"), n(r"\]: ERROR")))
    if key in ("U15", "U20", "CO33", "U2"):
        out = [m.split("+VGM:")[1].strip() for m in msgs if "RFCOMM >>" in m and "+VGM:" in m]
        inc = [m.split("AT+VGM=")[1].strip() for m in msgs if "RFCOMM <<" in m and "AT+VGM=" in m]
        q = [m.split("device quirks:")[1].strip() for m in msgs if "device quirks:" in m]

        def vals(v):
            if not v:
                return "none"
            return "%d sent, first %s, last %s, a 0 among them: %s" % (len(v), ",".join(v[:6]), v[-1],
                                                                       "YES" if "0" in v or "00" in v else "no")

        def counted(v):
            seen = {}
            for x in v:
                seen[x] = seen.get(x, 0) + 1
            return ", ".join("%s x%d" % (k, c) for k, c in sorted(seen.items())) or "none"
        return ("microphone gain sent to the headset (+VGM): %s; reported by the headset (AT+VGM): %s; "
                "device quirks word(s): %s (non-zero = a rule applied); disabled-by-quirk lines %d"
                % (vals(out), counted(inc), counted(q), n(r"disabled by quirk")))
    if key in ("U14", "CO29"):
        return ("profile switches by WirePlumber (Setting profile of): %d; restores: %d; 'not switching': %d"
                % (n(r"Setting profile of"), n(r"Restoring profile"), n(r"not switching")))
    if key in ("U8", "CO18"):
        return "kernel 'corrupted SCO packet' lines: %d" % n(r"corrupted SCO packet")
    return "%d matching lines" % len(msgs)


sys.exit(main())
