#!/usr/bin/env python3
"""Read-only: print the peak and RMS level (dBFS) of every second of a 16-bit WAV file.
Record the file first, for example (speak into the headset for 6 s):
    pw-record --format s16 --target <source node id from audio-ids.py> /tmp/u15-mic.wav
Usage: mic-peak.py <file.wav>"""
import array
import math
import sys
import wave

w = wave.open(sys.argv[1], "rb")
if w.getsampwidth() != 2:
    sys.exit("need a 16-bit file: record with --format s16")
rate, ch = w.getframerate(), w.getnchannels()
n = 0
while True:
    raw = w.readframes(rate)
    if not raw:
        break
    a = array.array("h")
    a.frombytes(raw)
    peak = max(abs(x) for x in a) if a else 0
    rms = math.sqrt(sum(x * x for x in a) / len(a)) if a else 0
    db = lambda v: -99.0 if v <= 0 else 20 * math.log10(v / 32768.0)
    print("second %2d: peak %6.1f dBFS   rms %6.1f dBFS" % (n, db(peak), db(rms)))
    n += 1
print("channels %d, rate %d Hz, %d s" % (ch, rate, n))
