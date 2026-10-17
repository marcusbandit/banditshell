pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property string family: Appearance.font.lock

    property bool badged: true

    readonly property var waiting: Notifications.history.filter(entry => !entry.leaving)
    readonly property int total: root.waiting.length

    readonly property int readableMax: 2
    readonly property var readable: root.waiting.filter(entry => Notifications.ruleFor(entry).lock).slice(0, root.readableMax)

    readonly property int deepest: 3

    readonly property var apps: {
        const seen = [];
        const out = [];
        for (const entry of root.waiting) {
            const key = AppNotifications.appIdFor(entry) || entry.appName || "unknown";
            if (seen.includes(key))
                continue;
            seen.push(key);
            out.push(entry.mark ?? "");
            if (out.length === root.deepest)
                break;
        }
        return out;
    }

    readonly property real disc: Appearance.font.line.small + Appearance.padding.small * 2
    readonly property real peekShare: 0.5
    readonly property real ring: Math.max(2, Math.round(root.disc / 16))

    function size(depth: int): real {
        return Math.round(root.disc * (1 - depth * 0.18));
    }

    function peek(depth: int): real {
        return depth > 0 ? Math.round(root.size(depth) * root.peekShare) : 0;
    }

    function reach(depth: int): real {
        let out = 0;
        for (let k = 1; k <= depth; k++)
            out += root.peek(k);
        return out;
    }

    property int shownTotal: 0

    onTotalChanged: if (root.total > 0)
        root.shownTotal = root.total
    Component.onCompleted: {
        root.shownTotal = root.total;
        here.snap();
        span.snap();
    }

    implicitWidth: span.value + root.disc
    implicitHeight: root.disc

    visible: here.value > 0.01

    Follow {
        id: here

        target: root.total > 0 ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.004
    }

    Follow {
        id: span

        target: root.reach(root.apps.length - 1)
        speed: Appearance.animation.trackSpeed
        epsilon: 0.1
    }

    Item {
        anchors.fill: parent
        opacity: here.value

        Repeater {
            model: root.deepest

            delegate: Item {
                id: slot

                required property int index

                readonly property string mark: root.apps[slot.index] ?? ""

                x: span.value - root.reach(slot.index)
                y: root.disc - height
                z: root.deepest - slot.index
                width: root.size(slot.index)
                height: width

                opacity: there.value * (1 - slot.index * 0.32)
                visible: there.value > 0.01

                Follow {
                    id: there

                    target: slot.index < root.apps.length ? 1 : 0
                    speed: Appearance.animation.revealSpeed
                    epsilon: 0.004
                }

                SquircleRect {
                    anchors.fill: parent
                    anchors.margins: -root.ring
                    pill: "object"
                    color: Appearance.colour.ink
                }

                SquircleRect {
                    anchors.fill: parent
                    pill: "object"

                    color: Appearance.colour.surfaceSolid
                    stroke: Appearance.colour.fillStrong
                    strokeWidth: Appearance.stroke.line
                }

                Image {
                    readonly property real margin: Math.round(slot.width * 0.2)

                    x: margin
                    y: margin
                    width: slot.width - margin * 2
                    height: width

                    visible: slot.mark !== "" && status === Image.Ready
                    source: slot.mark
                    sourceSize.width: width * Screen.devicePixelRatio
                    sourceSize.height: height * Screen.devicePixelRatio
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                }

                Icon {
                    anchors.centerIn: parent
                    visible: slot.mark === ""
                    name: "notifications"
                    size: Math.round(slot.width / 2)
                    fill: 1
                    color: Appearance.colour.textDim
                }
            }
        }

        Item {
            readonly property real across: Math.round(Appearance.font.line.small * 0.85)

            x: span.value + root.disc - width * 0.7
            y: -height * 0.3
            z: root.deepest + 1
            width: Math.max(across, count.implicitWidth + Appearance.padding.small)
            height: across

            opacity: badge.value
            visible: badge.value > 0.01

            Follow {
                id: badge

                target: root.badged && root.shownTotal > 1 ? 1 : 0
                speed: Appearance.animation.revealSpeed
                epsilon: 0.004
            }

            SquircleRect {
                anchors.fill: parent
                anchors.margins: -root.ring
                pill: "object"
                color: Appearance.colour.ink
            }

            SquircleRect {
                anchors.fill: parent
                pill: "object"
                color: Appearance.colour.accent
            }

            Text {
                id: count

                anchors.centerIn: parent
                text: root.shownTotal
                color: Appearance.colour.ink
                font.family: root.family
                font.pixelSize: Appearance.font.size.small
                font.variableAxes: ({ "wght": 650 })
                font.features: ({ "tnum": 1 })
                renderType: Text.NativeRendering
            }
        }
    }
}
