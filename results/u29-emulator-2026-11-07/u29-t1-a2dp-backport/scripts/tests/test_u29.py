# SPDX-License-Identifier: GPL-2.0-or-later
"""
U29: Device1.Connect() when the stored link key no longer matches the peer.

host0: bluetoothd under test ($U29_HOST0_BLUETOOTHD), A2DP source
host1: peer, unmodified baseline bluetoothd ($U29_HOST1_BLUETOOTHD), A2DP sink

Steps: pair; drop the ACL; replace host0's kernel key with a wrong one;
optionally hold an unsecured ACL (U29_ACL=hold); Device1.Connect() from a
D-Bus client; write the evidence to $U29_OUT/rep-N/.
"""

import json
import os
import re
import subprocess
import time
from pathlib import Path

import pytest

from pytest_bluezenv import Bluetoothctl, host_config

from .u29_plugins import A2DP_SINK_UUID, A2DP_SOURCE_UUID, CoBluetoothd, U29Ops

pytestmark = [pytest.mark.vm]

REPS = int(os.environ.get("U29_REPS", "5"))
ACL = os.environ.get("U29_ACL", "none")


def vm_unpair(peer):
    from pytest_bluezenv import utils

    exe = utils.find_exe("tools", "btmgmt")
    res = subprocess.run([exe, "--index", "0", "unpair", peer],
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         encoding="utf-8", timeout=10)
    return res.stdout


def vm_dump_state(peer):
    """stored info file of <peer> (key redacted) and kernel link keys seen
    by btmgmt"""
    import glob

    out = []
    for p in glob.glob(f"/run/bluetoothd-state-*/state/*/{peer.upper()}/info"):
        for line in open(p).read().splitlines():
            if line.startswith("Key="):
                line = "Key=<redacted>"
            out.append(line)
    return "\n".join(out)


hosts_cfg = host_config(
    [CoBluetoothd("U29_HOST0_BLUETOOTHD"), Bluetoothctl(), U29Ops(A2DP_SOURCE_UUID)],
    [CoBluetoothd("U29_HOST1_BLUETOOTHD"), Bluetoothctl(), U29Ops(A2DP_SINK_UUID)],
    mem="784M",
)


def lines(caplog, idx, name="bluetoothd"):
    pat = re.compile(rf"^host\.\d+\.{idx}\.{name}$")
    return [(r.created, r.getMessage()) for r in list(caplog.records) if pat.match(r.name)]


@hosts_cfg
@pytest.mark.parametrize("rep", range(REPS))
def test_u29_connect_refused(hosts, caplog, rep):
    host0, host1 = hosts
    out = Path(os.environ["U29_OUT"]) / f"rep-{rep}"
    out.mkdir(parents=True, exist_ok=True)
    ev = {}

    host0.call(vm_unpair, host1.bdaddr)
    host1.call(vm_unpair, host0.bdaddr)

    # pair, host0 initiating (same steps as CO-03's paired_hosts)
    host0.bluetoothctl.send("scan on\n")
    host0.bluetoothctl.expect(f"Controller {host0.bdaddr.upper()} Discovering: yes")
    host1.bluetoothctl.send("pairable on\n")
    host1.bluetoothctl.expect("Changing pairable on succeeded")
    host1.bluetoothctl.send("discoverable on\n")
    host1.bluetoothctl.expect(f"Controller {host1.bdaddr.upper()} Discoverable: yes")
    host0.bluetoothctl.expect(f"Device {host1.bdaddr.upper()}")
    host0.bluetoothctl.send(f"pair {host1.bdaddr}\n")
    idx, m = host0.bluetoothctl.expect(r"Confirm passkey (\d+).*:")
    key = m[0].decode("utf-8")
    host1.bluetoothctl.expect(f"Confirm passkey {key}")
    host0.bluetoothctl.send("yes\n")
    host1.bluetoothctl.send("yes\n")
    host0.bluetoothctl.expect("Pairing successful")
    host1.bluetoothctl.send(f"trust {host0.bdaddr}\n")
    host0.bluetoothctl.send(f"trust {host1.bdaddr}\n")
    host0.bluetoothctl.send("scan off\n")
    host0.bluetoothctl.send(f"disconnect {host1.bdaddr}\n")
    time.sleep(6.0)   # the idle ACL of the pairing goes away

    ev["state_host0"] = host0.call(vm_dump_state, host1.bdaddr)
    def hold():
        try:
            ev["hold_acl"] = host0.u29.hold_acl(host1.bdaddr)
        except Exception as exc:  # recorded, the run goes on
            ev["hold_acl"] = f"failed: {exc!r}"

    if ACL == "hold_before_key":
        hold()
    old, new, status = host0.u29.set_wrong_key(host1.bdaddr)
    ev["mgmt_load_link_keys_status"] = status
    ev["key_replaced"] = old != new
    if ACL == "hold_after_key":
        hold()
    ev["acl_mode"] = ACL

    path = f"/org/bluez/hci0/dev_{host1.bdaddr.upper().replace(':', '_')}"
    ev["device_path"] = path
    t0 = time.time()
    cid = host0.u29.call(path, "Connect")
    res = host0.u29.result(cid, 40)
    ev["connect"] = {k: v for k, v in res.items() if k not in ("client",)}
    ev["connect_seconds"] = round((time.time() - t0), 3)
    time.sleep(1.0)

    l0 = lines(caplog, 0)
    l1 = lines(caplog, 1)
    (out / "bluetoothd-host0.log").write_text("\n".join(m for _, m in l0) + "\n")
    (out / "bluetoothd-host1.log").write_text("\n".join(m for _, m in l1) + "\n")
    pat = re.compile(r"avdtp_connect_cb\(\) connect to .*Connection refused \(111\)")
    ev["avdtp_connect_cb_refused_111"] = any(pat.search(m) for _, m in l0)
    ev["a2dp_state_lines"] = [m for _, m in l0 if "state changed" in m]
    (out / "dbus-reply.json").write_text(json.dumps(ev, indent=2, sort_keys=True) + "\n")
    with open(Path(os.environ["U29_OUT"]) / "results.jsonl", "a") as f:
        f.write(json.dumps(dict(rep=rep, **ev), sort_keys=True) + "\n")
