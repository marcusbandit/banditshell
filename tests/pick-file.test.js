const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawn, spawnSync } = require("node:child_process");

const SCRIPT = path.resolve(__dirname, "../scripts/pick-file.py");

function eitherCase(globs) {
    const code = [
        "import importlib.util, json, sys",
        "spec = importlib.util.spec_from_file_location('pick_file', sys.argv[1])",
        "module = importlib.util.module_from_spec(spec)",
        "spec.loader.exec_module(module)",
        "print(json.dumps([module.either_case(g) for g in sys.argv[2:]]))"
    ].join("\n");
    const run = spawnSync("python3", ["-I", "-c", code, SCRIPT, ...globs], { encoding: "utf8" });
    assert.strictEqual(run.status, 0, run.stderr);
    return JSON.parse(run.stdout);
}

test("the file filter matches an extension in either case", () => {
    assert.deepStrictEqual(eitherCase(["*.p12", "*.json"]), ["*.[pP]12", "*.[jJ][sS][oO][nN]"]);
});

function checkWith(zenity) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "pick-file-"));
    if (zenity)
        fs.writeFileSync(path.join(dir, "zenity"), "#!/bin/sh\nexit 0\n", { mode: 0o755 });
    const code = [
        "import importlib.util, os, sys",
        "spec = importlib.util.spec_from_file_location('pick_file', sys.argv[1])",
        "module = importlib.util.module_from_spec(spec)",
        "spec.loader.exec_module(module)",
        "module.Gio = None",
        "os.environ['PATH'] = sys.argv[2]",
        "print(module.check())"
    ].join("\n");
    const run = spawnSync("python3", ["-I", "-c", code, SCRIPT, dir], { encoding: "utf8" });
    fs.rmSync(dir, { recursive: true, force: true });
    assert.strictEqual(run.status, 0, run.stderr);
    return Number(run.stdout.trim());
}

test("the check finds zenity when no portal answers, and says no chooser without either", () => {
    assert.strictEqual(checkWith(true), 0);
    assert.strictEqual(checkWith(false), 2);
});

const FAKE_PORTAL = `
import sys
from gi.repository import Gio, GLib
log = open(sys.argv[1], "a", buffering=1)
XML = """<node>
<interface name="org.freedesktop.portal.FileChooser"><method name="OpenFile"><arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="a{sv}" direction="in"/><arg type="o" direction="out"/></method></interface>
<interface name="org.freedesktop.portal.Request"><method name="Close"/></interface>
</node>"""
node = Gio.DBusNodeInfo.new_for_xml(XML)
def call(conn, sender, path, iface, method, params, invocation):
    if method == "OpenFile" and sys.argv[2:] == ["fail"]:
        log.write("asked\\n")
        GLib.timeout_add(500, lambda: invocation.return_dbus_error("org.freedesktop.portal.Error.Failed", "no backend"))
    elif method == "OpenFile":
        token = params.unpack()[2]["handle_token"]
        handle = "/org/freedesktop/portal/desktop/request/" + sender[1:].replace(".", "_") + "/" + token
        conn.register_object(handle, node.interfaces[1], call, None, None)
        log.write("opened\\n")
        invocation.return_value(GLib.Variant("(o)", (handle,)))
    else:
        log.write("closed " + path.rsplit("/", 1)[1] + "\\n")
        invocation.return_value(None)
def acquired(conn, name):
    print("ready", flush=True)
def bus(conn, name):
    conn.register_object("/org/freedesktop/portal/desktop", node.interfaces[0], call, None, None)
Gio.bus_own_name(Gio.BusType.SESSION, "org.freedesktop.portal.Desktop", 0, bus, acquired, None)
GLib.MainLoop().run()
`;

function until(ready, ms = 5000) {
    return new Promise((resolve, reject) => {
        const start = Date.now();
        const look = () => ready() ? resolve() : Date.now() - start > ms ? reject(new Error("timed out")) : setTimeout(look, 20);
        look();
    });
}

