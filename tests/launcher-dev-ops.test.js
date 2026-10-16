const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Ranking = lib("services/ranking.js", ["place"]);
const Ssh = lib("services/ssh-hosts.js", ["ask", "readCommand", "readFiles", "missingIncludes", "assemble", "configHosts", "readKnownHosts", "merged", "detailOf", "matching", "ambient", "validTarget", "terminalLine", "commandText"]);
const Ports = lib("services/listening-ports.js", ["ask", "command", "readListeners", "readUsers", "readSockets", "withSockets", "killable", "freeable", "verifyCommand", "confirmedPids", "killOutcome", "matching", "detailOf", "labelOf", "browsable", "validPort", "ownerName"]);
const Units = lib("services/systemd-units.js", ["ask", "readUnits", "matching", "detailOf", "stateOf", "controlCommand", "logsLine", "validUnit", "startable"]);
const Boxes = lib("services/containers.js", ["ask", "readAll", "matching", "detailOf", "controlCommand", "logsLine", "shellLine", "validId"]);
const Phone = lib("services/phone.js", ["ask", "readDevices", "matching", "detailOf", "commandFor", "payloadOf", "linkFrom", "shareable", "expandPath", "payloadLabel"]);
const Binaries = lib("services/system-binaries.js", ["probeCommand", "readPaths", "systemPath", "elevated"]);
const PATHS = Binaries.readPaths("pkexec\t/usr/bin/pkexec\nsystemctl\t/usr/bin/systemctl\nkill\t/usr/bin/kill\nfuser\t/usr/sbin/fuser");
const elevate = (tool, args) => Binaries.elevated(PATHS, tool, args);

const files = entries => entries.map(([pattern, list]) => `\u001d${pattern}\n` + list.map(([file, text]) => `\u001e${file}\n${text}\n`).join("")).join("");

