#!/usr/bin/env python3

import glob
import hashlib
import json
import os
import struct
import sys

ORIGIN = "https://xpui.app.spotify.com/"
STORE = "SpicyLyrics_LyricsStore"

ROOTS = [
    "~/.cache/spotify/Browser",
    "~/.cache/spotify/Default",
    "~/.var/app/com.spotify.Client/cache/spotify/Browser",
    "~/.var/app/com.spotify.Client/cache/spotify/Default",
]


def entry_name(key):
    digest = hashlib.sha1(key.encode()).digest()[:8]
    return "%016x_0" % struct.unpack("<Q", digest)[0]


def stores():
    found = []
    for root in ROOTS:
        pattern = os.path.join(os.path.expanduser(root), "Service Worker", "CacheStorage", "*", "index.txt")
        for index in glob.glob(pattern):
            try:
                raw = open(index, "rb").read()
            except OSError:
                continue
            origin = os.path.dirname(index)
            at = 0
            while True:
                at = raw.find(STORE.encode(), at)
                if at < 0:
                    break
                end = at + len(STORE)
                while end < len(raw) and (chr(raw[end]).isalnum() or raw[end] == ord("_")):
                    end += 1
                name = raw[at:end].decode()
                tail = raw[end:end + 64]
                uuid_at = tail.find(b"$")
                uuid = tail[uuid_at + 1:uuid_at + 37].decode(errors="replace") if uuid_at >= 0 else ""
                folder = os.path.join(origin, uuid)
                if uuid and os.path.isdir(folder):
                    found.append((name, folder))
                at = end
    found.sort(key=lambda s: (s[0] != STORE + "_g1", -os.path.getmtime(s[1])))
    return found


def read(folder, key):
    path = os.path.join(folder, entry_name(key))
    try:
        raw = open(path, "rb").read()
    except OSError:
        return None
    if key.encode() not in raw[:512]:
        return None
    start = raw.find(b'{"ExpiresAt"')
    if start < 0:
        return None
    try:
        wrapped, _ = json.JSONDecoder().raw_decode(raw[start:].decode("utf-8", "replace"))
    except ValueError:
        return None
    return wrapped.get("Content")


def main():
    if len(sys.argv) != 2 or not sys.argv[1].isalnum():
        print("usage: spicy-lyrics.py <spotify track id>", file=sys.stderr)
        return 2
    key = ORIGIN + sys.argv[1]
    found = stores()
    if not found:
        print(json.dumps({"Type": "Absent"}))
        return 0
    for _, folder in found:
        content = read(folder, key)
        if isinstance(content, dict) and content.get("Type") in ("Syllable", "Line", "Static"):
            print(json.dumps(content, ensure_ascii=False))
            return 0
        if isinstance(content, dict) and content.get("Value") == "NO_LYRICS":
            print(json.dumps({"Type": "None"}))
            return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
