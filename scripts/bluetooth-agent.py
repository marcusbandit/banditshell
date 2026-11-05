#!/usr/bin/env python3

import json
import signal
import sys
import threading

import gi

gi.require_version("GLib", "2.0")
gi.require_version("Gio", "2.0")
from gi.repository import GLib, Gio

AGENT_PATH = "/org/banditshell/bluetooth/agent"
CAPABILITY = "KeyboardDisplay"

AGENT_XML = """
<node>
  <interface name="org.bluez.Agent1">
    <method name="Release"/>
    <method name="RequestPinCode">
      <arg name="device" type="o" direction="in"/>
      <arg name="pincode" type="s" direction="out"/>
    </method>
    <method name="DisplayPinCode">
      <arg name="device" type="o" direction="in"/>
      <arg name="pincode" type="s" direction="in"/>
    </method>
    <method name="RequestPasskey">
      <arg name="device" type="o" direction="in"/>
      <arg name="passkey" type="u" direction="out"/>
    </method>
    <method name="DisplayPasskey">
      <arg name="device" type="o" direction="in"/>
      <arg name="passkey" type="u" direction="in"/>
      <arg name="entered" type="q" direction="in"/>
    </method>
    <method name="RequestConfirmation">
      <arg name="device" type="o" direction="in"/>
      <arg name="passkey" type="u" direction="in"/>
    </method>
    <method name="RequestAuthorization">
      <arg name="device" type="o" direction="in"/>
    </method>
    <method name="AuthorizeService">
      <arg name="device" type="o" direction="in"/>
      <arg name="uuid" type="s" direction="in"/>
    </method>
    <method name="Cancel"/>
  </interface>
</node>
"""

REJECTED = "org.bluez.Error.Rejected"
CANCELED = "org.bluez.Error.Canceled"

ASKS = {
    "RequestPinCode": "pin",
    "RequestPasskey": "passkey",
    "RequestConfirmation": "confirm",
    "RequestAuthorization": "authorize",
}


def address_of(path):
    leaf = str(path).rsplit("/", 1)[-1]
    if not leaf.startswith("dev_"):
        return ""
    return leaf[4:].replace("_", ":")


def passkey_text(value):
    return "%06d" % int(value)


def event_for(method, params, name):
    device = params[0] if params else ""
    base = {"address": address_of(device), "name": name}
    if method == "DisplayPinCode":
        return dict(base, event="show", code=str(params[1]), entered=0)
    if method == "DisplayPasskey":
        return dict(base, event="show", code=passkey_text(params[1]), entered=int(params[2]))
    kind = ASKS.get(method)
    if not kind:
        return None
    code = passkey_text(params[1]) if method == "RequestConfirmation" else ""
    return dict(base, event="ask", kind=kind, code=code)


def reply_for(method, answer):
    if not answer.get("accept"):
        return None
    code = str(answer.get("code") or "")
    if method == "RequestPinCode":
        return GLib.Variant("(s)", (code,)) if code else None
    if method == "RequestPasskey":
        if not code.isdigit() or int(code) > 999999:
            return None
        return GLib.Variant("(u)", (int(code),))
    return GLib.Variant("()", ())


class Agent:
    def __init__(self, bus):
        self.bus = bus
        self.pending = {}
        self.serial = 0
        self.lock = threading.Lock()

    def say(self, event):
        sys.stdout.write(json.dumps(event) + "\n")
        sys.stdout.flush()

    def alias(self, path):
        try:
            result = self.bus.call_sync(
                "org.bluez",
                path,
                "org.freedesktop.DBus.Properties",
                "Get",
                GLib.Variant("(ss)", ("org.bluez.Device1", "Alias")),
                GLib.VariantType("(v)"),
                Gio.DBusCallFlags.NONE,
                2000,
                None,
            )
            return result.unpack()[0]
        except GLib.Error:
            return ""

    def paired(self, path):
        try:
            result = self.bus.call_sync(
                "org.bluez",
                path,
                "org.freedesktop.DBus.Properties",
                "Get",
                GLib.Variant("(ss)", ("org.bluez.Device1", "Paired")),
                GLib.VariantType("(v)"),
                Gio.DBusCallFlags.NONE,
                2000,
                None,
            )
            return bool(result.unpack()[0])
        except GLib.Error:
            return False

    def drop_all(self, error):
        for invocation, _method in self.pending.values():
            invocation.return_dbus_error(error, "")
        self.pending.clear()

    def on_call(self, _conn, _sender, _path, _iface, method, params, invocation):
        values = params.unpack()
        if method == "Release":
            invocation.return_value(None)
            self.say({"event": "released"})
            GLib.idle_add(loop.quit)
            return
        if method == "Cancel":
            self.drop_all(CANCELED)
            self.say({"event": "cancel"})
            invocation.return_value(None)
            return
        if method == "AuthorizeService":
            if self.paired(values[0]):
                invocation.return_value(None)
            else:
                invocation.return_dbus_error(REJECTED, "")
            return
        event = event_for(method, values, self.alias(values[0]) if values else "")
        if not event:
            invocation.return_dbus_error(REJECTED, "")
            return
        if event["event"] == "show":
            self.say(event)
            invocation.return_value(None)
            return
        self.serial += 1
        event["id"] = self.serial
        self.pending[self.serial] = (invocation, method)
        self.say(event)

    def answer(self, line):
        try:
            answer = json.loads(line)
            key = int(answer.get("id"))
        except (ValueError, TypeError, AttributeError):
            return False
        held = self.pending.pop(key, None)
        if not held:
            return False
        invocation, method = held
        reply = reply_for(method, answer)
        if reply is None:
            invocation.return_dbus_error(REJECTED, "")
        elif method in ("RequestPinCode", "RequestPasskey"):
            invocation.return_value(reply)
        else:
            invocation.return_value(None)
        return False

    def listen(self):
        for line in sys.stdin:
            GLib.idle_add(self.answer, line)
        GLib.idle_add(loop.quit)


loop = GLib.MainLoop()


def main():
    bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
    agent = Agent(bus)
    info = Gio.DBusNodeInfo.new_for_xml(AGENT_XML).interfaces[0]
    bus.register_object(AGENT_PATH, info, agent.on_call, None, None)

    try:
        for method, args in (
            ("RegisterAgent", GLib.Variant("(os)", (AGENT_PATH, CAPABILITY))),
            ("RequestDefaultAgent", GLib.Variant("(o)", (AGENT_PATH,))),
        ):
            bus.call_sync("org.bluez", "/org/bluez", "org.bluez.AgentManager1", method, args, None, Gio.DBusCallFlags.NONE, 3000, None)
    except GLib.Error as error:
        agent.say({"event": "error", "why": error.message})
        return 1

    agent.say({"event": "ready"})
    threading.Thread(target=agent.listen, daemon=True).start()

    for sig in (signal.SIGINT, signal.SIGTERM):
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, sig, loop.quit)

    loop.run()

    try:
        bus.call_sync("org.bluez", "/org/bluez", "org.bluez.AgentManager1", "UnregisterAgent", GLib.Variant("(o)", (AGENT_PATH,)), None, Gio.DBusCallFlags.NONE, 1000, None)
    except GLib.Error:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
