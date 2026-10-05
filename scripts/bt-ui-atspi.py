#!/usr/bin/env python3
"""bt-ui-atspi — record what one application's UI does, from its own
accessibility events, without changing anything in the session.

    bt-ui-atspi.py --address <a11y bus address> [--comm gnome-control-c]...

Run as the desktop user (the accessibility bus is that user's). Prints one
line per event to stdout, line-buffered:

    <iso-time> pid=<n> <event> detail=<d> v1=<i> role=<r> name='<n>' parent='<p>' [value=...] [child=...]

WHY. The userspace items in docs/issues.md (U1, U4, U6 and the operator's mark
"the Configuration line disappears for a moment") are, so far, only the
operator's account of what GNOME Settings drew. The sound panel logs nothing
about its own widgets: whether the Configuration row was hidden, which line of
the profile list was selected, when the device list changed. GTK 4 publishes
exactly that on the accessibility bus — "showing"/"visible" state changes, list
selection, focus, children added and removed — and GTK 4.14 emits those
signals whether or not anyone listens (gtk/a11y/gtkatspicontext.c, 4.14.5: the
only condition on every emit_* call is that the context has a connection). So
listening is enough; nothing has to be switched on.

HOW IT STAYS PASSIVE. It subscribes to signals with ordinary match rules on the
accessibility bus. It does NOT register as an AT-SPI event listener with the
registry (org.a11y.atspi.Registry.RegisterEvent), which is what tells GTK 3 and
other toolkits to start emitting; and it does not touch the
org.gnome.desktop.interface toolkit-accessibility setting. The only calls it
makes are reads: the bus's GetConnectionUnixProcessID for a new sender, and,
for an object it has not seen, that object's Name, role name and parent's Name
(org.a11y.atspi.Accessible), each with a short timeout and cached.

Events from other applications are dropped by process name (/proc/<pid>/comm,
15 characters: "gnome-control-c"). BoundsChanged and text-caret events are not
subscribed at all — they carry no state and would dominate the volume.

Exit: SIGTERM or SIGINT ends it cleanly. If the bus goes away (a new login)
it exits non-zero, and the systemd unit that runs it restarts it against the
new bus (bt-ui-capture asks for the address again on every start).
"""
import argparse
import os
import signal
import sys
import time

import gi

gi.require_version("Gio", "2.0")
gi.require_version("GLib", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

CALL_TIMEOUT_MS = 300
OBJ = "org.a11y.atspi.Event.Object"
SUBSCRIBE = [
    (OBJ, "StateChanged"),
    (OBJ, "ChildrenChanged"),
    (OBJ, "SelectionChanged"),
    (OBJ, "PropertyChange"),
    (OBJ, "ActiveDescendantChanged"),
    ("org.a11y.atspi.Event.Window", None),
    ("org.a11y.atspi.Event.Focus", None),
]
EVENT_NAME = {
    "StateChanged": "object:state-changed",
    "ChildrenChanged": "object:children-changed",
    "SelectionChanged": "object:selection-changed",
    "PropertyChange": "object:property-change",
    "ActiveDescendantChanged": "object:active-descendant-changed",
}


def now():
    t = time.time()
    return time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(t)) + \
        ".%03d" % int((t % 1) * 1000) + time.strftime("%z", time.localtime(t))


def out(line):
    sys.stdout.write(line + "\n")
    sys.stdout.flush()


def short(v, n=80):
    s = str(v)
    s = s.replace("\n", "\\n")
    return s if len(s) <= n else s[:n] + "..."


