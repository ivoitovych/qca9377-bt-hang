# stage2.awk — per boot, how long did the controller stay on the USB bus after
# it stopped answering HCI, and what ended the observation?
#
# Reads a chronological merge of the kernel journal and watchdog service,
# including `-- Boot <id> --` separators. Kernel-only historical caches are
# accepted, but a reset with no positive origin marker is then UNKNOWN rather
# than silently attributed to the operator. Requires timestamp.awk.
#
# THE QUESTION THIS EXISTS TO ANSWER. The project believed the fault had two
# stages: HCI goes silent, then 45-66 s later the device leaves the USB bus.
# Every observation behind that figure had one of our own resets in between.
# The first observation without one showed no progression for 72 minutes.
#
# So the interval is only meaningful together with what TERMINATED it, and the
# terminator is the thing that was never recorded. Six kinds:
#
#   natural         USB disconnect with no intervention before it
#   intervened      watchdog or btusb-unload provenance positively establishes it
#   kernel-reset    the experimental kernel's hdev->reset path positively fires
#   unknown-reset   a USB reset occurred but its origin is not established
#   shutdown        the boot ended with the device still enumerated
#   ongoing         the current boot, still running
#
# Only `natural` measures an uncensored untreated transition. The rest are
# right-censored. A censored observation is a LOWER BOUND on the true survival
# time, never an estimate of it. Averaging unlike terminators is how the 45-66 s figure was
# produced.

function emit(   dur, cls, note) {
    if (!have_tmo) return
    n_boots_with_tmo++

    if (term_kind == "") {
        # No terminator seen and no more lines in this boot: the boot ended
        # with the controller still enumerated.
        term_kind = "shutdown"
        term_ts   = last_ts
        term_line = "(last kernel message of the boot)"
    }

    dur = iso_secs(term_ts) - iso_secs(tmo_ts)
    if (dur < 0) dur = 0

    if (term_kind == "disconnect")         { cls = "NATURAL";       n_natural++ }
    else if (term_kind == "intervention")  { cls = "intervened";    n_intervened++ }
    else if (term_kind == "kernel_reset")  { cls = "kernel-reset";  n_kernel_reset++ }
    else if (term_kind == "unknown_reset") { cls = "unknown-reset"; n_unknown_reset++ }
    else if (term_kind == "ongoing")       { cls = "ongoing";       n_ongoing++ }
    else                                    { cls = "shutdown";      n_shutdown++ }

    printf "\n  boot %-14s first HCI timeout %s\n", substr(boot_id, 1, 12), tmo_ts
    for (i = 1; i <= nev; i++) printf "%s\n", ev[i]
    printf "      HCI-nonresponse window: %.2fs (%s)  %s\n", dur, hms(dur), cls
    if (cls != "NATURAL")
        printf "      RIGHT-CENSORED — true survival time is longer than this\n"

    if (cls == "NATURAL") { if (dur > max_nat) max_nat = dur; sum_nat += dur }
    if (dur > max_any) { max_any = dur; max_any_cls = cls }
    have_tmo = 0
}

function hms(s,   h, m) {
    h = int(s / 3600); s -= h * 3600
    m = int(s / 60);   s -= m * 60
    if (h) return sprintf("%dh %dm %ds", h, m, s)
    if (m) return sprintf("%dm %ds", m, s)
    return sprintf("%ds", int(s))
}

function note(label, mark,   t) {
    t = iso_secs($1) - iso_secs(tmo_ts)
    ev[++nev] = sprintf("      +%9.2fs  %-52s%s", t, label, mark)
}

BEGIN {
    print "HCI non-response -> USB loss: how long, and what ended the observation?"
    print "──────────────────────────────────────────────────────────────"
    boot_id = "first-boot"
    if (vid == "") vid = "13d3"
    if (pid == "") pid = "3503"
}

/^-- Boot / {
    emit()
    boot_id = $3
    # dev_error is per-boot state and MUST reset here. Before it did, the first
    # boot in the journal with any bus error poisoned every later boot: their
    # resets classified as "hub recovery" (dev_error looked already set), so
    # intervened stayed 0 and a following disconnect printed NATURAL — a false
    # observation of the exact event this tool exists to say has never been
    # seen. Verified with a two-boot fixture before fixing.
    have_tmo = 0; term_kind = ""; nev = 0; dev_error = 0
    devpath = ""
    next
}

# Learn which usb path is OUR device, from its enumeration line. The USB-layer
# patterns below carry no VID:PID, only a path ("usb 3-3: ..."), and without
# this anchor ANY device's disconnect — a mouse unplugged mid-window — would
# terminate a stage-1 window, possibly as NATURAL. vid/pid arrive via -v from
# bt-stage2 (BT_VID/BT_PID); when no enumeration line names the device in a
# boot, the old unfiltered behaviour is kept rather than silently dropping
# coverage, and the summary says so.
$0 ~ ("idVendor=" vid ", idProduct=" pid) {
    if (match($0, / usb [0-9][0-9.-]*:/)) {
        devpath = substr($0, RSTART + 5, RLENGTH - 6)
    }
}

