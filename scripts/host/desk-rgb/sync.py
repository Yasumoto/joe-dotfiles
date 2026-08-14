#!/usr/bin/env python3
"""Lockstep spectrum across OpenRGB devices + Tartarus via OpenRazer.

This box only (scripts/host/desk-rgb). Not wired into home-manager.
OpenRGB owns fans / Aura / RAM / GPU / Mamba / Base Station.
OpenRazer owns the Tartarus only. Dygma Raise is left alone.
"""

from __future__ import annotations

import colorsys
import os
import sys
import time

from openrgb import OpenRGBClient
from openrgb.utils import RGBColor

SKIP_SUBSTR = ("tartarus", "raise", "commander pro")
TARTARUS_SERIAL = os.environ.get("TARTARUS_SERIAL", "PM1948F36502341")
PERIOD = float(os.environ.get("SPECTRUM_PERIOD", "10"))
FPS = float(os.environ.get("SPECTRUM_FPS", "8"))
HOST = os.environ.get("OPENRGB_HOST", "127.0.0.1")
PORT = int(os.environ.get("OPENRGB_PORT", "6742"))


def hsv_rgb(hue: float) -> tuple[int, int, int]:
    r, g, b = colorsys.hsv_to_rgb(hue % 1.0, 1.0, 1.0)
    return int(r * 255), int(g * 255), int(b * 255)


def tartarus_static(r: int, g: int, b: int) -> None:
    try:
        import subprocess

        subprocess.run(
            [
                "gdbus",
                "call",
                "--session",
                "--dest",
                "org.razer",
                "--object-path",
                f"/org/razer/device/{TARTARUS_SERIAL}",
                "--method",
                "razer.device.lighting.chroma.setStatic",
                str(r),
                str(g),
                str(b),
            ],
            check=False,
            capture_output=True,
            timeout=0.5,
        )
    except Exception:
        pass


def connect() -> OpenRGBClient:
    last_err: Exception | None = None
    for _ in range(60):
        try:
            return OpenRGBClient(address=HOST, port=PORT, name="desk-spectrum")
        except Exception as exc:  # noqa: BLE001
            last_err = exc
            time.sleep(1)
    raise SystemExit(f"failed to connect to OpenRGB: {last_err}")


def active_devices(client: OpenRGBClient):
    out = []
    for dev in client.devices:
        name = (dev.name or "").lower()
        if any(s in name for s in SKIP_SUBSTR):
            continue
        if not getattr(dev, "leds", None):
            continue
        out.append(dev)
    return out


def set_direct(devices) -> None:
    for dev in devices:
        try:
            dev.set_mode("direct")
        except Exception:
            try:
                dev.set_mode("Direct")
            except Exception:
                pass


def main() -> int:
    client = connect()
    devices = active_devices(client)
    if not devices:
        print("no OpenRGB devices to drive", file=sys.stderr)
        return 1
    set_direct(devices)
    print("syncing:", ", ".join(d.name for d in devices), flush=True)

    interval = 1.0 / max(FPS, 1.0)
    t0 = time.monotonic()
    while True:
        hue = ((time.monotonic() - t0) / max(PERIOD, 0.5)) % 1.0
        r, g, b = hsv_rgb(hue)
        color = RGBColor(r, g, b)
        for dev in devices:
            try:
                dev.set_color(color, fast=True)
            except Exception:
                try:
                    client = connect()
                    devices = active_devices(client)
                    set_direct(devices)
                except Exception:
                    time.sleep(1)
                    break
        tartarus_static(r, g, b)
        time.sleep(interval)


if __name__ == "__main__":
    raise SystemExit(main())
