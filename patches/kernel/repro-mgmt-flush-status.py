#!/usr/bin/env python3
"""Reproduce the MGMT pending-command flush status bug.

Bug: cmd_complete_rsp() answers a pending command that has no
cmd_complete callback by calling cmd_status_rsp(cmd, data), where data
is a struct cmd_lookup. cmd_status_rsp() reads that pointer as a u8 *,
so the Command Status byte is the first byte of match->sk (0x00 when sk
is NULL) instead of match->mgmt_status (MGMT_STATUS_NOT_POWERED, 0x0f).

Why "Start Discovery" then "Set Powered off" from btmgmt does not hit it
---------------------------------------------------------------------------
Set Powered(off) calls hci_cmd_sync_cancel_sync(..., -EHOSTDOWN) before
queueing the power-off work. A discovery that is already running is
woken with -EHOSTDOWN. start_discovery_complete() treats only
-ECANCELED as "the flush will reply", so it sends Command Complete
itself and mgmt_pending_free()s the command. By the time
__mgmt_power_off() walks the pending list, Start Discovery is gone.

The flush sees Start Discovery only when that command is still queued
behind the power-off work, which is what happens if userspace submits
it *while power-off is already inside hci_power_off_sync()* and has not
reached __mgmt_power_off() yet. On real hardware that window is the
multi-second HCI timeout of a controller that stopped answering
(the original QCA9377 trace). This script opens that window on purpose:

  1. Virtual controller on /dev/vhci, Command Complete for every HCI
     command, with sensible payloads for the reads init actually parses.
  2. MGMT Set Powered on, then Set Connectable. Connectable makes the
     kernel send HCI Write Scan Enable (0x0c1a) with page scan, which
     sets HCI_PSCAN.
  3. MGMT Set Powered off. hci_power_off_sync() sees HCI_PSCAN and blocks
     in HCI Write Scan Enable(0). The script does not answer it.
  4. While that command is outstanding, MGMT Start Discovery (BR/EDR).
     The adapter is still HCI_UP, so the command is mgmt_pending_add()ed
     with no cmd_complete callback and queued behind the running
     power-off work.
  5. The script answers Write Scan Enable. Power-off proceeds into
     hci_dev_close_sync() -> __mgmt_power_off() -> cmd_complete_rsp().
     hci_cmd_sync_dequeue() completes the discovery work with
     -ECANCELED, start_discovery_complete() returns without replying,
     and the fall-through sends Command Status.

Oracle
------
  Command Status (event 0x0002), opcode 0x0023, status 0x0f
      Patch is in. This is MGMT_STATUS_NOT_POWERED.
  Command Status, opcode 0x0023, status 0x00
      Bug reproduced as reported (Success). Usual when the first byte
      of match->sk is 0.
  Command Status, opcode 0x0023, any other status
      Bug reproduced. A Set Powered command is pending across this
      flush, so settings_rsp() stores that socket in match->sk and the
      bogus status is the low byte of the kernel struct sock pointer,
      not the callers' mgmt_status. It must not be 0x0f once the patch
      is applied.
  Command Complete (event 0x0001) for 0x0023
      The flush path was not hit.

Requirements: root (or CAP_NET_ADMIN), ``modprobe hci_vhci``, bluetoothd
stopped so it does not race on the new index. HCI command timeout is
2s; the stall is released well inside that.

Exit status: 0 patched, 1 bug reproduced, 2 did not hit the path.
"""

import argparse
import os
import select
import struct
import sys
import threading
import time

AF_BLUETOOTH = 31
BTPROTO_HCI = 1
HCI_CHANNEL_CONTROL = 3
HCI_DEV_NONE = 0xFFFF

HCI_COMMAND_PKT = 0x01
HCI_ACLDATA_PKT = 0x02
HCI_EVENT_PKT = 0x04
HCI_VENDOR_PKT = 0xFF

MGMT_OP_SET_POWERED = 0x0005
MGMT_OP_SET_CONNECTABLE = 0x0007
MGMT_OP_START_DISCOVERY = 0x0023

