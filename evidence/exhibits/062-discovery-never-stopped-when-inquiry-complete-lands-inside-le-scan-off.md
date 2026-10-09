# EX-062 — discovery-never-stopped-when-inquiry-complete-lands-inside-le-scan-off

**Claim.** With build E3 (the upstream QCA ROME entry for 13d3:3503, dc16388d45ec) on kernel 7.0.0-34, two BR/EDR+LE discovery cycles in these traces (2026-10-01 00:13 to 2026-10-05 13:58) ended with the controller's Inquiry Complete arriving after the kernel's LE Set Scan Enable (Disabled) command and before that command's Command Complete: 2026-10-01 03:51:27.961572 / .962690 / .965077 and 2026-10-04 10:26:11.625144 / .625697 / .627698. In neither did the kernel report Discovering: Disabled at the end of the cycle: the first stayed so until a system suspend 8 h 18 min later (12:09:41), the second for the rest of the traces, and the next start commands, 2026-10-05 13:57:53 and 13:57:59, were answered Busy (0x0a). Every other cycle that reached its end, in any other order, stopped.

**Relevance.** BTUSB_QCA_ROME sets HCI_QUIRK_SIMULTANEOUS_DISCOVERY (drivers/bluetooth/btusb.c). Under that quirk le_scan_disable() (net/bluetooth/hci_sync.c) queues the scan-off and returns without stopping while HCI_INQUIRY is still set, and hci_inquiry_complete_evt() (net/bluetooth/hci_event.c) does not stop while HCI_LE_SCAN is still set, which it is until the scan-off's Command Complete. An Inquiry Complete inside that window therefore leaves DISCOVERY_STOPPED unset, and start_discovery_internal() (net/bluetooth/mgmt.c) refuses every later start with MGMT_STATUS_BUSY until a suspend or power-off resets the state. Both ends are 10.24 s after the start (Inquiry length 0x08, DISCOV_LE_TIMEOUT), so the order is decided by milliseconds. An SCO link was up during the second cycle, not the first: a call is not required. The traces are preserved copies of /var/log/bt-health/trace with SHA256SUMS beside them.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /root/exp/qca9377-bt-hang/scripts/discovery-stop-race.py /root/bt-trace-keep/bt-*.btsnoop
```

## Output

Verbatim, 149 line(s), exit status 0.

```
bt-20261001-001332.btsnoop: 4 start command(s)
bt-20261001-002552.btsnoop: 0 start command(s)
bt-20261001-005941.btsnoop: 0 start command(s)
bt-20261001-010232.btsnoop: 2 start command(s)
bt-20261001-025855.btsnoop: 9 start command(s)
bt-20261001-031947.btsnoop: 1 start command(s)
bt-20261001-032205.btsnoop: 0 start command(s)
bt-20261001-032315.btsnoop: 0 start command(s)
bt-20261001-032445.btsnoop: 0 start command(s)
bt-20261001-032613.btsnoop: 7 start command(s)
bt-20261001-032836.btsnoop: 86 start command(s)
bt-20261001-113637.btsnoop: 412 start command(s)
bt-20261001-153614.btsnoop: 1558 start command(s)
bt-20261002-004049.btsnoop: 116 start command(s)
bt-20261002-011134.btsnoop: 5030 start command(s)
bt-20261003-011809.btsnoop: 3854 start command(s)
bt-20261003-182529.btsnoop: 175 start command(s)
bt-20261003-191212.btsnoop: 93 start command(s)
bt-20261003-193650.btsnoop: 168 start command(s)
bt-20261003-202151.btsnoop: 626 start command(s)
bt-20261003-230842.btsnoop: 626 start command(s)
bt-20261004-015538.btsnoop: 626 start command(s)
bt-20261004-044234.btsnoop: 626 start command(s)
bt-20261004-072930.btsnoop: 626 start command(s)
bt-20261004-101626.btsnoop: 36 start command(s)
bt-20261004-112756.btsnoop: 0 start command(s)
bt-20261004-122934.btsnoop: 0 start command(s)
bt-20261004-131740.btsnoop: 0 start command(s)
bt-20261004-134907.btsnoop: 0 start command(s)
bt-20261004-173401.btsnoop: 0 start command(s)
bt-20261004-181110.btsnoop: 0 start command(s)
bt-20261004-183133.btsnoop: 0 start command(s)
bt-20261004-192531.btsnoop: 0 start command(s)
bt-20261004-201237.btsnoop: 0 start command(s)
bt-20261004-225256.btsnoop: 0 start command(s)
bt-20261005-012858.btsnoop: 0 start command(s)
bt-20261005-023714.btsnoop: 0 start command(s)
bt-20261005-094058.btsnoop: 0 start command(s)
bt-20261005-102735.btsnoop: 0 start command(s)
bt-20261005-112212.btsnoop: 0 start command(s)
bt-20261005-124915.btsnoop: 2 start command(s)

