#!/usr/bin/env python3
"""Merge the LG detector disable into OpenRGB's settings before the server starts.

OpenRGB treats a missing detector key as enabled, then opens the 27GN950
and can save true back over the file. This runs from openrgb.service
while the server is stopped.
"""

import json
import os
import sys

DEST = os.path.expanduser("~/.config/OpenRGB/OpenRGB.json")
FRAGMENT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lg-27gn950-detector.json")


def load_wanted() -> dict:
    with open(FRAGMENT, encoding="utf-8") as fh:
        fragment = json.load(fh)
    wanted = fragment["Detectors"]["detectors"]
    if not isinstance(wanted, dict) or not wanted:
        raise SystemExit(f"no detectors in {FRAGMENT}")
    return wanted


def detectors_of(data: dict) -> dict:
    detectors = data.setdefault("Detectors", {}).setdefault("detectors", {})
    if not isinstance(detectors, dict):
        raise SystemExit(f"Detectors.detectors in {DEST} is not an object")
    return detectors


def main() -> int:
    wanted = load_wanted()
    os.makedirs(os.path.dirname(DEST), exist_ok=True)
    data: dict = {}
    if os.path.exists(DEST):
        with open(DEST, encoding="utf-8") as fh:
            data = json.load(fh)
    detectors = detectors_of(data)
    if all(detectors.get(key) is value for key, value in wanted.items()):
        return 0
    detectors.update(wanted)
    tmp = DEST + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=4)
        fh.write("\n")
    os.replace(tmp, DEST)
    with open(DEST, encoding="utf-8") as fh:
        check = json.load(fh)
    got = check["Detectors"]["detectors"]
    for key, value in wanted.items():
        if got.get(key) is not value:
            print(f"detector {key} is {got.get(key)!r}, want {value!r}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