MGMT_EV_CMD_COMPLETE = 0x0001
MGMT_EV_CMD_STATUS = 0x0002
MGMT_EV_INDEX_ADDED = 0x0004
MGMT_EV_INDEX_REMOVED = 0x0005
MGMT_EV_NEW_SETTINGS = 0x0006
MGMT_EV_CLASS_OF_DEV_CHANGED = 0x0007

MGMT_STATUS_SUCCESS = 0x00
MGMT_STATUS_NOT_POWERED = 0x0F
MGMT_STATUS_INVALID_INDEX = 0x11

# BR/EDR only. LE bits are not advertised, so 0x07 would be rejected.
DISCOVERY_BREDR = 0x01

HCI_WRITE_SCAN_ENABLE = 0x0C1A

STATUS_NAMES = {
    0x00: "Success",
    0x01: "Unknown Command",
    0x02: "Not Connected",
    0x03: "Failed",
    0x0A: "Busy",
    0x0B: "Rejected",
    0x0C: "Not Supported",
    0x0D: "Invalid Parameters",
    0x0E: "Disconnected",
    0x0F: "Not Powered",
    0x10: "Cancelled",
    0x11: "Invalid Index",
    0x12: "RFKilled",
}

HCI_NAMES = {
    0x0C03: "Reset",
    0x0C01: "Set Event Mask",
    0x0C05: "Set Event Filter",
    0x0C13: "Change Local Name",
    0x0C14: "Read Local Name",
    0x0C16: "Write Connection Accept Timeout",
    0x0C18: "Read Page Scan Activity",
    0x0C1A: "Write Scan Enable",
    0x0C1C: "Read Page Scan Type",
    0x0C23: "Read Class of Device",
    0x0C24: "Write Class of Device",
    0x0C25: "Read Voice Setting",
    0x0C38: "Read Number of Supported IAC",
    0x0C39: "Read Current IAC LAP",
    0x0C45: "Write Inquiry Mode",
    0x0C52: "Write Extended Inquiry Response",
    0x0C56: "Write Simple Pairing Mode",
    0x0C6D: "Write LE Host Supported",
    0x1001: "Read Local Version",
    0x1002: "Read Local Supported Commands",
    0x1003: "Read Local Supported Features",
    0x1004: "Read Local Extended Features",
    0x1005: "Read Buffer Size",
    0x1009: "Read BD ADDR",
    0x0C58: "Read Inquiry Response TX Power",
    0x201C: "LE Read Supported States",
    0x2003: "LE Read Local Features",
    0x2002: "LE Read Buffer Size",
}


def status_name(status):
    return STATUS_NAMES.get(status, "status 0x%02x" % status)


def hci_name(opcode):
    return HCI_NAMES.get(opcode, "opcode 0x%04x" % opcode)


def cmd_complete(opcode, rparams):
    """HCI Event packet: Command Complete. rparams includes the status byte."""
    if len(rparams) + 3 > 255:
        raise ValueError("Command Complete payload too long for %s" % hci_name(opcode))
    plen = 3 + len(rparams)
    return bytes([
        HCI_EVENT_PKT, 0x0E, plen, 0x01,
        opcode & 0xFF, (opcode >> 8) & 0xFF,
    ]) + rparams


