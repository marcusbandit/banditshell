#!/usr/bin/env python3
"""Is this machine folded over into a tablet right now?

WHY A SCRIPT AND NOT A FILE READ. A convertible reports its hinge as an evdev
SWITCH (SW_TABLET_MODE), and a switch has no sysfs attribute: the only way to
ask "what is it NOW" is an ioctl on the device node. Nothing in QML can issue an
ioctl, and no shell builtin can either, so the question needs a process. This is
that process, and it prints one word.

WHY IT IS ONLY THE STARTUP ANSWER. Every LATER change arrives through the
compositor, which already has these devices open and binds to the transition
(see the switch binds in ~/.config/hypr/lua/binds.lua). Nothing here polls. What
the compositor cannot tell the shell is the state it was ALREADY in when the
shell started, because that is not a transition, and a shell restarted while
folded would otherwise sit in laptop mode until the hinge next moved. This
answers exactly that one question, once.

IT NEEDS THE `input` GROUP, and this user is in it (added 2026-08-17). That is
a real grant and worth naming: membership in `input` is read access to every
evdev node, which is the ability to read every keystroke on the machine
including the ones typed into a password field. It was granted deliberately so
that a shell restarted while folded knows it, not as an accident of packaging.

It still answers `unknown` rather than failing when the group is missing,
because the answer has to survive the case where it is: a fresh machine, a
different user, or this session before the new group has been picked up. Group
membership applies at LOGIN, so the shell keeps reading `unknown` until the
next log in no matter what /etc/group says. The shell falls back to laptop mode
and the next fold corrects it, which costs one gesture.

    folded   the hinge is past the tablet threshold
    flat     it is not
    unknown  no such device, or no permission to ask

Exit status is 0 for a real answer and 1 for `unknown`, so a caller can branch
on the status rather than parsing the word.
"""

import fcntl
import glob
import os
import sys

# linux/input-event-codes.h
EV_SW = 0x05
SW_TABLET_MODE = 0x01

# asm-generic/ioctl.h. _IOC(dir, type, nr, size), with _IOC_READ == 2. The
# evdev "get" ioctls are all reads off type 'E', and the size is the length of
# the buffer being filled, which is why each of these is computed per call
# rather than being a constant.
_IOC_READ = 2


def _ior(nr: int, size: int) -> int:
    return (_IOC_READ << 30) | (size << 16) | (ord("E") << 8) | nr


def _eviocgbit(ev: int, size: int) -> int:
    return _ior(0x20 + ev, size)


def _eviocgsw(size: int) -> int:
    return _ior(0x1B, size)


def _eviocgname(size: int) -> int:
    return _ior(0x06, size)


# Enough bytes to cover SW_MAX (0x10) several times over. A byte would do; this
# costs nothing and does not have to be revisited when the kernel grows a switch.
BITMAP_BYTES = 8


def _has_bit(buf: "bytes | bytearray", bit: int) -> bool:
    return bool(buf[bit // 8] & (1 << (bit % 8)))


def probe(path: str):
    """(supported, folded, name) for one device node, or None if it cannot be read."""
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
    except OSError:
        return None

    try:
        caps = bytearray(BITMAP_BYTES)
        fcntl.ioctl(fd, _eviocgbit(EV_SW, BITMAP_BYTES), caps)
        if not _has_bit(caps, SW_TABLET_MODE):
            return None

        state = bytearray(BITMAP_BYTES)
        fcntl.ioctl(fd, _eviocgsw(BITMAP_BYTES), state)

        name = bytearray(256)
        try:
            fcntl.ioctl(fd, _eviocgname(len(name)), name)
            label = name.split(b"\x00", 1)[0].decode("utf-8", "replace")
        except OSError:
            label = os.path.basename(path)

        return (True, _has_bit(state, SW_TABLET_MODE), label)
    except OSError:
        return None
    finally:
        os.close(fd)


def main() -> int:
    # SORTED, and by the number rather than by the string, because event9 must
    # not come after event14: the answer is meant to be stable across boots and
    # a machine with two switch devices would otherwise pick a different one
    # depending on how the paths happened to sort.
    nodes = sorted(
        glob.glob("/dev/input/event*"),
        key=lambda p: int("".join(c for c in os.path.basename(p) if c.isdigit()) or -1),
    )

    denied = False
    for path in nodes:
        if not os.access(path, os.R_OK):
            denied = True
            continue
        found = probe(path)
        if found is None:
            continue
        _, folded, label = found
        if "--verbose" in sys.argv:
            print(f"{path}: {label}", file=sys.stderr)
        print("folded" if folded else "flat")
        return 0

    if denied and "--verbose" in sys.argv:
        print(
            "no readable device reports SW_TABLET_MODE. The nodes are "
            "root:input; this user is in `input`, but group membership only "
            "applies at LOGIN, so log out and back in.",
            file=sys.stderr,
        )
    print("unknown")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
