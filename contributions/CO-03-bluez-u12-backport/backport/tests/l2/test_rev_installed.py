# SPDX-License-Identifier: GPL-2.0-or-later
"""
Installed-package checks (run with an image whose bluez is installed as a
.deb, and $CO03_HOST0_BLUETOOTHD=/usr/libexec/bluetooth/bluetoothd):

R300 identity: the bluetoothd running in host0's guest is the packaged
     file: /proc/<pid>/exe, its MD5 against the package's md5sums entry,
     and dpkg's bluez version.
R310 the desktop trigger with Ubuntu 24.04's own PipeWire and WirePlumber
     (from the image, run in host0's guest): play to the Bluetooth sink;
     host1 (test fixture, slow1000) answers START after 1 s and never
     answers ABORT; right after PipeWire's Acquire() call is seen on the
     system bus (a monitor connection) the card profile is set to "off"
     (PipeWire releases the transport while START is pending); then back to
     a2dp-sink and play: the profile must be offered and media must
     reach host1.
"""

import json
import os
import re
import subprocess
import tempfile
import time
from pathlib import Path

import dbus
import pytest

from pytest_bluezenv import Bluetoothctl, DbusSession, HostPlugin, host_config
from pytest_bluezenv import utils

from .co03_plugins import A2DP_SINK_UUID, A2DP_SOURCE_UUID, CoBluetoothd, MediaApp
from .test_co03_a2dp import (
    ABORT_SENT,
    LOST,
    MODES,
    VM_MEM,
    count,
    first,
    ms,
    record,
    reps,
    wait_state,
)

pytestmark = [
    pytest.mark.vm,
    pytest.mark.skipif(
        not os.environ.get("CO03_HOST0_BLUETOOTHD", "").startswith("/usr/"),
        reason="installed-package tests: host0 must run the packaged /usr bluetoothd"),
]

REQ_TO_SUSP = re.compile(r"TRANSPORT_STATE_REQUESTING -> TRANSPORT_STATE_SUSPENDING")
ACQ_ADD = re.compile(r"media_owner_add\(\) Owner \S+ Request Acquire")


def vm_identity():
    """Runs in a VM: every running bluetoothd's executable and MD5, the
    packaged file's MD5 from dpkg's md5sums, dpkg's bluez version"""
    import hashlib
    import os
    import subprocess

    out = {"bluetoothd": []}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            exe = os.readlink(f"/proc/{pid}/exe")
        except OSError:
            continue
        if exe.split(" ")[0].endswith("/bluetoothd"):
            with open(f"/proc/{pid}/exe", "rb") as f:
                md5 = hashlib.md5(f.read()).hexdigest()
            out["bluetoothd"].append({"pid": int(pid), "exe": exe, "md5": md5})
    q = subprocess.run(["dpkg-query", "-W", "-f", "${Version} ${Status}", "bluez"],
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, encoding="utf-8")
    out["dpkg_bluez"] = q.stdout.strip()
    try:
        for line in open("/var/lib/dpkg/info/bluez.md5sums"):
            md5, path = line.split(None, 1)
            if path.strip() == "usr/libexec/bluetooth/bluetoothd":
                out["dpkg_md5"] = md5
    except OSError as exc:
        out["dpkg_md5"] = f"unreadable: {exc}"
    s = subprocess.run(["dpkg", "-S", "/usr/libexec/bluetooth/bluetoothd"],
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, encoding="utf-8")
    out["dpkg_owner"] = s.stdout.strip()
    return out


def identity_ok(ident):
    want = "/usr/libexec/bluetooth/bluetoothd"
    procs = [p for p in ident["bluetoothd"] if p["exe"] == want]
    return bool(procs) and all(p["md5"] == ident.get("dpkg_md5") for p in procs)


