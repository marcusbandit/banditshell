#!/usr/bin/env python3

import colorsys
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from palette import pixels

HUES = [
    (15, "red"),
    (45, "orange"),
    (70, "yellow"),
    (170, "green"),
    (255, "blue"),
    (295, "purple"),
    (340, "pink"),
    (360, "red"),
]

VIVID = 0.35
LIT = 0.25
SHARE = 0.03
DARK = 0.22
LIGHT = 0.72


def groups(px):
    weights = {}
    vivid = 0
    light = 0.0
    for r, g, b in px:
        hue, saturation, value = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        light += (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
        if saturation < VIVID or value < LIT:
            continue
        vivid += 1
        name = next(n for top, n in HUES if hue * 360 < top)
        weights[name] = weights.get(name, 0.0) + saturation * value
    light /= len(px)
    colourful = vivid / len(px) >= SHARE

    out = []
    if colourful:
        out.append(max(weights, key=weights.get))
    if light < DARK:
        out.append("black")
    elif light > LIGHT:
        out.append("white")
    elif not colourful:
        out.append("black" if light < 0.5 else "white")
    return out


def main():
    if len(sys.argv) < 2:
        print("usage: wallpaper-colours.py <cache.json> [file...]", file=sys.stderr)
        return 2

    cache_path = sys.argv[1]
    try:
        with open(cache_path) as f:
            cache = json.load(f)
    except (OSError, ValueError):
        cache = {}

    kept = {path: entry for path, entry in cache.items() if isinstance(entry, dict) and os.path.exists(path)}
    for path in sys.argv[2:]:
        try:
            st = os.stat(path)
        except OSError:
            continue
        stamp = [st.st_mtime_ns, st.st_size]
        known = cache.get(path)
        if isinstance(known, dict) and known.get("stamp") == stamp:
            found = known.get("groups", [])
        else:
            px = pixels(path)
            found = groups(px) if px else []
        kept[path] = {"stamp": stamp, "groups": found}
        print(f"{path}\t{' '.join(found)}", flush=True)

    os.makedirs(os.path.dirname(cache_path) or ".", exist_ok=True)
    temporary = f"{cache_path}.{os.getpid()}"
    with open(temporary, "w") as f:
        json.dump(kept, f)
    os.replace(temporary, cache_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