test.describe("ssh hosts", () => {
    test.it("reads ssh and ssh with a host", () => {
        assert.deepStrictEqual(Ssh.ask("ssh"), { words: "" });
        assert.deepStrictEqual(Ssh.ask("ssh homehub"), { words: "homehub" });
        assert.deepStrictEqual(Ssh.ask("  SSH me@box "), { words: "me@box" });
        assert.strictEqual(Ssh.ask("sshd"), null);
        assert.strictEqual(Ssh.ask("show ssh"), null);
    });

    test.it("passes include patterns as arguments, never inside the script", () => {
        const command = Ssh.readCommand(["config.d/*", "~/work/ssh"]);
        assert.deepStrictEqual(command.slice(0, 2), ["sh", "-c"]);
        assert.deepStrictEqual(command.slice(3), ["sh", "config.d/*", "~/work/ssh"]);
        assert.ok(!command[2].includes("config.d"));
        assert.match(command[2], /id_\*/);
    });

    test.it("follows Include lines in place, including globs that matched several files", () => {
        const blob = files([
            ["config", [["/h/.ssh/config", "Include config.d/*\nHost main\n  HostName 10.0.0.1"]]],
            ["config.d/*", [["/h/.ssh/config.d/a", "Host alpha\n  User ann"], ["/h/.ssh/config.d/b", "Host beta\nInclude deeper"]]]
        ]);
        const read = Ssh.readFiles(blob);
        assert.deepStrictEqual(Object.keys(read), ["config", "config.d/*"]);
        assert.deepStrictEqual(Ssh.missingIncludes(read), ["deeper"]);
        const all = Object.assign({}, read, Ssh.readFiles(files([["deeper", [["/h/.ssh/deeper", "Host gamma"]]]])));
        assert.deepStrictEqual(Ssh.missingIncludes(all), []);
        assert.deepStrictEqual(Ssh.configHosts(Ssh.assemble(all, "config", 0)).map(h => h.name), ["alpha", "beta", "gamma", "main"]);
    });

    test.it("stops on include loops", () => {
        const loop = Ssh.readFiles(files([["config", [["/h/.ssh/config", "Host one\nInclude config"]]]]));
        assert.deepStrictEqual(Ssh.configHosts(Ssh.assemble(loop, "config", 0)).map(h => h.name), ["one"]);
    });

    test.it("skips patterns, keeps first values and applies Host * defaults the way ssh does", () => {
        const text = ["User everyone", "Host web db *.lan !bad", "  HostName %h.example.org", "  Port 2222", "Host db", "  User root", "  HostName ignored", "Match host db", "  User matched", "Host *", "  User fallback", "  ProxyJump gate"].join("\n");
        const hosts = Ssh.configHosts(Ssh.assemble(Ssh.readFiles(files([["config", [["c", text]]]])), "config", 0));
        assert.deepStrictEqual(hosts.map(h => h.name), ["web", "db"]);
        assert.deepStrictEqual(hosts[0], { name: "web", address: "web.example.org", user: "everyone", port: "2222", jump: "gate", known: false });
        assert.strictEqual(hosts[1].address, "db.example.org");
        assert.strictEqual(Ssh.detailOf(hosts[0]), "everyone@web.example.org:2222 · via gate");
    });

    test.it("reads quoted values, equals signs and trailing comments", () => {
        const hosts = Ssh.configHosts(Ssh.assemble(Ssh.readFiles(files([["config", [["c", 'Host="nas" # the box\n  User=me\n  HostName "10.1.1.1"']]]])), "config", 0));
        assert.deepStrictEqual(hosts[0], { name: "nas", address: "10.1.1.1", user: "me", port: "", jump: "", known: false });
    });

    test.it("reads known_hosts, skipping hashed lines, patterns and revoked markers", () => {
        const known = Ssh.readKnownHosts(["|1|abc=|def= ssh-ed25519", "github.com,140.82.1.1 ssh-ed25519", "[git.local]:2222 ecdsa-sha2-nistp256", "@cert-authority *.corp ssh-rsa", "@revoked old.host ssh-rsa", "# comment", "github.com ssh-rsa"].join("\n"));
        assert.deepStrictEqual(known.map(h => `${h.name}:${h.port}:${h.keyType}`), ["github.com::ed25519", "140.82.1.1::ed25519", "git.local:2222:ecdsa", "old.host::rsa"]);
        assert.strictEqual(Ssh.detailOf(known[2]), "port 2222 · ecdsa · known host");
    });

    test.it("lists config hosts first and leaves addresses out until typed", () => {
        const configured = [{ name: "box", address: "10.0.0.9", user: "", port: "", jump: "", known: false }];
        const known = Ssh.readKnownHosts("10.0.0.9 ssh-ed25519\nzeta ssh-ed25519\nbox ssh-ed25519\n192.168.1.4 ssh-rsa\nalpha ssh-ed25519");
        const hosts = Ssh.merged(configured, known);
        assert.deepStrictEqual(hosts.map(h => h.name), ["box", "alpha", "zeta", "192.168.1.4"]);
        assert.deepStrictEqual(Ssh.matching(hosts, "", Ranking.place, 10).map(h => h.name), ["box", "alpha", "zeta"]);
        assert.deepStrictEqual(Ssh.matching(hosts, "192", Ranking.place, 10).map(h => h.name), ["192.168.1.4"]);
        assert.deepStrictEqual(Ssh.matching(hosts, "10.0", Ranking.place, 10).map(h => h.name), ["box"]);
    });

    test.it("offers an ambient row only for a configured host name typed in full or nearly", () => {
        const hosts = [{ name: "homehub", known: false }, { name: "hometown", known: true }];
        assert.deepStrictEqual(Ssh.ambient(hosts, "homehub").map(h => h.name), ["homehub"]);
        assert.deepStrictEqual(Ssh.ambient(hosts, "homeh").map(h => h.name), ["homehub"]);
        assert.deepStrictEqual(Ssh.ambient(hosts, "hom"), []);
        assert.deepStrictEqual(Ssh.ambient(hosts, "home hub"), []);
    });

    test.it("accepts plain targets and refuses option and shell tricks", () => {
        for (const ok of ["homehub", "me@box.lan", "10.0.0.1", "::1", "fe80::1%eth0", "a_b-c"])
            assert.ok(Ssh.validTarget(ok), ok);
        for (const bad of ["-oProxyCommand=x", "a b", "$(id)", "box;rm", "", "me@-x", "`x`"])
            assert.ok(!Ssh.validTarget(bad), bad);
    });

    test.it("quotes the host and keeps the terminal open only when ssh itself fails", () => {
        const line = Ssh.terminalLine({ name: "o'neil", known: false });
        assert.ok(line.startsWith("'ssh' '--' 'o'\\''neil';"));
        assert.match(line, /-eq 255/);
        assert.ok(Ssh.terminalLine({ name: "git.local", port: "2222", known: true }).startsWith("'ssh' '-p' '2222' '--' 'git.local'"));
        assert.strictEqual(Ssh.commandText({ name: "git.local", port: "2222", known: true }), "ssh -p 2222 git.local");
    });
});

const SS = [
    "LISTEN 0      128      127.0.0.1:3000   0.0.0.0:* users:((\"node\",pid=4242,fd=20)) uid:1000 ino:1 sk:1 cgroup:/user.slice/user-1000.slice/app.slice/x.scope <->",
    "LISTEN 0      128          [::1]:3000      [::]:* users:((\"node\",pid=4242,fd=21)) uid:1000 ino:2 sk:2 cgroup:/user.slice/user-1000.slice/app.slice/x.scope <->",
    "LISTEN 0      32   127.0.0.53%lo:53     0.0.0.0:* ino:3 sk:3 cgroup:/system.slice/dnsmasq.service <->",
    "LISTEN 0      4096       0.0.0.0:5355   0.0.0.0:* uid:976 ino:4 sk:4 cgroup:/system.slice/systemd-resolved.service <->",
    "LISTEN 0      511        0.0.0.0:8080   0.0.0.0:* users:((\"nginx\",pid=10,fd=6),(\"nginx\",pid=11,fd=6)) uid:1000 ino:5 sk:5 <->",
    "LISTEN 0      4096     127.0.0.1:30000  0.0.0.0:* ino:6 sk:6 cgroup:/system.slice/docker-abc.scope <->"
].join("\n");

