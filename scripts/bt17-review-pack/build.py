#!/usr/bin/env python3
"""Assemble the self-contained BT-17 patch review document.

Every code and log block is copied verbatim from its file or from the
base tree (git show), never retyped.  Usage:
  python3 -I build.py <out.md>
"""
import os
import re
import subprocess
import sys

ROOT = "/root/exp/qca9377-bt-hang"
TREE = "/root/exp/agent-work/bt17-emu-20261113/linux"
BASE = "da3cc0258"
HERE = os.path.dirname(os.path.abspath(__file__))
CO43 = "contributions/CO-43-btusb-runtime-resume-failure"
CO44 = "contributions/CO-44-mgmt-timeout-reported-as-auth-failed"
EMU = "results/bt17-emulation-2026-11-13"
INC = "results/incident-2026-11-12-1803"

missing = []
out = []


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8", errors="replace") as f:
        return f.read()


def fence(text, lang=""):
    longest = max((len(m) for m in re.findall(r"`{3,}|~{3,}", text)), default=0)
    mark = "`" * max(3, longest + 1)
    if not text.endswith("\n"):
        text += "\n"
    return f"{mark}{lang}\n{text}{mark}\n"


def add(s=""):
    out.append(s if s.endswith("\n") else s + "\n")


def file_block(rel, lang="", title=None):
    add(f"#### `{title or rel}`\n")
    add(fence(read(rel), lang))


def md_inline(rel, demote=2):
    """A markdown file, headings demoted so they nest under this document's."""
    add(f"*(verbatim: `{rel}`)*\n")
    lines = []
    infence = False
    for line in read(rel).splitlines():
        if line.startswith("```"):
            infence = not infence
        if not infence and line.startswith("#"):
            line = "#" * demote + line
        lines.append(line)
    add("\n".join(lines) + "\n")


def git_show(path):
    return subprocess.run(["git", "-C", TREE, "show", f"{BASE}:{path}"],
                          capture_output=True, text=True, check=True).stdout


def extract(src, name):
    """A top-level C definition (function or struct initializer) by name."""
    lines = src.splitlines()
    pat = re.compile(r"^[A-Za-z].*\b" + re.escape(name) + r"\b\s*(\(|=)")
    for i, line in enumerate(lines):
        if not pat.match(line) or line.rstrip().endswith(";"):
            continue
        # include a directly preceding comment block
        start = i
        if start > 0 and lines[start - 1].strip().endswith("*/"):
            j = start - 1
            while j > 0 and not lines[j].lstrip().startswith("/*"):
                j -= 1
            start = j
        for k in range(i, len(lines)):
            if lines[k].startswith("}"):
                return start + 1, "\n".join(lines[start:k + 1])
    return None, None


def source_section(path, names):
    src = git_show(path)
    for name in names:
        line, text = extract(src, name)
        if text is None:
            missing.append(f"{path}:{name}")
            add(f"*`{name}` not found in `{path}`*\n")
            continue
        add(f"#### `{path}`: `{name}` (from line {line})\n")
        add(fence(text, "c"))


ANSI = re.compile(r"\x1b\[[0-9;]*m")
KEEP = re.compile(r"RESULT|SCENARIO|step|usb 2-1|usb 1-1|btusb|Bluetooth|hci0: |"
                  r"tx timeout|reset|resume|suspend|disconnect|Resetting|PM: |"
                  r"BUG|WARNING|platform_pm|raw-gadget|not running|status 0x")
DROP = re.compile(r"cmd_cnt|dyndbg:|Calibrating")


def log_excerpt(rel, cap=220):
    kept = []
    for line in read(rel).splitlines():
        line = ANSI.sub("", line)
        if KEEP.search(line) and not DROP.search(line):
            kept.append(line)
    note = ""
    if len(kept) > cap:
        note = f"(first {cap} of {len(kept)} matching lines)\n"
        kept = kept[:cap]
    add(f"#### `{rel}`\n")
    add(f"Lines matching `{KEEP.pattern}`, without `{DROP.pattern}`, "
        f"colour codes removed. {note}")
    add(fence("\n".join(kept)))


def section(title):
    add(f"\n## {title}\n")


