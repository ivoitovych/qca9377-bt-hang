#!/usr/bin/env python3
"""Assemble the self-contained task document for outside reviewers (open BT-17 work).

Reuses build.py's helpers; every code and log block is copied verbatim from its file or
from the base tree (git show), never retyped.  Usage:
  python3 -I build-tasks.py <out.md>
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build as b  # noqa: E402


def main():
    with open(os.path.join(HERE, "tasks-intro.md"), encoding="utf-8") as f:
        b.add(f.read())

    b.section("4. What is settled: our checks of seven earlier reviews, and the emulation results")
    b.md_inline("reviews/2026-11-13T1600Z-bt17-patches-reviews-checks-and-plan.md")
    b.md_inline(f"{b.EMU}/README.md")
    for name in sorted(os.listdir(os.path.join(b.ROOT, b.EMU, "logs/runs"))):
        if name.startswith("matrix-"):
            b.file_block(f"{b.EMU}/logs/runs/{name}")

    b.section("5. The emulator and harness source, in full")
    for name in sorted(os.listdir(os.path.join(b.ROOT, b.EMU, "harness"))):
        lang = {".py": "python", ".sh": "sh", ".md": "markdown"}.get(
            os.path.splitext(name)[1], "")
        b.file_block(f"{b.EMU}/harness/{name}", lang)

    b.section("6. Representative test logs (kernel and emulator lines)")
    b.add("Full logs: `results/bt17-emulation-2026-11-13/logs/runs/`, with `SHA256SUMS` and "
          "`SHA256SUMS-hardened`.\n")
    b.KEEP = re.compile(b.KEEP.pattern + r"|EMU |Opcode|reset seen|BT17-EXIT|not resetting")
    for name in ["base-h-wedge-1", "ab-h-wedge-1", "final-h-wedge-settle60-1",
                 "base-h-dropcmd-1", "final-h-dropcmd-1", "base-h-recover-1",
                 "final-h-recover-1", "base-m-close-1", "final-m-close-1", "base-bt17-2"]:
        b.log_excerpt(f"{b.EMU}/logs/runs/{name}.log")

    b.section("7. The patches, in full")
    b.add("Applied in this order on bluetooth-next `da3cc0258`. No Signed-off-by yet: the "
          "author adds his own when sending.\n")
    b.add("### CO-43 (btusb)\n")
    for name in sorted(os.listdir(os.path.join(b.ROOT, b.CO43, "patch"))):
        b.file_block(f"{b.CO43}/patch/{name}", "diff")
    b.add("### CO-44 (MGMT, and its BlueZ test)\n")
    for name in sorted(os.listdir(os.path.join(b.ROOT, b.CO44, "patch"))):
        b.file_block(f"{b.CO44}/patch/{name}", "diff")

    b.section("8. The unpatched code (bluetooth-next `da3cc0258`)")
    b.add("Extracted with `git show da3cc0258:<path>`; each definition whole.\n")
    b.source_section("drivers/bluetooth/btusb_main.c", [
        "btusb_reset", "btusb_qca_reset", "btusb_tx_complete", "btusb_close",
        "alloc_bulk_urb", "alloc_ctrl_urb", "submit_or_queue_tx_urb", "btusb_waker",
        "btusb_suspend", "play_deferred", "btusb_resume", "btusb_driver"])
    b.source_section("net/bluetooth/hci_core.c", ["hci_cmd_timeout", "hci_cmd_work"])
    b.source_section("net/bluetooth/hci_sync.c", ["__hci_cmd_sync_sk", "hci_reset_sync"])
    b.source_section("net/bluetooth/lib.c", ["bt_to_errno"])
    b.source_section("net/bluetooth/mgmt.c", ["mgmt_errno_status", "mgmt_status"])
    b.source_section("drivers/usb/core/driver.c", [
        "usb_resume_interface", "usb_resume_both", "usb_resume_complete",
        "unbind_marked_interfaces", "rebind_marked_interfaces", "autosuspend_check",
        "usb_runtime_resume"])
    b.source_section("drivers/usb/core/hub.c", [
        "finish_port_resume", "usb_reset_device", "usb_queue_reset_device"])
    b.source_section("drivers/usb/core/message.c", ["__usb_queue_reset_device"])
    b.source_section("drivers/usb/core/usb.c", ["usb_lock_device_for_reset"])
    b.source_section("drivers/usb/core/urb.c", ["usb_anchor_urb", "usb_scuttle_anchored_urbs"])
    b.source_section("include/linux/pm_runtime.h", ["pm_runtime_active"])

    b.section("9. The defects (issue register, BT-17 to BT-24)")
    text = b.read("docs/issues.md")
    a = text.index("## BT-17 —")
    m = re.search(r"\n## (?!BT-(1[7-9]|2[0-4]) )", text[a + 1:])
    body = text[a:a + 1 + m.start()] if m else text[a:]
    body = re.sub(r"^## ", "### ", body.rstrip().rstrip("-").rstrip(), flags=re.M)
    b.add("*(verbatim: `docs/issues.md`, from BT-17 to the end of BT-24)*\n")
    b.add(body + "\n")

    b.section("10. The dossiers")
    b.md_inline(f"{b.CO43}/README.md")
    b.md_inline(f"{b.CO44}/README.md")

    dest = sys.argv[1]
    if os.path.exists(dest):
        sys.exit(f"refusing to overwrite {dest}")
    with open(dest, "w", encoding="utf-8") as f:
        f.write("".join(b.out))
    print(f"written {dest}: {sum(len(s) for s in b.out)} chars")
    for item in b.missing:
        print(f"MISSING {item}")


if __name__ == "__main__":
    main()
