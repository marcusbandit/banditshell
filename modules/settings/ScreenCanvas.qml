pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import "screens.js" as Screens

FocusScope {
    id: root

    property bool editable: false

    readonly property var rects: SettingsState.screenRects
    readonly property var live: SettingsState.liveRects
    readonly property var staged: SettingsState.stagedNames
    readonly property var trouble: SettingsState.screenTrouble
    readonly property var confirm: SettingsState.confirm

    readonly property real reach: 10 / Math.max(vk.value, 0.0001)
    readonly property real bar: root.editable ? 52 : 0
    readonly property real pad: Math.max(28, Math.min(root.width, root.height - root.bar) * 0.14)

    readonly property string nameKey: SettingsState.monitorNames.join(",")
    property var names: []

    property string dragName: ""
    property real dragX: 0
    property real dragY: 0
    property var guides: []
    property var corner: null
    property var held: null
    property real shake: 0

    readonly property var fitted: Screens.fit(root.staged.length ? root.rects.concat(root.live) : root.rects, root.width, root.height - root.bar, root.pad)
    readonly property var view: root.held ?? root.fitted

    readonly property var picked: root.rects.find(r => r.name === Monitors.selected) ?? null
    readonly property var pickedAt: root.dragName && root.picked ? Object.assign({}, root.picked, {
        x: root.dragX,
        y: root.dragY
    }) : root.picked

    onNameKeyChanged: root.names = SettingsState.monitorNames.slice()
    Component.onCompleted: {
        root.names = SettingsState.monitorNames.slice();
        vk.snap();
        vx.snap();
        vy.snap();
    }

    function toX(v: real): real {
        return vx.value + v * vk.value;
    }

    function toY(v: real): real {
        return vy.value + v * vk.value;
    }

    function exact(name: string, x: real, y: real): void {
        const placed = root.rects.map(r => r.name === name ? Object.assign({}, r, {
                x,
                y
            }) : r);
        const s = Screens.snap(placed, name, x, y, 0);
        root.guides = s.guides;
        root.corner = s.corner;
        linger.restart();
    }

    function settled(name: string): void {
        const now = root.rects.find(r => r.name === name);
        if (now)
            root.exact(name, now.x, now.y);
    }

    function nudge(dx: int, dy: int): void {
        const name = Monitors.selected;
        const to = Screens.nudge(root.rects, name, dx, dy);
        if (!to) {
            bump.restart();
            return;
        }
        SettingsState.stageScreen(name, {
            position: `${to.x}x${to.y}`
        });
        root.settled(name);
    }

    function cycle(step: int): void {
        const list = root.names;
        if (!list.length)
            return;
        const at = list.indexOf(Monitors.selected);
        Monitors.selected = list[(at + step + list.length) % list.length];
    }

    Keys.onPressed: event => {
        if (!root.editable)
            return;
        const step = event.modifiers & Qt.ShiftModifier ? 10 : 1;
        if (event.key === Qt.Key_Left)
            root.nudge(-step, 0);
        else if (event.key === Qt.Key_Right)
            root.nudge(step, 0);
        else if (event.key === Qt.Key_Up)
            root.nudge(0, -step);
        else if (event.key === Qt.Key_Down)
            root.nudge(0, step);
        else if (event.key === Qt.Key_Tab)
            root.cycle(1);
        else if (event.key === Qt.Key_Backtab)
            root.cycle(-1);
        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.staged.length && !root.trouble.clash.length)
            SettingsState.applyStage();
        else
            return;
        event.accepted = true;
    }

    Follow {
        id: vk

        target: root.view.k
        speed: Appearance.animation.revealSpeed
        epsilon: 0.00005
    }

    Follow {
        id: vx

        target: root.view.ox
        speed: Appearance.animation.revealSpeed
    }

    Follow {
        id: vy

        target: root.view.oy
        speed: Appearance.animation.revealSpeed
    }

    Follow {
        id: show

        target: root.dragName !== "" || linger.running ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.01
    }

    Timer {
        id: linger

        interval: 1400
    }

    SequentialAnimation {
        id: bump

        NumberAnimation {
            target: root
            property: "shake"
            to: 4
            duration: 50
        }

        NumberAnimation {
            target: root
            property: "shake"
            to: -4
            duration: 80
        }

        NumberAnimation {
            target: root
            property: "shake"
            to: 0
            duration: 60
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: mouse => {
            root.forceActiveFocus();
            mouse.accepted = false;
        }
    }

    Repeater {
        model: root.editable ? root.names : []

        delegate: Rectangle {
            id: ghost

            required property string modelData

            readonly property var r: root.live.find(x => x.name === ghost.modelData) ?? null
            readonly property var now: root.rects.find(x => x.name === ghost.modelData) ?? null

            visible: !!ghost.r && !!ghost.now && (ghost.r.x !== ghost.now.x || ghost.r.y !== ghost.now.y || ghost.r.w !== ghost.now.w || ghost.r.h !== ghost.now.h)
            x: root.toX(ghost.r?.x ?? 0)
            y: root.toY(ghost.r?.y ?? 0)
            width: (ghost.r?.w ?? 0) * vk.value
            height: (ghost.r?.h ?? 0) * vk.value
            radius: 6
            color: "transparent"
            border.width: 1
            border.color: Appearance.colour.textGhost

            StyledText {
                x: 6
                y: 4
                visible: ghost.width > implicitWidth + 12
                text: "now"
                color: Appearance.colour.textGhost
                font.pixelSize: Appearance.font.size.small
            }
        }
    }

    Repeater {
        model: root.names

        delegate: Rectangle {
            id: link

            required property string modelData

            readonly property var from: root.rects.find(r => r.name === link.modelData) ?? null
            readonly property var to: root.rects.find(r => r.name === link.from?.mirror) ?? null
            readonly property real fromX: root.toX((link.from?.x ?? 0) + (link.from?.w ?? 0) / 2)
            readonly property real fromY: root.toY((link.from?.y ?? 0) + (link.from?.h ?? 0) / 2)
            readonly property real toX: root.toX((link.to?.x ?? 0) + (link.to?.w ?? 0) / 2)
            readonly property real toY: root.toY((link.to?.y ?? 0) + (link.to?.h ?? 0) / 2)

            visible: !!link.from && !!link.to && !link.from.off
            x: link.fromX
            y: link.fromY - height / 2
            width: Math.hypot(link.toX - link.fromX, link.toY - link.fromY)
            height: 2
            rotation: Math.atan2(link.toY - link.fromY, link.toX - link.fromX) * 180 / Math.PI
            transformOrigin: Item.Left
            color: Appearance.colour.accent
            opacity: 0.6
            z: 4
        }
    }

    Repeater {
        model: root.names

        delegate: Item {
            id: mon

            required property string modelData

            readonly property var r: root.rects.find(x => x.name === mon.modelData) ?? null
            readonly property bool moving: root.dragName === mon.modelData
            readonly property bool picked: Monitors.selected === mon.modelData
            readonly property bool changed: root.staged.indexOf(mon.modelData) >= 0
            readonly property bool clashing: root.trouble.clash.some(p => p.indexOf(mon.modelData) >= 0)
            readonly property bool on: SettingsState.screenOn(mon.modelData)
            readonly property string follows: SettingsState.screenMirror(mon.modelData)

            Follow {
                id: fx

                target: mon.r?.x ?? 0
                speed: Appearance.animation.trackSpeed
                epsilon: 0.5
            }

            Follow {
                id: fy

                target: mon.r?.y ?? 0
                speed: Appearance.animation.trackSpeed
                epsilon: 0.5
            }

            Follow {
                id: fw

                target: mon.r?.w ?? 0
                speed: Appearance.animation.revealSpeed
                epsilon: 0.5
            }

            Follow {
                id: fh

                target: mon.r?.h ?? 0
                speed: Appearance.animation.revealSpeed
                epsilon: 0.5
            }

            Component.onCompleted: {
                fx.snap();
                fy.snap();
                fw.snap();
                fh.snap();
            }

            visible: !!mon.r
            x: root.toX(mon.moving ? root.dragX : fx.value) + (mon.picked ? root.shake : 0)
            y: root.toY(mon.moving ? root.dragY : fy.value)
            width: fw.value * vk.value
            height: fh.value * vk.value
            z: mon.moving ? 3 : mon.picked ? 2 : 1
            opacity: mon.on ? 1 : 0.7

            SquircleRect {
                anchors.fill: parent
                radius: 6
                color: Appearance.colour.fillStrong
            }

            SquircleImage {
                anchors.fill: parent
                visible: mon.on && SettingsState.v("wallOn")
                radius: 6
                source: Wallpaper.faceOf(Wallpaper.currentOn(mon.follows || mon.modelData))
                fillMode: Image.PreserveAspectCrop
            }

            Item {
                anchors.fill: parent
                visible: !mon.on
                clip: true

                Repeater {
                    model: Math.ceil((mon.width + mon.height) / 10)

                    delegate: Rectangle {
                        required property int index

                        x: index * 10 - mon.height
                        width: 5
                        height: Math.hypot(mon.width, mon.height) * 2
                        rotation: 45
                        transformOrigin: Item.TopLeft
                        color: Appearance.colour.fill
                    }
                }
            }

            SquircleRect {
                anchors.fill: parent
                radius: 6
                color: "transparent"
                stroke: mon.clashing ? Appearance.colour.alarm : mon.picked ? Appearance.colour.accent : Appearance.colour.fillStronger
                strokeWidth: mon.picked || mon.clashing ? 3 : 2
            }

            Rectangle {
                x: parent.width - width - 7
                y: 7
                width: 8
                height: 8
                radius: 4
                visible: root.editable && mon.changed
                color: Appearance.colour.accent
            }

            Item {
                x: 6
                y: parent.height - height - 6
                width: Math.min(parent.width - 12, tag.width + 12)
                height: tag.height + 2
                clip: true
                visible: parent.width > 40 && parent.height > 22

                SquircleRect {
                    anchors.fill: parent
                    radius: 6
                    color: Appearance.colour.surfaceSolid
                }

                Column {
                    id: tag

                    x: 6
                    y: 1

                    StyledText {
                        text: mon.modelData
                    }

                    StyledText {
                        visible: !!mon.follows && mon.height > 44
                        text: `follows ${mon.follows}`
                        color: Appearance.colour.accent
                        font.pixelSize: Appearance.font.size.small
                    }

                    StyledText {
                        visible: root.editable && !!mon.r && mon.height > 64 && mon.width > implicitWidth + 24
                        text: mon.r ? `${mon.r.pw} × ${mon.r.ph}${mon.r.hz ? ` · ${mon.r.hz} Hz` : ""}${Math.abs(mon.r.scale - 1) > 0.001 ? ` · ×${Math.round(mon.r.scale * 100) / 100}` : ""}` : ""
                        color: Appearance.colour.textDim
                        font.pixelSize: Appearance.font.size.small
                    }
                }
            }

            MouseArea {
                id: grab

                property point start
                property bool moved: false
                property real x0: 0
                property real y0: 0

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: !root.editable ? Qt.PointingHandCursor : mon.moving ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                preventStealing: true

                onPressed: mouse => {
                    root.forceActiveFocus();
                    if (Monitors.selected !== mon.modelData)
                        Monitors.selected = mon.modelData;
                    grab.start = mapToItem(root, mouse.x, mouse.y);
                    grab.moved = false;
                    grab.x0 = mon.r?.x ?? 0;
                    grab.y0 = mon.r?.y ?? 0;
                }

                onPositionChanged: mouse => {
                    if (!root.editable || !grab.pressed)
                        return;
                    const p = mapToItem(root, mouse.x, mouse.y);
                    const dx = p.x - grab.start.x;
                    const dy = p.y - grab.start.y;
                    if (!grab.moved && Math.hypot(dx, dy) > 3) {
                        grab.moved = true;
                        root.held = {
                            k: vk.value,
                            ox: vx.value,
                            oy: vy.value
                        };
                        root.dragName = mon.modelData;
                    }
                    if (!grab.moved)
                        return;
                    const free = (mouse.modifiers & Qt.ControlModifier) !== 0;
                    const s = Screens.snap(root.rects, mon.modelData, grab.x0 + dx / vk.value, grab.y0 + dy / vk.value, free ? 0 : root.reach);
                    root.dragX = s.x;
                    root.dragY = s.y;
                    root.guides = s.guides;
                    root.corner = s.corner;
                }

                onReleased: {
                    if (!grab.moved)
                        return;
                    const spot = Screens.settle(root.rects, mon.modelData, root.dragX, root.dragY, root.reach);
                    fx.value = root.dragX;
                    fy.value = root.dragY;
                    root.dragName = "";
                    root.held = null;
                    SettingsState.stageScreen(mon.modelData, {
                        position: `${spot.x}x${spot.y}`
                    });
                    root.settled(mon.modelData);
                }

                onCanceled: {
                    if (!grab.moved)
                        return;
                    fx.value = root.dragX;
                    fy.value = root.dragY;
                    root.dragName = "";
                    root.held = null;
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        opacity: show.value
        visible: opacity > 0.01
        z: 5

        Repeater {
            model: root.guides

            delegate: Item {
                id: guide

                required property var modelData

                readonly property bool vertical: guide.modelData.axis === "x"
                readonly property real at: guide.vertical ? root.toX(guide.modelData.at) : root.toY(guide.modelData.at)
                readonly property real from: (guide.vertical ? root.toY(guide.modelData.from) : root.toX(guide.modelData.from)) - 10
                readonly property real to: (guide.vertical ? root.toY(guide.modelData.to) : root.toX(guide.modelData.to)) + 10

                Rectangle {
                    x: guide.vertical ? Math.round(guide.at) - 1 : guide.from
                    y: guide.vertical ? guide.from : Math.round(guide.at) - 1
                    width: guide.vertical ? 2 : guide.to - guide.from
                    height: guide.vertical ? guide.to - guide.from : 2
                    color: Appearance.colour.accent
                    opacity: guide.modelData.kind === "centre" ? 1 : 0.8
                }

                Item {
                    visible: guide.modelData.kind === "centre"
                    x: guide.vertical ? Math.round(guide.at) - width / 2 : guide.to + 4
                    y: guide.vertical ? guide.to + 4 : Math.round(guide.at) - height / 2
                    width: centreWord.implicitWidth + 12
                    height: centreWord.implicitHeight + 2

                    SquircleRect {
                        anchors.fill: parent
                        radius: 6
                        color: Appearance.colour.accent
                    }

                    StyledText {
                        id: centreWord

                        anchors.centerIn: parent
                        text: "centred"
                        color: Appearance.colour.accentText
                        font.pixelSize: Appearance.font.size.small
                    }
                }
            }
        }

        Rectangle {
            visible: !!root.corner
            x: root.toX(root.corner?.x ?? 0) - width / 2
            y: root.toY(root.corner?.y ?? 0) - height / 2
            width: 12
            height: 12
            radius: 6
            color: Appearance.colour.accent
            border.width: 2
            border.color: Appearance.colour.surfaceSolid
        }
    }

    Item {
        x: Appearance.padding.normal
        y: Appearance.padding.normal
        width: Math.min(root.width - Appearance.padding.normal * 2, where.implicitWidth + 16)
        height: where.implicitHeight + 6
        visible: root.editable && !!root.pickedAt
        z: 6

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colour.surfaceSolid
        }

        StyledText {
            id: where

            x: 8
            width: parent.width - 16
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            textFormat: Text.StyledText
            text: root.pickedAt ? `${root.pickedAt.name} <font color="${Appearance.colour.textDim}">at ${root.pickedAt.x}, ${root.pickedAt.y} · ${root.pickedAt.w} × ${root.pickedAt.h}</font>` : ""
            font.pixelSize: Appearance.font.size.small
        }
    }

    StyledText {
        anchors.centerIn: parent
        visible: root.names.length === 0
        text: "no screens reported"
        color: Appearance.colour.textFaint
    }

    Item {
        id: footer

        readonly property bool asking: !!root.confirm
        readonly property bool pending: root.staged.length > 0
        readonly property bool clash: root.trouble.clash.length > 0

        x: Appearance.padding.normal
        y: root.height - height - Appearance.padding.normal
        width: root.width - Appearance.padding.normal * 2
        height: 36
        visible: root.editable
        z: 6

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - buttons.width - Appearance.padding.normal
            elide: Text.ElideRight
            color: footer.clash ? Appearance.colour.alarm : footer.asking || footer.pending ? Appearance.colour.text : Appearance.colour.textFaint
            text: {
                if (footer.asking)
                    return `keep these screens? going back in ${SettingsState.confirmLeft} s`;
                if (footer.clash)
                    return `${root.trouble.clash[0].join(" and ")} overlap · move one`;
                if (footer.pending && root.trouble.loose.length)
                    return `${root.trouble.loose[0]} touches no other screen`;
                if (footer.pending)
                    return root.staged.length === 1 ? `${root.staged[0]} changed · not applied yet` : `${root.staged.length} screens changed · not applied yet`;
                return "drag to move · arrows nudge · shift moves 10";
            }
        }

        Row {
            id: buttons

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.padding.small

            Button {
                visible: footer.asking || footer.pending
                size: 0
                text: footer.asking ? "Go back" : "Reset"
                onClicked: footer.asking ? SettingsState.revertApplied() : SettingsState.resetStage()
            }

            Button {
                visible: footer.asking || footer.pending
                size: 0
                style: "filled"
                text: footer.asking ? "Keep" : "Apply"
                interactive: footer.asking || !footer.clash
                onClicked: footer.asking ? SettingsState.keepApplied() : SettingsState.applyStage()
            }
        }
    }
}