test.describe("listening ports", () => {
    test.it("reads every way of asking", () => {
        assert.deepStrictEqual(Ports.ask("ports"), { port: "", words: "", udp: false, tcp: true, quit: false });
        assert.strictEqual(Ports.ask("port 3000").port, "3000");
        assert.deepStrictEqual(Ports.ask("who uses port 8080"), { port: "8080", words: "", udp: false, tcp: true, quit: false, exact: true });
        assert.strictEqual(Ports.ask("what is listening on port 53?").port, "53");
        assert.strictEqual(Ports.ask("kill port 3000").quit, true);
        assert.strictEqual(Ports.ask(":5432").port, "5432");
        assert.deepStrictEqual([Ports.ask("udp ports").udp, Ports.ask("udp ports").tcp], [true, false]);
        assert.deepStrictEqual([Ports.ask("ports all").udp, Ports.ask("ports all").tcp], [true, true]);
        assert.strictEqual(Ports.ask("ports node").words, "node");
        assert.strictEqual(Ports.ask("portal"), null);
        assert.strictEqual(Ports.ask("airport"), null);
    });

    test.it("asks ss for udp only when wanted", () => {
        assert.deepStrictEqual(Ports.command(false), ["ss", "-ltnpeH"]);
        assert.deepStrictEqual(Ports.command(true), ["ss", "-ltunpeH"]);
    });

    test.it("merges addresses of one listener and names owners, units and users", () => {
        const all = Ports.readListeners(SS, "tcp");
        assert.deepStrictEqual(all.map(l => l.port), [53, 3000, 5355, 8080, 30000]);
        const node = all.find(l => l.port === 3000);
        assert.deepStrictEqual(node.addresses, ["127.0.0.1", "[::1]"]);
        assert.deepStrictEqual(node.owners, [{ name: "node", pid: 4242 }]);
        assert.strictEqual(Ports.labelOf(node), "Port 3000 · node");
        assert.strictEqual(Ports.detailOf(node, 1000), "127.0.0.1, [::1] · TCP · PID 4242");
        const dns = all.find(l => l.port === 53);
        assert.deepStrictEqual([dns.addresses, dns.uid, dns.systemUnit], [["127.0.0.53"], 0, "dnsmasq.service"]);
        assert.strictEqual(Ports.labelOf(dns), "Port 53 · dnsmasq");
        assert.strictEqual(Ports.detailOf(dns, 1000), "127.0.0.53 · TCP · root");
        assert.strictEqual(Ports.detailOf(all.find(l => l.port === 5355), 1000), "0.0.0.0 · TCP · uid 976");
        assert.strictEqual(Ports.detailOf(all.find(l => l.port === 8080), 1000), "0.0.0.0 · TCP · PIDs 10, 11");
        assert.strictEqual(all.find(l => l.port === 30000).systemUnit, "");
        const users = Ports.readUsers("root:x:0:0::/root:/bin/bash\nsystemd-resolve:x:976:976::/:/usr/bin/nologin\nbroken line");
        assert.deepStrictEqual(users, { 0: "root", 976: "systemd-resolve" });
        assert.strictEqual(Ports.detailOf(all.find(l => l.port === 5355), 1000, users), "0.0.0.0 · TCP · systemd-resolve");
        assert.strictEqual(Ports.detailOf(all.find(l => l.port === 30000), 1000, {}), "127.0.0.1 · TCP · root");
    });

    test.it("reads the protocol column ss adds when tcp and udp are both listed", () => {
        const both = Ports.readListeners("tcp LISTEN 0 5 0.0.0.0:22 0.0.0.0:*\nudp UNCONN 0 0 0.0.0.0:5353 0.0.0.0:* users:((\"avahi\",pid=7,fd=1))", "tcp");
        assert.deepStrictEqual(both.map(l => `${l.protocol}:${l.port}`), ["tcp:22", "udp:5353"]);
    });

    test.it("matches exact ports, port prefixes, owner words and protocols", () => {
        const all = Ports.readListeners(SS, "tcp");
        assert.deepStrictEqual(Ports.matching(all, Ports.ask("port 3000"), Ranking.place).map(l => l.port), [3000, 30000]);
        assert.deepStrictEqual(Ports.matching(all, Ports.ask("who uses port 3000"), Ranking.place).map(l => l.port), [3000]);
        assert.deepStrictEqual(Ports.matching(all, Ports.ask("ports nginx"), Ranking.place).map(l => l.port), [8080]);
        assert.deepStrictEqual(Ports.matching(all, Ports.ask("ports dnsmasq"), Ranking.place).map(l => l.port), [53]);
        assert.deepStrictEqual(Ports.matching(all, Ports.ask("udp ports"), Ranking.place), []);
    });

    test.it("opens local listeners on localhost and refuses odd ports", () => {
        const all = Ports.readListeners(SS, "tcp");
        assert.strictEqual(Ports.browsable(all.find(l => l.port === 8080)), "http://localhost:8080");
        assert.strictEqual(Ports.browsable({ protocol: "tcp", port: 9, addresses: ["100.1.2.3"] }), "http://100.1.2.3:9");
        assert.strictEqual(Ports.browsable({ protocol: "udp", port: 9, addresses: ["0.0.0.0"] }), "");
        assert.strictEqual(Ports.browsable({ protocol: "tcp", port: 22, addresses: ["0.0.0.0"] }), "");
        assert.strictEqual(Ports.browsable({ protocol: "tcp", port: 5432, addresses: ["127.0.0.1"] }), "");
        assert.ok(Ports.validPort(3000) && !Ports.validPort("3000; x") && !Ports.validPort(70000) && !Ports.validPort(0));
    });
});

