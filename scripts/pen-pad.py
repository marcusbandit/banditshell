#!/usr/bin/env python3
"""Narrate the Wacom pad's buttons and ring on stdout, one event per line, forever.

WHY A SCRIPT AND NOT QML. The pad's ExpressKeys are not keyboard keys. The
compositor swallows them as tablet-pad input, there is no Hyprland bind that
fires on one, and no socket event mentions them, so nothing the shell can
subscribe to ever hears a pad press. The only place a pad button exists as an
addressable event is the evdev node, and QML cannot read an evdev node. This is
that reader. The pen is a different story and deliberately not handled here:
Hyprland forwards the stylus to surfaces as ordinary pointer input, so a
MouseArea already sees the tip and the barrel button. Only the PAD needs evdev.

WHY IT NEVER EXITS ON ITS OWN, which is the single property everything else
here is bent around. This process is the only path a pad press has into the
shell. If it dies, the feature is silently dead: no error surfaces anywhere, the
user just holds a button and nothing happens, and the only cure is noticing and
restarting the shell. Every failure mode therefore degrades to "say `gone`, wait
two seconds, try again" instead of to a traceback. The pad is Bluetooth, so it
is ABSENT far more often than it is present: it disconnects when the tablet
sleeps, when the machine suspends, when Bluetooth is toggled, and when the
battery runs out. None of those are errors, they are the normal weather, and the
node number changes on every reconnect, which is why the device is found by NAME
and re-found from scratch on every retry.

THE PROTOCOL, on stdout, one line each:

    ready         the pad was found and opened, and NOTHING is held
    gone          the pad went away, or was never there
    down <code>   pad button pressed,  e.g. `down 256`
    up <code>     pad button released, e.g. `up 256`
    ring <value>  ABS_WHEEL absolute position, 0 to 71 on this tablet

stderr carries diagnostics under --verbose and, without it, only things that are
genuinely wrong and worth a human's attention: a broken python-evdev, or nodes
this user is not allowed to read.

IT NEEDS THE `input` GROUP, and this user is in it. scripts/tablet-state.py
explains what that grant actually costs and why it was made; the same reasoning
applies here and is not repeated. What matters for this script is that group
membership applies at LOGIN, so a fresh grant reads as "no such device" until
the next log in, which is a case worth naming in the output rather than
crashing on.

IT DOES NOT GRAB THE DEVICE. An EVIOCGRAB would give this script exclusive
access and take the pad away from the compositor, which would break any pad
button the user has bound elsewhere and would make the pad useless the moment
this script is killed while holding one. Reading a shared node is enough: evdev
delivers every event to every reader.
"""

import argparse
import glob
import os
import select
import signal
import sys
import time

# linux/input-event-codes.h. These numbers are kernel ABI and cannot change, so
# they are written out here rather than pulled off `evdev.ecodes`, exactly as
# scripts/tablet-state.py writes out its SW_* bits. It also means the event
# filter below is readable without knowing the evdev package, and keeps the only
# use of that package down to "open the node and hand me events".
EV_KEY = 0x01
EV_ABS = 0x03
ABS_WHEEL = 0x08

# The BTN_MISC block, BTN_0 through BTN_9. This tablet exposes BTN_0..BTN_8,
# nine physical buttons, but the filter is written as the whole block because
# the bound is a property of the header and not of this one pad, and a larger
# Wacom with more ExpressKeys should not need this line edited. Everything
# outside the block is dropped, which is how BTN_STYLUS gets ignored: the pad
# node advertises it even though the stylus lives on a different node entirely,
# and forwarding it would hand the shell a phantom tenth button.
BTN_0 = 0x100
BTN_9 = 0x109

# Two seconds is slow enough that a pad which is off for an hour costs nothing,
# and fast enough that the user does not notice the gap between switching the
# tablet on and the shell believing it. There is no backoff on purpose: a
# backoff optimises for a failure that stays failed, and this one is expected to
# resolve itself constantly.
RETRY_SECONDS = 2.0

DEFAULT_DEVICE_NAME = "Wacom Intuos Pro M Pad"


