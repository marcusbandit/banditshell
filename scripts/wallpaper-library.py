#!/usr/bin/env python3

import hashlib
import json
import os
import re
import stat
import subprocess
import sys

ANIMATED = re.compile(rb"<animate|@keyframes|animation *:")


def walk(top, extensions):
    chosen = {}
    folders = set()
    for folder, dirs, files in os.walk(top, followlinks=True):
        try:
            here = os.stat(folder)
        except OSError:
            dirs[:] = []
            continue
        if (here.st_dev, here.st_ino) in folders:
            dirs[:] = []
            continue
        folders.add((here.st_dev, here.st_ino))
        for name in files:
            if os.path.splitext(name)[1][1:].lower() not in extensions:
                continue
            path = os.path.join(folder, name)
            try:
                st = os.stat(path)
            except OSError:
                continue
            if not stat.S_ISREG(st.st_mode):
                continue
            key = (st.st_dev, st.st_ino)
            if key not in chosen or path < chosen[key][0]:
                chosen[key] = (path, [st.st_mtime_ns, st.st_size])
    return sorted(chosen.values())


def stamp_of(path):
    try:
        st = os.stat(path)
    except OSError:
        return None
    return [st.st_mtime_ns, st.st_size]


def shape_of(path):
    try:
        out = subprocess.run(
            ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height", "-of", "csv=p=0", path],
            stdin=subprocess.DEVNULL, capture_output=True, text=True,
        ).stdout
    except OSError:
        return [0, 0]
    match = re.match(r"\s*(\d+),(\d+)", out)
    return [int(match.group(1)), int(match.group(2))] if match else [0, 0]


def poster_of(path, posters, fresh):
    out = os.path.join(posters, hashlib.md5(path.encode()).hexdigest() + ".jpg")
    if fresh or not os.path.isfile(out):
        try:
            os.makedirs(posters, exist_ok=True)
            subprocess.run(
                ["ffmpeg", "-v", "error", "-y", "-ss", "0", "-i", path, "-frames:v", "1", "-vf", "scale=640:-2", out],
                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
        except OSError:
            pass
    return out if os.path.isfile(out) else ""


def frozen_of(path):
    try:
        with open(path, "rb") as handle:
            return bool(ANIMATED.search(handle.read()))
    except OSError:
        return False


def measure(path, kind, posters, fresh):
    entry = {"shape": shape_of(path)}
    if kind == "video":
        entry["poster"] = poster_of(path, posters, fresh)
    if path.lower().endswith(".svg"):
        entry["frozen"] = frozen_of(path)
    return entry


def lines_for(path, entry):
    width, height = entry.get("shape", [0, 0])
    yield f"shape\t{path}\t{width}\t{height}"
    if "poster" in entry:
        yield f"poster\t{path}\t{entry['poster']}"
    if "frozen" in entry:
        yield f"frozen\t{path}\t{1 if entry['frozen'] else 0}"


def save(cache_path, cache):
    os.makedirs(os.path.dirname(cache_path) or ".", exist_ok=True)
    temporary = f"{cache_path}.{os.getpid()}"
    with open(temporary, "w") as handle:
        json.dump(cache, handle)
    os.replace(temporary, cache_path)


def say(line):
    print(line, flush=True)


def main():
    if len(sys.argv) < 6:
        print("usage: wallpaper-library.py <cache.json> <poster dir> <folder> <extensions> <video extensions> [extra file...]", file=sys.stderr)
        return 2

    cache_path, posters, top = sys.argv[1], sys.argv[2], sys.argv[3]
    extensions = set(sys.argv[4].lower().split(","))
    videos = set(sys.argv[5].lower().split(","))
    extras = sys.argv[6:]

    try:
        with open(cache_path) as handle:
            cache = json.load(handle)
        if not isinstance(cache, dict):
            cache = {}
    except (OSError, ValueError):
        cache = {}

    found = walk(top, extensions)
    for path in extras:
        stamp = stamp_of(path)
        if stamp is not None:
            found.append((path, stamp))

    for path, _ in found:
        say(f"file\t{path}")

    known = {path: entry for path, entry in cache.items() if isinstance(entry, dict)}
    kept = {}
    fresh = []
    for path, stamp in found:
        entry = known.get(path)
        poster = entry.get("poster") if isinstance(entry, dict) else ""
        if entry is not None and entry.get("stamp") == stamp and (not poster or os.path.isfile(poster)):
            kept[path] = entry
        else:
            fresh.append((path, stamp, entry is not None))

    changed = bool(fresh) or set(known) != {path for path, _ in found}
    say(f"listed\t{'changed' if changed else 'same'}")

    for path in kept:
        for line in lines_for(path, kept[path]):
            say(line)

    for index, (path, stamp, was_known) in enumerate(fresh):
        kind = "video" if os.path.splitext(path)[1][1:].lower() in videos else ""
        entry = measure(path, kind, posters, was_known)
        entry["stamp"] = stamp
        kept[path] = entry
        for line in lines_for(path, entry):
            say(line)
        if index % 8 == 7:
            save(cache_path, kept)

    if changed:
        save(cache_path, kept)
    say("done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