class StockPipeWire(HostPlugin):
    """PipeWire and WirePlumber as installed in the image (/usr/bin), in
    the guest, with their default configuration"""

    name = "pipewire"
    depends = [DbusSession()]

    def presetup(self, config):
        for exe in ("pipewire", "wireplumber", "pw-dump", "pw-cli", "pw-play"):
            if not Path("/usr/bin", exe).exists():
                pytest.skip(reason=f"{exe} not installed in this image")

    @utils.mainloop_wrap
    def setup(self, impl):
        import logging

        self.log = logging.getLogger(self.name)
        self.play_proc = None
        self.tmpdir = tempfile.TemporaryDirectory(prefix="pipewire-", dir="/run")
        rt = Path(self.tmpdir.name) / "runtime"
        st = Path(self.tmpdir.name) / "state"
        cf = Path(self.tmpdir.name) / "config"
        for d in (rt, st, cf):
            d.mkdir()
        rt.chmod(0o700)
        # The guest has no systemd-logind; WirePlumber 0.4's Bluetooth
        # monitors load the logind module by default and WirePlumber then
        # exits. Turn that one property off (a user drop-in, loaded after
        # 50-bluez-config.lua and before 90-enable-all.lua).
        lua = cf / "wireplumber" / "bluetooth.lua.d"
        lua.mkdir(parents=True)
        (lua / "51-no-logind.lua").write_text(
            'bluez_monitor.properties["with-logind"] = false\n'
            'bluez_midi_monitor.properties["with-logind"] = false\n')
        self.environ = env = dict(os.environ)
        env.update(XDG_RUNTIME_DIR=str(rt), PIPEWIRE_RUNTIME_DIR=str(rt),
                   XDG_STATE_HOME=str(st), XDG_CONFIG_HOME=str(cf),
                   PIPEWIRE_DEBUG="2", WIREPLUMBER_DEBUG="3")
        self.logger = utils.LogStream("pipewire")
        self.pw = subprocess.Popen(["/usr/bin/pipewire"], env=env,
                                   stdout=self.logger.stream, stderr=subprocess.STDOUT)
        utils.wait_until(lambda: subprocess.run(["/usr/bin/pw-dump"], env=env,
                                                stdout=subprocess.DEVNULL,
                                                timeout=5).returncode == 0)
        self.wp_logger = utils.LogStream("wireplumber")
        self.wp = subprocess.Popen(["/usr/bin/wireplumber"], env=env,
                                   stdout=self.wp_logger.stream, stderr=subprocess.STDOUT)
        bus = dbus.SystemBus()
        bus.set_exit_on_disconnect(False)
        adapter = dbus.Interface(bus.get_object("org.bluez", "/org/bluez/hci0"),
                                 "org.freedesktop.DBus.Properties")

        def ready():
            if self.pw.poll() is not None or self.wp.poll() is not None:
                raise RuntimeError("pipewire or wireplumber exited")
            uuids = [str(u) for u in adapter.Get("org.bluez.Adapter1", "UUIDs")]
            return A2DP_SOURCE_UUID in uuids

        utils.wait_until(ready)
        v = subprocess.run(["/usr/bin/pipewire", "--version"], env=env,
                           stdout=subprocess.PIPE, encoding="utf-8").stdout
        w = subprocess.run(["/usr/bin/wireplumber", "--version"], env=env,
                           stdout=subprocess.PIPE, encoding="utf-8").stdout
        self.versions = (v + w).replace("\n", " | ")
        self.log.info(f"stock PipeWire ready: {self.versions}")

    def get_versions(self):
        return self.versions

    def dump(self):
        out = subprocess.run(["/usr/bin/pw-dump"], env=self.environ, stdout=subprocess.PIPE,
                             encoding="utf-8", timeout=10).stdout
        return json.loads(out)

    def bt_device(self):
        """(id, active profile name, {profile name: available}) of the
        bluez5 device, or None"""
        for item in self.dump():
            if item.get("type") != "PipeWire:Interface:Device":
                continue
            if item["info"]["props"].get("device.api") != "bluez5":
                continue
            params = item["info"]["params"]
            active = (params.get("Profile") or [{}])[0].get("name")
            profs = {e["name"]: e.get("available") for e in params.get("EnumProfile", [])}
            idx = {e["name"]: e["index"] for e in params.get("EnumProfile", [])}
            return item["id"], active, profs, idx
        return None

    def set_profile(self, name):
        dev = self.bt_device()
        if dev is None or name not in dev[3]:
            raise ValueError(f"no profile {name}: {dev}")
        subprocess.run(["/usr/bin/pw-cli", "set-param", str(dev[0]), "Profile",
                        json.dumps({"index": dev[3][name], "save": False})],
                       env=self.environ, check=True, timeout=30)

    def arm_profile_on_acquire(self, name):
        """Watch the system bus (a monitor connection, BecomeMonitor; the
        guest runs as root) for the first MediaTransport1.Acquire call;
        right after it, set the card profile to <name> from a thread.
        bluez reports REQUESTING as "idle" on D-Bus, so the Acquire call
        itself is the only outside sign that START is about to be sent."""
        import threading

        self.acq = {"t_acquire": None, "t_off": None, "error": None}

        def fire():
            try:
                self.acq["t_off"] = time.time_ns()
                self.set_profile(name)
            except Exception as exc:
                self.acq["error"] = str(exc)[:200]

        def filt(conn, msg):
            if (self.acq["t_acquire"] is None and msg.get_type() == 1
                    and msg.get_interface() == "org.bluez.MediaTransport1"
                    and msg.get_member() == "Acquire"):
                self.acq["t_acquire"] = time.time_ns()
                threading.Thread(target=fire, daemon=True).start()

        def arm():
            self.mon_bus = dbus.SystemBus(private=True)
            self.mon_bus.set_exit_on_disconnect(False)
            self.mon_bus.add_message_filter(filt)
            self.mon_bus.call_blocking(
                "org.freedesktop.DBus", "/org/freedesktop/DBus",
                "org.freedesktop.DBus.Monitoring", "BecomeMonitor", "asu",
                (["type='method_call',interface='org.bluez.MediaTransport1'"], 0))

        utils.mainloop_invoke(arm)

    def acquire_watch_result(self):
        return dict(self.acq)

    def transport_state(self):
        """State of the first MediaTransport1 bluetoothd exports (host0
        has one A2DP transport in these tests)"""

        def get():
            bus = utils.get_dbus()
            om = dbus.Interface(bus.get_object("org.bluez", "/"),
                                "org.freedesktop.DBus.ObjectManager")
            for path, ifaces in om.GetManagedObjects().items():
                t = ifaces.get("org.bluez.MediaTransport1")
                if t is not None:
                    return str(t.get("State"))
            return None

        try:
            return utils.mainloop_invoke(get)
        except dbus.DBusException:
            return None

    def set_profile_when_pending(self, name, timeout=5.0):
        """Set the profile as soon as the transport is "pending" (bluez's
        REQUESTING: Acquire sent, START not answered); returns (VM time
        the profile was set, whether pending was seen, polls)"""
        end = time.monotonic() + timeout
        polls = 0
        seen = False
        while time.monotonic() < end:
            polls += 1
            if self.transport_state() == "pending":
                seen = True
                break
            time.sleep(0.02)
        t = time.time_ns()
        self.set_profile(name)
        return t, seen, polls

    def play(self):
        # pw-play 1.0.5 has no --raw: play a WAV file (30 s of noise)
        import wave
        wav = Path(self.tmpdir.name) / "noise.wav"
        if not wav.exists():
            with wave.open(str(wav), "wb") as w:
                w.setnchannels(2)
                w.setsampwidth(2)
                w.setframerate(44100)
                w.writeframes(os.urandom(44100 * 4 * 30))
        self.play_log = utils.LogStream("pw-play")
        self.play_proc = subprocess.Popen(
            ["/usr/bin/pw-play", "-v", str(wav)], env=self.environ,
            stdin=subprocess.DEVNULL, stdout=self.play_log.stream, stderr=subprocess.STDOUT)
        return time.time_ns()

    def stop(self):
        if getattr(self, "play_proc", None) is not None:
            self.play_proc.terminate()
            self.play_proc.wait()
            self.play_proc = None

    def teardown(self):
        self.stop()
        self.wp.terminate()
        self.pw.terminate()
        self.tmpdir.cleanup()


