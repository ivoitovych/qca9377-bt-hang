# EX-079 — co02-code-v6-v7-kernel-identical

**Claim.** The three kernel patches of the v7 candidate carry exactly the code of v6's: for each pair the diff text (every changed line, file name and hunk header; only the blob index lines left out) is IDENTICAL and git patch-id --stable is IDENTICAL. Only the commit messages changed.

**Relevance.** v7 rewrites the prose. This shows the rewrite did not touch the code that every test of v6 ran. The tool's positive control is EX-078.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ python3 -I /root/exp/qca9377-bt-hang/scripts/patch-code-compare.py /root/exp/qca9377-bt-hang/contributions/CO-02-sco-connect-reuses-closing-link/patch/v6/send/kernel /root/exp/qca9377-bt-hang/contributions/CO-02-sco-connect-reuses-closing-link/patch/v7-candidate/send/kernel
```

## Output

Verbatim, 13 line(s), exit status 0.

```
0001  0001-Bluetooth-hci_conn-hold-a-reused-SCO-connection-for-.patch
      code text: IDENTICAL (28 lines compared, index lines left out)
      patch-id : IDENTICAL  87b77ca498afea44 / 87b77ca498afea44
      message  : changed
0002  0002-Bluetooth-hci_conn-don-t-reuse-an-aborting-SCO-conne.patch
      code text: IDENTICAL (27 lines compared, index lines left out)
      patch-id : IDENTICAL  8c349a094c3759f4 / 8c349a094c3759f4
      message  : changed
0003  0003-Bluetooth-hci_conn-synchronize-with-SCO-disconnect-w.patch
      code text: IDENTICAL (21 lines compared, index lines left out)
      patch-id : IDENTICAL  9f50d1196989e2c7 / 9f50d1196989e2c7
      message  : changed
RESULT: the code is identical in every pair
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-10-26T06:48:20+01:00` |
| kernel | `7.0.0-38-generic` |
| capture boot id | `257d1599` |
| evidence boot ids | none named by the command (it selects by index or not by boot) — see the window above |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