totals by how the cycle ended:
   14614  IC first, stopped
       2  IC first, stopped only later
       1  IC in between, never stopped in these traces
       1  IC in between, stopped only later
      15  cancelled, stopped
       1  cancelled, stopped only later
      46  off done first, stopped
       2  refused (Busy 0x0a)
       5  start with no reply in the trace

cycles other than '<IC first | off done first | cancelled>, stopped':
  2026-10-01 03:51:17.588502  start 0x0023    IC in between    stopped only 29893 s later (2026-10-01 12:09:41.412414, just after le-scan-done)
  2026-10-02 10:30:43.324285  start 0x0023    IC first         stopped only 5 s later (2026-10-02 10:30:58.827904, just after le-scan-done)
  2026-10-02 19:48:03.853985  start 0x0023    IC first         stopped only 5 s later (2026-10-02 19:48:19.359360, just after le-scan-done)
  2026-10-03 18:01:42.364218  start 0x0023    cancelled        stopped only 5 s later (2026-10-03 18:01:55.707214, just after inquiry-cancel)
  2026-10-04 10:26:01.364189  start 0x0023    IC in between    never stopped in these traces  [SCO set up during the cycle]

--- timeline of the cycle started 2026-10-01 03:51:17.588502 (bt-20261001-032836.btsnoop), first 16 events:
    2026-10-01 03:51:17.588502  start             0x0023
    2026-10-01 03:51:17.693714  le-scan           on
    2026-10-01 03:51:17.696689  le-scan-done      
    2026-10-01 03:51:17.696771  discovering       Enabled
    2026-10-01 03:51:17.696953  inquiry           
    2026-10-01 03:51:17.699695  start-reply       Success 0x00
    2026-10-01 03:51:27.961572  le-scan           off
    2026-10-01 03:51:27.962690  inquiry-complete  
    2026-10-01 03:51:27.965077  le-scan-done      
    2026-10-01 12:09:41.412414  discovering       Disabled
    2026-10-01 12:09:41.414803  ctrl-suspend      
    2026-10-01 13:46:15.823641  le-scan           on
    2026-10-01 13:46:15.826594  le-scan-done      
    the next cycles:
      2026-10-01 13:46:15.826605  kernel restart  reply: -
      2026-10-01 13:46:31.561975  start 0x0023    reply: Success 0x00
      2026-10-01 13:46:47.567686  start 0x0023    reply: Success 0x00

--- timeline of the cycle started 2026-10-02 10:30:43.324285 (bt-20261002-011134.btsnoop), first 16 events:
    2026-10-02 10:30:43.324285  start             0x0023
    2026-10-02 10:30:43.429493  le-scan           on
    2026-10-02 10:30:43.432545  le-scan-done      
    2026-10-02 10:30:43.432602  discovering       Enabled
    2026-10-02 10:30:43.432720  inquiry           
    2026-10-02 10:30:43.435691  start-reply       Success 0x00
    2026-10-02 10:30:53.686393  inquiry-complete  
    2026-10-02 10:30:53.864216  le-scan           off
    2026-10-02 10:30:53.867395  le-scan-done      
    2026-10-02 10:30:58.827904  discovering       Disabled
    the next cycles:
      2026-10-02 10:31:04.324343  start 0x0023    reply: Success 0x00
      2026-10-02 10:31:20.324214  start 0x0023    reply: Success 0x00
      2026-10-02 10:31:36.323938  start 0x0023    reply: Success 0x00

