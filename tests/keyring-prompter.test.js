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
derive = prompter.Exchange._derive
def remember(self, peer):
    self.shared = pow(peer, self._private, prompter.PRIME_1536)
    derive(self, peer)
prompter.Exchange._derive = remember
short = agreed = 0
for _ in range(4000):
    theirs = Gcr.SecretExchange.new(None)
    ours = prompter.Exchange()
    ours.receive(theirs.begin())
    if ours.shared.bit_length() > 1528:
        continue
    short += 1
    theirs.receive(ours.send(b"pw"))
    agreed += ours.receive(theirs.send("back", -1)) == b"back"
    if short == 2:
        break
print(json.dumps({"short": short, "agreed": agreed}))
`);
        assert.ok(result.short >= 1, "never drew a shared key with a leading zero byte");
        assert.strictEqual(result.agreed, result.short);
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
});