def read_payload(opcode):
    """Return parameters, including status, for the reads init parses.

    Anything not listed gets a one-byte success status. Handlers that
    care about length bail out when the buffer is short; the sync status
    is still success, which is enough for the commands init always sends.
    """
    if opcode == 0x1001:  # Read Local Version
        # hci_ver 6 (4.0), so Read Local Supported Commands is issued.
        # manufacturer is meaningless here.
        return struct.pack("<BBH B H H", 0x00, 0x06, 0x0001, 0x06, 0xFFFF, 0x0001)
    if opcode == 0x1009:  # Read BD ADDR
        return bytes([0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66])
    if opcode == 0x1003:  # Read Local Supported Features
        # All zeros: BR/EDR capable (LMP_NO_BREDR clear), no LE, no SSP.
        # Init then skips the LE and extended-feature stages.
        return bytes(9)
    if opcode == 0x1002:  # Read Local Supported Commands
        return bytes(65)
    if opcode == 0x1005:  # Read Buffer Size
        # acl_mtu=1021, sco_mtu=0, acl_pkts=8, sco_pkts=0
        return struct.pack("<BHBHH", 0x00, 1021, 0, 8, 0)
    if opcode == 0x0C23:  # Read Class of Device
        return bytes(4)
    if opcode == 0x0C14:  # Read Local Name
        return bytes(249)
    if opcode == 0x0C25:  # Read Voice Setting
        return struct.pack("<BH", 0x00, 0x0060)
    if opcode == 0x0C38:  # Read Num Supported IAC
        return bytes([0x00, 0x01])
    if opcode == 0x0C39:  # Read Current IAC LAP (num + GIAC)
        return bytes([0x00, 0x01, 0x33, 0x8B, 0x9E])
    return bytes([0x00])


class VirtualController(threading.Thread):
    def __init__(self):
        super().__init__(name="vhci", daemon=True)
        self.fd = None
        self.index = None
        self.ready = threading.Event()
        self.stalled = threading.Event()
        self.release = threading.Event()
        self.stop = threading.Event()
        self.armed = threading.Event()
        self.error = None
        self.saw_page_scan = threading.Event()
        self._held = None
        self._log = []
        self._lock = threading.Lock()

    def log(self, msg):
        line = "%.3f %s" % (time.time(), msg)
        with self._lock:
            self._log.append(line)
        print("  hci " + msg, flush=True)

    def dump_log(self):
        with self._lock:
            return list(self._log)

    def arm(self):
        self.armed.set()

    def run(self):
        try:
            self._run()
        except Exception as exc:
            self.error = exc
            self.log("controller thread failed: %s" % exc)
            self.ready.set()
            self.stalled.set()

    def _run(self):
        try:
            self.fd = os.open("/dev/vhci", os.O_RDWR)
        except OSError as exc:
            self.error = exc
            self.ready.set()
            return

        # Primary controller. bits 0-1 = HCI_PRIMARY, nothing else set.
        os.write(self.fd, bytes([HCI_VENDOR_PKT, 0x00]))

        poll = select.poll()
        poll.register(self.fd, select.POLLIN)
        buf = b""

        while not self.stop.is_set():
            if self._held is not None and self.release.is_set():
                opcode, _params = self._held
                self._held = None
                self.log("release stalled %s" % hci_name(opcode))
                os.write(self.fd, cmd_complete(opcode, bytes([0x00])))

            events = poll.poll(100)
            if not events:
                continue
            try:
                chunk = os.read(self.fd, 4096)
            except OSError as exc:
                self.error = exc
                break
            if not chunk:
                break
            buf += chunk
            while True:
                pkt, buf = take_packet(buf)
                if pkt is None:
                    break
                self._handle(pkt)

        self.ready.set()

    def close(self):
        self.stop.set()
        self.release.set()
        fd = self.fd
        self.fd = None
        if fd is not None:
            try:
                os.close(fd)
            except OSError:
                pass

    def _handle(self, pkt):
        ptype = pkt[0]
        if ptype == HCI_VENDOR_PKT:
            # Fixed 2026-09-24: the reply is 0xff, opcode, le16 index — 4 bytes,
            # no second 0xff (hci_vhci.c __vhci_create_device()).
            if len(pkt) >= 4:
                self.index = pkt[2] | (pkt[3] << 8)
                self.log("virtual hci%d created" % self.index)
                self.ready.set()
            else:
                self.log("vendor packet %s" % pkt.hex())
            return
        if ptype != HCI_COMMAND_PKT:
            self.log("ignored pkt type 0x%02x len %d" % (ptype, len(pkt)))
            return
        if len(pkt) < 4:
            return
        opcode = pkt[1] | (pkt[2] << 8)
        plen = pkt[3]
        params = pkt[4:4 + plen]
        self.log("cmd %s params %s" % (hci_name(opcode), params.hex() or "-"))

        if (opcode == HCI_WRITE_SCAN_ENABLE and params[:1] == b"\x02"):
            self.saw_page_scan.set()

        if (self.armed.is_set() and self._held is None and not self.stalled.is_set()
                and opcode == HCI_WRITE_SCAN_ENABLE and params[:1] == b"\x00"):
            self._held = (opcode, params)
            self.log("STALL %s (power-off window is open)" % hci_name(opcode))
            self.stalled.set()
            return

        os.write(self.fd, cmd_complete(opcode, read_payload(opcode)))


