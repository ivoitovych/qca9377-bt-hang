# EX-014 — pristine-config-and-the-autosuspend-discrepancy

**Claim.** The pre-mitigation /etc snapshot proves no Bluetooth modprobe or udev configuration existed before this project added any, so removing those files restores the original state exactly. But the same snapshot records enable_autosuspend=N one hour BEFORE the mitigation was installed, while the kernel is built with CONFIG_BT_HCIBTUSB_AUTOSUSPEND=y — meaning the compiled default is Y. The two records disagree about the original runtime value.

**Relevance.** Checked when switching to experiment mode, because 'restore the Ubuntu default' is only meaningful if the default is known rather than assumed. The /etc half is decisive: with no modprobe.d or udev file present, the module default applies, and that default is Y by kernel config. The runtime half is not: N was already recorded before installation, so something in the first investigation session had changed it — changes-applied.md claims Before=Y, and one of the two records is wrong. Experiment mode therefore sets Y, matching what a clean install of this kernel would do, and this discrepancy is recorded rather than resolved by assertion.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ echo '--- pre-mitigation /etc: any bluetooth config? ---'; ls /root/exp/config-backup-20260810-052348/etc-modprobe.d/ | grep -ci btusb; ls /root/exp/config-backup-20260810-052348/etc-udev-rules.d/ | grep -ci bluetooth; echo '(0 and 0 = none existed)'; echo; echo '--- what the snapshot recorded at 05:28 ---'; grep -m1 enable_autosuspend /root/exp/config-backup-20260810-052348/runtime-state.txt; echo; echo '--- when each was created ---'; stat -c '%y %n' /root/exp/config-backup-20260810-052348 /usr/local/share/qca9377-bt-hang/installed-at; echo; echo '--- the compiled default ---'; grep BT_HCIBTUSB_AUTOSUSPEND /boot/config-$(uname -r)
```

## Output

Verbatim, 14 line(s), exit status 0.

```
--- pre-mitigation /etc: any bluetooth config? ---
0
0
(0 and 0 = none existed)

--- what the snapshot recorded at 05:28 ---
enable_autosuspend=N

--- when each was created ---
2026-08-10 05:28:01.153543462 +0200 /root/exp/config-backup-20260810-052348
2026-08-10 06:28:19.669970348 +0200 /usr/local/share/qca9377-bt-hang/installed-at

--- the compiled default ---
CONFIG_BT_HCIBTUSB_AUTOSUSPEND=y
```

**Evidence window.** `2026-08-10T05:28:01.153543462+02:00` — `2026-08-10T06:28:19.669970348+02:00`

> **Annotation added 2026-08-22 (`BL-09`), derived from this exhibit's own
> content. The captured output above is untouched.** Nothing is inferred here. Both instants are
> already absolute in the captured output —
> `2026-08-10 05:28:01.153543462 +0200` and `2026-08-10 06:28:19.669970348 +0200`,
> as `stat` prints them — and are only rewritten into the `T`-separated form this
> field requires. No zone was chosen and no precision dropped.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-13T02:20:08+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `d28ebac2` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
