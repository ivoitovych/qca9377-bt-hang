# SPDX-License-Identifier: GPL-2.0-or-later
"""
Companion check for 664a5d3785a1 ("a2dp: don't change setup sep when it
is reconfiguring"): which local SEP a reconfiguration ends on when the
deferred SUSPEND of a cancelled Acquire() runs during it.

host0 registers TWO SBC source endpoints (/co03/ep0, /co03/ep1). After
connecting, the stream is on one of them (the "initial" endpoint).
SetConfiguration() on the remote SEP then asks for the OTHER endpoint
(the "target"), with a configuration that differs from the first one
(bitpool max 35 instead of 53), so both the endpoint and the
configuration bytes of the resulting stream show which SEP was used.

R251 control: the reconfiguration alone, transport idle. Must end on the
     target endpoint on every build (shows the observation works).
R252 the race: Acquire(), Release() at once (the Release waits for START,
     which host1 answers after 300 ms), SetConfiguration() for the target
     50 ms later, i.e. while START is pending. START completes, then the
     deferred SUSPEND of the cancelled Acquire (a2dp_cancel_resume_cb ->
     a2dp_suspend()) runs while the reconfiguration waits for CLOSE_RSP.
     Without 664a5d3785a1, a2dp_suspend() sets setup->sep back to the
     initial SEP before failing, and a2dp_reconfigure() then configures
     that one. Assert: the stream after the reconfiguration is on the
     target endpoint with the requested configuration; every call
     answered; no sanitizer report; a new Acquire and media work on it.
"""

import re
import time

import pytest

from pytest_bluezenv import Bluetoothctl, host_config

from .co03_plugins import A2DP_SINK_UUID, A2DP_SOURCE_UUID, CoBluetoothd, MediaApp
from .co03_plugins_rev import MediaAppRev
from .test_co03_a2dp import (
    ABORT_SENT,
    LOST,
    MODES,
    VM_MEM,
    _op,
    connect,
    count,
    first,
    ms,
    probe,
    record,
    remote_sep,
    reps,
    sanitizer_lines,
)

pytestmark = [pytest.mark.vm]

SBC_CONF_TARGET = (0x21, 0x15, 2, 35)
SUSPEND_FAILED = re.compile(r"avdtp_suspend failed|SEP in bad state for suspend")
SETUP_RECONF = re.compile(r"a2dp\.c:setup_reconfigure\(\)")
CANCEL_RESUME = re.compile(r"cancel resume")


def two_ep_hosts(mode):
    h0 = [CoBluetoothd("CO03_HOST0_BLUETOOTHD"), Bluetoothctl(),
          MediaAppRev((A2DP_SOURCE_UUID, A2DP_SOURCE_UUID))]
    h1 = [CoBluetoothd("CO03_HOST1_BLUETOOTHD", env=MODES[mode]), Bluetoothctl(),
          MediaApp((A2DP_SINK_UUID,))]
    return host_config(h0, h1, mem=VM_MEM)


def reconf_case(paired_hosts, caplog, name, mode, rep, race):
    host0, host1 = paired_hosts
    tp0, tp1 = connect(host0, host1)
    eps = host0.media.transport_endpoints()
    ep_initial = eps.get(tp0)
    conf_initial = [c for _, e, p, c in host0.media.get_setconfs() if p == tp0]
    target_index = 1 if ep_initial == "/co03/ep0" else 0
    target = f"/co03/ep{target_index}"
    sep = remote_sep(host0, host1)
    n_before = len(host0.media.get_setconfs())
    t_start = host0.call(time.time_ns)

    ids = []
    if race:
        ids = host0.media.seq([("app", "Acquire", tp0, 0), ("app", "Release", tp0, 0)])
        time.sleep(0.05)
    op = host0.media.set_configuration_caps(sep, target_index, SBC_CONF_TARGET)
    res = host0.media.results(ids + [op], 10)
    t0 = res[0].get("t_call") or t_start
    time.sleep(3.0)

    after = host0.media.get_setconfs()[n_before:]
    data = {
        "race": race,
        "ep_initial": ep_initial,
        "conf_initial": conf_initial[-1] if conf_initial else None,
        "ep_target": target,
        "conf_requested": list(SBC_CONF_TARGET),
        "ops": [_op(r) for r in res],
        "setconf_after": [{"ep": e, "transport": p, "conf": c, "ms": ms(t, t0)} for t, e, p, c in after],
        "clears": [{"ep": e, "ms": ms(t, t0)} for t, e, p in host0.media.get_clears() if t >= t0],
        "suspend_failed_lines": count(caplog, 0, SUSPEND_FAILED, t0),
        "setup_reconfigure_lines": count(caplog, 0, SETUP_RECONF, t0),
        "cancel_resume_lines": count(caplog, 0, CANCEL_RESUME, t0),
        "abort_sent": count(caplog, 0, ABORT_SENT, t0),
        "lost_ms": ms(first(caplog, 0, LOST, t0), t0),
        "sanitizer": sanitizer_lines(caplog),
    }
    data["ep_final"] = after[-1][1] if after else None
    data["conf_final"] = after[-1][3] if after else None
    cur0 = host0.media.current_transports()
    cur1 = host1.media.current_transports()
    tp_new = after[-1][2] if after else None
    if tp_new in cur0 and cur1:
        data["probe"] = probe(host0, host1, tp_new, cur1[-1])
    else:
        data["probe"] = {"flowed": False, "why": f"new transport {tp_new} current0 {cur0} current1 {cur1}"}
    record(name, mode, rep, data)

    failed = []
    if data["ep_final"] != target:
        failed.append(f"stream ended on {data['ep_final']} (SetConfiguration asked for {target}; "
                      f"initial {ep_initial})")
    if data["conf_final"] != list(SBC_CONF_TARGET):
        failed.append(f"configuration {data['conf_final']} != requested {list(SBC_CONF_TARGET)}")
    if any(o["reply"] == "none" for o in data["ops"]):
        failed.append(f"unanswered {data['ops']}")
    if data["sanitizer"]:
        failed.append(f"sanitizer {data['sanitizer'][:2]}")
    if not data["probe"].get("flowed"):
        failed.append(f"probe {data['probe']}")
    assert not failed, "; ".join(failed)


@two_ep_hosts("slow300")
@reps()
def test_r251_reconfigure_other_ep_idle(paired_hosts, caplog, rep):
    """R251 control: SetConfiguration to the other local endpoint while
    idle: the stream ends on the requested endpoint"""
    reconf_case(paired_hosts, caplog, "r251", "slow300", rep, race=False)


@two_ep_hosts("slow300")
@reps()
def test_r252_reconfigure_other_ep_during_cancelled_acquire(paired_hosts, caplog, rep):
    """R252 SetConfiguration to the other local endpoint while a
    Release() waits for the START of a cancelled Acquire(): the deferred
    SUSPEND runs during the reconfiguration; the stream must end on the
    requested endpoint"""
    reconf_case(paired_hosts, caplog, "r252", "slow300", rep, race=True)
