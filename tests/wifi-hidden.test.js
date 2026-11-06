const test = require("node:test");
const assert = require("node:assert");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const SCRIPT = path.resolve(__dirname, "../scripts/wifi-hidden.py");

const hasGi = spawnSync("python3", ["-c", "import gi; gi.require_version('Gio', '2.0')"]).status === 0;
const hasBus = spawnSync("sh", ["-c", "command -v dbus-run-session"]).status === 0;

function python(code, args = [], input = "") {
    return spawnSync("python3", ["-I", "-c", code, ...args], { encoding: "utf8", timeout: 20000, input });
}

const LOAD = `
import importlib.util, sys
spec = importlib.util.spec_from_file_location("hidden", sys.argv[1])
hidden = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hidden)
`;

test.describe("hidden network request", { skip: !hasGi && "python3 gi is missing" }, () => {
    test("names and passwords are checked before NetworkManager hears about them", () => {
        const run = python(LOAD + `
import json
p = hidden.problem
print(json.dumps([
    p("", "wpa", "longenough"),
    p("x" * 33, "open", ""),
    p("office", "open", ""),
    p("office", "wpa", "short"),
    p("office", "wpa", "x" * 64),
    p("office", "wpa", "a" * 64),
    p("office", "sae", ""),
    p("office", "sae", "x"),
    p("office", "wep", "12345"),
]))
`, [SCRIPT]);
        assert.deepStrictEqual(JSON.parse(run.stdout), [
            "the network needs a name",
            "a network name is 32 bytes at most",
            "",
            "wi-fi passwords are 8 to 63 characters",
            "wi-fi passwords are 8 to 63 characters",
            "",
            "the network needs a password",
            "",
            "that kind of security is not supported",
        ]);
    });

    test("the profile is hidden, auto-joins and carries the password only when there is one", () => {
        const run = python(LOAD + `
import json
def plain(settings):
    return {section: {k: v.unpack() for k, v in keys.items()} for section, keys in settings.items()}
secured = plain(hidden.settings_for("Office", "wpa", "correct horse", "11111111-2222-3333-4444-555555555555"))
sae = plain(hidden.settings_for("Office", "sae", "correct horse", "id"))
open_ = plain(hidden.settings_for("Café", "open", "", "id"))
print(json.dumps({"secured": secured, "sae": sae["802-11-wireless-security"], "open": open_}, default=list))
`, [SCRIPT]);
        const seen = JSON.parse(run.stdout);
        assert.strictEqual(seen.secured.connection.id, "Office");
        assert.strictEqual(seen.secured.connection.type, "802-11-wireless");
        assert.strictEqual(seen.secured.connection.autoconnect, true);
        assert.strictEqual(seen.secured["802-11-wireless"].hidden, true);
        assert.deepStrictEqual(seen.secured["802-11-wireless"].ssid, [...Buffer.from("Office")]);
        assert.deepStrictEqual(seen.secured["802-11-wireless-security"], { "key-mgmt": "wpa-psk", psk: "correct horse" });
        assert.strictEqual(seen.sae["key-mgmt"], "sae");
        assert.strictEqual(seen.open["802-11-wireless-security"], undefined);
        assert.deepStrictEqual(seen.open["802-11-wireless"].ssid, [...Buffer.from("Café")]);
    });

    test("a bad request is refused before NetworkManager is asked, with a plain reason", () => {
        const run = spawnSync("python3", ["-I", SCRIPT, "wlan0"], { encoding: "utf8", timeout: 20000, input: JSON.stringify({ ssid: "x".repeat(40), security: "wpa", password: "hunter22hunter22" }) + "\n" });
        assert.strictEqual(run.status, 1);
        assert.deepStrictEqual(JSON.parse(run.stdout), { event: "failed", why: "a network name is 32 bytes at most" });
    });
});

