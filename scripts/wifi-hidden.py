#!/usr/bin/env python3

import json
import sys
import uuid

import gi

gi.require_version("GLib", "2.0")
gi.require_version("Gio", "2.0")
from gi.repository import GLib, Gio

NM = "org.freedesktop.NetworkManager"
NM_PATH = "/org/freedesktop/NetworkManager"
ACTIVE = "org.freedesktop.NetworkManager.Connection.Active"
CONNECTION = "org.freedesktop.NetworkManager.Settings.Connection"

ACTIVATED = 2
DEACTIVATED = 4

KEY_MANAGEMENT = {"wpa": "wpa-psk", "sae": "sae"}

REASONS = {
    5: "no address came back",
    6: "no answer from the network",
    9: "wrong password",
    10: "wrong password",
}

TIMEOUT_SECONDS = 60


def problem(ssid, security, password):
    if not ssid:
        return "the network needs a name"
    if len(ssid.encode("utf-8")) > 32:
        return "a network name is 32 bytes at most"
    if security == "open":
        return ""
    if security not in KEY_MANAGEMENT:
        return "that kind of security is not supported"
    if security == "wpa":
        hex_key = len(password) == 64 and all(c in "0123456789abcdefABCDEF" for c in password)
        if not hex_key and not 8 <= len(password) <= 63:
            return "wi-fi passwords are 8 to 63 characters"
    if not password:
        return "the network needs a password"
    return ""


def settings_for(ssid, security, password, identity):
    settings = {
        "connection": {
            "id": GLib.Variant("s", ssid),
            "type": GLib.Variant("s", "802-11-wireless"),
            "uuid": GLib.Variant("s", identity),
            "autoconnect": GLib.Variant("b", True),
        },
        "802-11-wireless": {
            "ssid": GLib.Variant("ay", ssid.encode("utf-8")),
            "mode": GLib.Variant("s", "infrastructure"),
            "hidden": GLib.Variant("b", True),
        },
        "ipv4": {"method": GLib.Variant("s", "auto")},
        "ipv6": {"method": GLib.Variant("s", "auto")},
    }
    if security != "open":
        settings["802-11-wireless-security"] = {
            "key-mgmt": GLib.Variant("s", KEY_MANAGEMENT[security]),
            "psk": GLib.Variant("s", password),
        }
    return settings


def reason_text(reason):
    return REASONS.get(reason, "could not join")


def say(event):
    sys.stdout.write(json.dumps(event) + "\n")
    sys.stdout.flush()


def call(bus, path, interface, method, args, reply):
    result = bus.call_sync(NM, path, interface, method, args, GLib.VariantType(reply) if reply else None, Gio.DBusCallFlags.NONE, 10000, None)
    return result.unpack() if result else ()


def main():
    if len(sys.argv) < 2 or not sys.argv[1]:
        say({"event": "failed", "why": "there is no wireless adapter to put it on"})
        return 1
    try:
        request = json.loads(sys.stdin.readline())
        ssid = str(request["ssid"])
        security = str(request["security"])
        password = str(request.get("password") or "")
    except (ValueError, KeyError, TypeError):
        say({"event": "failed", "why": "the request was not understood"})
        return 1

    why = problem(ssid, security, password)
    if why:
        say({"event": "failed", "why": why})
        return 1

    bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
    loop = GLib.MainLoop()
    outcome = {"code": 1, "saved": ""}

    def finish(event, code):
        outcome["code"] = code
        say(event)
        loop.quit()

    def discard():
        if outcome["saved"]:
            try:
                call(bus, outcome["saved"], CONNECTION, "Delete", None, None)
            except GLib.Error:
                pass

    def judge(state, reason):
        if state == ACTIVATED:
            finish({"event": "joined"}, 0)
        elif state == DEACTIVATED:
            discard()
            finish({"event": "failed", "why": reason_text(reason)}, 1)

    try:
        (device,) = call(bus, NM_PATH, NM, "GetDeviceByIpIface", GLib.Variant("(s)", (sys.argv[1],)), "(o)")
        settings = settings_for(ssid, security, password, str(uuid.uuid4()))
        saved, active = call(
            bus,
            NM_PATH,
            NM,
            "AddAndActivateConnection",
            GLib.Variant("(a{sa{sv}}oo)", (settings, device, "/")),
            "(oo)",
        )
    except GLib.Error as error:
        say({"event": "failed", "why": "NetworkManager refused it" if "NotAuthorized" in error.message or "PermissionDenied" in error.message else "NetworkManager would not take it"})
        return 1

    outcome["saved"] = saved

    def on_signal(_conn, _sender, _path, _iface, _name, params):
        state, reason = params.unpack()
        judge(state, reason)

    bus.signal_subscribe(NM, ACTIVE, "StateChanged", active, None, Gio.DBusSignalFlags.NONE, on_signal)

    try:
        (current,) = call(
            bus,
            active,
            "org.freedesktop.DBus.Properties",
            "Get",
            GLib.Variant("(ss)", (ACTIVE, "State")),
            "(v)",
        )
        if current in (ACTIVATED, DEACTIVATED):
            judge(current, 0)
    except GLib.Error:
        pass

    def expire():
        discard()
        finish({"event": "failed", "why": reason_text(6)}, 1)
        return False

    GLib.timeout_add_seconds(TIMEOUT_SECONDS, expire)
    loop.run()
    return outcome["code"]


if __name__ == "__main__":
    sys.exit(main())
