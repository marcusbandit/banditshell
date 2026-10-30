pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import "chargelimit.js" as Logic

Singleton {
    id: root

    readonly property var places: ["/usr/local/libexec/banditshell-charge-limit:/usr/share/polkit-1/actions/org.banditshell.charge-limit.policy", "/run/current-system/sw/bin/banditshell-charge-limit:/run/current-system/sw/share/polkit-1/actions/org.banditshell.charge-limit.policy"]
    property string helperPath: "/usr/local/libexec/banditshell-charge-limit"
    readonly property string installCommand: `bash ${Quickshell.shellPath("install.sh")} --charge-limit`

    readonly property bool hold: Config.values.battery.holdCharge
    readonly property int wanted: Logic.wanted(root.hold, Config.values.battery.holdAt)
    readonly property string setting: `${root.hold}:${root.wanted}`
    readonly property bool ready: Config.ready && root.probed

    property bool probed: false
    property bool supported: false
    property bool helper: false
    property bool nixos: false
    property int current: -1
    property var refused: null
    property bool settling: false
    property bool owed: false

    readonly property var situation: ({
            probed: root.probed,
            supported: root.supported,
            helper: root.helper,
            nixos: root.nixos,
            current: root.current,
            wanted: root.wanted,
            hold: root.hold,
            owed: root.owed,
            refused: root.refused,
            writing: root.settling || writer.running
        })

    readonly property string trouble: Logic.trouble(root.situation, root.installCommand)

    function request(): void {
        root.owed = true;
        root.read();
    }

    function consider(): void {
        if (root.owed && root.current === root.wanted)
            root.owed = false;
        if (Logic.shouldWrite(root.situation))
            root.write();
    }

    function write(): void {
        root.settling = true;
        writer.target = root.wanted;
        writer.command = ["pkexec", root.helperPath, String(root.wanted)];
        writer.running = true;
    }

    function read(): void {
        if (!probe.running)
            probe.running = true;
    }

    onReadyChanged: {
        if (root.ready && root.hold)
            root.request();
    }

    onSettingChanged: {
        if (!root.ready)
            return;
        root.refused = null;
        root.request();
    }

    Connections {
        target: SessionControl

        function onSleepingChanged(): void {
            if (!SessionControl.sleeping && root.hold)
                root.request();
        }
    }

    Process {
        id: writer

        property int target: 100

        onExited: code => {
            root.settling = false;
            root.owed = false;
            probe.after = writer.target;
            probe.failed = code !== 0;
            if (probe.failed)
                console.warn(`ChargeLimit: pkexec ${root.helperPath} ${writer.target} exited ${code}`);
            root.read();
        }
    }

    Process {
        id: probe

        property int after: -1
        property bool failed: false

        running: true
        command: ["sh", "-c", `
for battery in /sys/class/power_supply/BAT*; do
  attribute="$battery/charge_control_end_threshold"
  if [ -e "$attribute" ]; then
    echo "threshold $(cat "$attribute" 2>/dev/null)"
    break
  fi
done
if command -v pkexec >/dev/null 2>&1; then
  for place in ${root.places.join(" ")}; do
    if [ -x "\${place%%:*}" ] && [ -f "\${place#*:}" ]; then
      echo "helper \${place%%:*}"
      break
    fi
  done
fi
if [ -e /etc/NIXOS ]; then
  echo nixos
fi
`]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = Logic.parseProbe(text);
                const judged = probe.after;
                probe.after = -1;
                if (root.probed && found.current !== root.current)
                    recheck.reset();
                root.supported = found.supported;
                root.helper = found.helper;
                root.nixos = found.nixos;
                if (found.helperPath)
                    root.helperPath = found.helperPath;
                root.current = found.current;
                root.probed = true;
                if (judged >= 0 && found.current !== judged)
                    root.refused = {
                        wanted: judged,
                        got: found.current,
                        failed: probe.failed
                    };
                else if (judged >= 0)
                    root.refused = null;
                root.consider();
            }
        }
    }

    Connections {
        target: Battery

        function onOnBatteryChanged(): void {
            if (root.supported)
                root.read();
        }
    }

    Backoff {
        id: recheck

        base: 30000
        cap: 600000
        running: root.supported
        onDue: root.read()
    }
}