const UNITS = [
    "\u001esystem units",
    JSON.stringify([
        { unit: "docker.service", load: "loaded", active: "active", sub: "running", description: "Docker Application Container Engine" },
        { unit: "sshd.service", load: "loaded", active: "inactive", sub: "dead", description: "OpenSSH Daemon" },
        { unit: "broken.service", load: "loaded", active: "failed", sub: "failed", description: "Broken" },
        { unit: "ghost.service", load: "not-found", active: "inactive", sub: "dead", description: "ghost.service" },
        { unit: "getty@tty1.service", load: "loaded", active: "active", sub: "running", description: "Getty on tty1" }
    ]),
    "\u001esystem files",
    JSON.stringify([
        { unit_file: "docker.service", state: "enabled", preset: "disabled" },
        { unit_file: "sshd.service", state: "disabled", preset: "disabled" },
        { unit_file: "getty@.service", state: "enabled", preset: "enabled" },
        { unit_file: "bluetooth.service", state: "disabled", preset: "disabled" },
        { unit_file: "hidden.service", state: "masked", preset: null }
    ]),
    "\u001euser units",
    JSON.stringify([{ unit: "pipewire.service", load: "loaded", active: "active", sub: "running", description: "PipeWire Multimedia Service" }]),
    "\u001euser files",
    ""
].join("\n");

test.describe("systemd services", () => {
    test.it("reads lists, single services and verbs", () => {
        assert.deepStrictEqual(Units.ask("services"), { verb: "", scope: "", words: "", failed: false });
        assert.deepStrictEqual(Units.ask("service docker"), { verb: "", scope: "", words: "docker", failed: false });
        assert.deepStrictEqual(Units.ask("restart sshd"), { verb: "restart", scope: "", words: "sshd", failed: false });
        assert.deepStrictEqual(Units.ask("stop bluetooth.service"), { verb: "stop", scope: "", words: "bluetooth", failed: false });
        assert.deepStrictEqual(Units.ask("restart user pipewire"), { verb: "restart", scope: "user", words: "pipewire", failed: false });
        assert.deepStrictEqual(Units.ask("user services"), { verb: "", scope: "user", words: "", failed: false });
        assert.strictEqual(Units.ask("failed services").failed, true);
        assert.strictEqual(Units.ask("services failed").failed, true);
        assert.deepStrictEqual(Units.ask("systemctl --user restart pipewire"), { verb: "restart", scope: "user", words: "pipewire", failed: false });
        assert.strictEqual(Units.ask("stop the music now"), null);
        assert.strictEqual(Units.ask("servicemenu"), null);
    });

    test.it("merges loaded units with unit files and leaves templates and missing units out", () => {
        const units = Units.readUnits(UNITS);
        assert.deepStrictEqual(units.map(u => `${u.scope}:${u.base}`), ["system:docker", "system:sshd", "system:broken", "system:getty@tty1", "system:bluetooth", "system:hidden", "user:pipewire"]);
        assert.strictEqual(Units.detailOf(units[0]), "running · enabled · Docker Application Container Engine");
        assert.strictEqual(Units.detailOf(units[4]), "inactive · disabled");
        assert.strictEqual(Units.stateOf(units[5]), "masked");
        assert.ok(!Units.startable(units[5]) && Units.startable(units[4]) && !Units.startable(units[0]));
        assert.strictEqual(Units.detailOf(units[6]), "user · running · PipeWire Multimedia Service");
    });

    test.it("puts failed and running services first and makes verbs match names only", () => {
        const units = Units.readUnits(UNITS);
        assert.deepStrictEqual(Units.matching(units, Units.ask("services"), Ranking.place, 3).map(m => m.unit.base), ["broken", "docker", "getty@tty1"]);
        assert.deepStrictEqual(Units.matching(units, Units.ask("failed services"), Ranking.place, 9).map(m => m.unit.base), ["broken"]);
        assert.deepStrictEqual(Units.matching(units, Units.ask("services container"), Ranking.place, 9).map(m => m.unit.base), ["docker"]);
        assert.deepStrictEqual(Units.matching(units, Units.ask("stop container"), Ranking.place, 9), []);
        const sshd = Units.matching(units, Units.ask("restart sshd"), Ranking.place, 9);
        assert.deepStrictEqual(sshd.map(m => [m.unit.base, m.exact]), [["sshd", true]]);
        assert.deepStrictEqual(Units.matching(units, Units.ask("user services"), Ranking.place, 9).map(m => m.unit.base), ["pipewire"]);
    });

    test.it("runs system units through pkexec with a validated name and user units directly", () => {
        assert.deepStrictEqual(Units.controlCommand({ name: "docker.service", scope: "system" }, "restart", elevate), ["/usr/bin/pkexec", "/usr/bin/systemctl", "restart", "--", "docker.service"]);
        assert.deepStrictEqual(Units.controlCommand({ name: "pipewire.service", scope: "user" }, "stop", elevate), ["systemctl", "--user", "stop", "--", "pipewire.service"]);
        assert.deepStrictEqual(Units.controlCommand({ name: "web.socket", names: ["web.socket", "web.service"], scope: "user" }, "stop", elevate), ["systemctl", "--user", "stop", "--", "web.socket", "web.service"]);
        assert.strictEqual(Units.controlCommand({ name: "docker.service", scope: "system" }, "mask", elevate), null);
        assert.strictEqual(Units.controlCommand({ name: "docker.service", scope: "system" }, "start", null), null);
        assert.strictEqual(Units.controlCommand({ name: "docker.service", scope: "system" }, "start", (tool, args) => Binaries.elevated({ pkexec: "/usr/bin/pkexec" }, tool, args)), null);
        for (const bad of ["-x.service", "a b.service", "x;rm.service", "docker", "getty@.service", "$(id).service", "web@.socket", "x.timer"])
            assert.strictEqual(Units.controlCommand({ name: bad, scope: "system" }, "start", elevate), null, bad);
        assert.strictEqual(Units.logsLine({ name: "x;y", scope: "system" }), "");
        assert.ok(Units.logsLine({ name: "docker.service", scope: "system" }).startsWith("journalctl -u 'docker.service' -n 200 -f;"));
        assert.ok(Units.logsLine({ name: "pipewire.service", scope: "user" }).startsWith("journalctl --user -u 'pipewire.service'"));
    });
});

