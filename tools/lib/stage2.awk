# stage2.awk — per boot, how long did the controller stay on the USB bus after
# it stopped answering HCI, and what ended the observation?
#
# Reads `journalctl -k -b all -o short-iso-precise`, including the
# `-- Boot <id> --` separators. Requires tools/lib/timestamp.awk for iso_secs().
#
# THE QUESTION THIS EXISTS TO ANSWER. The project believed the fault had two
# stages: HCI goes silent, then 45-66 s later the device leaves the USB bus.
# Every observation behind that figure had one of our own resets in between.
# The first observation without one showed no progression for 72 minutes.
#
# So the interval is only meaningful together with what TERMINATED it, and the
# terminator is the thing that was never recorded. Four kinds:
#
#   natural       USB disconnect with no intervention before it
#   intervened    we unloaded btusb or issued a reset first
#   shutdown      the boot ended with the device still enumerated
#   ongoing       the current boot, still running
#
# Only `natural` measures the fault. The rest are right-censored, and a
# censored observation is a LOWER BOUND on the true survival time, never an
# estimate of it. Averaging the four together is how the 45-66 s figure was
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

    if (term_kind == "disconnect" && !intervened) { cls = "NATURAL";   n_natural++ }
    else if (term_kind == "disconnect")           { cls = "intervened"; n_intervened++ }
    else if (term_kind == "unload")               { cls = "intervened"; n_intervened++ }
    else if (term_kind == "reset")                { cls = "intervened"; n_intervened++ }
    else if (term_kind == "ongoing")              { cls = "ongoing";    n_ongoing++ }
    else                                          { cls = "shutdown";   n_shutdown++ }

    printf "\n  boot %-14s first HCI timeout %s\n", substr(boot_id, 1, 12), tmo_ts
    for (i = 1; i <= nev; i++) printf "%s\n", ev[i]
    printf "      stage-1 window: %.2fs (%s)  %s\n", dur, hms(dur), cls
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
    print "Stage 1 -> stage 2: how long, and what ended the observation?"
    print "──────────────────────────────────────────────────────────────"
    boot_id = "first-boot"
}

/^-- Boot / {
    emit()
    boot_id = $3
    have_tmo = 0; intervened = 0; term_kind = ""; nev = 0
    next
}

{ last_ts = $1 }

# The window opens at the first unanswered HCI command of the boot. Later
# timeouts in the same boot are part of the same failure, not new ones.
/command( 0x[0-9a-f]+)? tx timeout/ {
    if (!have_tmo) {
        have_tmo = 1; tmo_ts = $1; intervened = 0; term_kind = ""; nev = 0
    }
    next
}

!have_tmo { next }
term_kind != "" { next }

# Ours, unambiguously: nothing else in the system unloads the driver.
/deregistering interface driver btusb/ {
    note("usbcore: deregistering interface driver btusb", "  <-- OURS")
    intervened = 1; term_kind = "unload"; term_ts = $1
    next
}

# A reset the kernel was ASKED to perform. The hub driver also resets after its
# own errors, so a reset that follows a descriptor-read failure is a symptom
# rather than an intervention — recorded, but it does not set term_kind.
/reset (full|high|low)-speed USB device/ {
    if (dev_error) { note("usb: reset after descriptor errors (hub recovery)", "") }
    else {
        note("usb: reset issued", "  <-- OURS (no preceding bus error)")
        intervened = 1; term_kind = "reset"; term_ts = $1
    }
    next
}

# Bus-level symptoms. These are the fault progressing, not an intervention.
/device descriptor read|device not accepting address|error -110|error -62/ {
    if (!dev_error) note("usb: first bus-level error", "")
    dev_error = 1
    next
}

/USB disconnect, device number/ {
    note("usb: USB disconnect", intervened ? "" : "  <-- NATURAL")
    term_kind = "disconnect"; term_ts = $1
    next
}

END {
    if (have_tmo && term_kind == "") { term_kind = "ongoing"; term_ts = last_ts
                                       term_line = "(journal ends; boot still running)" }
    emit()

    print ""
    print "──────────────────────────────────────────────────────────────"
    printf "  boots reaching stage 1        %d\n", n_boots_with_tmo + 0
    printf "    ended naturally             %d   <- the only ones that measure the fault\n", n_natural + 0
    printf "    ended by our intervention   %d\n", n_intervened + 0
    printf "    ended by shutdown           %d\n", n_shutdown + 0
    printf "    still running               %d\n", n_ongoing + 0
    print ""
    if (n_natural > 0)
        printf "  longest NATURAL stage-1 window   %.2fs (%s)\n", max_nat, hms(max_nat)
    else {
        print "  No natural progression to stage 2 has been observed."
        print "  Every stage-1 window so far was ended by us or by shutdown, so"
        print "  the fault's untreated trajectory is UNKNOWN — not 45-66s, not"
        print "  indefinite. The experiment that settles it is a boot left"
        print "  strictly alone after BT-1 until the device leaves the bus."
    }
    printf "  longest window of any kind       %.2fs (%s, %s)\n", max_any, hms(max_any), max_any_cls
}
