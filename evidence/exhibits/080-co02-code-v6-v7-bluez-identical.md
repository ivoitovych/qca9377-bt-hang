# EX-080 — co02-code-v6-v7-bluez-identical

**Claim.** The BlueZ test mail of the v7 candidate carries exactly the code of the v6 test commit that was built and run (patch/v6/bluez-commit, the 18/18 focused runs, 33/33 full runs, and the leak experiments): diff text IDENTICAL over 632 lines, git patch-id IDENTICAL. Only the commit message changed.

**Relevance.** The v6 BlueZ test results apply to v7 unchanged. The tool's positive control is EX-078.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ python3 -I /root/exp/qca9377-bt-hang/scripts/patch-code-compare.py /root/exp/qca9377-bt-hang/contributions/CO-02-sco-connect-reuses-closing-link/patch/v6/bluez-commit /root/exp/qca9377-bt-hang/contributions/CO-02-sco-connect-reuses-closing-link/patch/v7-candidate/send/bluez
```

## Output

Verbatim, 5 line(s), exit status 0.

```
0001  0001-tools-sco-tester-Add-SCO-reconnect-tests.patch
      code text: IDENTICAL (632 lines compared, index lines left out)
      patch-id : IDENTICAL  01df21faf4ee72b4 / 01df21faf4ee72b4
      message  : changed
RESULT: the code is identical in every pair
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-10-26T06:48:23+01:00` |
| kernel | `7.0.0-38-generic` |
| capture boot id | `257d1599` |
| evidence boot ids | none named by the command (it selects by index or not by boot) — see the window above |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