const PODMAN = JSON.stringify([
    { Id: "a".repeat(64), Names: ["pod-infra"], Image: "", State: "exited", Status: "Exited (0)", IsInfra: true, Ports: [] },
    { Id: "b".repeat(64), Names: ["web"], Image: "docker.io/library/nginx:latest", State: "running", Status: "Up 3 minutes", IsInfra: false, PodName: "site", Ports: [{ host_ip: "127.0.0.1", container_port: 80, host_port: 8080, range: 1, protocol: "tcp" }] },
    { Id: "c".repeat(64), Names: ["cache"], Image: "ghcr.io/valkey/valkey:8", State: "exited", Status: "Exited (0) 2 hours ago", IsInfra: false, Ports: [{ host_ip: "", container_port: 53, host_port: 5300, range: 2, protocol: "udp" }] }
]);
const DOCKER = [JSON.stringify({ ID: "d".repeat(12), Names: "db,db-alias", Image: "postgres:16", State: "running", Status: "Up 5 days", Ports: "0.0.0.0:5432->5432/tcp, :::5432->5432/tcp" })].join("\n");

test.describe("containers", () => {
    test.it("reads containers, engines and filters", () => {
        assert.deepStrictEqual(Boxes.ask("containers"), { engine: "", words: "" });
        assert.deepStrictEqual(Boxes.ask("podman"), { engine: "podman", words: "" });
        assert.deepStrictEqual(Boxes.ask("docker ps"), { engine: "docker", words: "" });
        assert.deepStrictEqual(Boxes.ask("docker ps -a"), { engine: "docker", words: "" });
        assert.deepStrictEqual(Boxes.ask("podman web"), { engine: "podman", words: "web" });
        assert.deepStrictEqual(Boxes.ask("container cache"), { engine: "", words: "cache" });
        assert.strictEqual(Boxes.ask("dockerfile"), null);
        assert.strictEqual(Boxes.ask("ps"), null);
    });

    test.it("reads podman and docker output and leaves infra containers out", () => {
        const got = Boxes.readAll(`\u001epodman 0\n${PODMAN}\n\u001edocker 0\n${DOCKER}\n`);
        assert.deepStrictEqual(got.problems, {});
        assert.deepStrictEqual(got.containers.map(c => `${c.engine}:${c.name}:${c.state}`), ["podman:web:running", "podman:cache:exited", "docker:db:running"]);
        assert.strictEqual(Boxes.detailOf(got.containers[0], false), "nginx:latest · Up 3 minutes · 127.0.0.1:8080→80 · pod site");
        assert.strictEqual(Boxes.detailOf(got.containers[1], false), "valkey/valkey:8 · Exited (0) 2 hours ago · 5300-5301→53/udp");
        assert.strictEqual(Boxes.detailOf(got.containers[2], true), "docker · postgres:16 · Up 5 days · 5432→5432");
        assert.deepStrictEqual(Boxes.matching(got.containers, Boxes.ask("containers"), Ranking.place).map(c => c.name), ["web", "db", "cache"]);
        assert.deepStrictEqual(Boxes.matching(got.containers, Boxes.ask("docker"), Ranking.place).map(c => c.name), ["db"]);
        assert.deepStrictEqual(Boxes.matching(got.containers, Boxes.ask("containers postgres"), Ranking.place).map(c => c.name), ["db"]);
    });

    test.it("tells a refused socket, a stopped daemon and a missing engine apart", () => {
        const denied = Boxes.readAll("\u001epodman 127\n\u001edocker 1\npermission denied while trying to connect to the docker API at unix:///var/run/docker.sock\n");
        assert.deepStrictEqual(denied.problems, { podman: { kind: "missing" }, docker: { kind: "denied", socket: "/var/run/docker.sock" } });
        const stopped = Boxes.readAll("\u001edocker 1\nCannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?\n");
        assert.strictEqual(stopped.problems.docker.kind, "stopped");
        assert.strictEqual(Boxes.readAll("\u001epodman 0\nnot json\n").problems.podman.kind, "failed");
    });

    test.it("acts by validated id and quotes terminal lines", () => {
        const box = { engine: "podman", id: "b".repeat(64), name: "web" };
        assert.deepStrictEqual(Boxes.controlCommand(box, "stop"), ["podman", "stop", "b".repeat(64)]);
        assert.strictEqual(Boxes.controlCommand(box, "rm"), null);
        assert.strictEqual(Boxes.controlCommand({ engine: "sh", id: box.id }, "stop"), null);
        assert.strictEqual(Boxes.controlCommand({ engine: "podman", id: "web; rm -rf" }, "stop"), null);
        assert.ok(Boxes.logsLine(box).startsWith(`'podman' 'logs' '-f' '--tail' '200' '${"b".repeat(64)}';`));
        assert.ok(Boxes.shellLine(box).includes("'sh' '-c' 'if command -v bash >/dev/null 2>&1; then exec bash; fi; exec sh'"));
        assert.strictEqual(Boxes.shellLine({ engine: "podman", id: "x" }), "");
    });
});

