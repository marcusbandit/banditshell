pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property string filter: ""
    property bool live: root.visible

    signal asks(Item item, var actions, real x, real y)

    onLiveChanged: Mixer.watch(root, root.live)
    Component.onCompleted: Mixer.watch(root, root.live)
    Component.onDestruction: Mixer.watch(root, false)

    readonly property real contentHeight: rows.implicitHeight

    readonly property string term: root.filter.trim().toLowerCase()
    readonly property bool filtering: root.term !== ""

    function matches(app: var): bool {
        if (!root.filtering)
            return true;
        const hay = `${app.display} ${app.binary} ${app.name}`.toLowerCase();
        return hay.indexOf(root.term) >= 0;
    }

    readonly property var outputKeys: Mixer.outputApps.filter(a => root.matches(a)).map(a => a.key)
    readonly property var inputKeys: Mixer.inputApps.filter(a => root.matches(a)).map(a => a.key)

    readonly property var entries: (root.filtering ? [] : ["device:out", "device:in"]).concat(root.outputKeys.map(k => `out:${k}`), root.inputKeys.map(k => `in:${k}`))

    property string selectedKey: ""
    property bool showsSelection: true
    readonly property int fallback: Math.max(0, root.entries.findIndex(k => k.startsWith("out:")))
    readonly property int selected: root.entries.indexOf(root.selectedKey) >= 0 ? root.entries.indexOf(root.selectedKey) : root.fallback
    readonly property string current: root.entries[root.selected] ?? ""

    function pick(key: string): void {
        root.selectedKey = key;
        root.reveal();
    }

    function move(delta: int): void {
        if (!root.entries.length)
            return;
        const next = Math.max(0, Math.min(root.entries.length - 1, root.selected + delta));
        root.pick(root.entries[next]);
    }

    function rowFor(key: string): Item {
        for (const item of rows.children)
            if (item.entryKey === key)
                return item;
        return null;
    }

    function reveal(): void {
        Qt.callLater(() => {
            const item = root.rowFor(root.current);
            if (!item)
                return;
            const at = item.mapToItem(rows, 0, 0).y;
            const top = flick.contentY;
            const bottom = top + flick.height;
            if (at < top)
                wheel.scrollTo(at - Appearance.padding.large);
            else if (at + item.height > bottom)
                wheel.scrollTo(at + item.height - flick.height + Appearance.padding.large);
        });
    }

    function nudge(steps: int): void {
        root.rowFor(root.current)?.nudge(steps);
    }

    function toggle(): void {
        root.rowFor(root.current)?.toggle();
    }

    readonly property Item currentRow: root.entries.length >= 0 ? root.rowFor(root.current) : null
    readonly property bool currentMuted: !!root.currentRow?.muted
    readonly property string currentName: root.currentRow?.name ?? ""

    function actionsForCurrent(): var {
        return root.currentRow?.actions() ?? [];
    }

    function claimKey(event: var): bool {
        const claimed = root.handleKey(event);
        if (claimed)
            root.showsSelection = true;
        return claimed;
    }

    function handleKey(event: var): bool {
        const mods = event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier | Qt.ShiftModifier);
        if (mods)
            return false;
        switch (event.key) {
        case Qt.Key_Up:
            root.move(-1);
            return true;
        case Qt.Key_Down:
            root.move(1);
            return true;
        case Qt.Key_Left:
            root.nudge(-1);
            return true;
        case Qt.Key_Right:
            root.nudge(1);
            return true;
        case Qt.Key_PageUp:
            root.move(-5);
            return true;
        case Qt.Key_PageDown:
            root.move(5);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.toggle();
            return true;
        }
        return false;
    }

    component Heading: StyledText {
        width: parent ? parent.width : 0
        leftPadding: Appearance.padding.card
        topPadding: Appearance.padding.large
        bottomPadding: Appearance.padding.small
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    Flickable {
        id: flick

        anchors.fill: parent
        contentHeight: rows.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        WheelStep {
            id: wheel

            flick: flick
        }

        Column {
            id: rows

            width: flick.width

            StyledText {
                readonly property string entryKey: ""

                width: parent.width
                leftPadding: Appearance.padding.card
                rightPadding: Appearance.padding.card
                bottomPadding: Appearance.padding.small
                text: Mixer.headline
                color: Mixer.soundingApps.length ? Appearance.colour.text : Appearance.colour.textDim
                font.pixelSize: Appearance.font.size.large
                wrapMode: Text.Wrap
            }

            Heading {
                readonly property string entryKey: ""

                visible: !root.filtering
                text: "Devices"
            }

            MixerDevice {
                readonly property string entryKey: "device:out"

                visible: !root.filtering
                width: parent.width
                selected: root.showsSelection && root.current === entryKey
                onPicked: root.pick(entryKey)
                onAsks: (item, actions, x, y) => root.asks(item, actions, x, y)
            }

            MixerDevice {
                readonly property string entryKey: "device:in"

                visible: !root.filtering
                width: parent.width
                input: true
                selected: root.showsSelection && root.current === entryKey
                onPicked: root.pick(entryKey)
                onAsks: (item, actions, x, y) => root.asks(item, actions, x, y)
            }

            Heading {
                readonly property string entryKey: ""

                text: "Playing"
            }

            StyledText {
                readonly property string entryKey: ""

                visible: !root.outputKeys.length
                width: parent.width
                leftPadding: Appearance.padding.card
                topPadding: Appearance.padding.small
                bottomPadding: Appearance.padding.normal
                text: root.filtering ? "No app matches" : "No app has sound open"
                color: Appearance.colour.textFaint
                font.pixelSize: Appearance.font.size.normal
            }

            Repeater {
                model: ScriptModel {
                    values: root.outputKeys
                }

                delegate: MixerApp {
                    required property string modelData

                    readonly property string entryKey: `out:${modelData}`

                    width: rows.width
                    appKey: modelData
                    selected: root.showsSelection && root.current === entryKey
                    onPicked: root.pick(entryKey)
                    onAsks: (item, actions, x, y) => root.asks(item, actions, x, y)
                }
            }

            Heading {
                readonly property string entryKey: ""

                visible: root.inputKeys.length > 0
                text: "Recording"
            }

            Repeater {
                model: ScriptModel {
                    values: root.inputKeys
                }

                delegate: MixerApp {
                    required property string modelData

                    readonly property string entryKey: `in:${modelData}`

                    width: rows.width
                    appKey: modelData
                    listening: true
                    selected: root.showsSelection && root.current === entryKey
                    onPicked: root.pick(entryKey)
                    onAsks: (item, actions, x, y) => root.asks(item, actions, x, y)
                }
            }

            Item {
                readonly property string entryKey: ""

                width: 1
                height: Appearance.padding.large
            }
        }
    }
}