def take_packet(buf):
    if not buf:
        return None, buf
    ptype = buf[0]
    if ptype == HCI_COMMAND_PKT:
        if len(buf) < 4:
            return None, buf
        need = 4 + buf[3]
    elif ptype == HCI_ACLDATA_PKT:
        if len(buf) < 5:
            return None, buf
        need = 5 + (buf[3] | (buf[4] << 8))
    elif ptype == HCI_EVENT_PKT:
        if len(buf) < 3:
            return None, buf
        need = 3 + buf[2]
    elif ptype == HCI_VENDOR_PKT:
        # Create-device reply: 0xff + opcode + le16 id = 4 bytes (fixed
        # 2026-09-24; the original expected 5 and swallowed the next packet).
        need = 4
    else:
        # Drop an unknown byte rather than wedging the stream.
        return buf[:1], buf[1:]
    if len(buf) < need:
        return None, buf
    return buf[:need], buf[need:]


class Mgmt:
    def __init__(self):
        self.sock = socket_mod().socket(AF_BLUETOOTH, socket_mod().SOCK_RAW, BTPROTO_HCI)
        addr = struct.pack("HHH", AF_BLUETOOTH, HCI_DEV_NONE, HCI_CHANNEL_CONTROL)
        # Fixed 2026-09-24: Python's socket.bind() rejects a packed sockaddr_hci
        # ("wrong format") and its tuple form has no channel on this Python;
        # bind through libc, as this project's bin/bt-capture does.
        import ctypes, ctypes.util
        libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)
        if libc.bind(self.sock.fileno(), addr, len(addr)) != 0:
            err = ctypes.get_errno()
            raise OSError(err, os.strerror(err))
        self.sock.setblocking(False)
        self._buf = b""
        self.events = []
        self._cond = threading.Condition()
        self._stop = False
        self._thread = threading.Thread(target=self._reader, name="mgmt", daemon=True)
        self._thread.start()

    def close(self):
        self._stop = True
        try:
            self.sock.close()
        except OSError:
            pass

    def _reader(self):
        poll = select.poll()
        poll.register(self.sock, select.POLLIN)
        while not self._stop:
            if not poll.poll(200):
                continue
            try:
                chunk = self.sock.recv(4096)
            except OSError:
                break
            if not chunk:
                break
            self._buf += chunk
            frames = []
            while len(self._buf) >= 6:
                opcode, index, length = struct.unpack_from("<HHH", self._buf)
                if len(self._buf) < 6 + length:
                    break
                payload = self._buf[6:6 + length]
                self._buf = self._buf[6 + length:]
                frames.append((opcode, index, payload))
            if frames:
                with self._cond:
                    self.events.extend(frames)
                    self._cond.notify_all()

    def send(self, opcode, index, param=b""):
        hdr = struct.pack("<HHH", opcode, index, len(param))
        self.sock.send(hdr + param)

    def wait(self, predicate, timeout):
        deadline = time.time() + timeout
        with self._cond:
            while True:
                for i, ev in enumerate(self.events):
                    if predicate(ev):
                        return self.events.pop(i)
                remain = deadline - time.time()
                if remain <= 0:
                    return None
                self._cond.wait(remain)


def socket_mod():
    import socket
    return socket


