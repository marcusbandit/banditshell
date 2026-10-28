const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const PROMPTER = path.resolve(__dirname, "../scripts/keyring-prompter.py");

const hasGcr = spawnSync("python3", ["-c", "import gi, cryptography; gi.require_version('Gcr', '3'); from gi.repository import Gcr"]).status === 0;
const hasBus = spawnSync("sh", ["-c", "command -v dbus-run-session"]).status === 0;

const CLIENT = `
import json, queue, subprocess, sys, threading, time
import gi
gi.require_version("Gcr", "3")
from gi.repository import Gcr, GLib

SHELL = """
import json, subprocess, sys, threading
helper = subprocess.Popen([sys.executable, "-I", sys.argv[1]], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
print(json.dumps({"event": "helper", "pid": helper.pid}), flush=True)
def answer():
    for line in sys.stdin:
        helper.stdin.write(line)
        helper.stdin.flush()
threading.Thread(target=answer, daemon=True).start()
for line in helper.stdout:
    sys.stdout.write(line)
    sys.stdout.flush()
"""

shell = subprocess.Popen([sys.executable, "-I", "-c", SHELL, sys.argv[1]], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
events = queue.Queue()

def read():
    for line in shell.stdout:
        events.put(json.loads(line))

threading.Thread(target=read, daemon=True).start()

def wait_for(kind, timeout=10):
    deadline = time.time() + timeout
    while time.time() < deadline:
        GLib.MainContext.default().iteration(False)
        try:
            event = events.get(timeout=0.05)
        except queue.Empty:
            continue
        if event.get("event") == kind:
            return event
    raise SystemExit(f"no {kind} event")

def alive(pid):
    try:
        with open(f"/proc/{pid}/stat") as handle:
            return handle.read().rsplit(")", 1)[1].split()[0] != "Z"
    except OSError:
        return False

helper = wait_for("helper")["pid"]

def open_prompt():
    wait_for("acquired")
    return Gcr.SystemPrompt.open_for_prompter("org.gnome.keyring.SystemPrompter", 10, None)

def ask(prompt, secret):
    out = {}
    loop = GLib.MainLoop()
    def done(source, result):
        out["password"] = source.password_finish(result)
        loop.quit()
    prompt.password_async(None, done)
    shown = wait_for("show")
    shell.stdin.write(json.dumps({"id": shown["id"], "reply": "yes", "secret": secret}) + "\\n")
    shell.stdin.flush()
    GLib.timeout_add_seconds(10, loop.quit)
    loop.run()
    return out.get("password")
`;

function python(script, { bus = false, timeout = 60000 } = {}) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "keyring-prompter-"));
    const file = path.join(dir, "probe.py");
    fs.writeFileSync(file, script);
    const command = bus ? ["dbus-run-session", "--", "python3", "-I", file, PROMPTER] : ["python3", "-I", file, PROMPTER];
    const run = spawnSync(command[0], command.slice(1), {
        encoding: "utf8",
        env: { PATH: process.env.PATH, HOME: dir, XDG_DATA_HOME: path.join(dir, "data"), XDG_DATA_DIRS: path.join(dir, "system") },
        timeout
    });
    fs.rmSync(dir, { recursive: true, force: true });
    assert.strictEqual(run.status, 0, run.stderr);
    return JSON.parse(run.stdout.trim().split("\n").pop());
}