const NM = `
import json, os, subprocess, sys, threading, queue, time
import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

SCRIPT = sys.argv[1]
OUTCOME = sys.argv[2]
ADDRESS = os.environ["DBUS_SESSION_BUS_ADDRESS"]

XML = """
<node>
<interface name="org.freedesktop.NetworkManager">
<method name="GetDeviceByIpIface"><arg type="s" direction="in"/><arg type="o" direction="out"/></method>
<method name="AddAndActivateConnection"><arg type="a{sa{sv}}" direction="in"/><arg type="o" direction="in"/><arg type="o" direction="in"/><arg type="o" direction="out"/><arg type="o" direction="out"/></method>
</interface>
</node>
"""
SAVED_XML = """
<node><interface name="org.freedesktop.NetworkManager.Settings.Connection"><method name="Delete"/></interface></node>
"""
ACTIVE_XML = """
<node><interface name="org.freedesktop.DBus.Properties"><method name="Get"><arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="v" direction="out"/></method></interface></node>
"""

seen = {"calls": []}
conn_holder = {}

def on_nm(conn, sender, path, iface, method, params, invocation):
    values = params.unpack()
    if method == "GetDeviceByIpIface":
        seen["iface"] = values[0]
        invocation.return_value(GLib.Variant("(o)", ("/org/freedesktop/NetworkManager/Devices/3",)))
        return
    settings, device, specific = values
    seen["settings"] = {k: sorted(v.keys()) for k, v in settings.items()}
    seen["psk"] = settings.get("802-11-wireless-security", {}).get("psk")
    seen["device"] = device
    invocation.return_value(GLib.Variant("(oo)", ("/org/freedesktop/NetworkManager/Settings/9", "/org/freedesktop/NetworkManager/ActiveConnection/4")))
    if OUTCOME == "instant":
        return
    state, reason = (2, 1) if OUTCOME == "joined" else (4, 9)
    def fire():
        conn.emit_signal(None, "/org/freedesktop/NetworkManager/ActiveConnection/4", "org.freedesktop.NetworkManager.Connection.Active", "StateChanged", GLib.Variant("(uu)", (state, reason)))
        return False
    GLib.timeout_add(400, fire)

def on_saved(conn, sender, path, iface, method, params, invocation):
    seen["calls"].append(method)
    invocation.return_value(None)

def on_active(conn, sender, path, iface, method, params, invocation):
    invocation.return_value(GLib.Variant("(v)", (GLib.Variant("u", 2 if OUTCOME == "instant" else 1),)))

def acquired(conn, name):
    conn.register_object("/org/freedesktop/NetworkManager", Gio.DBusNodeInfo.new_for_xml(XML).interfaces[0], on_nm, None, None)
    conn.register_object("/org/freedesktop/NetworkManager/Settings/9", Gio.DBusNodeInfo.new_for_xml(SAVED_XML).interfaces[0], on_saved, None, None)
    conn.register_object("/org/freedesktop/NetworkManager/ActiveConnection/4", Gio.DBusNodeInfo.new_for_xml(ACTIVE_XML).interfaces[0], on_active, None, None)
    threading.Thread(target=scenario, daemon=True).start()

def scenario():
    env = dict(os.environ, DBUS_SYSTEM_BUS_ADDRESS=ADDRESS)
    proc = subprocess.Popen([sys.executable, "-I", SCRIPT, "wlan0"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, env=env)
    proc.stdin.write(json.dumps({"ssid": "Office", "security": "wpa", "password": "correct horse"}) + "\\n")
    proc.stdin.flush()
    out, _ = proc.communicate(timeout=20)
    seen["out"] = [json.loads(l) for l in out.splitlines()]
    seen["exit"] = proc.returncode
    print(json.dumps(seen), flush=True)
    GLib.idle_add(loop.quit)

loop = GLib.MainLoop()
Gio.bus_own_name(Gio.BusType.SESSION, "org.freedesktop.NetworkManager", Gio.BusNameOwnerFlags.NONE, acquired, None, None)
GLib.timeout_add_seconds(40, loop.quit)
loop.run()
`;

function fakeManager(outcome) {
    const run = spawnSync("dbus-run-session", ["--", "python3", "-I", "-c", NM, SCRIPT, outcome], { encoding: "utf8", timeout: 60000 });
    return JSON.parse(run.stdout.trim().split("\n").pop());
}

test.describe("hidden network join on a private bus", { skip: (!hasGi && "python3 gi is missing") || (!hasBus && "dbus-run-session is missing") }, () => {
    test("adds the profile on the named adapter and keeps it once the network is up", () => {
        const seen = fakeManager("joined");
        assert.strictEqual(seen.iface, "wlan0");
        assert.strictEqual(seen.psk, "correct horse");
        assert.deepStrictEqual(seen.settings["802-11-wireless"], ["hidden", "mode", "ssid"]);
        assert.deepStrictEqual(seen.out, [{ event: "joined" }]);
        assert.strictEqual(seen.exit, 0);
        assert.deepStrictEqual(seen.calls, []);
    });

    test("a join that is already up when first looked at ends at once and keeps the profile", () => {
        const started = Date.now();
        const seen = fakeManager("instant");
        assert.deepStrictEqual(seen.out, [{ event: "joined" }]);
        assert.strictEqual(seen.exit, 0);
        assert.deepStrictEqual(seen.calls, []);
        assert.ok(Date.now() - started < 15000);
    });

    test("a refused password says so and takes the profile back out", () => {
        const seen = fakeManager("refused");
        assert.deepStrictEqual(seen.out, [{ event: "failed", why: "wrong password" }]);
        assert.strictEqual(seen.exit, 1);
        assert.deepStrictEqual(seen.calls, ["Delete"]);
    });
});
