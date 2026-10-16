#!/usr/bin/env python3

import argparse
import glob
import os
import select
import signal
import sys
import time

EV_KEY = 0x01
EV_ABS = 0x03
ABS_WHEEL = 0x08

BTN_0 = 0x100
BTN_9 = 0x109

RETRY_SECONDS = 2.0

DEFAULT_DEVICE_NAME = "Wacom Intuos Pro M Pad"

class _Terminated(BaseException):
    pass

def _stop(_signum, _frame):
    raise _Terminated()

def _event_nodes():
    return sorted(
        glob.glob("/dev/input/event*"),
        key=lambda p: int("".join(c for c in os.path.basename(p) if c.isdigit()) or -1),
    )

def find_pad(evdev, name, log):
    denied = False
    seen = []
    for path in _event_nodes():
        try:
            dev = evdev.InputDevice(path)
        except PermissionError:
            denied = True
            continue
        except OSError:
            continue
        try:
            found = dev.name
        except Exception:
            found = ""
        if found == name:
            log(f"{path}: {found}")
            return dev, denied, seen
        seen.append(f"{path}: {found}")
        dev.close()
    return None, denied, seen

class PadReader:
    def grab_patiently(self, dev):
        for _ in range(50):
            try:
                dev.grab()
                return
            except OSError as exc:
                if exc.errno != 16:
                    raise
                time.sleep(0.1)
        dev.grab()

    def __init__(self, name, verbose, grab=False):
        self.name = name
        self.verbose = verbose
        self.grab = grab
        self.held = set()
        self.connected = None
        self.warned = set()
        self.last_scan = None

    def log(self, message):
        if self.verbose:
            print(message, file=sys.stderr, flush=True)

    def warn_once(self, key, message):
        if key not in self.warned:
            self.warned.add(key)
            print(message, file=sys.stderr, flush=True)

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

    def log_missing(self, seen):
        if not self.verbose or seen == self.last_scan:
            return
        self.last_scan = seen
        self.log(f"no match for {self.name!r} among:\n  " + "\n  ".join(seen))

    def emit(self, line):
        try:
            print(line, flush=True)
        except BrokenPipeError:
            raise _Terminated()

    def go_ready(self):
        self.held.clear()
        self.connected = True
        self.emit("ready")

    def go_gone(self):
        if self.connected is False:
            return
        for code in sorted(self.held):
            self.emit(f"up {code}")
        self.held.clear()
        self.connected = False
        self.emit("gone")

    def pump(self, dev):
        poller = select.poll()
        device_fd = dev.fileno()
        poller.register(device_fd, select.POLLIN)
        self.watch_hangup(poller)
        while True:
            for fd, _revents in poller.poll():
                if fd != device_fd:
                    raise _Terminated()
                try:
                    for event in dev.read():
                        self.handle(event)
                except BlockingIOError:
                    continue

    def handle(self, event):
        if event.type == EV_KEY and BTN_0 <= event.code <= BTN_9:
            if event.value == 0:
                if event.code in self.held:
                    self.held.discard(event.code)
                    self.emit(f"up {event.code}")
            elif event.code not in self.held:
                self.held.add(event.code)
                self.emit(f"down {event.code}")
        elif event.type == EV_ABS and event.code == ABS_WHEEL:
            self.emit(f"ring {event.value}")

    def run(self):
        while True:
            evdev = None
            try:
                import evdev  # noqa: PLC0415
            except Exception as exc:
                self.warn_once(
                    "import",
                    f"python-evdev is not usable ({exc}). No pad event can be "
                    "read until that package imports, so install or repair it. "
                    f"Retrying every {RETRY_SECONDS:g}s until then.",
                )

            dev = None
            denied = False
            if evdev is not None:
                try:
                    dev, denied, seen = find_pad(evdev, self.name, self.log)
                    if dev is None:
                        self.log_missing(seen)
                except Exception as exc:
                    self.log(f"scan failed: {exc!r}")

            if dev is None:
                if denied:
                    self.warn_once(
                        "denied",
                        "some /dev/input nodes could not be opened. The nodes are "
                        "root:input and this user should be in `input`, but group "
                        "membership only applies at LOGIN, so log out and back in.",
                    )
                self.go_gone()
                self.wait(RETRY_SECONDS)
                continue

            if self.grab:
                try:
                    self.grab_patiently(dev)
                    self.log("grabbed: the compositor will not see pad events")
                except Exception as exc:
                    self.warn_once(
                        "grab",
                        f"could not grab the pad ({exc}). Pad buttons still "
                        "reach the compositor, which on Hyprland 0.56 with "
                        "GTK4 means every GTK window dies on the next press.",
                    )

            self.go_ready()
            try:
                self.pump(dev)
            except OSError as exc:
                self.log(f"read ended: {exc}")
            except _Terminated:
                raise
            except Exception as exc:
                self.log(f"unexpected read failure: {exc!r}")
            finally:
                if self.grab:
                    try:
                        dev.ungrab()
                    except Exception:
                        pass
                try:
                    dev.close()
                except Exception:
                    pass

            self.go_gone()
            self.wait(RETRY_SECONDS)

def main():
    parser = argparse.ArgumentParser(
        description="Print Wacom pad button and ring events on stdout, forever.",
    )
    parser.add_argument("--device-name", default=DEFAULT_DEVICE_NAME)
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--grab", action="store_true")
    args = parser.parse_args()

    try:
        sys.stdout.reconfigure(line_buffering=True)
    except Exception:
        pass

    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(sig, _stop)

    reader = PadReader(args.device_name, args.verbose, args.grab)
    try:
        reader.run()
    except _Terminated:
        pass
    finally:
        try:
            sys.stdout.flush()
        except Exception:
            try:
                sys.stdout = open(os.devnull, "w")
            except OSError:
                pass
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
