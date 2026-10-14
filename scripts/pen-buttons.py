#!/usr/bin/env python3

import argparse
import glob
import os
import re
import select
import signal
import sys
import time

EV_KEY = 0x01

BTN_TOOL_PEN = 0x140
BTN_TOOL_RUBBER = 0x141
BTN_STYLUS = 0x14B
BTN_STYLUS2 = 0x14C

RETRY_SECONDS = 2.0

CLONE_MARK = "banditshell-pen-buttons"

DEFAULT_LOWER = "right click"
DEFAULT_UPPER = "middle click"

OUTPUT = {
    "right click": BTN_STYLUS,
    "middle click": BTN_STYLUS2,
    "nothing": None,
    "erase": None,
}

class _Terminated(BaseException):
    pass

def _stop(_signum, _frame):
    raise _Terminated()

def plain(name):
    return re.sub(r"[^a-z0-9]+", "-", str(name).lower()).strip("-")

class Remapper:
    def __init__(self, lower, upper):
        for choice in (lower, upper):
            if choice not in OUTPUT:
                raise ValueError(f"not a pen button choice: {choice!r}")
        self.choice = {BTN_STYLUS: lower, BTN_STYLUS2: upper}
        self.held = set()
        self.sent = set()
        self.pen_near = False
        self.rubber_near = False
        self.erasing = False
        self.tool = None

    @property
    def identity(self):
        return self.choice[BTN_STYLUS] == DEFAULT_LOWER and self.choice[BTN_STYLUS2] == DEFAULT_UPPER

    def feed(self, etype, code, value):
        if etype != EV_KEY:
            return [(etype, code, value)]
        if code in self.choice:
            return [] if value == 2 else self.button(code, value)
        if code == BTN_TOOL_PEN:
            return self.pen(value)
        if code == BTN_TOOL_RUBBER:
            self.rubber_near = bool(value)
        return [(etype, code, value)]

    def button(self, code, value):
        if value:
            self.held.add(code)
        else:
            self.held.discard(code)
        wanted = {OUTPUT[self.choice[c]] for c in self.held} - {None}
        out = [(EV_KEY, c, 1) for c in sorted(wanted - self.sent)]
        out += [(EV_KEY, c, 0) for c in sorted(self.sent - wanted)]
        self.sent = wanted
        self.erasing = any(self.choice[c] == "erase" for c in self.held)
        return out + self.retool()

    def pen(self, value):
        self.pen_near = bool(value)
        if value:
            self.tool = BTN_TOOL_RUBBER if self.erasing else BTN_TOOL_PEN
            return [(EV_KEY, self.tool, 1)]
        gone, self.tool = self.tool, None
        return [(EV_KEY, gone if gone is not None else BTN_TOOL_PEN, 0)]

    def retool(self):
        if not self.pen_near or self.rubber_near:
            return []
        wanted = BTN_TOOL_RUBBER if self.erasing else BTN_TOOL_PEN
        if wanted == self.tool:
            return []
        before, self.tool = self.tool, wanted
        lifted = [] if before is None else [(EV_KEY, before, 0)]
        return lifted + [(EV_KEY, wanted, 1)]

    def release(self):
        out = [(EV_KEY, c, 0) for c in sorted(self.sent)]
        if self.tool is not None:
            out.append((EV_KEY, self.tool, 0))
        self.held.clear()
        self.sent = set()
        self.tool = None
        return out

def event_nodes():
    return sorted(
        glob.glob("/dev/input/event*"),
        key=lambda p: int("".join(c for c in os.path.basename(p) if c.isdigit()) or -1),
    )

def has_stylus_buttons(dev, ecodes):
    return BTN_STYLUS in dev.capabilities().get(ecodes.EV_KEY, [])

def find_pen(evdev, wanted, log):
    denied = False
    for path in event_nodes():
        try:
            dev = evdev.InputDevice(path)
        except PermissionError:
            denied = True
            continue
        except OSError:
            continue
        try:
            fits = plain(dev.name) == wanted and dev.phys != CLONE_MARK and has_stylus_buttons(dev, evdev.ecodes)
        except Exception:
            fits = False
        if fits:
            log(f"{path}: {dev.name}")
            return dev, denied
        dev.close()
    return None, denied

