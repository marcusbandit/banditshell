const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const FIXTURES = path.join(__dirname, "fixtures/network");

function load(file, names) {
    const src = fs.readFileSync(path.join(ROOT, "services", file), "utf8");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

function fixture(name) {
    return fs.readFileSync(path.join(FIXTURES, name), "utf8");
}

const Nmcli = load("nmcli.js", ["splitFromRight", "connections", "fields"]);
const Hotspot = load("hotspot.js", ["bandCode", "bandLabel", "passwordProblem", "capabilities", "blocker", "editCommands", "createCommands", "startCommands", "stopCommands", "restartCommands", "candidates", "readingCommand", "readProfile", "readProfiles", "ownProfile", "newUuid", "countClients", "clientsLabel", "explainFailure"]);
const Tunnels = load("tunnels.js", ["tunnelsFrom", "merge", "switchCommand", "explainSwitch", "resolvePath", "importKind", "importProblem", "importCommand", "importedName", "explainImport"]);

test.describe("nmcli output", () => {
    test("connections are split from the right, so a colon in a name survives", () => {
        const all = Nmcli.connections(fixture("connections.txt"));
        assert.strictEqual(all.length, 13);
        const wired = all.find(c => c.name === "Wired connection 1");
        assert.deepStrictEqual(wired, { name: "Wired connection 1", uuid: "56bda55e-6828-3a85-9a06-28704adfb980", type: "802-3-ethernet", active: true });
        assert.deepStrictEqual(all.find(c => c.name === "home: wg"), { name: "home: wg", uuid: "7a3f0b6e-52c8-4a6e-8d4e-2d6bb7a0e0c1", type: "wireguard", active: true });
        assert.strictEqual(all.find(c => c.name === "Pixelman").active, false);
    });

    test("blank and short lines are skipped", () => {
        assert.deepStrictEqual(Nmcli.connections(""), []);
        assert.deepStrictEqual(Nmcli.connections("\nnonsense\n"), []);
        assert.deepStrictEqual(Nmcli.connections(undefined), []);
    });

    test("fields split at the first colon only", () => {
        const profile = Nmcli.fields(fixture("hotspot-profile.txt"));
        assert.strictEqual(profile["802-11-wireless.ssid"], "bandit's: hotspot");
        assert.strictEqual(profile["802-11-wireless-security.psk"], "pa:ss word\\n");
        assert.strictEqual(profile["802-11-wireless.band"], "a");
    });
});

test.describe("hotspot", () => {
    const ready = { hasDevice: true, capabilitiesKnown: true, accessPoint: true, fiveGigahertz: true, radioOn: true, band: "2.4 GHz", ssid: "banditshell", password: "longenough", profileExists: false };

    test("bands translate both ways, and an empty profile band is 2.4", () => {
        assert.strictEqual(Hotspot.bandCode("2.4 GHz"), "bg");
        assert.strictEqual(Hotspot.bandCode("5 GHz"), "a");
        assert.strictEqual(Hotspot.bandLabel("a"), "5 GHz");
        assert.strictEqual(Hotspot.bandLabel("bg"), "2.4 GHz");
        assert.strictEqual(Hotspot.bandLabel(""), "2.4 GHz");
        assert.strictEqual(Hotspot.bandLabel(undefined), "2.4 GHz");
    });

    test("a password under 8 characters is refused with a reason, and empty is left to the blocker", () => {
        assert.strictEqual(Hotspot.passwordProblem(""), "");
        assert.strictEqual(Hotspot.passwordProblem("1234567"), "needs 8 characters or more");
        assert.strictEqual(Hotspot.passwordProblem("12345678"), "");
        assert.strictEqual(Hotspot.passwordProblem("x".repeat(63)), "");
        assert.strictEqual(Hotspot.passwordProblem("x".repeat(64)), "63 characters at most");
    });

    test("capabilities read the adapter's access point and 5 GHz support", () => {
        assert.deepStrictEqual(Hotspot.capabilities(fixture("capabilities.txt")), { accessPoint: true, fiveGigahertz: true });
        assert.deepStrictEqual(Hotspot.capabilities("WIFI-PROPERTIES.AP:no\nWIFI-PROPERTIES.5GHZ:yes\n"), { accessPoint: false, fiveGigahertz: true });
        assert.deepStrictEqual(Hotspot.capabilities(""), { accessPoint: false, fiveGigahertz: false });
    });

    test("the blocker says why it cannot start, in order", () => {
        assert.strictEqual(Hotspot.blocker(ready), "");
        assert.strictEqual(Hotspot.blocker({ ...ready, hasDevice: false }), "no wi-fi adapter");
        assert.strictEqual(Hotspot.blocker({ ...ready, accessPoint: false }), "this adapter cannot host a hotspot");
        assert.strictEqual(Hotspot.blocker({ ...ready, radioOn: false }), "turn wi-fi on first");
        assert.strictEqual(Hotspot.blocker({ ...ready, band: "5 GHz", fiveGigahertz: false }), "this adapter has no 5 GHz band");
        assert.strictEqual(Hotspot.blocker({ ...ready, ssid: "" }), "give it a name first");
        assert.strictEqual(Hotspot.blocker({ ...ready, password: "" }), "give it a password first");
        assert.strictEqual(Hotspot.blocker({ ...ready, password: "short" }), "needs 8 characters or more");
    });

    test("capabilities not read yet do not block, and a saved profile can start without a readable password", () => {
        assert.strictEqual(Hotspot.blocker({ ...ready, capabilitiesKnown: false, accessPoint: false }), "");
        assert.strictEqual(Hotspot.blocker({ ...ready, password: "", profileExists: true }), "");
        assert.strictEqual(Hotspot.blocker({ ...ready, password: "short", profileExists: true }), "needs 8 characters or more");
    });

    const uuid = "0d0a5b1c-3c1e-4d1e-9c55-3f4b9f0c5a11";
    const profile = { device: "wlp7s0", uuid, ssid: "my net", password: "hunter2hunter2", band: "5 GHz" };
    const modifyArgs = ["nmcli", "connection", "modify", "uuid", uuid, "802-11-wireless.ssid", "my net", "802-11-wireless.band", "a"];
    const passwordEdit = { command: ["nmcli", "connection", "edit", "uuid", uuid], input: "set wifi-sec.psk hunter2hunter2\nsave\nquit\n" };
    const up = ["nmcli", "--wait", "30", "connection", "up", "uuid", uuid, "ifname", "wlp7s0"];

    const argvOf = commands => commands.flatMap(command => Array.isArray(command) ? command : command.command);

    test("a first start adds an access point profile under its own name, then brings it up by uuid", () => {
        const commands = Hotspot.startCommands(profile, false);
        assert.strictEqual(commands.length, 3);
        const add = commands[0];
        assert.deepStrictEqual(add.slice(0, 8), ["nmcli", "connection", "add", "type", "wifi", "con-name", "banditshell hotspot", "connection.uuid"]);
        assert.strictEqual(add[8], uuid);
        assert.ok(add.join(" ").includes("802-11-wireless.mode ap"));
        assert.ok(add.join(" ").includes("ipv4.method shared"));
        assert.deepStrictEqual(commands.slice(1), [passwordEdit, up]);
    });

    test("the password never appears in an argument list", () => {
        for (const commands of [Hotspot.startCommands(profile, false), Hotspot.startCommands(profile, true), Hotspot.restartCommands(profile), Hotspot.editCommands(profile)])
            assert.ok(!argvOf(commands).some(word => word.includes("hunter2hunter2")));
    });

    test("a password with a line break cannot smuggle in editor commands", () => {
        const [, edit] = Hotspot.editCommands({ ...profile, password: "abcdefgh\nsave\nquit" });
        assert.strictEqual(edit.input, "set wifi-sec.psk abcdefgh save quit\nsave\nquit\n");
    });

    test("a start with a saved profile edits it, then brings it up", () => {
        assert.deepStrictEqual(Hotspot.startCommands(profile, true), [modifyArgs, passwordEdit, up]);
    });

    test("an unreadable password is left alone in the profile", () => {
        assert.deepStrictEqual(Hotspot.editCommands({ ...profile, password: "" }), [modifyArgs]);
    });

    test("stopping and restarting go through the same profile by uuid", () => {
        assert.deepStrictEqual(Hotspot.stopCommands(uuid), [["nmcli", "connection", "down", "uuid", uuid]]);
        const restart = Hotspot.restartCommands(profile);
        assert.deepStrictEqual(restart, [modifyArgs, passwordEdit, ["nmcli", "connection", "down", "uuid", uuid], up]);
    });

    test("fresh uuids look like version 4 uuids and differ", () => {
        const first = Hotspot.newUuid();
        assert.match(first, /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
        assert.notStrictEqual(first, Hotspot.newUuid());
    });

    const wifi = (name, id, active = false) => ({ name, uuid: id, type: "802-11-wireless", active });

    test("only wifi profiles with the hotspot names are candidates, ours first", () => {
        const found = Hotspot.candidates([wifi("Hotspot", "a"), { name: "Hotspot", uuid: "b", type: "vpn", active: false }, wifi("Home", "c"), wifi("banditshell hotspot", "d")]);
        assert.deepStrictEqual(found.map(c => c.uuid), ["d", "a"]);
        assert.deepStrictEqual(Hotspot.candidates([]), []);
    });

    test("one read asks about every candidate by uuid", () => {
        const command = Hotspot.readingCommand(["a", "b"]);
        assert.deepStrictEqual(command.slice(0, 2), ["sh", "-c"]);
        assert.deepStrictEqual(command.slice(3), ["sh", "a", "b"]);
    });

    const readOut = [
        "uuid:a", "802-11-wireless.mode:infrastructure", "802-11-wireless.ssid:phone", "802-11-wireless.band:", "802-11-wireless-security.psk:phonepass1",
        "uuid:b", "802-11-wireless.mode:ap", "802-11-wireless.ssid:my net", "802-11-wireless.band:a", "802-11-wireless-security.psk:pa:ss word"
    ].join("\n");

    test("the read output splits per profile and keeps the mode", () => {
        const profiles = Hotspot.readProfiles(readOut);
        assert.deepStrictEqual(profiles.map(p => p.mode), ["infrastructure", "ap"]);
        assert.deepStrictEqual(profiles[1], { uuid: "b", mode: "ap", ssid: "my net", band: "5 GHz", password: "pa:ss word" });
        assert.deepStrictEqual(Hotspot.readProfiles(""), []);
    });

    test("a client profile called Hotspot is never taken as ours", () => {
        const connections = [wifi("Hotspot", "a", true)];
        assert.strictEqual(Hotspot.ownProfile(connections, Hotspot.readProfiles(readOut)), null);
    });

    test("an access point profile called Hotspot still is, and ours wins over it", () => {
        const profiles = Hotspot.readProfiles(readOut);
        const legacy = Hotspot.ownProfile([wifi("Hotspot", "b", true)], profiles);
        assert.strictEqual(legacy.uuid, "b");
        assert.strictEqual(legacy.active, true);
        const both = Hotspot.ownProfile([wifi("Hotspot", "b"), wifi("banditshell hotspot", "c")], profiles.concat([{ ...profiles[1], uuid: "c" }]));
        assert.strictEqual(both.uuid, "c");
    });

    test("the profile reads back with its name, band and password", () => {
        assert.deepStrictEqual(Hotspot.readProfile(Nmcli.fields(fixture("hotspot-profile.txt"))), { ssid: "bandit's: hotspot", band: "5 GHz", password: "pa:ss word\\n" });
        assert.deepStrictEqual(Hotspot.readProfile({}), { ssid: "", band: "2.4 GHz", password: "" });
    });

    test("iw stations are counted by address", () => {
        assert.strictEqual(Hotspot.countClients(fixture("stations.txt")), 2);
        assert.strictEqual(Hotspot.countClients(""), 0);
    });

    test("neighbours count once per device, and only live ones", () => {
        assert.strictEqual(Hotspot.countClients(fixture("neighbours.txt")), 5);
        assert.strictEqual(Hotspot.countClients("192.168.1.9 INCOMPLETE \n192.168.1.8 FAILED \n"), 0);
    });

    test("the count reads as words", () => {
        assert.strictEqual(Hotspot.clientsLabel(0), "0 devices");
        assert.strictEqual(Hotspot.clientsLabel(1), "1 device");
        assert.strictEqual(Hotspot.clientsLabel(3), "3 devices");
    });

    test("failures come back in plain words", () => {
        assert.strictEqual(Hotspot.explainFailure("Error: Failed to add/activate new connection: Insufficient privileges"), "you are not allowed to start it");
        assert.strictEqual(Hotspot.explainFailure("Error: No suitable device found."), "there is no wi-fi adapter to use");
        assert.strictEqual(Hotspot.explainFailure("Error: Timeout expired (90 seconds)"), "it took too long to start");
        assert.strictEqual(Hotspot.explainFailure("Error: something odd"), "NetworkManager would not start it");
        assert.strictEqual(Hotspot.explainFailure(""), "NetworkManager would not start it");
    });
});

test.describe("tunnels", () => {
    const all = Nmcli.connections(fixture("connections.txt"));

    test("only vpn and wireguard connections count, with their live state", () => {
        const found = Tunnels.tunnelsFrom(all);
        assert.deepStrictEqual(found.map(t => [t.name, t.kind, t.on]), [["home: wg", "wireguard", true], ["work-vpn", "vpn", false]]);
    });

    test("tailscale's tun device is not a tunnel", () => {
        assert.ok(!Tunnels.tunnelsFrom(all).some(t => t.name === "tailscale0"));
    });

    test("a switch in flight shows where it is going, and troubles ride along", () => {
        const found = Tunnels.tunnelsFrom(all);
        const merged = Tunnels.merge(found, { [found[1].uuid]: true }, { [found[0].uuid]: "it was not running" });
        assert.deepStrictEqual(merged.map(t => [t.busy, t.on, t.trouble]), [[false, true, "it was not running"], [true, true, ""]]);
    });

    test("switches go by uuid, so two tunnels with one name stay apart", () => {
        const tunnel = { name: "home", uuid: "abc" };
        assert.deepStrictEqual(Tunnels.switchCommand(tunnel, true), ["nmcli", "--wait", "30", "connection", "up", "uuid", "abc"]);
        assert.deepStrictEqual(Tunnels.switchCommand(tunnel, false), ["nmcli", "connection", "down", "uuid", "abc"]);
    });

    test("switch failures come back in plain words", () => {
        assert.strictEqual(Tunnels.explainSwitch("Error: Connection activation failed: Secrets were required, but not provided", true), "it needs a password, and nothing here can ask for one");
        assert.strictEqual(Tunnels.explainSwitch("Error: Timeout expired (30 seconds)", true), "it took too long to answer");
        assert.strictEqual(Tunnels.explainSwitch("", true), "NetworkManager could not bring it up");
        assert.strictEqual(Tunnels.explainSwitch("", false), "NetworkManager could not take it down");
    });

    test("the extension picks the import type", () => {
        assert.strictEqual(Tunnels.importKind("/home/me/wg0.conf"), "wireguard");
        assert.strictEqual(Tunnels.importKind("/home/me/work.OVPN"), "openvpn");
        assert.strictEqual(Tunnels.importKind("/home/me/notes.txt"), "");
        assert.strictEqual(Tunnels.importKind("/home/me/conf"), "");
        assert.strictEqual(Tunnels.importKind(""), "");
    });

    test("a path that cannot be imported says why", () => {
        assert.strictEqual(Tunnels.importProblem("   "), "type where the file is first");
        assert.strictEqual(Tunnels.importProblem("/tmp/x.txt"), "that is not a .conf or .ovpn file");
        assert.strictEqual(Tunnels.importProblem("/tmp/x.conf"), "");
    });

    test("a leading tilde becomes the home folder", () => {
        assert.strictEqual(Tunnels.resolvePath(" ~/vpn/wg0.conf ", "/home/me"), "/home/me/vpn/wg0.conf");
        assert.strictEqual(Tunnels.resolvePath("~", "/home/me"), "/home/me");
        assert.strictEqual(Tunnels.resolvePath("/etc/wg0.conf", "/home/me"), "/etc/wg0.conf");
        assert.strictEqual(Tunnels.resolvePath("~other/wg0.conf", "/home/me"), "~other/wg0.conf");
    });

    test("the import command carries the type and the file", () => {
        assert.deepStrictEqual(Tunnels.importCommand("/tmp/wg0.conf"), ["nmcli", "connection", "import", "type", "wireguard", "file", "/tmp/wg0.conf"]);
        assert.deepStrictEqual(Tunnels.importCommand("/tmp/a b.ovpn"), ["nmcli", "connection", "import", "type", "openvpn", "file", "/tmp/a b.ovpn"]);
    });

    test("the imported name is read from nmcli's reply", () => {
        assert.strictEqual(Tunnels.importedName("Connection 'wg0' (7a3f0b6e-52c8-4a6e-8d4e-2d6bb7a0e0c1) successfully added.\n"), "wg0");
        assert.strictEqual(Tunnels.importedName("nothing useful"), "");
    });

    test("import failures come back in plain words", () => {
        assert.strictEqual(Tunnels.explainImport("Error: failed to import 'x.conf': No such file or directory", "wireguard"), "there is no file at that path");
        assert.strictEqual(Tunnels.explainImport("Error: Permission denied", "openvpn"), "you are not allowed to read that file");
        assert.strictEqual(Tunnels.explainImport("Error: failed to load VPN plugin", "openvpn"), "NetworkManager has no openvpn support installed");
        assert.strictEqual(Tunnels.explainImport("Error: invalid configuration", "wireguard"), "NetworkManager could not read that as a wireguard file");
        assert.strictEqual(Tunnels.explainImport("", "wireguard"), "NetworkManager would not import it");
    });
});
