const test = require("node:test");
const assert = require("node:assert");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const AGENT = path.resolve(__dirname, "../scripts/bluetooth-agent.py");

const hasGi = spawnSync("python3", ["-c", "import gi; gi.require_version('Gio', '2.0')"]).status === 0;
const hasBus = spawnSync("sh", ["-c", "command -v dbus-run-session"]).status === 0;

function python(code, args = []) {
    return spawnSync("python3", ["-I", "-c", code, ...args], { encoding: "utf8", timeout: 20000 });
}

const LOAD = `
import importlib.util, sys
spec = importlib.util.spec_from_file_location("agent", sys.argv[1])
agent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(agent)
`;

test.describe("agent requests", { skip: !hasGi && "python3 gi is missing" }, () => {
    test("a device path gives its address and a passkey is padded to six digits", () => {
        const run = python(LOAD + `
print(agent.address_of("/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF"), agent.address_of("/org/bluez/hci0"), agent.passkey_text(42))
`, [AGENT]);
        assert.strictEqual(run.stdout.trim(), "AA:BB:CC:DD:EE:FF  000042");
    });

    test("each request turns into the event the menu reads", () => {
        const run = python(LOAD + `
import json
dev = "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF"
print(json.dumps([
    agent.event_for("RequestConfirmation", (dev, 123456), "Pixel"),
    agent.event_for("RequestPasskey", (dev,), "Keys"),
    agent.event_for("RequestPinCode", (dev,), ""),
    agent.event_for("DisplayPasskey", (dev, 4321, 2), "Keys"),
    agent.event_for("DisplayPinCode", (dev, "0000"), "Old"),
    agent.event_for("AuthorizeService", (dev, "uuid"), "Keys"),
], sort_keys=True))
`, [AGENT]);
        const [confirm, passkey, pin, shown, shownPin, service] = JSON.parse(run.stdout);
        assert.deepStrictEqual(confirm, { address: "AA:BB:CC:DD:EE:FF", code: "123456", event: "ask", kind: "confirm", name: "Pixel" });
        assert.strictEqual(passkey.kind, "passkey");
        assert.strictEqual(pin.kind, "pin");
        assert.deepStrictEqual(shown, { address: "AA:BB:CC:DD:EE:FF", code: "004321", entered: 2, event: "show", name: "Keys" });
        assert.strictEqual(shownPin.code, "0000");
        assert.strictEqual(service, null);
    });

    test("an answer becomes the reply BlueZ expects, and a bad one becomes a refusal", () => {
        const run = python(LOAD + `
import json
r = agent.reply_for
print(json.dumps([
    r("RequestPasskey", {"accept": True, "code": "4321"}).unpack(),
    r("RequestPasskey", {"accept": True, "code": "1234567"}),
    r("RequestPasskey", {"accept": True, "code": "12a"}),
    r("RequestPasskey", {"accept": False, "code": "4321"}),
    r("RequestPinCode", {"accept": True, "code": "0000"}).unpack(),
    r("RequestPinCode", {"accept": True, "code": ""}),
    r("RequestConfirmation", {"accept": True}).unpack(),
]))
`, [AGENT]);
        assert.deepStrictEqual(JSON.parse(run.stdout), [[4321], null, null, null, ["0000"], null, []]);
    });
});

