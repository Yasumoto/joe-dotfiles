#!/usr/bin/env python3
"""Lockstep spectrum across OpenRGB devices + Tartarus via OpenRazer.

This box only (scripts/host/desk-rgb). Not wired into home-manager.
OpenRGB owns fans / Aura / RAM / GPU / Mamba / Base Station.
OpenRazer owns the Tartarus only. Dygma Raise is left alone.

The LG 27GN950 is driven over its native HID video-sync protocol, not
OpenRGB. OpenRGB keeps a stale hidraw handle across USB re-enumerations,
so the monitor otherwise runs its own firmware effect and looks off-beat.

Commands:
  sync.py             run the spectrum loop (default)
  sync.py off         turn desk + monitor lighting off
  sync.py lock-watch  GNOME lock -> off, unlock -> start desk-spectrum
"""

from __future__ import annotations

import colorsys
import os
import socket
import subprocess
import sys
import time

from openrgb import OpenRGBClient
from openrgb.utils import RGBColor

SKIP_SUBSTR = ("tartarus", "raise", "commander pro", "lg 27gn", "lg monitor")
TARTARUS_SERIAL = os.environ.get("TARTARUS_SERIAL", "PM1948F36502341")
PERIOD = float(os.environ.get("SPECTRUM_PERIOD", "48"))
FPS = float(os.environ.get("SPECTRUM_FPS", "3"))
SAT = float(os.environ.get("SPECTRUM_SAT", "0.55"))
VAL = float(os.environ.get("SPECTRUM_VAL", "0.62"))
MONITOR_VAL = float(os.environ.get("SPECTRUM_MONITOR_VAL", "0.40"))
HOST = os.environ.get("OPENRGB_HOST", "127.0.0.1")
PORT = int(os.environ.get("OPENRGB_PORT", "6742"))

LG_VID_PID = "0000043E:00009A8A"
LG_VIDEO_SYNC = "a02020308d1"
LG_TURN_OFF = "f02020200dd"
SPECTRUM_UNIT = "desk-spectrum.service"


def wait_for_port(host: str, port: int, timeout: float = 60.0) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with socket.create_connection((host, port), timeout=1.0):
                return True
        except OSError:
            time.sleep(0.4)
    return False


def hsv_rgb(hue: float, sat: float, val: float) -> tuple[int, int, int]:
    r, g, b = colorsys.hsv_to_rgb(hue % 1.0, sat, val)
    return int(r * 255), int(g * 255), int(b * 255)


def clamp_component(n: int) -> int:
    # LG video-sync can crash if any RGB channel is 0.
    return min(255, max(1, n))


def tartarus_static(r: int, g: int, b: int) -> None:
    try:
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


def connect(name: str = "desk-spectrum", timeout: float = 60.0) -> OpenRGBClient:
    if not wait_for_port(HOST, PORT, timeout=timeout):
        raise SystemExit(f"OpenRGB SDK not listening on {HOST}:{PORT}")
    last_err: Exception | None = None
    for _ in range(20):
        try:
            return OpenRGBClient(address=HOST, port=PORT, name=name)
        except Exception as exc:  # noqa: BLE001
            last_err = exc
            time.sleep(0.5)
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


def lg_crc(hexdata: str) -> str:
    crc = 0
    for bit in bytearray.fromhex(hexdata):
        crc ^= bit
        for _ in range(8):
            crc <<= 1
            if crc & 0x100:
                crc ^= 0x101
    return f"{crc:02x}"


def find_lg_hidraw() -> str | None:
    hidraw = "/sys/class/hidraw"
    try:
        names = os.listdir(hidraw)
    except OSError:
        return None
    for name in names:
        uevent = os.path.join(hidraw, name, "device", "uevent")
        try:
            text = open(uevent, encoding="utf-8", errors="ignore").read()
        except OSError:
            continue
        if LG_VID_PID not in text:
            continue
        if "/input1" not in text:
            continue
        path = f"/dev/{name}"
        if os.access(path, os.W_OK):
            return path
    return None


