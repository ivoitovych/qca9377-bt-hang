#!/usr/bin/env python3
"""final.py: run the analysis scripts and keep their outputs in results/ with a SHA256SUMS file."""
import hashlib
import os
import subprocess

W = "/root/exp/agent-work/laptop-evidence-mining-20261111"
os.makedirs(W + "/results", exist_ok=True)
jobs = {
    "sco_summary_all.txt": ["sco_summary.py"] + [W + "/" + d for d in ("s3A", "s3B1", "s3B2a", "s3B2b", "s3C")],
    "links_analysis.txt": ["links_analysis.py"] + [W + "/" + d for d in ("s3A", "s3B1", "s3B2a", "s3B2b", "s3C")],
    "vgm_timeline.txt": ["vgm_timeline.py"],
    "u19.txt": ["u19.py"],
    "u14.txt": ["u14.py"],
    "inventory.txt": ["inventory.py"],
    "co20.txt": ["co20.py"],
    "alt_vs_links.txt": ["alt_vs_links.py"],
    "pids.txt": ["pids.py"],
    "u12.txt": ["u12.py"],
    "u16_refused_starts.txt": ["seq.py", r"adapter.c:start_discovery\(\)", "adapter.c:trigger_start_discovery", "3", "--from", "2026-10-25 00:00", "--max", "80", "--short", "(trigger)"],
    "a2dp_codecs_by_endpoint.txt": ["g.py", "SetConfiguration", "--ident", "bluetoothd", "--group", r"A2DPSource/(\w+)"],
    "gsd_media_keys_gvc.txt": ["g.py", r"gvc_mixer_ui_device_get_id|Failed to match stream id", "--max", "30", "--width", "200"],
    "pw_out_of_range_gain.txt": ["g.py", r"RFCOMM >> \+VG[MS]: ([2-9][0-9]|1[6-9]|[1-9][0-9]{2,})$", "--max", "20", "--width", "90"],
    "kernel_hci_quirk_lines.txt": ["g.py", "advertised, but not supported", "--group", "DAY"],
    "dumped_core_by_process.txt": ["g.py", "dumped core", "--ident", "systemd-coredump", "--group", r"Process [0-9]+ \(([^)]+)\) of user"],
    "btmon_exited_by_day.txt": ["g.py", r"btmon exited \(#[0-9]+\)", "--ident", "bt-trace", "--group", "DAY"],
    "corrupted_sco_by_day.txt": ["g.py", "corrupted SCO packet", "--group", "DAY"],
    "sco_unknown_handle_by_day.txt": ["g.py", "SCO packet for unknown connection handle", "--group", "DAY"],
    "a2dp_cancel.txt": ["g.py", r"a2dp_cancel\(\)|Failed to restore profile", "--max", "100", "--width", "120"],
}
for out, cmd in jobs.items():
    r = subprocess.run(["python3", "-I", W + "/" + cmd[0]] + cmd[1:], capture_output=True, text=True)
    with open(W + "/results/" + out, "w") as f:
        f.write(r.stdout + (("\nSTDERR:\n" + r.stderr) if r.stderr else ""))
    print(out, len(r.stdout))
with open(W + "/results/SHA256SUMS", "w") as f:
    for n in sorted(os.listdir(W + "/results")):
        if n != "SHA256SUMS":
            f.write(hashlib.sha256(open(W + "/results/" + n, "rb").read()).hexdigest() + "  " + n + "\n")
