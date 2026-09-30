#!/usr/bin/env python3
"""What colours a wallpaper is mostly made of."""

import os
import shutil
import subprocess
import sys

WIDTH, HEIGHT = 96, 54

COLOURS = 6
ROUNDS = 20

FLOOR = 0.02

def pixels(path):
    """The picture as a flat list of (r, g, b), or an empty list."""
    if path.lower().endswith(".svg"):
        rsvg = shutil.which("rsvg-convert")
        if not rsvg:
            return []
        out = subprocess.run(
            [rsvg, "-w", str(WIDTH), "-h", str(HEIGHT), "-f", "png", path],
            capture_output=True,
        )
        if out.returncode != 0 or not out.stdout:
            return []
        raw = subprocess.run(
            ["ffmpeg", "-v", "error", "-i", "pipe:0", "-frames:v", "1",
             "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
            input=out.stdout, capture_output=True,
        )
    else:
        raw = subprocess.run(
            ["ffmpeg", "-v", "error", "-i", path, "-frames:v", "1",
             "-vf", f"scale={WIDTH}:{HEIGHT}:flags=area",
             "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
            capture_output=True,
        )

    if raw.returncode != 0 or not raw.stdout:
        return []
    b = raw.stdout
    return [(b[i], b[i + 1], b[i + 2]) for i in range(0, len(b) - 2, 3)]

def seeds(px):
    """Starting centroids: the fullest bins of a coarse grid, spread out."""
    bins = {}
    for r, g, b in px:
        key = (r * 6 // 256, g * 6 // 256, b * 6 // 256)
        bins[key] = bins.get(key, 0) + 1

    picked = []
    for key, _ in sorted(bins.items(), key=lambda kv: -kv[1]):
        c = tuple((k * 256 + 128) // 6 for k in key)
        if all(dist2(c, p) > 60 * 60 for p in picked):
            picked.append(c)
        if len(picked) == COLOURS:
            break
    return picked

def dist2(a, b):
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2

def cluster(px):
    centres = seeds(px)
    if not centres:
        return []

    for _ in range(ROUNDS):
        sums = [[0, 0, 0, 0] for _ in centres]
        for p in px:
            i = min(range(len(centres)), key=lambda j: dist2(p, centres[j]))
            s = sums[i]
            s[0] += p[0]
            s[1] += p[1]
            s[2] += p[2]
            s[3] += 1
        moved = False
        for i, s in enumerate(sums):
            if not s[3]:
                continue
            c = (s[0] // s[3], s[1] // s[3], s[2] // s[3])
            if c != centres[i]:
                moved = True
            centres[i] = c
        if not moved:
            break

    counts = [0] * len(centres)
    for p in px:
        counts[min(range(len(centres)), key=lambda j: dist2(p, centres[j]))] += 1

    total = float(len(px))
    out = [(c, n / total) for c, n in zip(centres, counts) if n]
    out.sort(key=lambda cs: -cs[1])
    return [cs for cs in out if cs[1] >= FLOOR] or out[:1]

def main():
    if len(sys.argv) < 2:
        print("usage: palette.py <image|video|svg>", file=sys.stderr)
        return 2
    path = sys.argv[1]
    if not os.path.exists(path):
        return 1
    px = pixels(path)
    if not px:
        return 1
    for (r, g, b), share in cluster(px):
        print(f"#{r:02x}{g:02x}{b:02x} {share:.4f}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