function exited(child) {
    return new Promise(resolve => child.on("exit", (code, signal) => resolve(code ?? signal)));
}

function read(file) {
    try {
        return fs.readFileSync(file, "utf8");
    } catch {
        return "";
    }
}

async function withRig(work) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "pick-file-"));
    const started = [];
    const run = (file, args, env) => {
        const child = spawn(file, args, { env, stdio: ["ignore", "pipe", "ignore"] });
        started.push(child);
        return child;
    };
    try {
        return await work(dir, path.join(dir, "log"), run);
    } finally {
        for (const child of started)
            if (child.exitCode === null && child.signalCode === null)
                child.kill("SIGKILL");
        fs.rmSync(dir, { recursive: true, force: true });
    }
}

function zenityAfter(ending) {
    return withRig(async (dir, log, run) => {
        fs.writeFileSync(path.join(dir, "zenity"), `#!/bin/sh\ntrap 'echo stopped >>"${log}"; kill $!; exit 143' TERM\necho open >>"${log}"\nsleep 30 &\nwait $!\n`, { mode: 0o755 });
        const child = run("python3", ["-I", SCRIPT, "Pick", "*.pem", dir], { PATH: `${dir}:/usr/bin:/bin`, DBUS_SESSION_BUS_ADDRESS: `unix:path=${dir}/no-bus`, HOME: dir });
        const done = exited(child);
        await until(() => read(log).includes("open"));
        child.kill(ending);
        const code = await done;
        await until(() => read(log).includes("stopped")).catch(() => {});
        return { code, said: read(log) };
    });
}

test("ending the chooser ends its zenity dialog too", { timeout: 20000 }, async () => {
    const { code, said } = await zenityAfter("SIGTERM");
    assert.strictEqual(code, 1);
    assert.match(said, /stopped/);
});

test("zenity goes even when the chooser is killed outright", { timeout: 20000 }, async () => {
    const { said } = await zenityAfter("SIGKILL");
    assert.match(said, /stopped/);
});

const portalSkip = spawnSync("python3", ["-I", "-c", "import gi; gi.require_version('Gio', '2.0'); from gi.repository import Gio"]).status !== 0 || spawnSync("sh", ["-c", "command -v dbus-daemon"]).status !== 0 ? "needs python-gobject and dbus-daemon" : false;

function portalRun(mode, ready) {
    return withRig(async (dir, log, run) => {
        fs.writeFileSync(path.join(dir, "zenity"), `#!/bin/sh\necho zenity >>"${log}"\n`, { mode: 0o755 });
        const daemon = run("dbus-daemon", ["--session", "--nofork", "--print-address=1", `--address=unix:path=${dir}/bus`], process.env);
        let address = "";
        daemon.stdout.on("data", chunk => address += chunk);
        await until(() => address.includes("\n"));
        const env = { PATH: `${dir}:/usr/bin:/bin`, DBUS_SESSION_BUS_ADDRESS: address.trim(), HOME: dir };
        const portal = run("python3", ["-I", "-c", FAKE_PORTAL, log, ...mode], env);
        let up = "";
        portal.stdout.on("data", chunk => up += chunk);
        await until(() => up.includes("ready"));
        const child = run("python3", ["-I", SCRIPT, "Pick", "*.pem", dir], env);
        const done = exited(child);
        await until(() => read(log).includes(ready));
        child.kill("SIGTERM");
        return { code: await done, said: read(log), pid: child.pid };
    });
}

test("ending the chooser closes the portal's dialog", { skip: portalSkip, timeout: 20000 }, async () => {
    const { code, said, pid } = await portalRun([], "opened");
    assert.strictEqual(code, 1);
    assert.match(said, new RegExp(`closed banditshell${pid}`));
});

test("ending the chooser while the portal fails does not open zenity instead", { skip: portalSkip, timeout: 20000 }, async () => {
    const { code, said } = await portalRun(["fail"], "asked");
    assert.strictEqual(code, 1);
    assert.doesNotMatch(said, /zenity/);
});
