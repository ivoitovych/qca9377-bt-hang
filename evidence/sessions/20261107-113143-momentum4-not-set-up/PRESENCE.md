# Was the MOMENTUM 4 discoverable, and why did its row outlive the switch-off?

Checked 2026-11-07 against the HCI capture and BlueZ 5.72 source, for the operator's two
impressions: (1) a headset not in pairing mode should not be offered as "Not set up"; (2) after
it was switched off it stayed listed. The headset is `AA:BB:CC:00:00:01` here.

## Commands

```
scripts/capture-window.sh /var/log/bt-health/capture/hci-20261107-110649.btsnoop \
  "2026-11-07 11:16:00" "2026-11-07 11:19:00" \
  "Extended Inquiry Result|Inquiry Result|Inquiry Complete|Flags: 0x|Address: <headset>" \
  > tmp/u29-presence/decode-1116-1119.txt
python3 -I scripts/device-adv-summary.py tmp/u29-presence/decode-1116-1119.txt <headset> "11:18:30" "11:18:49"
```

The decode also prints the pairing at 11:18:58 and was deleted after the run; it is rebuilt
from the capture by the first command.

## Output (the headset's records; the address written as the placeholder)

```
11:16:06.813646 LE ADV_IND (0x00) flags 0x18
11:16:06.815599 LE SCAN_RSP (0x04) flags -
11:16:23.097766 LE ADV_IND (0x00) flags 0x18
11:16:39.599574 LE ADV_IND (0x00) flags 0x18
11:16:40.446590 LE ADV_IND (0x00) flags 0x18
11:16:55.235059 LE ADV_IND (0x00) flags 0x18
11:17:11.096676 LE ADV_IND (0x00) flags 0x18
11:17:11.729918 LE ADV_IND (0x00) flags 0x18
11:17:27.079899 LE ADV_IND (0x00) flags 0x18
11:17:43.379442 LE ADV_IND (0x00) flags 0x18
11:17:59.280387 LE ADV_IND (0x00) flags 0x18
11:18:03.360399 LE ADV_IND (0x00) flags 0x18
11:18:03.676379 LE ADV_IND (0x00) flags 0x18
11:18:16.085328 LE ADV_IND (0x00) flags 0x18
11:18:18.003328 LE ADV_IND (0x00) flags 0x18
11:18:19.259324 LE ADV_IND (0x00) flags 0x18
11:18:21.896347 LE ADV_IND (0x00) flags 0x18
11:18:25.156289 LE ADV_IND (0x00) flags 0x18
11:18:25.990848 LE ADV_IND (0x00) flags 0x18
11:18:28.803523 LE ADV_IND (0x00) flags 0x18
11:18:29.736268 LE ADV_IND (0x00) flags 0x18
11:18:49.111151 LE ADV_IND (0x00) flags 0x18
11:18:51.299296 LE ADV_IND (0x00) flags 0x18
11:18:52.344196 BR/EDR Extended Inquiry Result flags -
11:18:59.317094 LE ADV_IND (0x00) flags 0x18
reports from other addresses, from 11:18:30 to 11:18:49: 8
```

(Each `ADV_IND` is followed within 3 ms by a `SCAN_RSP` with no data; those lines are left out
here, plus one lone `SCAN_RSP` at 11:17:27.603667.) BR/EDR inquiry rounds ended (`Inquiry
Complete`, Success) at 11:16:16.94, 11:16:33.23, 11:16:49.23, 11:17:05.23, 11:17:21.31,
11:17:37.32, 11:17:53.32, 11:18:13.40 and 11:18:39.74; the headset answered none of them.

The 11:18:52 inquiry answer lists Handsfree, Headset, Audio Sink, A2DP and AVRCP and the name
"MOMENTUM 4", class 0x240404. The LE advertisement at 11:16:06 carries flags 0x18 (only the two
"Simultaneous LE and BR/EDR" bits), one 16-bit UUID 0xfcfe and the name.

## What it shows

1. **The headset was not discoverable until 11:18:52.** Its LE advertisements carry neither
   discoverable bit (`0x01` limited, `0x02` general), and it answered no BR/EDR inquiry over nine
   rounds. At 11:18:52 it answered one with its full service list: pairing mode.
2. **BlueZ did not make a row out of those advertisements.** 5.72 `src/adapter.c`
   `device_is_discoverable()`: for LE without a filtered discovery, discoverable =
   `flags & (EIR_LIM_DISC | EIR_GEN_DISC)`; `btd_adapter_device_found()` creates no device when it
   is false. The first advertisement (11:16:06.81) created nothing; the device was created at
   11:16:10.138 by the headset's own connection (`Connect Request` from the headset 11:16:09.509,
   three Link Key Negative Replies, the headset's disconnect 11:16:14.275).
3. **Once the row existed, the non-discoverable advertisements kept it.** In the same function
   `device_update_last_seen()` is called for an existing device *before* the discoverable check
   that drops the report; 5.72 `src/device.c` `device_update_last_seen()` restarts the
   temporary-device removal timer (`btd_opts.tmpto`, `TemporaryTimeout`, 30 s: commented out in
   `/etc/bluetooth/main.conf` l.109, so the default). So an advertisement that says "not
   discoverable" kept an unpaired "Not set up" row alive for about three minutes.
4. **Silence 11:18:29.74 → 11:18:49.11 (19.4 s)** while the laptop was scanning (8 reports from
   other devices from 11:18:30 to 11:18:49, an inquiry round ended 11:18:39.74). That fits the
   operator's switch-off; the capture cannot see a power button. The row could go at the
   earliest 30 s after the last sighting. The 11:18:31.47 disconnect restarted the timer
   again (`device_remove_connection()` → `device_update_last_seen()`, `src/device.c:3380` in
   the running 5.72-0ubuntu5.5 tree), so about 11:19:01.5. The headset was back at 11:18:49. At 11:18:51.887 the headset ended the
   tenth refused attempt itself and at 11:18:52 it was in pairing mode.
