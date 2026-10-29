#!/usr/bin/env python3

import os
import shutil
import signal
import subprocess
import sys

try:
    import gi

    gi.require_version("GLib", "2.0")
    gi.require_version("Gio", "2.0")
    from gi.repository import GLib, Gio
except (ImportError, ValueError):
    GLib = Gio = None

try:
    gi.require_version("GLibUnix", "2.0")
    from gi.repository import GLibUnix

    on_signal = GLibUnix.signal_add
except (ImportError, ValueError, NameError, AttributeError):
    on_signal = GLib.unix_signal_add if GLib else None

PICKED, CANCELLED, NO_CHOOSER = 0, 1, 2
ENDINGS = (signal.SIGTERM, signal.SIGINT, signal.SIGHUP)


def either_case(glob):
    return "".join(f"[{c.lower()}{c.upper()}]" if c.isalpha() else c for c in glob)
PATIENCE_SECONDS = 1800


def through_portal(title, pattern, folder):
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    token = f"banditshell{os.getpid()}"
    sender = bus.get_unique_name()[1:].replace(".", "_")
    handle = f"/org/freedesktop/portal/desktop/request/{sender}/{token}"
    loop = GLib.MainLoop()
    answer = {}

    def on_response(_conn, _sender, _path, _iface, _signal, params):
        code, results = params.unpack()
        answer["code"] = code
        answer["uris"] = results.get("uris", [])
        loop.quit()

    def listen(path):
        bus.signal_subscribe("org.freedesktop.portal.Desktop", "org.freedesktop.portal.Request", "Response",
                             path, None, Gio.DBusSignalFlags.NONE, on_response)

    asked = {"path": handle, "ended": False}

    def give_up(*_):
        asked["ended"] = True
        try:
            bus.call_sync("org.freedesktop.portal.Desktop", asked["path"], "org.freedesktop.portal.Request", "Close",
                          None, None, Gio.DBusCallFlags.NONE, 2000, None)
        except GLib.Error:
            pass
        loop.quit()
        return GLib.SOURCE_REMOVE

    for number in ENDINGS:
        on_signal(GLib.PRIORITY_HIGH, number, give_up)
    listen(handle)
    options = {
        "handle_token": GLib.Variant("s", token),
        "filters": GLib.Variant("a(sa(us))", [(pattern, [(0, either_case(glob)) for glob in pattern.split()])]),
    }
    if os.path.isdir(folder):
        options["current_folder"] = GLib.Variant("ay", folder.encode() + b"\0")
    try:
        given = bus.call_sync("org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop",
                              "org.freedesktop.portal.FileChooser", "OpenFile",
                              GLib.Variant("(ssa{sv})", ("", title, options)), GLib.VariantType("(o)"),
                              Gio.DBusCallFlags.NONE, -1, None).unpack()[0]
    except GLib.Error:
        while GLib.MainContext.default().iteration(False):
            pass
        if asked["ended"]:
            return CANCELLED, ""
        raise
    if given != handle:
        listen(given)
        asked["path"] = given
    GLib.timeout_add_seconds(PATIENCE_SECONDS, give_up)
    loop.run()
    if answer.get("code") != 0 or not answer.get("uris"):
        return CANCELLED, ""
    return PICKED, Gio.File.new_for_uri(answer["uris"][0]).get_path() or ""


def through_zenity(title, pattern, folder):
    if not shutil.which("zenity"):
        return NO_CHOOSER, ""
    guard = ["setpriv", "--pdeathsig", "TERM"] if shutil.which("setpriv") else []
    zenity = subprocess.Popen(guard + ["zenity", "--file-selection", f"--title={title}", f"--file-filter={pattern} | {' '.join(either_case(glob) for glob in pattern.split())}",
                                       f"--filename={folder.rstrip('/')}/"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)

    def stop(_number, _frame):
        zenity.terminate()
        sys.exit(CANCELLED)

    for number in ENDINGS:
        signal.signal(number, stop)
    out, _ = zenity.communicate()
    return (PICKED, out.strip()) if zenity.returncode == 0 and out.strip() else (CANCELLED, "")


def portal_answers():
    if Gio is None:
        return False
    try:
        bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        bus.call_sync("org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop",
                      "org.freedesktop.DBus.Properties", "Get",
                      GLib.Variant("(ss)", ("org.freedesktop.portal.FileChooser", "version")),
                      GLib.VariantType("(v)"), Gio.DBusCallFlags.NONE, 5000, None)
        return True
    except GLib.Error:
        return False


def check():
    return PICKED if portal_answers() or shutil.which("zenity") else NO_CHOOSER


def main():
    if sys.argv[1:2] == ["--check"]:
        sys.exit(check())
    title = sys.argv[1] if len(sys.argv) > 1 else "Open"
    pattern = sys.argv[2] if len(sys.argv) > 2 else "*"
    folder = os.path.expanduser(sys.argv[3] if len(sys.argv) > 3 else "~")
    if Gio is None:
        print("pick-file: python-gobject is missing, trying zenity", file=sys.stderr)
        code, path = through_zenity(title, pattern, folder)
    else:
        try:
            code, path = through_portal(title, pattern, folder)
        except GLib.Error as e:
            print(f"pick-file: no portal file chooser ({e.message}), trying zenity", file=sys.stderr)
            code, path = through_zenity(title, pattern, folder)
    if path:
        print(path)
    sys.exit(code)


if __name__ == "__main__":
    main()