{ last_ts = $1 }

# The window opens at the first unanswered HCI command of the boot. Later
# timeouts in the same boot are part of the same failure, not new ones.
/command( 0x[0-9a-f]+)? tx timeout/ {
    if (!have_tmo) {
        have_tmo = 1; tmo_ts = $1; term_kind = ""; nev = 0
        dev_error = 0
    }
    next
}

!have_tmo { next }
term_kind != "" { next }

# Is this USB-layer line about OUR device? When the boot named the device's
# path, require it; when it did not, accept the line and count the boot as
# unanchored so the summary can say the classification ran unfiltered there.
function ours(line) {
    if (devpath == "") { unanchored[boot_id] = 1; return 1 }
    return index(line, " usb " devpath ":") > 0
}

# Positive userspace provenance. The default bt-stage2 acquisition includes
# this service alongside the kernel. Historical kernel-only caches do not, so
# their clean USB reset lines deliberately fall into unknown_reset below.
/bt-hang-watchdog.*(EARLY intervention|Detected .*intervening|Recovering Bluetooth controller)/ {
    note("watchdog intervention marker", "  <-- POSITIVE PROVENANCE")
    term_kind = "intervention"; term_ts = $1
    next
}

# Positive driver-unload provenance. Driver-level, carries no device path — no
# ours() check is possible; unloading btusb detaches every controller it drives.
/deregistering interface driver btusb/ {
    note("usbcore: deregistering interface driver btusb", "  <-- POSITIVE INTERVENTION")
    term_kind = "intervention"; term_ts = $1
    next
}

# Positive treatment provenance from a kernel built with hdev->reset. This is
# neither natural history nor an operator action: it is the treatment whose
# effect Builds A/B/C/D are intended to measure.
/Bluetooth: hci[0-9]+: (Resetting usb device|Reset qca device via bt_en gpio)/ {
    note("kernel command-timeout reset callback", "  <-- TREATMENT")
    term_kind = "kernel_reset"; term_ts = $1
    next
}

# A USB reset line does not contain its origin. A reset after a recognized bus
# error remains part of the stock hub-recovery trajectory. A clean reset with
# no positive marker is NOT thereby "ours": its origin is unknown, and it
# censors the natural-history window in its own category.
/reset (full|high|low)-speed USB device/ {
    if (!ours($0)) next
    if (dev_error) { note("usb: reset after descriptor errors (hub recovery)", "") }
    else {
        note("usb: reset issued; origin not established", "  <-- UNKNOWN")
        term_kind = "unknown_reset"; term_ts = $1
    }
    next
}

# Bus-level symptoms. These are the fault progressing, not an intervention.
/device descriptor read|device not accepting address|error -110|error -62/ {
    if (!ours($0)) next
    if (!dev_error) note("usb: first bus-level error", "")
    dev_error = 1
    next
}

/USB disconnect, device number/ {
    if (!ours($0)) next
    note("usb: USB disconnect", "  <-- NATURAL")
    term_kind = "disconnect"; term_ts = $1
    next
}

END {
    if (have_tmo && term_kind == "") { term_kind = "ongoing"; term_ts = last_ts
                                       term_line = "(journal ends; boot still running)" }
    emit()

    print ""
    print "──────────────────────────────────────────────────────────────"
    printf "  boots with HCI non-response   %d\n", n_boots_with_tmo + 0
    printf "    ended naturally             %d   <- uncensored untreated transitions\n", n_natural + 0
    printf "    ended by positive intervention %d\n", n_intervened + 0
    printf "    ended by kernel treatment reset %d\n", n_kernel_reset + 0
    printf "    ended by unknown-origin reset   %d\n", n_unknown_reset + 0
    printf "    ended by shutdown           %d\n", n_shutdown + 0
    printf "    still running               %d\n", n_ongoing + 0
    print ""
    if (n_natural > 0)
        printf "  longest uncensored HCI-to-USB-loss window   %.2fs (%s)\n", max_nat, hms(max_nat)
    else {
        print "  No uncensored HCI-nonresponse-to-USB-loss transition was observed."
        print "  Every HCI-nonresponse window was ended by intervention, a reset of"
        print "  known treatment or unknown origin, or shutdown. Therefore"
        print "  the fault's untreated trajectory is UNKNOWN — not 45-66s, not"
        print "  indefinite. The experiment that settles it is a boot left"
        print "  strictly alone after BT-1 until the device leaves the bus."
    }
    printf "  longest window of any kind       %.2fs (%s, %s)\n", max_any, hms(max_any), max_any_cls
    nu = 0
    for (b in unanchored) nu++
    if (nu > 0) {
        print ""
        printf "  ⚠ %d boot(s) had no enumeration line naming %s:%s, so their\n", nu, vid, pid
        print  "    USB-layer events were classified WITHOUT a device filter —"
        print  "    a disconnect from any USB device could have terminated those"
        print  "    windows. Treat their classification as weaker."
    }
}
