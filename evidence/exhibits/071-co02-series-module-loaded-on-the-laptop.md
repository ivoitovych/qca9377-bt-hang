# EX-071 — co02-series-module-loaded-on-the-laptop

**Claim.** On boot 257d1599 (up since 2026-10-23 11:04:40) the loaded bluetooth module is the CO-02 build, srcversion 0D084A056A9EEFB98E8F331, the one in updates/ (sha256 702186d9d17dc6cc…), which results-2026-10-23-hw-prep.md section 3 lists as Ubuntu 7.0.0-38's Bluetooth + abd93c85c8667 + 816fb1590a4c + v5 (tree with816-series ff077afb28e8).

**Relevance.** Ties every hardware exhibit of this boot (EX-067 to EX-073) to the exact code under test.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /root/exp/qca9377-bt-hang/scripts/module-updates.sh status
```

## Output

Verbatim, 7 line(s), exit status 0.

```
module:              bluetooth
kernel:              7.0.0-38-generic
loaded srcversion:   0D084A056A9EEFB98E8F331
loaded version:      2.22
next boot resolves:  /lib/modules/7.0.0-38-generic/updates/bluetooth.ko
updates/ module:     srcversion 0D084A056A9EEFB98E8F331  sha256 702186d9d17dc6cc…
initramfs:           no bluetooth.ko — updates/ + depmod is enough
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-10-25T22:21:26+01:00` |
| kernel | `7.0.0-38-generic` |
| capture boot id | `257d1599` |
| evidence boot ids | `257d1599` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