class LGSphere:
    """Native 27GN950 HID writer. Re-finds hidraw after USB flaps."""

    def __init__(self) -> None:
        self.path: str | None = None
        self.fd: int | None = None
        self.ready = False

    def close(self) -> None:
        if self.fd is not None:
            try:
                os.close(self.fd)
            except OSError:
                pass
        self.fd = None
        self.path = None
        self.ready = False

    def _write(self, payload: bytes) -> None:
        if self.fd is None:
            raise OSError("no lg hidraw")
        n = os.write(self.fd, payload)
        if n != len(payload):
            raise OSError(f"short hidraw write {n}/{len(payload)}")

    def _send_hex(self, hexstr: str) -> None:
        self._write(bytes.fromhex(hexstr))

    def _send_command(self, cmd: str) -> None:
        padding = "0" * (119 - len(cmd))
        self._send_hex("5343c" + cmd + "4544" + padding)

    def open_hid(self) -> bool:
        path = find_lg_hidraw()
        if not path:
            self.close()
            return False
        if path == self.path and self.fd is not None:
            return True
        self.close()
        try:
            fd = os.open(path, os.O_RDWR)
        except OSError:
            return False
        self.path = path
        self.fd = fd
        self.ready = False
        return True

    def attach(self) -> bool:
        if not self.open_hid():
            return False
        if self.ready:
            return True
        try:
            self._send_command(LG_VIDEO_SYNC)
            self.ready = True
            print(f"lg video-sync on {self.path}", flush=True)
            return True
        except OSError as exc:
            print(f"lg attach failed: {exc}", file=sys.stderr, flush=True)
            self.close()
            return False

    def turn_off(self) -> bool:
        if not self.open_hid():
            return False
        try:
            self._send_command(LG_TURN_OFF)
            self.ready = False
            return True
        except OSError as exc:
            print(f"lg turn_off failed: {exc}", file=sys.stderr, flush=True)
            self.close()
            return False

    def set_color(self, r: int, g: int, b: int) -> bool:
        if not self.attach():
            return False
        color = f"{clamp_component(r):02x}{clamp_component(g):02x}{clamp_component(b):02x}"
        body = "5343c1029100" + (color * 48)
        cmd = body + lg_crc(body) + "4544"
        cmd1, cmd2, cmd3 = cmd[:128], cmd[128:256], cmd[256:] + "0" * 78
        try:
            self._send_hex(cmd1)
            self._send_hex(cmd2)
            self._send_hex(cmd3)
            return True
        except OSError as exc:
            print(f"lg frame failed: {exc}", file=sys.stderr, flush=True)
            self.close()
            return False


def lights_off() -> int:
    try:
        client = connect(name="desk-off", timeout=3.0)
    except SystemExit as exc:
        print(f"OpenRGB skip: {exc}", file=sys.stderr, flush=True)
        client = None
    if client is not None:
        for dev in active_devices(client):
            try:
                dev.off()
                print(f"off {dev.name}", flush=True)
            except Exception as exc:  # noqa: BLE001
                try:
                    dev.set_mode("direct")
                    dev.set_color(RGBColor(0, 0, 0))
                    print(f"black {dev.name}", flush=True)
                except Exception as exc2:  # noqa: BLE001
                    print(f"failed {dev.name}: {exc} / {exc2}", file=sys.stderr, flush=True)
    tartarus_static(0, 0, 0)
    lg = LGSphere()
    ok = lg.turn_off()
    print(f"lg turn_off={'ok' if ok else 'failed'} path={lg.path}", flush=True)
    lg.close()
    return 0


def _systemctl(*args: str) -> None:
    subprocess.run(["systemctl", "--user", *args], check=False)


def on_lock() -> None:
    print("session locked: stopping spectrum + lights off", flush=True)
    _systemctl("stop", SPECTRUM_UNIT)
    lights_off()


def on_unlock() -> None:
    print("session unlocked: starting spectrum", flush=True)
    _systemctl("start", SPECTRUM_UNIT)


def lock_watch() -> int:
    print("watching org.gnome.ScreenSaver ActiveChanged", flush=True)
    proc = subprocess.Popen(
        [
            "gdbus",
            "monitor",
            "--session",
            "--dest",
            "org.gnome.ScreenSaver",
            "--object-path",
            "/org/gnome/ScreenSaver",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    assert proc.stdout is not None
    try:
        for line in proc.stdout:
            if "ActiveChanged" not in line:
                continue
            if "(true" in line:
                on_lock()
            elif "(false" in line:
                on_unlock()
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                proc.kill()
    rc = proc.wait()
    return rc if rc is not None else 1


def run_spectrum() -> int:
    client = connect()
    devices = active_devices(client)
    if not devices:
        print("no OpenRGB devices to drive", file=sys.stderr)
        return 1
    set_direct(devices)
    lg = LGSphere()
    lg.attach()
    print(
        "syncing:",
        ", ".join(d.name for d in devices),
        "+ LG HID" if lg.ready else "+ LG (waiting)",
        f"(period={PERIOD}s fps={FPS} sat={SAT} val={VAL} monitor_val={MONITOR_VAL})",
        flush=True,
    )

    interval = 1.0 / max(FPS, 0.5)
    t0 = time.monotonic()
    last_desk = None
    last_monitor = None
    while True:
        hue = ((time.monotonic() - t0) / max(PERIOD, 0.5)) % 1.0
        r, g, b = hsv_rgb(hue, SAT, VAL)
        mr, mg, mb = hsv_rgb(hue, SAT, MONITOR_VAL)
        color = RGBColor(r, g, b)
        desk_key = (r, g, b)
        mon_key = (mr, mg, mb)

        if mon_key != last_monitor or not lg.ready:
            if lg.set_color(mr, mg, mb):
                last_monitor = mon_key

        for dev in devices:
            try:
                if desk_key != last_desk:
                    dev.set_color(color, fast=True)
            except Exception:
                try:
                    client = connect()
                    devices = active_devices(client)
                    set_direct(devices)
                    last_desk = None
                except Exception:
                    time.sleep(1)
                    break
        if desk_key != last_desk:
            tartarus_static(r, g, b)
        last_desk = desk_key
        time.sleep(interval)


def main() -> int:
    cmd = sys.argv[1] if len(sys.argv) > 1 else "spectrum"
    if cmd in ("spectrum", "run"):
        return run_spectrum()
    if cmd in ("off", "lights-off"):
        return lights_off()
    if cmd in ("lock-watch", "watch-lock"):
        return lock_watch()
    print("usage: sync.py [spectrum|off|lock-watch]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
