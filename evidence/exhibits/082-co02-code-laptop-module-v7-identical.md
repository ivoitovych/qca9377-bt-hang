# EX-082 — co02-code-laptop-module-v7-identical

**Claim.** The CO-02 change in the laptop's module (co02-ubuntu38/with816-series ff077afb28e8 on Ubuntu 7.0.0-38's Bluetooth with abd93c85c8667 and 816fb1590a4c; EX-071, the hardware runs EX-067 to EX-077) is the same code change as the v7 candidate's three patches on bluetooth-next 47d4d9f67e92: the same file, git patch-id IDENTICAL, and the 36 changed lines IDENTICAL, although the bases differ.

**Relevance.** The laptop ran the series as one commit on another base, so the mail comparison does not cover it. git patch-id ignores line numbers; the changed-line comparison checks every +/- line in order. The tool's positive control: the same script on the prerequisite commit vs v7 reports DIFFER on all three counts (run 2026-10-26, transcript).

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /root/exp/qca9377-bt-hang/scripts/change-code-compare.sh /root/exp/qca9377-bt-hang/cache/co02-send 96f7336a918ff ff077afb28e8 /root/exp/qca9377-bt-hang/cache/co02-send 47d4d9f67e92 co02-send/v7-prose
```

## Output

Verbatim, 6 line(s), exit status 0.

```
A: 96f7336a918ff..ff077afb28e8 in /root/exp/qca9377-bt-hang/cache/co02-send
B: 47d4d9f67e92..co02-send/v7-prose in /root/exp/qca9377-bt-hang/cache/co02-send
files: IDENTICAL (net/bluetooth/hci_conn.c )
patch-id: IDENTICAL 13fb52c3d619335d
changed lines: IDENTICAL (36 lines)
RESULT: the same code change
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-10-26T06:48:32+01:00` |
| kernel | `7.0.0-38-generic` |
| capture boot id | `257d1599` |
| evidence boot ids | none named by the command (it selects by index or not by boot) — see the window above |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