class Helper:
    def __init__(self, device, remapper, verbose):
        self.wanted = plain(device)
        self.remapper = remapper
        self.verbose = verbose
        self.warned = set()
        self.last = None

    def log(self, message):
        if self.verbose:
            print(message, file=sys.stderr, flush=True)

    def warn_once(self, key, message):
        if key not in self.warned:
            self.warned.add(key)
            print(message, file=sys.stderr, flush=True)

    def say(self, word):
        if word == self.last:
            return
        self.last = word
        try:
            print(word, flush=True)
        except BrokenPipeError:
            raise _Terminated()

    def watch_hangup(self, poller):
        try:
            poller.register(sys.stdout.fileno(), 0)
            return True
        except Exception:
            return False

    def wait(self, seconds):
        poller = select.poll()
        if not self.watch_hangup(poller):
            time.sleep(seconds)
            return
        if poller.poll(seconds * 1000.0):
            raise _Terminated()

    def idle(self):
        self.say("idle")
        while True:
            self.wait(3600)

    def pump(self, dev, uinput):
        poller = select.poll()
        poller.register(dev.fileno(), select.POLLIN)
        self.watch_hangup(poller)
        while True:
            for fd, _revents in poller.poll():
                if fd != dev.fileno():
                    raise _Terminated()
                try:
                    for event in dev.read():
                        for out in self.remapper.feed(event.type, event.code, event.value):
                            uinput.write(*out)
                except BlockingIOError:
                    continue

    def serve(self, evdev, dev):
        try:
            uinput = evdev.UInput.from_device(
                dev,
                name=dev.name,
                vendor=dev.info.vendor,
                product=dev.info.product,
                version=dev.info.version,
                bustype=dev.info.bustype,
                phys=CLONE_MARK,
                input_props=dev.input_props(),
            )
        except Exception as exc:
            self.warn_once("uinput", f"could not make a stand-in for the pen ({exc}). /dev/uinput needs to be writable by this user; the pen is left as it is.")
            self.say("denied")
            return
        try:
            try:
                dev.grab()
            except Exception as exc:
                self.warn_once("grab", f"could not take the pen over ({exc}); the pen is left as it is.")
                self.say("denied")
                return
            self.log("the pen is now read through a stand-in")
            self.say("ready")
            try:
                self.pump(dev, uinput)
            except OSError as exc:
                self.log(f"read ended: {exc}")
            finally:
                try:
                    for out in self.remapper.release():
                        uinput.write(*out)
                except Exception:
                    pass
                try:
                    dev.ungrab()
                except Exception:
                    pass
        finally:
            try:
                uinput.close()
            except Exception:
                pass

    def run(self):
        if self.remapper.identity:
            self.idle()
        while True:
            evdev = None
            try:
                import evdev
            except Exception as exc:
                self.warn_once("import", f"python-evdev is not usable ({exc}); retrying every {RETRY_SECONDS:g}s.")
            dev = None
            denied = False
            if evdev is not None:
                try:
                    dev, denied = find_pen(evdev, self.wanted, self.log)
                except Exception as exc:
                    self.log(f"scan failed: {exc!r}")
            if dev is None:
                if denied:
                    self.warn_once("denied", "some /dev/input nodes could not be opened; this user needs to be in the input group, and group changes apply at login.")
                    self.say("denied")
                else:
                    self.say("gone")
                self.wait(RETRY_SECONDS)
                continue
            try:
                self.serve(evdev, dev)
            finally:
                try:
                    dev.close()
                except Exception:
                    pass
            if self.last == "ready":
                self.say("gone")
            self.wait(RETRY_SECONDS)

def main():
    parser = argparse.ArgumentParser(
        description="Remap a pen's two side buttons by reading it through a stand-in device, forever.",
    )
    parser.add_argument("--device", required=True, help="the pen as Hyprland names it, e.g. wacom-intuos-pro-m-pen")
    parser.add_argument("--lower", default=DEFAULT_LOWER, choices=sorted(OUTPUT))
    parser.add_argument("--upper", default=DEFAULT_UPPER, choices=sorted(OUTPUT))
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    try:
        sys.stdout.reconfigure(line_buffering=True)
    except Exception:
        pass

    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(sig, _stop)

    helper = Helper(args.device, Remapper(args.lower, args.upper), args.verbose)
    try:
        helper.run()
    except _Terminated:
        pass
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
