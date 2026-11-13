#!/bin/bash
# run-guest-hostcpu.sh <same arguments as run-guest.sh>: the guest gets the host's CPU model
# (a Ryzen here), so that btusb's platform_is_ryzen() is true in the guest.
export HOSTCPU=1
exec /root/exp/agent-work/bt17-emu-20261113/scripts/run-guest.sh "$@"
