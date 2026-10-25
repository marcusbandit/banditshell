pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    readonly property bool open: root.shown
    property bool shown: false

    property int selected: root.resting

    property string arming: ""

    property string restoreTo: ""

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    readonly property var actions: Power.actions.concat([
        {
            key: "suspend",
            icon: "bedtime",
            label: "Sleep",
            safe: true
        }
    ])

    readonly property int resting: Math.max(0, root.actions.findIndex(a => a.safe))

    readonly property Item maskItem: catcher

    readonly property real button: Appearance.sizes.sessionButton

    readonly property string again: "Press again"

    readonly property string lines: {
        const lines = [root.again];
        for (const entry of root.actions)
            lines.push(entry.label, entry.safe ? "" : root.armedLine(entry));
        return lines.join("\n");
    }

    readonly property real line: Appearance.font.line.small

    readonly property real cellWidth: Math.max(root.button, Math.ceil(widest.implicitWidth) + root.pad * 2)

    readonly property real cellHeight: Math.max(root.button, Appearance.sizes.sessionIcon + Appearance.padding.hair + root.line * 2 + root.gap * 2)

    readonly property real gap: Appearance.padding.small

    readonly property real pad: Appearance.padding.normal

    readonly property real step: root.cellHeight + root.gap

    readonly property real groupWidth: root.cellWidth + root.gap * 2
    readonly property real groupHeight: root.actions.length * root.step - root.gap + root.gap * 2

    readonly property real cellRadius: Appearance.rounding.normal
    readonly property real groupRadius: root.cellRadius + root.gap

    readonly property real contentWidth: root.groupWidth
    readonly property real contentHeight: root.groupHeight

    readonly property real panelWidth: root.contentWidth + root.pad * 2
    readonly property real panelHeight: root.contentHeight + root.pad * 2

    readonly property real slide: (root.panelWidth + Appearance.sizes.melt) * (1 - reveal.value)

    readonly property var blobs: [
        {
            x: root.width - root.panelWidth + root.slide,
            y: (root.height - root.panelHeight) / 2,
            w: root.panelWidth,
            h: root.panelHeight,
            radius: Appearance.rounding.large
        }
    ]

    function show(): void {
        if (root.shown)
            return;
        root.restoreTo = Hypr.focusedOn(root.screenName);
        root.selected = root.resting;
        root.arming = "";

        marker.snap();
        root.shown = true;

        Qt.callLater(keys.forceActiveFocus);
    }

    function hide(): void {
        if (!root.shown)
            return;
        root.shown = false;
        root.arming = "";
        keys.focus = false;
        Hypr.restoreFocus(root.restoreTo);
        root.restoreTo = "";
    }

    function toggle(): void {
        if (root.shown)
            root.hide();
        else
            root.show();
    }

    function choose(index: int): void {
        if (index < 0 || index >= root.actions.length || index === root.selected)
            return;
        root.selected = index;
        root.arming = "";
    }

    function move(delta: int): void {
        root.choose(Math.max(0, Math.min(root.actions.length - 1, root.selected + delta)));
    }

    function armedLine(entry: var): string {
        return `to ${entry.label.toLowerCase()}`;
    }

    function run(entry: var): void {
        if (entry.key === "suspend")
            Suspension.perform("suspend");
        else
            Power.run(entry);
    }

    function activate(index: int): void {
        const entry = root.actions[index];
        if (!entry)
            return;

        if (entry.safe || root.arming === entry.key) {
            root.run(entry);
            root.hide();
        } else {
            root.arming = entry.key;
        }
    }

    onArmingChanged: {
        if (root.arming !== "")
            disarm.restart();
        else
            disarm.stop();
    }

    Timer {
        id: disarm

        interval: 4000
        onTriggered: root.arming = ""
    }

    StyledText {
        id: widest

        visible: false
        text: root.lines
    }

    Follow {
        id: reveal

        speed: Appearance.animation.revealSpeed
        target: root.shown ? 1 : 0
        epsilon: 0.005
    }

    Follow {
        id: marker

        speed: Appearance.animation.trackSpeed
        target: root.selected * root.step
    }

    Item {
        id: keys

        Keys.onPressed: event => {
            const ctrl = event.modifiers & Qt.ControlModifier;

            if (event.key === Qt.Key_Escape) {
                Appearance.instantly();
                root.hide();
            } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P)))
                root.move(-1);
            else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N)))
                root.move(1);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                if (!event.isAutoRepeat)
                    root.activate(root.selected);
            } else
                return;

            event.accepted = true;
        }
    }

    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.open
        visible: root.open

        onClicked: root.hide()
    }

    Item {
        id: panel

        x: root.width - root.panelWidth + root.slide
        y: (root.height - root.panelHeight) / 2
        width: root.panelWidth
        height: root.panelHeight
        visible: reveal.value > 0.001
        enabled: root.open

        SquircleRect {
            x: root.pad
            anchors.verticalCenter: parent.verticalCenter
            width: root.groupWidth
            height: root.groupHeight
            radius: root.groupRadius
            color: Appearance.colour.fill

            SquircleRect {
                x: root.gap
                y: root.gap + marker.value
                width: root.cellWidth
                height: root.cellHeight
                radius: root.cellRadius

                color: markerTone.value

                FollowColour {
                    id: markerTone

                    target: root.arming ? Appearance.colour.accentFill : Appearance.colour.fillStronger
                    speed: Appearance.animation.revealSpeed
                }
            }

            Column {
                x: root.gap
                y: root.gap
                spacing: root.gap

                Repeater {
                    model: root.actions

                    delegate: Item {
                        id: cell

                        required property var modelData
                        required property int index

                        readonly property bool armed: root.arming === cell.modelData.key
                        readonly property bool chosen: root.selected === cell.index

                        width: root.cellWidth
                        height: root.cellHeight

                        Icon {
                            id: glyph

                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Math.round((root.cellHeight - Appearance.sizes.sessionIcon - Appearance.padding.hair - root.line * (cell.armed ? 2 : 1)) / 2)

                            name: cell.modelData.icon
                            size: Appearance.sizes.sessionIcon

                            color: glyphTone.value

                            FollowColour {
                                id: glyphTone

                                target: cell.armed ? Appearance.colour.accent : cell.chosen ? Appearance.colour.text : Appearance.colour.textDim
                                speed: Appearance.animation.trackSpeed
                            }
                        }

                        StyledText {
                            anchors.top: glyph.bottom
                            anchors.topMargin: Appearance.padding.hair
                            anchors.horizontalCenter: parent.horizontalCenter

                            text: cell.armed ? `${root.again}\n${root.armedLine(cell.modelData)}` : cell.modelData.label
                            horizontalAlignment: Text.AlignHCenter
                            color: glyphTone.value
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true

                            cursorShape: Qt.PointingHandCursor

                            onEntered: root.choose(cell.index)
                            onClicked: {
                                root.choose(cell.index);
                                root.activate(cell.index);
                            }
                        }
                    }
                }
            }
        }
    }
}
