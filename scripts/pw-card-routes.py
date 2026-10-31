#!/usr/bin/env python3
"""pw-card-routes.py — what each Bluetooth card offers, from a saved pw-dump.

    python3 -I scripts/pw-card-routes.py <pw-dump.json>

For every bluez5 device: the active Profile, each EnumProfile (index, name,
available, priority), the active Route params, and each EnumRoute (index,
name, direction, available, the profiles it belongs to, its devices). This is
what a sound panel draws its output and input lists from.

WHY (2026-10-31): GNOME Settings showed "Handsfree - MOMENTUM 4" as the only
headset output, no headphones entry; the question is whether the card itself
stopped offering the A2DP route, or the panel left it out.
"""
import json
import sys


def main():
    data = json.load(open(sys.argv[1]))
    for item in data:
        if item.get("type") != "PipeWire:Interface:Device":
            continue
        props = item["info"]["props"]
        if props.get("device.api") != "bluez5":
            continue
        params = item["info"].get("params", {})
        print(f"device {item['id']}: {props.get('device.description')}")
        for p in params.get("Profile", []):
            print(f"  active profile: {p.get('index')} {p.get('name')}")
        for p in params.get("EnumProfile", []):
            print(f"  profile {p.get('index'):>3} {p.get('name'):<34} "
                  f"available={p.get('available')} priority={p.get('priority')}")
        for r in params.get("Route", []):
            print(f"  active route: {r.get('index')} {r.get('name')} {r.get('direction')} "
                  f"device={r.get('device')} available={r.get('available')}")
        for r in params.get("EnumRoute", []):
            print(f"  route {r.get('index'):>3} {r.get('name'):<22} {r.get('direction'):<7} "
                  f"available={r.get('available')} profiles={r.get('profiles')} "
                  f"devices={r.get('devices')} desc={r.get('description')!r}")


if __name__ == "__main__":
    main()