test.describe("phone through KDE Connect", () => {
    test.it("reads every way of asking", () => {
        const of = text => {
            const got = Phone.ask(text);
            return got && [got.action, got.device, got.payload ? `${got.payload.kind}:${got.payload.value}` : ""].join("|");
        };
        assert.strictEqual(of("phone"), "list||");
        assert.strictEqual(of("kde connect"), "list||");
        assert.strictEqual(of("ring phone"), "ring||");
        assert.strictEqual(of("find my phone"), "ring||");
        assert.strictEqual(of("ring pixel"), "ring|pixel|");
        assert.strictEqual(of("ping my phone"), "ping||");
        assert.strictEqual(of("phone battery"), "battery||");
        assert.strictEqual(of("battery of my phone"), "battery||");
        assert.strictEqual(of("send to phone"), "send||");
        assert.strictEqual(of("send clipboard to my phone"), "clipboard||");
        assert.strictEqual(of("send a file to phone"), "file||");
        assert.strictEqual(of("share a link with phone"), "link||");
        assert.strictEqual(of("send https://example.com/a?b=1 to phone"), "share||link:https://example.com/a?b=1");
        assert.strictEqual(of("send www.example.com to phone"), "share||link:https://www.example.com");
        assert.strictEqual(of("send ~/Downloads/a b.pdf to phone"), "share||file:~/Downloads/a b.pdf");
        assert.strictEqual(of("send hello there to tablet"), "share||text:hello there");
        assert.strictEqual(of("phones please"), null);
        assert.strictEqual(of("battery"), null);
    });

    test.it("reads busctl and qdbus answers and leaves unpaired devices out", () => {
        const devices = Phone.readDevices(["abc\t0\tb true\ts \"phone\"\t\t\tOld Phone", "def\t1\tb true\ts \"phone\"\ti 84\tb true\tPixel 8", "ghi\t1\ttrue\ttablet\t40\tfalse\tTab", "jkl\t1\tb false\ts \"phone\"\t\t\tStranger", "bad id\t1\ttrue\tphone\t1\ttrue\tX", "mno\t1\t\t\t\t\tNo D-Bus"].join("\n"));
        assert.deepStrictEqual(devices.map(d => `${d.name}:${d.reachable}:${d.charge}:${d.charging}:${d.type}`), ["Pixel 8:true:84:true:phone", "Tab:true:40:false:tablet", "No D-Bus:true:-1:false:phone", "Old Phone:false:-1:false:phone"]);
        assert.strictEqual(Phone.detailOf(devices[0]), "84% · charging");
        assert.strictEqual(Phone.detailOf(devices[1]), "tablet · 40%");
        assert.strictEqual(Phone.detailOf(devices[3]), "not reachable");
        assert.deepStrictEqual(Phone.matching(devices, Phone.ask("ring pixel"), Ranking.place).map(d => d.name), ["Pixel 8"]);
        assert.deepStrictEqual(Phone.matching(devices, Phone.ask("ring tablet"), Ranking.place).map(d => d.name), ["Pixel 8", "Tab", "No D-Bus", "Old Phone"]);
        assert.deepStrictEqual(Phone.matching(devices, Phone.ask("ring tab"), Ranking.place).map(d => d.name), ["Tab"]);
        assert.deepStrictEqual(Phone.matching(devices, Phone.ask("find report.pdf"), Ranking.place), []);
    });

    test.it("builds fixed commands that keep payloads out of option positions", () => {
        assert.deepStrictEqual(Phone.commandFor("def", "ring", null), ["kdeconnect-cli", "--ring", "--device=def"]);
        assert.deepStrictEqual(Phone.commandFor("def", "clipboard", null), ["kdeconnect-cli", "--send-clipboard", "--device=def"]);
        assert.deepStrictEqual(Phone.commandFor("def", "share", { kind: "file", value: "/home/a/-x.pdf" }), ["kdeconnect-cli", "--share=/home/a/-x.pdf", "--device=def"]);
        assert.deepStrictEqual(Phone.commandFor("def", "share", { kind: "text", value: "-v" }), ["kdeconnect-cli", "--share-text=-v", "--device=def"]);
        assert.strictEqual(Phone.commandFor("def", "share", { kind: "file", value: "relative.pdf" }), null);
        assert.strictEqual(Phone.commandFor("def", "share", { kind: "link", value: "javascript alert" }), null);
        assert.strictEqual(Phone.commandFor("de f", "ring", null), null);
        assert.strictEqual(Phone.commandFor("def", "unpair", null), null);
        assert.strictEqual(Phone.expandPath("~/a.pdf", "/home/me"), "/home/me/a.pdf");
        assert.strictEqual(Phone.expandPath("Downloads/a.pdf", "/home/me/"), "/home/me/Downloads/a.pdf");
        assert.strictEqual(Phone.expandPath("./a.pdf", "/home/me"), "/home/me/a.pdf");
        assert.strictEqual(Phone.expandPath("/tmp/a.pdf", "/home/me"), "/tmp/a.pdf");
        assert.ok(Phone.shareable({ kind: "file", value: Phone.expandPath("notes/a b.txt", "/home/me") }));
        assert.deepStrictEqual(Phone.linkFrom("example.org/talk"), { kind: "link", value: "https://example.org/talk" });
        assert.deepStrictEqual(Phone.linkFrom("https://a.b/c"), { kind: "link", value: "https://a.b/c" });
        assert.deepStrictEqual(Phone.linkFrom("see you at noon"), { kind: "text", value: "see you at noon" });
        assert.strictEqual(Phone.payloadLabel({ kind: "file", value: "/home/me/a.pdf" }), "a.pdf");
    });
});