class Recorder:
    def __init__(self, conn, comms):
        self.conn = conn
        self.comms = set(comms)
        self.sender_pid = {}      # unique name -> pid or None (not ours)
        self.info = {}            # (sender, path) -> (role, name, parent)

    # -- reads, each bounded by a timeout -------------------------------
    def call(self, dest, path, iface, method, args, rtype):
        try:
            return self.conn.call_sync(dest, path, iface, method, args,
                                       GLib.VariantType.new(rtype) if rtype else None,
                                       Gio.DBusCallFlags.NO_AUTO_START,
                                       CALL_TIMEOUT_MS, None)
        except GLib.Error:
            return None

    def pid_of(self, sender):
        if sender in self.sender_pid:
            return self.sender_pid[sender]
        pid = None
        r = self.call("org.freedesktop.DBus", "/org/freedesktop/DBus",
                      "org.freedesktop.DBus", "GetConnectionUnixProcessID",
                      GLib.Variant("(s)", (sender,)), "(u)")
        if r is not None:
            p = r.unpack()[0]
            try:
                with open(f"/proc/{p}/comm", encoding="utf-8") as f:
                    comm = f.read().strip()
            except OSError:
                comm = ""
            if comm in self.comms:
                pid = p
                out(f"{now()} # application seen: pid={p} comm={comm} sender={sender}")
        self.sender_pid[sender] = pid
        return pid

    def prop(self, sender, path, name, rtype):
        r = self.call(sender, path, "org.freedesktop.DBus.Properties", "Get",
                      GLib.Variant("(ss)", ("org.a11y.atspi.Accessible", name)), "(v)")
        if r is None:
            return None
        v = r.unpack()[0]
        return v

    def describe(self, sender, path, refresh=False):
        key = (sender, path)
        if not refresh and key in self.info:
            return self.info[key]
        role = "?"
        r = self.call(sender, path, "org.a11y.atspi.Accessible", "GetRoleName",
                      None, "(s)")
        if r is not None:
            role = r.unpack()[0]
        name = self.prop(sender, path, "Name", "s")
        parent_name = ""
        parent = self.prop(sender, path, "Parent", "(so)")
        if isinstance(parent, tuple) and len(parent) == 2 and parent[1] not in ("", "/org/a11y/atspi/null"):
            pn = self.prop(parent[0] or sender, parent[1], "Name", "s")
            parent_name = pn if isinstance(pn, str) else ""
        res = (role, name if isinstance(name, str) else "?", parent_name)
        self.info[key] = res
        return res

    # -- the one signal handler -----------------------------------------
    def on_signal(self, conn, sender, path, iface, member, params):
        pid = self.pid_of(sender)
        if pid is None:
            return
        try:
            args = params.unpack()
        except Exception:  # noqa: BLE001 — a malformed event must not end the record
            args = ()
        if iface == OBJ:
            event = EVENT_NAME.get(member, f"object:{member}")
        elif iface.endswith(".Window"):
            event = f"window:{member.lower()}"
        else:
            event = f"focus:{member.lower()}"
        detail = args[0] if len(args) > 0 else ""
        v1 = args[1] if len(args) > 1 else ""
        extra = ""
        refresh = member == "PropertyChange" and detail == "accessible-name"
        role, name, parent = self.describe(sender, path, refresh=refresh)
        if member == "PropertyChange" and len(args) > 3:
            extra = f" value={short(args[3])!r}"
        elif member == "ChildrenChanged" and len(args) > 3 and isinstance(args[3], tuple) \
                and len(args[3]) == 2:
            crole, cname, _ = self.describe(args[3][0] or sender, args[3][1])
            extra = f" child_role={crole} child={short(cname)!r}"
        full = f"{event}:{detail}" if detail else event
        out(f"{now()} pid={pid} {full} v1={v1} role={role} name={short(name)!r} "
            f"parent={short(parent)!r}{extra} path={path}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--address", required=True, help="accessibility bus address")
    ap.add_argument("--comm", action="append", default=[],
                    help="process name to keep (default gnome-control-c)")
    a = ap.parse_args()
    comms = a.comm or ["gnome-control-c"]

    conn = Gio.DBusConnection.new_for_address_sync(
        a.address,
        Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT |
        Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION,
        None, None)
    rec = Recorder(conn, comms)
    for iface, member in SUBSCRIBE:
        conn.signal_subscribe(None, iface, member, None, None,
                              Gio.DBusSignalFlags.NONE, rec.on_signal)

    loop = GLib.MainLoop()
    rc = {"code": 0}

    def closed(_conn, _remote, _err):
        out(f"{now()} # accessibility bus connection closed")
        rc["code"] = 3
        loop.quit()

    conn.connect("closed", closed)
    for s in (signal.SIGTERM, signal.SIGINT):
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, s, lambda: (loop.quit(), False)[1])
    out(f"{now()} # bt-ui-atspi start pid={os.getpid()} comm={','.join(comms)} "
        f"(passive: match rules only, no registry listener)")
    loop.run()
    out(f"{now()} # bt-ui-atspi stop")
    return rc["code"]


if __name__ == "__main__":
    sys.exit(main())
