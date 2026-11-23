#!/usr/bin/env python3
"""apply-co26-knob.py <kernel tree> : TEST ONLY, never sent.

Adds the module parameter bluetooth.scratch_fail_mesh_add=N: the next N
hci_add_adv_instance() calls that would create a new instance with a mesh
handle fail with -ENOMEM (default 0: no change). It recreates the research
knob of 2026-10-29 and 11-14 (tmp/co05-w4/msg-scratch.txt), without the lock
assertions. Refuses to apply twice.
"""
import sys
from pathlib import Path

f = Path(sys.argv[1]) / "net/bluetooth/hci_core.c"
s = f.read_text()
if "scratch_fail_mesh_add" in s:
    sys.exit("already applied")

anchor = "/* This function requires the caller holds hdev->lock */\nstruct adv_info *hci_add_adv_instance("
if s.count(anchor) != 1:
    sys.exit("anchor for the parameter not found exactly once")
s = s.replace(anchor,
              "static int scratch_fail_mesh_add;\t/* TEST ONLY */\n"
              "module_param(scratch_fail_mesh_add, int, 0644);\n\n" + anchor)

alloc = "\t\tadv = kzalloc_obj(*adv);\n\t\tif (!adv)\n\t\t\treturn ERR_PTR(-ENOMEM);\n"
if s.count(alloc) != 1:
    sys.exit("anchor for the injection not found exactly once")
s = s.replace(alloc,
              "\t\tif (mesh_handle && scratch_fail_mesh_add > 0) {\t/* TEST ONLY */\n"
              "\t\t\tscratch_fail_mesh_add--;\n"
              "\t\t\treturn ERR_PTR(-ENOMEM);\n"
              "\t\t}\n\n" + alloc)
f.write_text(s)
print("applied to", f)
