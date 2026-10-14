#!/usr/bin/env python3

import argparse
import glob
import json
import os
import re

DEFAULT_SYS_INPUT = "/sys/class/input"
DEFAULT_UDEV_DATA = "/run/udev/data"

KINDS = (
    ("ID_INPUT_TOUCHPAD", "touchpad"),
    ("ID_INPUT_POINTINGSTICK", "pointingstick"),
    ("ID_INPUT_MOUSE", "mouse"),
)

def read_text(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            return handle.read().strip()
    except OSError:
        return ""

def udev_properties(udev_data, numbers):
    properties = {}
    for line in read_text(os.path.join(udev_data, f"c{numbers}")).splitlines():
        if line.startswith("E:") and "=" in line:
            key, _, value = line[2:].partition("=")
            properties[key] = value
    return properties

def millimetres(properties, key):
    try:
        value = float(properties.get(key, ""))
    except ValueError:
        return None
    return value if value > 0 else None

def describe(sys_input, udev_data, node):
    name = read_text(os.path.join(sys_input, node, "device", "name"))
    numbers = read_text(os.path.join(sys_input, node, "dev"))
    if not name or not re.fullmatch(r"\d+:\d+", numbers):
        return None
    properties = udev_properties(udev_data, numbers)
    kind = next((label for key, label in KINDS if properties.get(key) == "1"), None)
    if kind is None:
        return None
    return {
        "name": name,
        "kind": kind,
        "widthMm": millimetres(properties, "ID_INPUT_WIDTH_MM"),
        "heightMm": millimetres(properties, "ID_INPUT_HEIGHT_MM"),
    }

def main():
    parser = argparse.ArgumentParser(
        description="Print the pointing devices udev knows about as a JSON list.",
    )
    parser.add_argument("--sys-input", default=DEFAULT_SYS_INPUT)
    parser.add_argument("--udev-data", default=DEFAULT_UDEV_DATA)
    args = parser.parse_args()

    nodes = sorted(
        os.path.basename(path)
        for path in glob.glob(os.path.join(args.sys_input, "event*"))
    )
    found = []
    for node in nodes:
        device = describe(args.sys_input, args.udev_data, node)
        if device is not None:
            found.append(device)
    print(json.dumps(found))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