class _Terminated(BaseException):
    """SIGTERM, SIGINT or SIGHUP arrived, or the reader hung up.

    It derives from BaseException rather than Exception so that none of the
    deliberately broad `except Exception` handlers in this file can swallow it.
    Those handlers exist to keep the process alive through anything the kernel
    or the evdev package throws; a shutdown request is the one thing that must
    get through them.

    It is RAISED from the signal handler rather than setting a flag, because
    since PEP 475 a blocking read is retried automatically after a handler
    returns. A flag would therefore not be looked at until the next pad event,
    which on a tablet sitting idle on a desk is never, and the process would
    outlive the shell that spawned it.
    """


def _stop(_signum, _frame):
    raise _Terminated()


def _event_nodes():
    """Every /dev/input/event* path, sorted by number rather than by string.

    event9 must not sort after event14. Nothing here depends on the order today
    because the match is by name and names are unique, but an unsorted glob
    makes the verbose output shuffle between runs for no reason, and if two
    devices ever did carry the same name the choice should at least be stable.
    """
    return sorted(
        glob.glob("/dev/input/event*"),
        key=lambda p: int("".join(c for c in os.path.basename(p) if c.isdigit()) or -1),
    )


def find_pad(evdev, name, log):
    """Open the node whose evdev name is `name`, or return None.

    Returns (device, denied, seen). `denied` is True if at least one node could
    not even be opened, which is the difference between "the tablet is switched
    off", normal and silent, and "this user cannot read input devices", a real
    problem a human has to fix that would otherwise look identical from the
    outside. `seen` is every name that was not the wanted one, handed back
    rather than logged here so that the caller, which is the only thing that
    knows how often it is asking, can decide whether the answer is worth saying
    again.

    The nodes are enumerated here instead of through `evdev.list_devices()`
    because that helper filters on read AND WRITE access. Reading a pad needs
    neither write access nor a reason to want it, and on a machine where the
    input nodes are handed out read-only the helper would report an empty world
    while the pad sat there perfectly readable. InputDevice itself asks for
    read-write and falls back to read-only, which is the behaviour that is
    actually wanted, so the nodes go to it directly.
    """
    denied = False
    seen = []
    for path in _event_nodes():
        try:
            dev = evdev.InputDevice(path)
        except PermissionError:
            denied = True
            continue
        except OSError:
            # A node can vanish between the glob and the open, and a few
            # pseudo-devices refuse to be opened at all. Neither is worth a word.
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
    """The retry loop, plus the small amount of state the protocol needs.

    The state is one set of currently held button codes. It exists for two
    reasons, and both of them are about what the CONSUMER is left believing.

    First, autorepeat. evdev reports a held key as value 1 once and then value 2
    over and over. A hold-to-activate gesture that saw a fresh `down` on every
    repeat would re-enter itself many times a second, so the set turns the
    repeats into nothing.

    Second, and more important, a disconnect must not leave the consumer stuck.
    The gesture this feeds is hold-to-activate: press and hold BTN_0, the
    overlay is up, release it and the edit commits. If the tablet's Bluetooth
    drops while the button is down, the release happens out of earshot and no
    `up` will ever arrive, so the consumer would sit with an overlay it can
    never dismiss. So every held code is released explicitly, `up <code>` for
    each, BEFORE the `gone` line goes out. A pad that is not connected cannot be
    holding anything, so those releases are true rather than a convenience.

    `ready` carries the same guarantee from the other side: it means the pad was
    just opened and nothing is held, so a consumer may treat it as a hard reset
    of its own idea of the pad and resynchronise there. This is why `ready` is
    printed on EVERY successful open and not only the first.

    What is deliberately NOT done is seeding the held set from the kernel's
    current key state at open time. EVIOCGKEY, which is what `active_keys()`
    asks, reports BTN_8 as permanently pressed on this tablet with nothing
    touching it, verified on this machine with the pad idle on the desk. Trusting
    it would emit a `down 264` that never gets an `up`, which is precisely the
    stuck consumer this class is built to prevent. The kernel's word on a pad's
    resting state is not reliable; the edges it sends afterwards are, so only the
    edges are believed.
    """

    def __init__(self, name, verbose):
        self.name = name
        self.verbose = verbose
        self.held = set()
        # Tri-state on purpose. None means nothing has been said yet, which is
        # what makes the very first `gone` print when the pad is absent at
        # startup while every later duplicate is suppressed. `gone` is a
        # transition, not a status line, and repeating it every two seconds
        # forever would drown the consumer's log and teach it to ignore the word.
        self.connected = None
        self.warned = set()
        self.last_scan = None

    def log(self, message):
        if self.verbose:
            print(message, file=sys.stderr, flush=True)

    def warn_once(self, key, message):
        """A real problem, said to stderr exactly once no matter how long the
        retry loop runs. Without the once-only guard a permission error would
        write two lines a second until the shell was killed."""
        if key not in self.warned:
            self.warned.add(key)
            print(message, file=sys.stderr, flush=True)

    def watch_hangup(self, poller):
        """Add stdout to `poller` so that the reader going away wakes us.

        Registered with an empty event mask on purpose. poll() reports
        POLLERR, POLLHUP and POLLNVAL whether or not they were asked for, and
        those are the only things stdout has to say that are worth hearing: a
        pipe whose read end has been closed reports one of them immediately.

        WHY THIS EXISTS AT ALL. Noticing a dead consumer through a failed write
        is not enough, because this process legitimately writes nothing for as
        long as the tablet is untouched, which is most of the day. Tested
        without it: kill the reader and the script sits in its retry sleep
        forever, and every shell restart leaves another orphan behind holding
        the pad open. Waiting on the hangup instead of on the clock costs one
        registered descriptor and makes the write failure a fallback rather than
        the only signal.

        Returns False if stdout has no descriptor to watch, which happens when
        it has been replaced by something in-memory. The caller then falls back
        to a plain sleep, which is worse only in that case.
        """
        try:
            poller.register(sys.stdout.fileno(), 0)
            return True
        except Exception:
            return False

    def wait(self, seconds):
        """Sleep between retries, but wake immediately if the reader hangs up."""
        poller = select.poll()
        if not self.watch_hangup(poller):
            time.sleep(seconds)
            return
        if poller.poll(seconds * 1000.0):
            raise _Terminated()

    def log_missing(self, seen):
        """The roll call from a failed scan, said only when it changes.

        A failed scan has one line to say per input device on the machine, and
        it happens every two seconds for as long as the tablet is switched off,
        which is most of the time. Printed unconditionally that is a wall of log
        for a machine doing nothing wrong, and it buries the only interesting
        moment, the one where the pad's name appears or turns out to be spelled
        differently than expected. So the list goes out only when it differs
        from the one last printed, which is exactly when something was plugged
        in or unplugged and therefore exactly when somebody is looking.
        """
        if not self.verbose or seen == self.last_scan:
            return
        self.last_scan = seen
        self.log(f"no match for {self.name!r} among:\n  " + "\n  ".join(seen))

    def emit(self, line):
        """One protocol line, flushed.

        The flush is the whole point. stdout to a pipe is block buffered by
        default, so without it the lines would sit in a 4 KiB buffer and reach
        the shell in clumps, minutes late or never. For a hold gesture that is
        indistinguishable from the feature being broken. Line buffering is also
        set on the stream in main(); doing both is not redundant paranoia, it is
        that reconfigure() is unavailable if stdout has been replaced by
        something that is not a TextIOWrapper, and this line is the one that has
        to work in every case.

        A BrokenPipeError means the shell that spawned this went away. That is
        the one legitimate reason to stop, and it is not the process exiting on
        its own: there is no longer anybody on the other end to tell anything to.
        It is only the second line of defence though, because a write is the one
        thing this process may not do for hours at a stretch. See wait() for the
        first.
        """
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
        """Forward events until the device stops giving them.

        Only two kinds of event get through. EV_KEY inside the BTN_MISC block is
        a pad button. EV_ABS ABS_WHEEL is the touch ring, and its value is
        absolute, so a consumer wanting a delta subtracts the previous one
        itself rather than being handed a difference it cannot resynchronise.
        Everything else is dropped, including SYN_REPORT, which only marks the
        end of a report and carries nothing this protocol has a word for, and
        ABS_MISC, which the Wacom driver uses to flag the pad's internal mode
        and which changes on presses that have already been reported as buttons.

        The ring is not deduplicated. The kernel already suppresses an absolute
        axis that has not moved, so consecutive identical values do not arrive,
        and a filter here would only risk eating a real one.

        The wait is a poll() over two descriptors rather than the package's own
        read_loop(), which waits on the device alone. The second descriptor is
        stdout, so that a consumer that dies mid-session is noticed while the
        tablet is idle instead of at the next pad press, which may never come.
        """
        poller = select.poll()
        device_fd = dev.fileno()
        poller.register(device_fd, select.POLLIN)
        self.watch_hangup(poller)
        while True:
            for fd, _revents in poller.poll():
                if fd != device_fd:
                    # stdout was registered for errors only, so anything at all
                    # from it means the far end is gone.
                    raise _Terminated()
                try:
                    for event in dev.read():
                        self.handle(event)
                except BlockingIOError:
                    # poll() said readable and the kernel then had nothing to
                    # give. That is not a disconnect and must not be treated as
                    # one, because tearing the device down and reopening it
                    # would print a `gone` and a `ready` for nothing. A real
                    # removal arrives as ENODEV instead, which is a plain
                    # OSError and does end the session.
                    continue

    def handle(self, event):
        """One raw event in, at most one protocol line out."""
        if event.type == EV_KEY and BTN_0 <= event.code <= BTN_9:
            if event.value == 0:
                if event.code in self.held:
                    self.held.discard(event.code)
                    self.emit(f"up {event.code}")
            elif event.code not in self.held:
                # Covers value 1 and value 2 in one branch: a repeat on a button
                # already known to be down falls out here, and a repeat arriving
                # without its press, which is what a reader that attached
                # mid-hold would see, is still honoured as the press it stands
                # for.
                self.held.add(event.code)
                self.emit(f"down {event.code}")
        elif event.type == EV_ABS and event.code == ABS_WHEEL:
            self.emit(f"ring {event.value}")

    def run(self):
        while True:
            evdev = None
            try:
                # Imported inside the loop, and by name each time, so that a
                # python-evdev that is broken or missing at startup behaves like
                # a pad that is unplugged: the process keeps running, keeps
                # saying `gone`, and starts working by itself the moment the
                # package is installed. An import at the top of the file would
                # instead traceback before the first line of protocol was ever
                # written, which is the one outcome this script must not have.
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
                    # Nothing in find_pad is supposed to raise anything but
                    # OSError, which it handles. This is here because an
                    # unexpected exception during a scan of every input node on
                    # the machine is still not a reason to take the feature down.
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

            self.go_ready()
            try:
                self.pump(dev)
            except OSError as exc:
                # The expected end of every session. When Bluetooth drops, the
                # node is removed under the open descriptor and the next read
                # fails with ENODEV. It is the normal path, not an error, so it
                # is only worth a word under --verbose.
                self.log(f"read ended: {exc}")
            except _Terminated:
                raise
            except Exception as exc:
                # Anything else out of the evdev package. Unknown, therefore
                # treated as a disconnect: drop the device, say `gone`, open it
                # again in two seconds. A reopen fixes far more than it breaks.
                self.log(f"unexpected read failure: {exc!r}")
            finally:
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
    # A value-carrying option is why this uses argparse where its sibling
    # scripts/tablet-state.py just looks for its flags in sys.argv. The default
    # is the name of the tablet this was written for, and it is overridable
    # because the name is the ONLY stable handle: the node number changes on
    # every Bluetooth reconnect, so a caller pointing at /dev/input/event26 is
    # already wrong by the next time the tablet wakes up.
    parser.add_argument("--device-name", default=DEFAULT_DEVICE_NAME)
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    try:
        sys.stdout.reconfigure(line_buffering=True)
    except Exception:
        # Not fatal. Every emit() flushes anyway; this only saves the flush from
        # being the sole thing standing between the consumer and a stalled pipe.
        pass

    # SIGHUP is in the list because a shell that dies without closing the pipe
    # cleanly still sends one, and being reparented to init while nobody is
    # reading is exactly the leak this avoids.
    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(sig, _stop)

    reader = PadReader(args.device_name, args.verbose)
    try:
        reader.run()
    except _Terminated:
        # A clean stop is a zero. The caller asked for this one, so it is not a
        # failure and a supervisor must not treat it as something to restart.
        pass
    finally:
        # Interpreter shutdown flushes stdout, and if the pipe is already broken
        # that flush prints an "Exception ignored" traceback that has nowhere
        # useful to go and looks like a crash in the shell's log. Pointing the
        # stream at /dev/null first makes the final flush a no-op.
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
