const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawn, spawnSync } = require("node:child_process");

const TAKEOVER = path.resolve(__dirname, "../scripts/polkit-takeover.sh");

const scratches = [];
const sleepers = [];

test.after(() => {
    for (const sleeper of sleepers)
        sleeper.kill();
    for (const dir of scratches)
        fs.rmSync(dir, { recursive: true, force: true });
});

function executable(file, body) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, `#!/bin/sh\n${body}\n`);
    fs.chmodSync(file, 0o755);
    return file;
}

function takeover({ agents, units = [] }) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "polkit-takeover-"));
    scratches.push(dir);
    const bin = path.join(dir, "bin");
    const pids = {};
    const links = {};
    for (const agent of agents) {
        const sleeper = spawn("sleep", ["30"]);
        sleepers.push(sleeper);
        pids[agent.name.slice(0, 15)] = sleeper.pid;
        links[sleeper.pid] = agent.link(dir);
        if (agent.onPath)
            executable(path.join(bin, agent.name), "exit 0");
    }
    executable(path.join(bin, "pgrep"), `case "$4" in\n${Object.entries(pids).map(([name, pid]) => `    ${name}) echo ${pid} ;;`).join("\n")}\nesac`);
    executable(path.join(bin, "readlink"), `case "$1" in\n${Object.entries(links).map(([pid, link]) => `    /proc/${pid}/exe) echo '${link}' ;;`).join("\n")}\nesac`);
    executable(path.join(bin, "systemctl"), `[ "$2" = stop ] && exit 0\n${units.map(unit => `echo '${unit} loaded active running Agent'`).join("\n")}`);
    const run = spawnSync("bash", [TAKEOVER], { encoding: "utf8", env: { PATH: `${bin}:/usr/bin:/bin` } });
    return run.stdout.trim().split("\n").filter(Boolean).map(line => line.replace(dir, "<scratch>"));
}

test.describe("polkit-takeover.sh", () => {
    test("records the agent's own path when its binary is still in place", () => {
        const lines = takeover({ agents: [{ name: "hyprpolkitagent", link: dir => executable(path.join(dir, "lib/hyprpolkitagent"), "exit 0") }] });
        assert.deepStrictEqual(lines, ["exe\t<scratch>/lib/hyprpolkitagent"]);
    });

    test("records the upgraded binary, not the deleted one the agent was running", () => {
        const lines = takeover({ agents: [{ name: "polkit-gnome-authentication-agent-1", link: dir => `${executable(path.join(dir, "lib/polkit-gnome-authentication-agent-1"), "exit 0")} (deleted)` }] });
        assert.deepStrictEqual(lines, ["exe\t<scratch>/lib/polkit-gnome-authentication-agent-1"]);
    });

    test("looks the agent up by name when its old path is gone", () => {
        const lines = takeover({ agents: [{ name: "lxpolkit", onPath: true, link: dir => `${path.join(dir, "gone/lxpolkit")} (deleted)` }] });
        assert.deepStrictEqual(lines, ["exe\t<scratch>/bin/lxpolkit"]);
    });

    test("names a stopped systemd unit so it can be started again", () => {
        assert.deepStrictEqual(takeover({ agents: [], units: ["plasma-polkit-agent.service"] }), ["unit\tplasma-polkit-agent.service"]);
    });
});
