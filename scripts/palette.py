#!/usr/bin/env python3
"""What colours a wallpaper is mostly made of.

Prints one line per colour, most of the picture first:

    #1b3a34 0.41
    #7fd1b9 0.22
    ...

The share is the fraction of the picture that colour stands for, so the lines
sum to 1. `services/Wallpaper.qml` runs this and hands the result to whatever
wants it; nothing here decides what a theme should do with them.

WHY A SCRIPT AND NOT QML. QML cannot read the pixels of an image: there is no
way to get at a decoded QImage from the language, so the shell can draw a
wallpaper and cannot look at one. Everything here is therefore about getting
pixels into a process that can count them, which is what ffmpeg is for.

WHY NOT ffmpeg's OWN palettegen. It exists and it answers a different question:
it picks the palette that best REPRODUCES the picture, so it spends its entries
on the subtle gradations that a GIF would otherwise band, and hands back eight
shades of the same sky. What is wanted here is the opposite, the few colours a
person would name if asked, which is a clustering problem and not a
quantisation one.
"""

import os
import shutil
import subprocess
import sys

# Small on purpose. This is a question about the broad areas of a picture, and
# every pixel past the first few thousand is another vote for the same answer at
# a linear cost. 96x54 is 16:9 and about five thousand of them.
WIDTH, HEIGHT = 96, 54

# How many colours to report, and how many rounds of k-means to spend. Lloyd's
# algorithm on five thousand points in three dimensions has converged long
# before twenty; the cap is there so a pathological picture cannot spin.
COLOURS = 6
ROUNDS = 20

# Under this share, a cluster is a detail rather than a colour of the picture:
# one bright flower in a forest is not what the forest is made of. Reported
# anyway if it is one of the few there are, but never worth splitting a real
# colour to find.
FLOOR = 0.02


def pixels(path):
    """The picture as a flat list of (r, g, b), or an empty list."""
    # SVG IS NOT A PICTURE UNTIL SOMETHING DRAWS IT, and ffmpeg mostly cannot:
    # its svg decoder is optional and usually absent. rsvg-convert is the same
    # library Qt's own SVG support is a cousin of and is present wherever a
    # desktop is, so it renders first and ffmpeg reads the result.
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
        # `area` rather than the default, and it is the whole reason the
        # downscale is trustworthy: it averages every source pixel into the
        # destination, so the small image is a true summary of the big one.
        # Bilinear would sample, and sampling a picture to a hundredth of its
        # size is closer to picking pixels at random than to shrinking it.
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
    """Starting centroids: the fullest bins of a coarse grid, spread out.

    k-means finds a local minimum and which one depends entirely on where it
    starts. Started at random it will happily put three centroids inside the
    same sky and none on the ground. Started at the fullest bins of a 6x6x6
    grid, rejecting any bin too close to one already taken, it starts with one
    centroid per region of colour that actually has area, which is the answer
    already roughly right.
    """
    bins = {}
    for r, g, b in px:
        key = (r * 6 // 256, g * 6 // 256, b * 6 // 256)
        bins[key] = bins.get(key, 0) + 1

    picked = []
    for key, _ in sorted(bins.items(), key=lambda kv: -kv[1]):
        c = tuple((k * 256 + 128) // 6 for k in key)
        # Two bins of a 6-level grid are 42 apart along one axis; 60 is a bit
        # more than that in the diagonal, which keeps neighbouring bins of one
        # gradient from each taking a seat.
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
