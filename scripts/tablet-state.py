#!/usr/bin/env python3
"""Is this machine folded over into a tablet right now?"""

import fcntl
import glob
import os
import sys

EV_SW = 0x05
SW_LID = 0x00
SW_TABLET_MODE = 0x01

_IOC_READ = 2

def _ior(nr: int, size: int) -> int:
    return (_IOC_READ << 30) | (size << 16) | (ord("E") << 8) | nr

def _eviocgbit(ev: int, size: int) -> int:
    return _ior(0x20 + ev, size)

def _eviocgsw(size: int) -> int:
    return _ior(0x1B, size)

def _eviocgname(size: int) -> int:
    return _ior(0x06, size)

BITMAP_BYTES = 8

def _has_bit(buf: "bytes | bytearray", bit: int) -> bool:
    return bool(buf[bit // 8] & (1 << (bit % 8)))

def probe(path: str, switch: int):
    """(supported, set, name) for one device node, or None if it cannot be read."""
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
    except OSError:
        return None

    try:
        caps = bytearray(BITMAP_BYTES)
        fcntl.ioctl(fd, _eviocgbit(EV_SW, BITMAP_BYTES), caps)
        if not _has_bit(caps, switch):
            return None

        state = bytearray(BITMAP_BYTES)
        fcntl.ioctl(fd, _eviocgsw(BITMAP_BYTES), state)

        name = bytearray(256)
        try:
            fcntl.ioctl(fd, _eviocgname(len(name)), name)
            label = name.split(b"\x00", 1)[0].decode("utf-8", "replace")
        except OSError:
            label = os.path.basename(path)

        return (True, _has_bit(state, switch), label)
    except OSError:
        return None
    finally:
        os.close(fd)

def main() -> int:
    lid = "--lid" in sys.argv
    switch = SW_LID if lid else SW_TABLET_MODE
    on, off = ("closed", "open") if lid else ("folded", "flat")

    nodes = sorted(
        glob.glob("/dev/input/event*"),
        key=lambda p: int("".join(c for c in os.path.basename(p) if c.isdigit()) or -1),
    )

    denied = False
    for path in nodes:
        if not os.access(path, os.R_OK):
            denied = True
            continue
        found = probe(path, switch)
        if found is None:
            continue
        _, is_on, label = found
        if "--verbose" in sys.argv:
            print(f"{path}: {label}", file=sys.stderr)
        print(on if is_on else off)
        return 0

    if denied and "--verbose" in sys.argv:
        print(
            f"no readable device reports {'SW_LID' if lid else 'SW_TABLET_MODE'}. "
            "The nodes are "
            "root:input; this user is in `input`, but group membership only "
            "applies at LOGIN, so log out and back in.",
            file=sys.stderr,
        )
    print("unknown")
    return 1

if __name__ == "__main__":
    raise SystemExit(main())