def installed_hosts(mode, pipewire):
    h0 = [CoBluetoothd("CO03_HOST0_BLUETOOTHD"), Bluetoothctl()]
    h0.append(StockPipeWire() if pipewire else MediaApp((A2DP_SOURCE_UUID,)))
    h1 = [CoBluetoothd("CO03_HOST1_BLUETOOTHD", env=MODES[mode]), Bluetoothctl(),
          MediaApp((A2DP_SINK_UUID,))]
    return host_config(h0, h1, mem=VM_MEM)


@installed_hosts("plain", pipewire=False)
@reps()
def test_r300_installed_identity(paired_hosts, caplog, rep):
    """R300 host0's running bluetoothd is the packaged file"""
    host0, host1 = paired_hosts
    ident = host0.call(vm_identity)
    record("r300", "plain", rep, {"identity": ident})
    assert identity_ok(ident), ident


def wait_device(host, profile, timeout=30):
    end = time.monotonic() + timeout
    dev = None
    while time.monotonic() < end:
        dev = host.pipewire.bt_device()
        if dev and dev[1] == profile:
            return dev
        time.sleep(0.2)
    raise AssertionError(f"bluez5 device not in {profile}: {dev}")


@installed_hosts("slow1000", pipewire=True)
@reps()
def test_r310_stock_pipewire_profile_off_during_start(paired_hosts, caplog, rep):
    """R310 Noble's PipeWire/WirePlumber: profile 'off' while START is
    pending, then back to a2dp-sink and play"""
    host0, host1 = paired_hosts
    ident = host0.call(vm_identity)
    host1.bluetoothctl.send(f"trust {host0.bdaddr}\n")
    host0.bluetoothctl.send("scan off\n")
    host0.bluetoothctl.send(f"connect {host1.bdaddr}\n")
    tp1 = host1.media.wait_transport(30)
    dev = wait_device(host0, "a2dp-sink")
    time.sleep(1.0)
    host0.pipewire.arm_profile_on_acquire("off")
    t0 = host0.pipewire.play()
    time.sleep(5.0)
    host0.pipewire.stop()
    w = host0.pipewire.acquire_watch_result()
    data = {"identity": ident, "versions": host0.pipewire.get_versions(),
            "profiles_before": dev[2], "off_ms": ms(w["t_off"], t0),
            "acquire_call_ms": ms(w["t_acquire"], t0), "off_error": w["error"],
            "acquire_seen_ms": ms(first(caplog, 0, ACQ_ADD, t0), t0),
            "release_while_requesting": count(caplog, 0, REQ_TO_SUSP, t0),
            "abort_sent": count(caplog, 0, ABORT_SENT, t0),
            "lost_ms": ms(first(caplog, 0, LOST, t0), t0)}
    after = host0.pipewire.bt_device()
    data["profiles_after"] = after[2] if after else None
    try:
        host0.pipewire.set_profile("a2dp-sink")
        wait_device(host0, "a2dp-sink", 15)
        data["a2dp_back"] = True
    except Exception as exc:
        data["a2dp_back"] = False
        data["a2dp_back_error"] = str(exc)[:300]
    if data["a2dp_back"]:
        time.sleep(1.0)
        host0.pipewire.play()
        tp1 = host1.media.wait_transport(10)
        data["remote_pending"] = wait_state(host1, tp1, "pending", 10)
        r1 = host1.media.results(host1.media.seq([("rx", "TryAcquire", tp1, 0)]), 10)[0]
        data["remote_tryacquire"] = r1.get("error") or ("ok" if r1.get("ok") else "none")
        packets, nbytes = host1.media.read_media(tp1, 3.0) if r1.get("ok") else (0, 0)
        data["read_packets"] = packets
        host0.pipewire.stop()
    record("r310", "slow1000", rep, data)
    failed = []
    if not identity_ok(ident):
        failed.append(f"identity {ident}")
    if not data["release_while_requesting"]:
        failed.append("trigger not reached: no Release while REQUESTING (run does not test U12)")
    if data["lost_ms"] is not None:
        failed.append(f"A2DP lost at {data['lost_ms']} ms")
    if not data["a2dp_back"]:
        failed.append(f"a2dp-sink not back: {data.get('a2dp_back_error')}")
    elif not data.get("read_packets"):
        failed.append(f"no media at host1 after the switch back ({data.get('remote_tryacquire')})")
    assert not failed, "; ".join(failed)
