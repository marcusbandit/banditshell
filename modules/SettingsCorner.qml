pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components

Item {
    id: root

    required property real border

    signal activated

    readonly property real mark: Appearance.sizes.cornerIcon

    readonly property real reach: root.border + root.mark + Appearance.padding.normal * 2

    readonly property real grab: Math.max(root.border + Appearance.padding.normal, Appearance.sizes.minTarget)

    readonly property real slide: (root.reach + Appearance.sizes.melt) * (1 - reveal.value)

    readonly property real padX: root.width - root.reach + root.slide
    readonly property real padY: root.height - root.reach + root.slide

    readonly property bool hovered: zone.containsMouse && !root.hoverLost
    property bool dwellMet: false

    onHoveredChanged: if (!root.hovered)
        root.dwellMet = false

    readonly property bool open: (root.hovered && root.dwellMet) || zone.pressed || linger.running

    Timer {
        id: hoverDwell

        interval: Appearance.anim.dwell
        running: root.hovered
        onTriggered: root.dwellMet = true
    }

    readonly property Item maskItem: zone

    readonly property var blobs: reveal.value <= 0.001 ? [] : [
        {
            x: root.padX,
            y: root.padY,
            w: root.reach,
            h: root.reach,
            radius: Appearance.rounding.large,

            smooth: Math.min(Appearance.sizes.melt, root.reach / 2)
        }
    ]

    Follow {
        id: reveal

        target: root.open ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    Timer {
        id: linger

        interval: Appearance.anim.grace
    }

    property bool hoverLost: false

    property int patience: 1

    readonly property var shellWindow: QsWindow.window

    Timer {
        id: watchdog

        interval: Appearance.anim.grace * root.patience
        repeat: true

        running: Compositor.isHyprland && zone.containsMouse && !zone.pressed && !root.hoverLost

        onTriggered: {
            if (!probe.running)
                probe.running = true;
        }
    }

    Process {
        id: probe

        command: ["hyprctl", "-j", "cursorpos"]

        stdout: StdioCollector {
            onStreamFinished: root.judge(text)
        }
    }

    function judge(text: string): void {
        let pos = null;
        try {
            pos = JSON.parse(text);
        } catch (e) {
            return;
        }

        if (!pos || typeof pos.x !== "number" || typeof pos.y !== "number")
            return;

        if (!zone.containsMouse || zone.pressed)
            return;

        const screen = root.shellWindow?.screen;
        if (!screen)
            return;

        const corner = zone.mapToItem(null, 0, 0);
        const left = screen.x + corner.x;
        const top = screen.y + corner.y;

        if (pos.x >= left && pos.x <= left + zone.width && pos.y >= top && pos.y <= top + zone.height) {
            root.patience *= 2;
            return;
        }

        root.hoverLost = true;
    }

    MouseArea {
        id: zone

        anchors.right: parent.right
        anchors.bottom: parent.bottom

        width: Math.max(root.grab, root.width - root.padX)
        height: Math.max(root.grab, root.height - root.padY)

        hoverEnabled: true

        onExited: linger.restart()

        onEntered: {
            linger.stop();
            root.hoverLost = false;
            root.patience = 1;
        }

        onPositionChanged: {
            root.hoverLost = false;
            root.patience = 1;
        }

        onClicked: root.activated()
    }

    Item {
        x: root.padX
        y: root.padY
        width: root.reach - root.border
        height: root.reach - root.border

        visible: reveal.value > 0.001
        opacity: reveal.value

        Icon {
            anchors.centerIn: parent

            name: "settings"
            size: root.mark
            color: Appearance.colour.text
        }
    }
}