const BLUEZ = `
import json, os, subprocess, sys, threading, queue, time
import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

AGENT = sys.argv[1]
ADDRESS = os.environ["DBUS_SESSION_BUS_ADDRESS"]
DEVICE = "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF"
IFACE = "org.bluez.Agent1"

MANAGER_XML = """
<node><interface name="org.bluez.AgentManager1">
<method name="RegisterAgent"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
<method name="RequestDefaultAgent"><arg type="o" direction="in"/></method>
<method name="UnregisterAgent"><arg type="o" direction="in"/></method>
</interface></node>
"""

PROPS_XML = """
<node><interface name="org.freedesktop.DBus.Properties"><method name="Get"><arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="v" direction="out"/></method></interface></node>
"""
STRANGER = "/org/bluez/hci0/dev_11_22_33_44_55_66"

calls = queue.Queue()
registered = {}

def on_device(conn, sender, path, iface, method, params, invocation):
    prop = params.unpack()[1]
    paired = path == DEVICE
    value = GLib.Variant("b", paired) if prop == "Paired" else GLib.Variant("s", "Keys" if paired else "Stranger")
    invocation.return_value(GLib.Variant("(v)", (value,)))

def on_manager(conn, sender, path, iface, method, params, invocation):
    calls.put((method, params.unpack(), sender))
    if method == "RegisterAgent":
        registered["sender"] = sender
        registered["path"] = params.unpack()[0]
        registered["capability"] = params.unpack()[1]
    invocation.return_value(None)

def acquired(conn, name):
    conn.register_object("/org/bluez", Gio.DBusNodeInfo.new_for_xml(MANAGER_XML).interfaces[0], on_manager, None, None)
    for device in (DEVICE, STRANGER):
        conn.register_object(device, Gio.DBusNodeInfo.new_for_xml(PROPS_XML).interfaces[0], on_device, None, None)
    threading.Thread(target=scenario, args=(conn,), daemon=True).start()

loop = GLib.MainLoop()
Gio.bus_own_name(Gio.BusType.SESSION, "org.bluez", Gio.BusNameOwnerFlags.NONE, acquired, None, None)

results = {}

def ask(conn, method, args, signature, reply_type, out):
    try:
        reply = conn.call_sync(registered["sender"], registered["path"], IFACE, method, GLib.Variant(signature, args), GLib.VariantType(reply_type) if reply_type else None, Gio.DBusCallFlags.NONE, 8000, None)
        out["value"] = reply.unpack() if reply else ()
    except GLib.Error as error:
        out["error"] = Gio.dbus_error_get_remote_error(error)

def scenario(conn):
    try:
        env = dict(os.environ, DBUS_SYSTEM_BUS_ADDRESS=ADDRESS)
        proc = subprocess.Popen([sys.executable, "-I", AGENT], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, env=env)
        lines = queue.Queue()
        threading.Thread(target=lambda: [lines.put(json.loads(l)) for l in proc.stdout], daemon=True).start()

        def next_event(kind):
            deadline = time.time() + 8
            while time.time() < deadline:
                try:
                    event = lines.get(timeout=0.2)
                except queue.Empty:
                    continue
                if event["event"] == kind:
                    return event
            raise RuntimeError("no " + kind + " event")

        def answer(payload):
            proc.stdin.write(json.dumps(payload) + "\\n")
            proc.stdin.flush()

        next_event("ready")
        results["capability"] = registered["capability"]
        results["path"] = registered["path"]

        out = {}
        t = threading.Thread(target=ask, args=(conn, "RequestConfirmation", (DEVICE, 123456), "(ou)", None, out))
        t.start()
        event = next_event("ask")
        results["confirm"] = [event["kind"], event["code"], event["address"]]
        results["confirmName"] = event["name"]
        answer({"id": event["id"], "accept": True})
        t.join()
        results["confirmReply"] = out

        out = {}
        t = threading.Thread(target=ask, args=(conn, "RequestPasskey", (DEVICE,), "(o)", "(u)", out))
        t.start()
        event = next_event("ask")
        answer({"id": event["id"], "accept": True, "code": "4321"})
        t.join()
        results["passkeyReply"] = out

        out = {}
        t = threading.Thread(target=ask, args=(conn, "RequestPinCode", (DEVICE,), "(o)", "(s)", out))
        t.start()
        event = next_event("ask")
        answer({"id": event["id"], "accept": False})
        t.join()
        results["refusedReply"] = out

        out = {}
        t = threading.Thread(target=ask, args=(conn, "RequestPasskey", (DEVICE,), "(o)", "(u)", out))
        t.start()
        next_event("ask")
        cancel = {}
        ask(conn, "Cancel", (), "()", None, cancel)
        t.join()
        results["canceledReply"] = out
        next_event("cancel")

        out = {}
        ask(conn, "AuthorizeService", (DEVICE, "0000110b-0000-1000-8000-00805f9b34fb"), "(os)", None, out)
        results["pairedService"] = out
        out = {}
        ask(conn, "AuthorizeService", (STRANGER, "0000110b-0000-1000-8000-00805f9b34fb"), "(os)", None, out)
        results["strangerService"] = out

        out = {}
        ask(conn, "DisplayPasskey", (DEVICE, 4321, 2), "(ouq)", None, out)
        event = next_event("show")
        results["shown"] = [event["code"], event["entered"]]

        proc.stdin.close()
        proc.wait(timeout=8)
        results["exit"] = proc.returncode
        methods = []
        while not calls.empty():
            methods.append(calls.get()[0])
        results["manager"] = methods
    except Exception as error:
        results["failure"] = repr(error)
    print(json.dumps(results), flush=True)
    GLib.idle_add(loop.quit)

GLib.timeout_add_seconds(40, loop.quit)
loop.run()
`;

test.describe("agent on a private bus", { skip: (!hasGi && "python3 gi is missing") || (!hasBus && "dbus-run-session is missing") }, () => {
    test("registers with BlueZ, asks, answers, refuses, cancels and unregisters", () => {
        const run = spawnSync("dbus-run-session", ["--", "python3", "-I", "-c", BLUEZ, AGENT], { encoding: "utf8", timeout: 60000 });
        const last = run.stdout.trim().split("\n").pop();
        const seen = JSON.parse(last);
        assert.strictEqual(seen.failure, undefined);
        assert.strictEqual(seen.capability, "KeyboardDisplay");
        assert.deepStrictEqual(seen.confirm, ["confirm", "123456", "AA:BB:CC:DD:EE:FF"]);
        assert.strictEqual(seen.confirmName, "Keys");
        assert.deepStrictEqual(seen.confirmReply, { value: [] });
        assert.deepStrictEqual(seen.passkeyReply, { value: [4321] });
        assert.strictEqual(seen.refusedReply.error, "org.bluez.Error.Rejected");
        assert.strictEqual(seen.canceledReply.error, "org.bluez.Error.Canceled");
        assert.deepStrictEqual(seen.pairedService, { value: [] });
        assert.strictEqual(seen.strangerService.error, "org.bluez.Error.Rejected");
        assert.deepStrictEqual(seen.shown, ["004321", 2]);
        assert.strictEqual(seen.exit, 0);
        assert.deepStrictEqual(seen.manager, ["RegisterAgent", "RequestDefaultAgent", "UnregisterAgent"]);
    });
});
