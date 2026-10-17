pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.components

Singleton {
    id: root

    readonly property string installer: `${Quickshell.shellDir}/scripts/install-package.sh`

    readonly property var tools: ["brightnessctl", "ddcutil", "wf-recorder", "wl-screenrec", "gpu-screen-recorder", "slurp", "tailscale", "hyprctl", "xdg-user-dir", "theme-set", "pw-play", "obs"]

    readonly property var packages: ({
            brightnessctl: ["pacman:brightnessctl", "apt:brightnessctl", "dnf:brightnessctl", "zypper:brightnessctl", "xbps:brightnessctl", "apk:brightnessctl"],
            ddcutil: ["pacman:ddcutil", "apt:ddcutil", "dnf:ddcutil", "zypper:ddcutil", "xbps:ddcutil", "apk:ddcutil"],
            "wf-recorder": ["pacman:wf-recorder", "apt:wf-recorder", "dnf:wf-recorder", "zypper:wf-recorder", "xbps:wf-recorder", "apk:wf-recorder"],
            slurp: ["pacman:slurp", "apt:slurp", "dnf:slurp", "zypper:slurp", "xbps:slurp", "apk:slurp"],
            tailscale: ["pacman:tailscale", "dnf:tailscale", "zypper:tailscale", "xbps:tailscale", "apk:tailscale"]
        })

    property var found: ({})
    property bool probed: false
    property var installing: ({})

    signal installed(string tool)

    function has(tool: string): bool {
        return !!root.found[tool];
    }

    function pathOf(tool: string): string {
        return root.found[tool] ?? "";
    }

    function stateOf(tool: string): string {
        return root.installing[tool] ?? "";
    }

    function canInstall(tool: string): bool {
        return !!root.packages[tool];
    }

    function installLabel(tool: string): string {
        switch (root.stateOf(tool)) {
        case "trying":
            return `Installing ${tool}`;
        case "terminal":
            return `Finish installing ${tool} in the terminal`;
        case "failed":
            return `Installing ${tool} failed`;
        case "nowhere":
            return `No package manager here has ${tool}`;
        }
        return `Install ${tool}`;
    }

    function probe(): void {
        if (!prober.running)
            prober.running = true;
    }

    function mark(tool: string, state: string): void {
        const next = Object.assign({}, root.installing);
        if (state)
            next[tool] = state;
        else
            delete next[tool];
        root.installing = next;
    }

    function install(tool: string): void {
        const wanted = root.packages[tool];
        if (!wanted || root.has(tool) || root.stateOf(tool) === "trying")
            return;
        root.mark(tool, "trying");
        Polkit.expect(`Install ${tool}`, tool);
        const job = runner.createObject(root, {
            command: [root.installer, "--polkit", ...wanted]
        });
        job.finished.connect((code, output, error) => root.finish(tool, job.began ? code : -1));
        job.running = true;
    }

    function finish(tool: string, code: int): void {
        Polkit.forget();
        if (code < 0) {
            root.mark(tool, "failed");
            return;
        }
        if (code === 4 || code === 127) {
            root.mark(tool, "terminal");
            Quickshell.execDetached([`${Quickshell.shellDir}/scripts/in-terminal.sh`, `'${root.installer}' --ask ${root.packages[tool].join(" ")}`]);
            return;
        }
        root.mark(tool, code === 0 || code === 126 ? "" : code === 3 ? "nowhere" : "failed");
        if (code === 0)
            root.installed(tool);
        root.probe();
    }

    Component.onCompleted: root.probe()

    Process {
        id: prober

        command: ["sh", "-c", "for tool do where=$(command -v \"$tool\") && printf '%s\\t%s\\n' \"$tool\" \"$where\"; done; true", "sh", ...root.tools]

        stdout: StdioCollector {
            onStreamFinished: {
                const next = {};
                for (const line of text.split("\n")) {
                    const cut = line.indexOf("\t");
                    if (cut > 0)
                        next[line.slice(0, cut)] = line.slice(cut + 1);
                }
                root.found = next;
                root.probed = true;
                for (const tool of Object.keys(root.installing))
                    if (next[tool] && root.installing[tool] === "terminal")
                        root.mark(tool, "");
            }
        }
    }

    Component {
        id: runner

        CommandJob {}
    }
}