def main():
    with open(os.path.join(HERE, "intro.md"), encoding="utf-8") as f:
        add(f.read())

    section("3. The incident's evidence (laptop, 2026-11-12)")
    md_inline(f"{INC}/README.md")
    for name in sorted(os.listdir(os.path.join(ROOT, INC))):
        if name.startswith("excerpt-"):
            file_block(f"{INC}/{name}")

    section("4. The defects (issue register, BT-17 to BT-23)")
    text = read("docs/issues.md")
    a = text.index("## BT-17 —")
    m = re.search(r"\n## (?!BT-(1[7-9]|2[0-3]) )", text[a + 1:])
    body = text[a:a + 1 + m.start()] if m else text[a:]
    body = re.sub(r"^## ", "### ", body.rstrip().rstrip("-").rstrip(), flags=re.M)
    add("*(verbatim: `docs/issues.md`, from BT-17 to the end of BT-23)*\n")
    add(body + "\n")

    section("5. The patches, in full")
    add("Applied in this order on bluetooth-next `da3cc0258`. No Signed-off-by yet: the author "
        "adds his own when sending. The file in the tree is `drivers/bluetooth/btusb_main.c` "
        "(bluetooth-next splits btusb; Ubuntu's `7.0.0-42` still has one `btusb.c`, and all "
        "five apply to it with line offsets only).\n")
    add("### CO-43 (btusb)\n")
    for name in sorted(os.listdir(os.path.join(ROOT, CO43, "patch"))):
        file_block(f"{CO43}/patch/{name}", "diff")
    add("### CO-44 (MGMT, and its BlueZ test)\n")
    for name in sorted(os.listdir(os.path.join(ROOT, CO44, "patch"))):
        file_block(f"{CO44}/patch/{name}", "diff")
    add("### Test tool only, not a candidate\n")
    file_block(f"{EMU}/patches/debug-only/"
               "0001-DEBUG-ONLY-btusb-bt23_delay_ms-widens-the-window-aft.patch", "diff")

    section("6. The unpatched code they change (bluetooth-next `da3cc0258`)")
    add("Extracted with `git show da3cc0258:<path>`; each definition whole.\n")
    source_section("drivers/bluetooth/btusb_main.c", [
        "btusb_reset", "btusb_qca_reset", "submit_or_queue_tx_urb", "btusb_waker",
        "play_deferred", "btusb_suspend", "btusb_resume", "btusb_driver"])
    source_section("net/bluetooth/hci_core.c", ["hci_cmd_timeout"])
    source_section("net/bluetooth/mgmt.c", ["mgmt_errno_status", "mgmt_status"])
    source_section("drivers/usb/core/driver.c", [
        "usb_resume_interface", "usb_resume_complete", "unbind_marked_interfaces",
        "rebind_marked_interfaces"])
    source_section("drivers/usb/core/hub.c", [
        "finish_port_resume", "usb_reset_device", "usb_queue_reset_device"])
    source_section("drivers/usb/core/message.c", ["__usb_queue_reset_device"])

    section("7. The emulation: method and results")
    md_inline(f"{EMU}/README.md")
    for name in sorted(os.listdir(os.path.join(ROOT, EMU, "logs/runs"))):
        if name.startswith("matrix-"):
            file_block(f"{EMU}/logs/runs/{name}")

    section("8. The emulator and harness source, in full")
    for name in sorted(os.listdir(os.path.join(ROOT, EMU, "harness"))):
        lang = {".py": "python", ".sh": "sh", ".md": "markdown"}.get(
            os.path.splitext(name)[1], "")
        file_block(f"{EMU}/harness/{name}", lang)
    file_block("scripts/bt17-provoke.py", "python")
    file_block("scripts/bt17-arm-usb-debug.sh", "sh")

    section("9. Representative test logs (kernel lines)")
    add("Full logs: `results/bt17-emulation-2026-11-13/logs/runs/` with `SHA256SUMS`.\n")
    for name in ["base-bt17-2", "final-m-dead-1", "base-m-recover-1", "final-m-recover-1",
                 "base-m-close-1", "final-m-close-1", "bt23-race-bt23-1", "bt23-fix-bt23-1",
                 "final-ryzen-bt17-1", "base-pm-sysfreeze-plain-1", "base-pm-rg-plain-2"]:
        log_excerpt(f"{EMU}/logs/runs/{name}.log")

    section("10. The dossiers: state, CI results and open items")
    md_inline(f"{CO43}/README.md")
    md_inline(f"{CO44}/README.md")
    file_block(f"{CO44}/logs/excerpt.txt")
    for d in ["co43-20261113", "co44-20261113", "co44-verifyfixes-20261113",
              "co44-bluez-20261113"]:
        rel = f"tmp/bot-ci-local/{d}/summary.txt"
        if os.path.exists(os.path.join(ROOT, rel)):
            file_block(rel, title=f"{rel} (the list's CI bot, run locally)")
        else:
            missing.append(rel)

    dest = sys.argv[1]
    if os.path.exists(dest):
        sys.exit(f"refusing to overwrite {dest}")
    with open(dest, "w", encoding="utf-8") as f:
        f.write("".join(out))
    print(f"written {dest}: {sum(len(s) for s in out)} chars")
    for m in missing:
        print(f"MISSING {m}")


if __name__ == "__main__":
    main()
