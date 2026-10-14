#!/usr/bin/env python3
"""Follow Tartarus Pro mode taps with the keymap indicator.

Orange is the factory layer. Blue is the WoW layer. The round mode button
is Left Alt on the boot-keyboard interface. A press shorter than 250 ms
toggles, matching input-remapper if_tap(..., 250). A longer hold is Alt
and leaves the color alone.

The macro cannot run a command, so this watches interface 0 while the
preset grabs the evdev node. The indicator is the side stripe (LED 0x0B)
on interface 2, not the key backlight. Do not GET that report (it hangs)
and do not write sysfs device_mode.

input-remapper resets $wow when its injector process restarts. This
process paints orange again when that PID changes.
"""

from __future__ import annotations

import fcntl
import glob
import json
import os
import select
import subprocess
import time

VIDPID = "HID_ID=0003:00001532:00000244"
LEFT_ALT = 0x04
TAP_S = 0.250
ORANGE = (255, 80, 0)
BLUE = (0, 0, 255)
STATE_PATH = os.path.join(
    os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")),
    "tartarus-keymap-led.json",
)
INJECT_MARK = 'Starting injecting the preset for "Razer Razer Tartarus Pro"'


def log(message: str) -> None:
    print(message, flush=True)


def find_interfaces() -> tuple[str | None, str | None]:
    """Return hidraw paths for USB interfaces 0 (keys) and 2 (lighting)."""
    boot = None
    light = None
    for node in glob.glob("/sys/class/hidraw/hidraw*"):
        try:
            uevent = open(os.path.join(node, "device/uevent"), encoding="ascii").read()
            iface = open(os.path.join(node, "device/../bInterfaceNumber"), encoding="ascii").read().strip()
        except OSError:
            continue
        if VIDPID not in uevent:
            continue
        path = "/dev/" + os.path.basename(node)
        if iface == "00":
            boot = path
        elif iface == "02":
            light = path
    return boot, light


def side_stripe(rgb: tuple[int, int, int]) -> bytearray:
    """90-byte extended-matrix static report, plus a leading hidraw report id."""
    report = bytearray(90)
    report[1] = 0x1F  # Tartarus Pro transaction id
    report[5] = 0x09
    report[6] = 0x0F  # extended matrix
    report[7] = 0x02  # set effect. 0x82 is the GET and it hangs.
    report[8] = 0x01  # VARSTORE
    report[9] = 0x0B  # SIDE_STRIPE_LED
    report[10] = 0x01  # static
    report[13] = 0x01
    report[14], report[15], report[16] = rgb
    crc = 0
    for i in range(2, 88):
        crc ^= report[i]
    report[88] = crc
    return bytearray([0x00]) + report


def paint(path: str, rgb: tuple[int, int, int]) -> None:
    buf = side_stripe(rgb)
    # HIDIOCSFEATURE: _IOC(READ|WRITE, 'H', 6, len)
    ioc = (3 << 30) | (len(buf) << 16) | (ord("H") << 8) | 6
    last = None
    for _ in range(3):
        try:
            fd = os.open(path, os.O_RDWR)
        except OSError as exc:
            last = exc
            time.sleep(0.05)
            continue
        try:
            fcntl.ioctl(fd, ioc, buf)
            return
        except OSError as exc:
            last = exc
            time.sleep(0.05)
        finally:
            os.close(fd)
    raise OSError(f"side stripe set failed on {path}: {last}")


def load_state() -> dict:
    try:
        with open(STATE_PATH, encoding="ascii") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def save_state(wow: bool, injector_pid: str | None) -> None:
    os.makedirs(os.path.dirname(STATE_PATH), exist_ok=True)
    tmp = STATE_PATH + ".tmp"
    with open(tmp, "w", encoding="ascii") as fh:
        json.dump({"wow": wow, "injector_pid": injector_pid}, fh)
    os.replace(tmp, STATE_PATH)


def injector_pid() -> str | None:
    try:
        out = subprocess.check_output(
            [
                "journalctl",
                "-u",
                "input-remapper.service",
                "-n",
                "80",
                "-o",
                "short",
                "--no-pager",
            ],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    found = None
    for line in out.splitlines():
        if INJECT_MARK not in line or "[" not in line:
            continue
        try:
            found = line.split("[", 1)[1].split("]", 1)[0]
        except IndexError:
            continue
    return found


def modifier(report: bytes) -> int | None:
    if len(report) == 8:
        return report[0]
    if len(report) == 9 and report[0] == 0:
        return report[1]
    return None


def main() -> None:
    state = load_state()
    pid = injector_pid()
    if pid is not None and pid == state.get("injector_pid"):
        wow = bool(state.get("wow"))
    else:
        wow = False
    boot_path = None
    light_path = None
    fd = None
    held_at = None
    alt_down = False
    next_pid_check = 0.0

    while True:
        if boot_path is None or light_path is None or fd is None:
            boot_path, light_path = find_interfaces()
            if not boot_path or not light_path:
                log(f"waiting for Tartarus interfaces (boot={boot_path} light={light_path})")
                time.sleep(2)
                continue
            try:
                fd = os.open(boot_path, os.O_RDWR | os.O_NONBLOCK)
            except OSError as exc:
                log(f"open {boot_path} failed: {exc}")
                fd = None
                time.sleep(2)
                continue
            try:
                paint(light_path, BLUE if wow else ORANGE)
            except OSError as exc:
                log(f"paint failed: {exc}")
            save_state(wow, pid)
            log(
                f"keymap indicator {'blue' if wow else 'orange'} "
                f"on {light_path}; watching {boot_path}; injector {pid}"
            )

        now = time.monotonic()
        if now >= next_pid_check:
            next_pid_check = now + 5
            current = injector_pid()
            if current is not None and current != pid:
                pid = current
                wow = False
                held_at = None
                alt_down = False
                try:
                    paint(light_path, ORANGE)
                    log(f"injector restarted ({pid}); indicator orange")
                except OSError as exc:
                    log(f"paint after injector restart failed: {exc}")
                save_state(wow, pid)

        readable, _, _ = select.select([fd], [], [], 1.0)
        if not readable:
            continue
        try:
            report = os.read(fd, 64)
        except OSError as exc:
            log(f"read {boot_path} failed: {exc}")
            os.close(fd)
            fd = None
            boot_path = None
            light_path = None
            continue
        if not report:
            os.close(fd)
            fd = None
            boot_path = None
            light_path = None
            continue
        mods = modifier(report)
        if mods is None:
            continue
        down = bool(mods & LEFT_ALT)
        if down and not alt_down:
            held_at = time.monotonic()
            alt_down = True
        elif alt_down and not down:
            started = held_at
            held_at = None
            alt_down = False
            if started is None:
                continue
            duration = time.monotonic() - started
            if duration >= TAP_S:
                continue
            wow = not wow
            save_state(wow, pid)
            try:
                paint(light_path, BLUE if wow else ORANGE)
                log(f"tap {duration * 1000:.0f} ms -> {'blue' if wow else 'orange'}")
            except OSError as exc:
                log(f"tap paint failed: {exc}")


if __name__ == "__main__":
    main()