test.describe("privileged commands", () => {
    test.it("resolves programs only from the system folders and passes tool names as arguments", () => {
        const command = Binaries.probeCommand(["pkexec", "kill", "bad name", "../x"]);
        assert.deepStrictEqual(command.slice(3), ["sh", "pkexec", "kill"]);
        assert.ok(!command[2].includes("PATH") && command[2].includes("/usr/bin /bin /usr/sbin /sbin"));
        const paths = Binaries.readPaths("systemctl\t/home/me/.local/bin/systemctl\nkill\t/usr/bin/kill\npkexec\t/usr/local/bin/pkexec\nfuser\t/usr/bin/../../tmp/fuser\nkill\t/bin/kill");
        assert.deepStrictEqual(paths, { kill: "/usr/bin/kill" });
        assert.strictEqual(Binaries.elevated(paths, "kill", ["-TERM", "4"]), null);
        assert.deepStrictEqual(Binaries.elevated(PATHS, "kill", ["-TERM", "4"]), ["/usr/bin/pkexec", "/usr/bin/kill", "-TERM", "4"]);
        assert.deepStrictEqual(Binaries.elevated(PATHS, "fuser", ["-k"]), ["/usr/bin/pkexec", "/usr/sbin/fuser", "-k"]);
        assert.ok(!Binaries.systemPath("/usr/bin/systemctl", "kill") && Binaries.systemPath("/sbin/fuser", "fuser"));
    });
});