def describe_event(opcode, index, payload):
    if opcode in (MGMT_EV_CMD_STATUS, MGMT_EV_CMD_COMPLETE) and len(payload) >= 3:
        cmd = payload[0] | (payload[1] << 8)
        status = payload[2]
        data = payload[3:]
        kind = "Command Status" if opcode == MGMT_EV_CMD_STATUS else "Command Complete"
        extra = ""
        if opcode == MGMT_EV_CMD_COMPLETE:
            extra = " param %s" % (data.hex() or "-")
        return "%s index %d opcode 0x%04x status 0x%02x (%s)%s" % (
            kind, index, cmd, status, status_name(status), extra)
    if opcode == MGMT_EV_NEW_SETTINGS and len(payload) >= 4:
        settings = struct.unpack_from("<I", payload)[0]
        return "New Settings index %d 0x%08x" % (index, settings)
    if opcode == MGMT_EV_CLASS_OF_DEV_CHANGED:
        return "Class of Device Changed index %d %s" % (index, payload.hex())
    if opcode == MGMT_EV_INDEX_ADDED:
        return "Index Added %d" % index
    if opcode == MGMT_EV_INDEX_REMOVED:
        return "Index Removed %d" % index
    return "event 0x%04x index %d param %s" % (opcode, index, payload.hex())


def wait_cmd(mgmt, index, cmd_opcode, timeout):
    def match(ev):
        opcode, ev_index, payload = ev
        if ev_index != index or len(payload) < 3:
            return False
        if opcode not in (MGMT_EV_CMD_STATUS, MGMT_EV_CMD_COMPLETE):
            return False
        cmd = payload[0] | (payload[1] << 8)
        return cmd == cmd_opcode

    ev = mgmt.wait(match, timeout)
    if ev is None:
        return None
    print("  mgmt " + describe_event(*ev), flush=True)
    return ev


def command_result(ev):
    opcode, _index, payload = ev
    if opcode not in (MGMT_EV_CMD_STATUS, MGMT_EV_CMD_COMPLETE) or len(payload) < 3:
        return None, None
    kind = "status" if opcode == MGMT_EV_CMD_STATUS else "complete"
    return kind, payload[2]


