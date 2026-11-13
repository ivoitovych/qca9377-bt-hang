#!/usr/bin/env python3
"""Write the focused, committable log excerpts of BT-17 into results/incident-2026-11-12-1803/.

Each excerpt file starts with the exact command that produced it. Bluetooth
addresses are replaced by <addr>. Kernel dynamic-debug noise (bare "hci0:"
lines, skb/entry pointers) is dropped; the full logs are in the git-ignored
archive/incidents/20261112-bt17-controller-off-bus/.
"""
import re, subprocess, sys

OUT = "/root/exp/qca9377-bt-hang/results/incident-2026-11-12-1803"
MAC = re.compile(r"\b[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}\b")
NOISE = re.compile(r"kernel: (hci0: ?$|hci0: (entry|skb|length|end|result|opcode 0x|Opcode 0x)|hci0 cmd_cnt|0$|hci0$)")
KEEP_KERNEL = re.compile(r"13d3|btusb|Bluetooth:|usb 3-3|usb3-port3|xhci_hcd|ath10k_pci .*firmware ver|rfkill")

def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, check=True).stdout.splitlines()

def write(name, cmd, lines, note=""):
    with open(f"{OUT}/{name}", "w") as f:
        f.write("# command: " + " ".join(cmd) + "\n")
        f.write("# filter: " + note + "\n" if note else "")
        f.write("# Bluetooth addresses replaced by <addr>\n")
        for l in lines:
            f.write(MAC.sub("<addr>", l) + "\n")
    print(name, len(lines))

jk = lambda b, *a: ["journalctl", "-b", b, "_TRANSPORT=kernel", "--no-pager", "-o", "short-precise", *a]

# 1. Failing boot: kernel, controller-related, whole boot, debug noise removed.
cmd = jk("-1")
lines = [l for l in run(cmd) if KEEP_KERNEL.search(l) and not NOISE.search(l)]
write("excerpt-boot-1-kernel-controller.txt", cmd, lines,
      "lines matching " + KEEP_KERNEL.pattern + ", dynamic-debug noise dropped")

# 2. Failing boot: the last good exchange and the failure, kernel incl. debug, 18:00:26.84 to 18:00:26.85 and 18:03:08 to 18:03:20.
for since, until, tag in (("2026-11-12 18:00:26.84", "2026-11-12 18:00:26.85", "last-good"),
                          ("2026-11-12 18:03:08.8", "2026-11-12 18:03:20", "failure")):
    cmd = jk("-1", "--since", since, "--until", until)
    lines = [l for l in run(cmd) if not re.search(r"kernel: hci0: ?$|kernel: 0$|kernel: hci0$", l)]
    write(f"excerpt-boot-1-kernel-{tag}-window.txt", cmd, lines, "whole window, blank debug lines dropped")

# 3. Failing boot: bluetoothd and session lines in the trigger window.
cmd = ["journalctl", "-b", "-1", "--no-pager", "-o", "short-precise", "--since", "2026-11-12 18:03:08",
       "--until", "2026-11-12 18:03:18", "-t", "bluetoothd", "-t", "gdm-password]", "-t", "systemd-logind"]
lines = [l for l in run(cmd) if re.search(r"session opened|New session|mgmt|remove_uuid|Failed|adapter_free|index|Endpoint unregistered: sender=:1\.38 path=/MediaEndpoint/A2DPSource/ldac", l)]
write("excerpt-boot-1-userspace-trigger.txt", cmd, lines, "login, mgmt commands, failures, adapter removal")

# 4. Shutdown of the boots around it.
for b in ("-2", "-1"):
    cmd = ["journalctl", "-b", b, "--no-pager", "-o", "short-precise", "-t", "systemd-logind"]
    lines = [l for l in run(cmd) if re.search(r"will (power off|reboot)|powering down|rebooting", l)]
    write(f"excerpt-boot{b}-end.txt", cmd, lines, "how the boot ended")

# 5. Current boot: the controller does not enumerate.
cmd = jk("0")
lines = [l for l in run(cmd) if re.search(r"usb 3-3|usb3-port3|Bluetooth: Core|ath10k_pci .*firmware ver", l)]
write("excerpt-boot0-kernel-no-controller.txt", cmd, lines, "port 3-3, Bluetooth core, Wi-Fi firmware line")

# 6. Capture decode around the failure.
cap = "/root/exp/qca9377-bt-hang/tmp/incident-20261112-1803/captures/hci-20261112-180017.btsnoop"
cmd = ["btmon", "-T", "--columns=200", "-r", cap]
dec = run(cmd)
start = next(i for i, l in enumerate(dec) if "#119" in l)
end = next(i for i, l in enumerate(dec) if "Delete Index" in l)
write("excerpt-boot-1-hci-capture-decode.txt", cmd, dec[start:end + 1], "frames #119 to Delete Index")