test.describe("quitting a port owner", () => {
    const LINES = [
        "LISTEN 0 4096 127.0.0.1:4713 0.0.0.0:* users:((\"systemd\",pid=1234,fd=40)) uid:1000 ino:9 sk:9 cgroup:/user.slice/user-1000.slice/user@1000.service/init.scope <->",
        "LISTEN 0 4096 127.0.0.1:8000 0.0.0.0:* users:((\"python3\",pid=5555,fd=3),(\"systemd\",pid=1234,fd=41)) uid:1000 ino:10 sk:10 cgroup:/user.slice/user-1000.slice/user@1000.service/init.scope <->",
        "LISTEN 0 4096 0.0.0.0:631 0.0.0.0:* ino:11 sk:11 cgroup:/init.scope <->",
        "LISTEN 0 4096 0.0.0.0:7000 0.0.0.0:* users:((\"init\",pid=1,fd=7)) ino:12 sk:12 <->",
        "LISTEN 0 511 127.0.0.1:3000 0.0.0.0:* users:((\"node\",pid=4242,fd=20)) uid:1000 ino:1 sk:1 cgroup:/user.slice/app.slice/x.scope <->",
        "LISTEN 0 511 127.0.0.1:9000 0.0.0.0:* uid:1001 ino:2 sk:2 cgroup:/user.slice/user-1001.slice/session-3.scope <->"
    ].join("\n");
    const SOCKETS_USER = JSON.stringify([{ listen: "127.0.0.1:4713", unit: "pipewire-pulse.socket", activates: "pipewire-pulse.service" }, { listen: "[::]:8000", unit: "web.socket", activates: "web.service" }, { listen: "/run/user/1000/bus", unit: "dbus.socket", activates: "dbus-broker.service" }]);
    const SOCKETS_SYSTEM = JSON.stringify([{ listen: "[::]:631", unit: "cups.socket", activates: "cups.service" }, { listen: "0.0.0.0:7777", unit: "echo@.socket", activates: "" }, { listen: "[::]:9999", unit: "x.socket", activates: "echo@.service" }]);

    test.it("never treats a systemd manager as a port owner", () => {
        const all = Ports.withSockets(Ports.readListeners(LINES, "tcp"), Ports.readSockets(SOCKETS_SYSTEM, SOCKETS_USER));
        const at = port => all.find(l => l.port === port);
        assert.deepStrictEqual(at(4713).owners, []);
        assert.strictEqual(at(4713).manager, true);
        assert.deepStrictEqual(at(4713).socketUnit, { port: 4713, scope: "user", label: "pipewire-pulse.socket", names: ["pipewire-pulse.socket", "pipewire-pulse.service"] });
        assert.strictEqual(Ports.labelOf(at(4713)), "Port 4713 · pipewire-pulse");
        assert.deepStrictEqual(at(8000).owners, [{ name: "python3", pid: 5555 }]);
        assert.strictEqual(at(8000).socketUnit.label, "web.socket");
        assert.strictEqual(at(631).manager, true);
        assert.strictEqual(at(631).unit, "");
        assert.strictEqual(at(631).socketUnit.scope, "system");
        assert.strictEqual(at(7000).manager, true);
        assert.strictEqual(at(7000).socketUnit, null);
        assert.strictEqual(Ports.labelOf(at(7000)), "Port 7000 · systemd");
        for (const port of [4713, 8000, 631, 7000])
            assert.ok(!Ports.killable(at(port)) && !Ports.freeable(at(port)), port);
        assert.ok(Ports.killable(at(3000)) && !Ports.freeable(at(3000)));
        assert.ok(!Ports.killable(at(9000)) && Ports.freeable(at(9000)));
        assert.deepStrictEqual(Ports.readSockets(SOCKETS_SYSTEM, "").map(s => [s.label, s.names.length]), [["cups.socket", 2], ["x.socket", 1]]);
    });

    test.it("kills only pids that still own the port under the same name", () => {
        const node = Ports.readListeners(LINES, "tcp").find(l => l.port === 3000);
        const command = Ports.verifyCommand(node);
        assert.deepStrictEqual(command.slice(3), ["sh", "-ltunpeH", "4242"]);
        const fresh = "tcp LISTEN 0 511 127.0.0.1:3000 0.0.0.0:* users:((\"node\",pid=4242,fd=20)) uid:1000 <->";
        assert.deepStrictEqual(Ports.confirmedPids(node, `4242\tnode\n\u001e${fresh}`), [4242]);
        assert.deepStrictEqual(Ports.confirmedPids(node, `4242\tbash\n\u001e${fresh}`), []);
        assert.deepStrictEqual(Ports.confirmedPids(node, `4242\t\n\u001e${fresh}`), []);
        assert.deepStrictEqual(Ports.confirmedPids(node, "4242\tnode\n\u001etcp LISTEN 0 511 127.0.0.1:3000 0.0.0.0:* users:((\"node\",pid=9999,fd=20)) <->"), []);
        assert.deepStrictEqual(Ports.confirmedPids(node, "4242\tnode\n\u001etcp LISTEN 0 511 127.0.0.1:3001 0.0.0.0:* users:((\"node\",pid=4242,fd=20)) <->"), []);
        assert.deepStrictEqual(Ports.confirmedPids(node, "4242\tnode"), []);
    });

    test.it("escalates only the pids kill was refused for", () => {
        const both = Ports.killOutcome(1, "kill: sending signal to 10 failed: No such process\nkill: sending signal to 11 failed: Operation not permitted", [10, 11, 12]);
        assert.deepStrictEqual([both.gone, both.denied, both.failed], [[10], [11], false]);
        assert.deepStrictEqual(Ports.killOutcome(1, "kill: (10) - No such process", [10]), { gone: [10], denied: [], failed: false });
        assert.deepStrictEqual(Ports.killOutcome(0, "", [10]), { gone: [], denied: [], failed: false });
        const odd = Ports.killOutcome(-1, "the command did not start", [10]);
        assert.deepStrictEqual([odd.denied, odd.failed], [[], true]);
        assert.deepStrictEqual(Ports.killOutcome(1, "kill: sending signal to 77 failed: Operation not permitted", [10]).denied, []);
    });
});
