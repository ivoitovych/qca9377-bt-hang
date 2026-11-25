#!/usr/bin/python3 -I
"""co38-laptop-repro.py: reproduce CO-38 on the real controller, stock kernel, no build, no reboot.

Talks MGMT directly (HCI_CHANNEL_CONTROL), on index 0, and prints every reply in hex:
  1. Read Advertising Features (0x003d); stops if any instance is already listed.
  2. Add Advertising (0x003e): instance 2 only, no data, flags 0, duration 0, timeout 60 s, so the
     kernel removes it by itself if this script dies before step 4.
  3. Read Advertising Features: with the bug, instance 2 is missing (num_instances 0).
  4. Remove Advertising (0x003f) instance 2, then Read Advertising Features again.
Run on the operator's yes only (CO-38, 2026-11-25). Sends nothing else.
"""
import ctypes
import socket
import struct
import sys
import time

AF_BLUETOOTH, BTPROTO_HCI, HCI_CHANNEL_CONTROL, HCI_DEV_NONE = 31, 1, 3, 0xFFFF
INDEX = 0
OP_READ_ADV_FEATURES, OP_ADD_ADVERTISING, OP_REMOVE_ADVERTISING = 0x003D, 0x003E, 0x003F
EV_CMD_COMPLETE, EV_CMD_STATUS = 0x0001, 0x0002
EV_NAMES = {0x0023: "Advertising Added", 0x0024: "Advertising Removed"}


class SockaddrHci(ctypes.Structure):
    _fields_ = [("family", ctypes.c_ushort), ("dev", ctypes.c_ushort), ("channel", ctypes.c_ushort)]


def open_control():
    s = socket.socket(AF_BLUETOOTH, socket.SOCK_RAW | socket.SOCK_CLOEXEC, BTPROTO_HCI)
    libc = ctypes.CDLL(None, use_errno=True)
    addr = SockaddrHci(AF_BLUETOOTH, HCI_DEV_NONE, HCI_CHANNEL_CONTROL)
    if libc.bind(s.fileno(), ctypes.byref(addr), ctypes.sizeof(addr)) != 0:
        raise OSError(ctypes.get_errno(), "bind HCI_CHANNEL_CONTROL")
    s.settimeout(5.0)
    return s


def stamp():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")


def command(s, opcode, params=b""):
    s.send(struct.pack("<HHH", opcode, INDEX, len(params)) + params)
    print(f"{stamp()} > opcode 0x{opcode:04x} index {INDEX} params [{params.hex()}]")
    deadline = time.monotonic() + 5.0
    while time.monotonic() < deadline:
        pkt = s.recv(1024)
        ev, idx, plen = struct.unpack_from("<HHH", pkt)
        body = pkt[6:6 + plen]
        if ev in (EV_CMD_COMPLETE, EV_CMD_STATUS):
            op, status = struct.unpack_from("<HB", body)
            if op != opcode:
                continue
            rp = body[3:]
            kind = "Command Complete" if ev == EV_CMD_COMPLETE else "Command Status"
            print(f"{stamp()} < {kind} opcode 0x{op:04x} status 0x{status:02x} reply [{rp.hex()}]")
            return status, rp
        if ev in EV_NAMES and idx == INDEX:
            print(f"{stamp()} < event {EV_NAMES[ev]} [{body.hex()}]")
    raise TimeoutError(f"no reply to 0x{opcode:04x}")


def show_features(rp):
    flags, max_adv, max_scan, max_inst, num = struct.unpack_from("<IBBBB", rp)
    ids = list(rp[8:8 + num])
    print(f"    supported_flags 0x{flags:08x} max_adv_data_len {max_adv} max_scan_rsp_len {max_scan}"
          f" max_instances {max_inst} num_instances {num} instances {ids}")
    return num, ids


def main():
    s = open_control()
    print(f"{stamp()} step 1: Read Advertising Features")
    st, rp = command(s, OP_READ_ADV_FEATURES)
    if st != 0:
        sys.exit(f"read failed, status 0x{st:02x}")
    num, ids = show_features(rp)
    if num:
        sys.exit("instances already listed; not adding one (the result would not be clean)")

    print(f"{stamp()} step 2: Add Advertising, instance 2 only, timeout 60 s")
    add = struct.pack("<BIHHBB", 2, 0, 0, 60, 0, 0)
    st, rp = command(s, OP_ADD_ADVERTISING, add)
    if st != 0:
        sys.exit(f"add failed, status 0x{st:02x}")
    try:
        print(f"{stamp()} step 3: Read Advertising Features with instance 2 added")
        st, rp = command(s, OP_READ_ADV_FEATURES)
        num, ids = show_features(rp)
        verdict = "BUG REPRODUCED: instance 2 missing" if 2 not in ids else "instance 2 listed (no bug)"
        print(f"    RESULT: {verdict}")
    finally:
        print(f"{stamp()} step 4: Remove Advertising, instance 2")
        command(s, OP_REMOVE_ADVERTISING, struct.pack("<B", 2))
        st, rp = command(s, OP_READ_ADV_FEATURES)
        show_features(rp)


if __name__ == "__main__":
    main()