--- timeline of the cycle started 2026-10-02 19:48:03.853985 (bt-20261002-011134.btsnoop), first 16 events:
    2026-10-02 19:48:03.853985  start             0x0023
    2026-10-02 19:48:03.961614  le-scan           on
    2026-10-02 19:48:03.964284  le-scan-done      
    2026-10-02 19:48:03.964370  discovering       Enabled
    2026-10-02 19:48:03.964674  inquiry           
    2026-10-02 19:48:03.967893  start-reply       Success 0x00
    2026-10-02 19:48:14.218252  inquiry-complete  
    2026-10-02 19:48:14.522804  le-scan           off
    2026-10-02 19:48:14.525206  le-scan-done      
    2026-10-02 19:48:19.359360  discovering       Disabled
    the next cycles:
      2026-10-02 19:48:24.855262  start 0x0023    reply: Success 0x00
      2026-10-02 19:48:40.854470  start 0x0023    reply: Success 0x00
      2026-10-02 19:48:56.852640  start 0x0023    reply: Success 0x00

--- timeline of the cycle started 2026-10-03 18:01:42.364218 (bt-20261003-011809.btsnoop), first 16 events:
    2026-10-03 18:01:42.364218  start             0x0023
    2026-10-03 18:01:42.470058  le-scan           on
    2026-10-03 18:01:42.472998  le-scan-done      
    2026-10-03 18:01:42.473014  discovering       Enabled
    2026-10-03 18:01:42.473071  inquiry           
    2026-10-03 18:01:42.476037  start-reply       Success 0x00
    2026-10-03 18:01:50.561087  inquiry-cancel    
    2026-10-03 18:01:55.707214  discovering       Disabled
    2026-10-03 18:01:55.707291  le-scan           off
    2026-10-03 18:01:55.709804  le-scan-done      
    2026-10-03 18:01:55.777975  new-settings      not powered
    2026-10-03 18:01:55.778015  index-gone        Close Index: 34:6F
    the next cycles:
      2026-10-03 18:01:56.814066  start 0x0023    reply: Success 0x00
      2026-10-03 18:02:04.644625  start 0x0023    reply: Success 0x00
      2026-10-03 18:02:08.926702  start 0x0023    reply: Success 0x00

--- timeline of the cycle started 2026-10-04 10:26:01.364189 (bt-20261004-101626.btsnoop), first 16 events:
    2026-10-04 10:26:01.364189  start             0x0023
    2026-10-04 10:26:01.369717  le-scan           on
    2026-10-04 10:26:01.372647  le-scan-done      
    2026-10-04 10:26:01.372661  discovering       Enabled
    2026-10-04 10:26:01.372730  inquiry           
    2026-10-04 10:26:01.375684  start-reply       Success 0x00
    2026-10-04 10:26:02.492712  sco-setup         
    2026-10-04 10:26:02.758654  sco-complete      
    2026-10-04 10:26:11.625144  le-scan           off
    2026-10-04 10:26:11.625697  inquiry-complete  
    2026-10-04 10:26:11.627698  le-scan-done      
    2026-10-04 10:42:45.474762  sco-setup         
    2026-10-04 10:42:45.555409  sco-complete      
    2026-10-04 11:07:30.365354  sco-setup         
    2026-10-04 11:07:30.449327  sco-complete      
    2026-10-04 11:46:18.605397  sco-setup         
    the next cycles:
      2026-10-05 13:57:53.964382  start 0x003a    reply: Busy 0x0a
      2026-10-05 13:57:59.822856  start 0x003a    reply: Busy 0x0a
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-10-09T23:02:07+02:00` |
| kernel | `7.0.0-34-generic` |
| capture boot id | `c34cfa10` |
| evidence boot ids | `c34cfa10` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
