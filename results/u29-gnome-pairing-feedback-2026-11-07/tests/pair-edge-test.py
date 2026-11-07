#!/usr/bin/python3
# Edge cases for a failed Device1.Pair(), widget level (widget-harness), observations only.
#
#   SCENARIO=remove : Pair() waits, the device object is removed from the mock
#                     (InterfacesRemoved, flushed to the client), waits again, then Pair()
#                     returns org.bluez.Error.$ERROR
#   SCENARIO=cancel : Pair() calls the widget's agent (RequestConfirmation); the harness
#                     presses the dialog's Cancel button; the widget answers the agent;
#                     Pair() then returns org.bluez.Error.$ERROR. What the real bluetoothd
#                     returns for a refused confirmation is NOT known here, so $ERROR is a
#                     parameter.
#   SCENARIO=peer   : Pair() returns org.bluez.Error.$ERROR at once, no user action
#
# env: OUTDIR HARNESS SCENARIO ERROR REPEAT
# Writes <tag>.stdout.log, <tag>.stderr.log and <tag>.exit (process exit status) per run;
# the cancel scenario also appends to agent-debug.txt in OUTDIR.
import os
import subprocess
import unittest

import dbus
import dbusmock

OUTDIR = os.environ.get('OUTDIR', '/out')
HARNESS = os.environ.get('HARNESS', '/work/widget-harness')
SCENARIO = os.environ.get('SCENARIO', 'remove')
ERROR = os.environ.get('ERROR', 'AuthenticationFailed')
REPEAT = int(os.environ.get('REPEAT', '1'))
ADDRESS = '11:22:33:44:55:66'

# code strings use @@ERR@@ / @@TEXT@@ tokens (no % formatting, the code contains % itself)
RAISE = 'raise dbus.exceptions.DBusException("@@TEXT@@", name="org.bluez.Error.@@ERR@@")'

REMOVE_CODE = '''
import time
from dbusmock import mockobject
time.sleep(0.5)
path = self.path
mockobject.objects["/org/bluez/hci0"].RemoveObject(path)
mockobject.objects["/"].EmitSignal("org.freedesktop.DBus.ObjectManager", "InterfacesRemoved", "oas",
                                   [dbus.ObjectPath(path), ["org.bluez.Device1"]])
# the mock loop is blocked in this method: push the signal out now, or the client
# would only see it together with the error reply
self.connection.flush()
time.sleep(1)
''' + RAISE

# Pair() must be ASYNCHRONOUS here: the agent looks the device up on org.bluez (this mock)
# while it handles RequestConfirmation, so a blocking Pair() handler deadlocks it (seen:
# confirm_callback ran 25 s late, after Pair() timed out). This code runs once, on the call
# of "Install", and replaces the synchronous mock Pair() by a dbus-python async method.
CANCEL_INSTALL = '''
import dbus.service

def make(devpath, errname, errtext):
    def pair_impl(obj, ok, err):
        bus = obj.connection
        d = open("/out/agent-debug.txt", "a")
        agent = None
        for n in bus.list_names():
            if not n.startswith(":"):
                continue
            try:
                pid = int(bus.call_blocking("org.freedesktop.DBus", "/org/freedesktop/DBus",
                                            "org.freedesktop.DBus", "GetConnectionUnixProcessID",
                                            "s", (n,)))
                if open("/proc/" + str(pid) + "/comm").read().strip() == "widget-harness":
                    agent = n
            except Exception:
                pass
        d.write("AGENT-NAME " + str(agent) + "\\n")
        def on_reply(*a):
            d.write("AGENT-REPLY accepted\\n")
            d.write("MOCK-PAIR-RETURNS org.bluez.Error." + errname + "\\n"); d.close()
            err(dbus.exceptions.DBusException(errtext, name="org.bluez.Error." + errname))
        def on_err(e):
            d.write("AGENT-REPLY error " + str(e.get_dbus_name()) + " | " + str(e.get_dbus_message()) + "\\n")
            d.write("MOCK-PAIR-RETURNS org.bluez.Error." + errname + "\\n"); d.close()
            err(dbus.exceptions.DBusException(errtext, name="org.bluez.Error." + errname))
        # the agent only accepts calls from the connection that owns org.bluez: this one
        bus.call_async(agent, "/org/gnome/bluetooth/settings", "org.bluez.Agent1",
                       "RequestConfirmation", "ou",
                       (dbus.ObjectPath(devpath), dbus.UInt32(123456)),
                       reply_handler=on_reply, error_handler=on_err, timeout=30)
    return pair_impl

impl = make(self.path, "@@ERR@@", "@@TEXT@@")
dm = dbus.service.method("org.bluez.Device1", in_signature="", out_signature="",
                         async_callbacks=("ok", "err"))(impl)
dm.__name__ = "Pair"
self.methods["org.bluez.Device1"]["Pair"] = ("", "", "", dm)
'''


class Edge(dbusmock.DBusTestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.start_system_bus()
        cls.start_session_bus()
        cls.dbus_con = cls.get_dbus(True)
        (cls.p_mock, cls.obj_bluez) = cls.spawn_server_template('bluez5', {})

    @classmethod
    def tearDownClass(cls):
        cls.p_mock.terminate()
        cls.p_mock.wait()
        super().tearDownClass()

    def fresh(self):
        self.obj_bluez.Reset()
        self.mock = dbus.Interface(self.obj_bluez, 'org.bluez.Mock')
        self.mock.AddAdapter('hci0', 'my-computer')
        self.path = self.mock.AddDevice('hci0', ADDRESS, 'My Phone')
        self.dev = dbus.Interface(self.dbus_con.get_object('org.bluez', self.path),
                                  dbusmock.MOCK_IFACE)
        text = ''.join(' ' + c if c.isupper() and i else c for i, c in enumerate(ERROR))

        def tok(code):
            return code.replace('@@TEXT@@', text).replace('@@ERR@@', ERROR)
        if SCENARIO == 'remove':
            self.dev.AddMethod('org.bluez.Device1', 'Pair', '', '', tok(REMOVE_CODE))
        elif SCENARIO == 'cancel':
            self.dev.AddMethod('org.example.Test', 'Install', '', '', tok(CANCEL_INSTALL))
            dbus.Interface(self.dbus_con.get_object('org.bluez', self.path),
                           'org.example.Test').Install()
        else:
            self.dev.AddMethod('org.bluez.Device1', 'Pair', '', '', tok(RAISE))

    def test_scenario(self):
        os.makedirs(OUTDIR, exist_ok=True)
        for i in range(1, REPEAT + 1):
            self.fresh()
            tag = '%s-%s-%d' % (SCENARIO, ERROR, i)
            env = dict(os.environ)
            env.update(G_MESSAGES_DEBUG='all', GSK_RENDERER='cairo', GSETTINGS_BACKEND='memory',
                       GDK_BACKEND='x11', GTK_A11Y='none')
            if SCENARIO == 'cancel':
                env['HARNESS_PRESS_CANCEL'] = '1'
            out = subprocess.run([HARNESS, OUTDIR, tag], env=env, capture_output=True,
                                 text=True, timeout=90)
            with open('%s/%s.stdout.log' % (OUTDIR, tag), 'w') as f:
                f.write(out.stdout)
            with open('%s/%s.stderr.log' % (OUTDIR, tag), 'w') as f:
                f.write(out.stderr)
            with open('%s/%s.exit' % (OUTDIR, tag), 'w') as f:
                f.write('%d\n' % out.returncode)
            print('RUN', tag, 'exit', out.returncode)


if __name__ == '__main__':
    unittest.main(verbosity=2)