def bluetoothd_running():
    proc = "/proc"
    try:
        names = os.listdir(proc)
    except OSError:
        return False
    for name in names:
        if not name.isdigit():
            continue
        try:
            with open(os.path.join(proc, name, "comm"), "rb") as fh:
                comm = fh.read().strip()
        except OSError:
            continue
        if comm == b"bluetoothd":
            return True
    return False


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("--hold", type=float, default=0.3,
                        help="seconds to keep Write Scan Enable stalled "
                             "after Start Discovery is submitted "
                             "(must stay under the 2s HCI timeout; default 0.3)")
    parser.add_argument("--timeout", type=float, default=8.0,
                        help="timeout for power-on and connectable (default 8)")
    args = parser.parse_args()

    if args.hold < 0 or args.hold > 1.5:
        print("--hold must be between 0 and 1.5 (HCI command timeout is 2s)",
              file=sys.stderr)
        return 2

    if os.geteuid() != 0:
        print("must run as root (needs /dev/vhci and the MGMT control socket)",
              file=sys.stderr)
        return 2
    if not os.path.exists("/dev/vhci"):
        print("/dev/vhci is missing. Load the virtual HCI driver:",
              file=sys.stderr)
        print("  modprobe hci_vhci", file=sys.stderr)
        return 2
    if bluetoothd_running():
        print("bluetoothd is running. It will race for the new adapter.",
              file=sys.stderr)
        print("  systemctl stop bluetooth", file=sys.stderr)
        return 2

    try:
        with open("/proc/version", "r", encoding="utf-8", errors="replace") as fh:
            print(fh.readline().strip())
    except OSError:
        pass

    ctrl = VirtualController()
    ctrl.start()
    if not ctrl.ready.wait(3):
        print("timed out creating the virtual controller", file=sys.stderr)
        ctrl.close()
        return 2
    if ctrl.error is not None or ctrl.index is None:
        print("failed to create virtual controller: %s" % ctrl.error,
              file=sys.stderr)
        ctrl.close()
        return 2

    index = ctrl.index
    print("using hci%d" % index)
    mgmt = Mgmt()
    rc = 2
    try:
        print("power on")
        mgmt.send(MGMT_OP_SET_POWERED, index, bytes([0x01]))
        ev = wait_cmd(mgmt, index, MGMT_OP_SET_POWERED, args.timeout)
        if ev is None:
            print("no reply to Set Powered on; HCI log:", file=sys.stderr)
            for line in ctrl.dump_log():
                print(" ", line, file=sys.stderr)
            return 2
        kind, status = command_result(ev)
        if kind != "complete" or status != MGMT_STATUS_SUCCESS:
            print("Set Powered on failed", file=sys.stderr)
            return 2

        print("set connectable (so power-off emits Write Scan Enable)")
        mgmt.send(MGMT_OP_SET_CONNECTABLE, index, bytes([0x01]))
        ev = wait_cmd(mgmt, index, MGMT_OP_SET_CONNECTABLE, args.timeout)
        if ev is None or command_result(ev) != ("complete", MGMT_STATUS_SUCCESS):
            print("Set Connectable failed", file=sys.stderr)
            return 2
        if not ctrl.saw_page_scan.is_set():
            print("kernel never sent Write Scan Enable(page). "
                  "Power-off will not block and the flush window will not open.",
                  file=sys.stderr)
            return 2

        print("power off, stalling HCI Write Scan Enable(0)")
        ctrl.arm()
        mgmt.send(MGMT_OP_SET_POWERED, index, bytes([0x00]))
        if not ctrl.stalled.wait(3):
            print("power-off did not send Write Scan Enable(0) within 3s",
                  file=sys.stderr)
            print("HCI log:", file=sys.stderr)
            for line in ctrl.dump_log():
                print(" ", line, file=sys.stderr)
            return 2

        print("submit Start Discovery while power-off is blocked")
        mgmt.send(MGMT_OP_START_DISCOVERY, index, bytes([DISCOVERY_BREDR]))
        time.sleep(args.hold)
        print("release stall after %.2fs" % args.hold)
        ctrl.release.set()

        print("waiting for the Start Discovery reply")
        ev = wait_cmd(mgmt, index, MGMT_OP_START_DISCOVERY, 5)
        # Drain the power-off completion and the New Settings that
        # __mgmt_power_off() emits after the flush, for the log.
        end = time.time() + 2
        while time.time() < end:
            extra = mgmt.wait(lambda e: e[1] == index, 0.2)
            if extra is None:
                continue
            # The discovery reply was already popped.
            print("  mgmt " + describe_event(*extra), flush=True)

        if ev is None:
            print("no Start Discovery reply", file=sys.stderr)
            return 2

        kind, status = command_result(ev)
        print()
        if kind == "status" and status == MGMT_STATUS_NOT_POWERED:
            print("PATCHED: Command Status 0x0f (Not Powered).")
            print("The flush passed match->mgmt_status through.")
            rc = 0
        elif kind == "status" and status == MGMT_STATUS_INVALID_INDEX:
            print("PATCHED: Command Status 0x11 (Invalid Index).")
            print("The flush passed match->mgmt_status through "
                  "(unregister path).")
            rc = 0
        elif kind == "status":
            print("BUG REPRODUCED: Command Status for Start Discovery "
                  "is 0x%02x (%s), not 0x0f (Not Powered)."
                  % (status, status_name(status)))
            if status == MGMT_STATUS_SUCCESS:
                print("This is the reported failure: a zero-length Success, "
                      "which is what crashes bluetoothd's "
                      "start_discovery_complete().")
            else:
                print("Set Powered was still pending, so the bogus byte is "
                      "the low 8 bits of match->sk (a kernel struct sock *), "
                      "not a real MGMT status. The patch makes this 0x0f.")
            rc = 1
        else:
            print("DID NOT HIT THE FLUSH: Start Discovery got Command "
                  "Complete status 0x%02x (%s)." % (status, status_name(status)))
            print("start_discovery_complete() replied itself. The pending "
                  "command was not still queued when __mgmt_power_off() ran.")
            rc = 2
        return rc
    finally:
        mgmt.close()
        ctrl.close()
        ctrl.join(timeout=2)


if __name__ == "__main__":
    sys.exit(main())