test.describe("keyring-prompter.py", { skip: !hasGcr && "python3 gi, cryptography or Gcr 3 missing" }, () => {
    test("agrees with gcr when the shared key starts with zero bytes", () => {
        const result = python(`
import importlib.util, json, sys
import gi
gi.require_version("Gcr", "3")
spec = importlib.util.spec_from_file_location("prompter", sys.argv[1])
prompter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prompter)
from gi.repository import Gcr
theirs = Gcr.SecretExchange.new(None)
opening = theirs.begin()
peer = int.from_bytes(prompter._keyfile_read(opening)["public"], "big")
for private in range(3, 1 << 20, 2):
    if pow(peer, private, prompter.PRIME_1536).bit_length() <= 1528:
        break
ours = prompter.Exchange()
ours._private = private
ours._public = pow(prompter.GENERATOR, private, prompter.PRIME_1536)
ours.receive(opening)
short = pow(peer, private, prompter.PRIME_1536).bit_length() <= 1528
theirs.receive(ours.send(b"pw"))
agreed = short and ours.receive(theirs.send("back", -1)) == b"back"
print(json.dumps({"agreed": agreed}))
`);
        assert.strictEqual(result.agreed, true);
    });

    test("names a program by its binary even after an upgrade deleted it", () => {
        const result = python(`
import importlib.util, json, os, shutil, subprocess, sys, tempfile
spec = importlib.util.spec_from_file_location("prompter", sys.argv[1])
prompter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prompter)
where = tempfile.mkdtemp()
binary = os.path.join(where, "gcr-prompter")
shutil.copy(shutil.which("sleep"), binary)
running = subprocess.Popen([binary, "30"])
os.remove(binary)
deleted = os.readlink(f"/proc/{running.pid}/exe").endswith(" (deleted)")
named = prompter.Prompter(None).program_at(running.pid)
running.kill()
print(json.dumps({"deleted": deleted, "named": named}))
`);
        assert.deepStrictEqual(result, { deleted: true, named: "gcr-prompter" });
    });

    test("tells gnome-keyring a typed password is not blank", { skip: !hasBus && "dbus-run-session missing" }, () => {
        const result = python(`
${CLIENT}
prompt = open_prompt()
prompt.set_password_new(True)
answer = ask(prompt, "hunter2")
print(json.dumps({"password": answer, "strength": prompt.get_password_strength()}))
`, { bus: true });
        assert.strictEqual(result.password, "hunter2");
        assert.ok(result.strength > 0, `strength ${result.strength}`);
    });

    test("quits when the shell goes away while a card is showing", { skip: !hasBus && "dbus-run-session missing" }, () => {
        const result = python(`
${CLIENT}
prompt = open_prompt()
prompt.password_async(None, lambda *_: None)
wait_for("show")
shell.kill()
deadline = time.time() + 5
while alive(helper) and time.time() < deadline:
    time.sleep(0.05)
print(json.dumps({"exited": not alive(helper)}))
`, { bus: true });
        assert.strictEqual(result.exited, true);
    });
    test("waits in line for the prompter name, says which process holds it, and takes it once the holder lets go", { skip: !hasBus && "dbus-run-session missing" }, () => {
        const result = python(`
import json, os, queue, subprocess, sys, threading, time
from gi.repository import Gio, GLib

NAME = "org.gnome.keyring.SystemPrompter"
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)

def call(method, args, reply):
    return bus.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", method, args, GLib.VariantType.new(reply), Gio.DBusCallFlags.NONE, -1, None).unpack()[0]

held = call("RequestName", GLib.Variant("(su)", (NAME, 4)), "(u)")
helper = subprocess.Popen([sys.executable, "-I", sys.argv[1]], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
events = queue.Queue()
threading.Thread(target=lambda: [events.put(json.loads(line)) for line in helper.stdout], daemon=True).start()

def next_about(timeout=10):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            event = events.get(timeout=0.05)
        except queue.Empty:
            continue
        if event.get("name") == NAME:
            return event
    return {}

owner = next_about()
first = owner.get("event")
time.sleep(0.3)
waiting = helper.poll() is None
call("ReleaseName", GLib.Variant("(s)", (NAME,)), "(u)")
second = next_about().get("event")
helper.kill()
print(json.dumps({"held": held, "first": first, "holder": owner.get("pid") == os.getpid(), "waiting": waiting, "second": second}))
`, { bus: true });
        assert.deepStrictEqual(result, { held: 1, first: "owner", holder: true, waiting: true, second: "acquired" });
    });
});
