pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.menu.content

Item {
    id: root

    signal requested(string key, bool deliberate)
    signal released

    property string hoveredKey: ""

    property bool menusShown: false

    onHoveredKeyChanged: {
        root.markItem(root.hoveredKey);

        if (root.hoveredKey) {
            if (root.menusShown)
                root.requested(root.hoveredKey, false);
        } else
            root.released();
    }

    property int markedIndex: 0

    readonly property real pitch: Appearance.sizes.traySlot + Appearance.sizes.trayGap

    function markItem(key: string): void {
        const i = root.shown.findIndex(item => root.keyFor(item) === key);
        if (i < 0)
            return;

        const cold = lit.value < 0.01;
        root.markedIndex = i;
        if (cold)
            slide.snap();
    }

    Follow {
        id: slide

        speed: Appearance.anim.trackSpeed
        target: root.markedIndex * root.pitch
    }

    Follow {
        id: lit

        speed: Appearance.anim.revealSpeed
        target: root.hoveredKey ? 1 : 0
        epsilon: 0.005
    }

    readonly property var shown: Tray.items.slice(0, Appearance.sizes.trayMax)

    function keyFor(item: var): string {
        return `tray:${Tray.keyOf(item)}`;
    }

    readonly property var items: root.shown.map(i => ({
                key: root.keyFor(i),
                title: Tray.nameOf(i),
                body: trayMenu
            }))

    property var openItem: null

    function entryFor(key: string): var {
        const entry = root.items.find(i => i.key === key) ?? null;
        if (entry)
            root.openItem = root.shown.find(i => root.keyFor(i) === key) ?? null;
        return entry;
    }

    function iconFor(key: string): Item {
        for (let i = 0; i < repeater.count; i++) {
            const item = repeater.itemAt(i);
            if (item?.key === key)
                return item;
        }
        return null;
    }

    implicitWidth: root.shown.length ? Appearance.sizes.traySlot : 0
    implicitHeight: root.shown.length ? column.implicitHeight : 0
    visible: root.shown.length > 0

    readonly property bool boxed: fill.color.a > 0
    readonly property real sideGap: (width - (root.boxed ? fill.width : Appearance.sizes.traySlot)) / 2
    readonly property real overhang: root.boxed ? Appearance.padding.small : 0

    G2Rect {
        id: fill

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: column.top
        anchors.bottom: column.bottom
        anchors.topMargin: -root.overhang
        anchors.bottomMargin: -root.overhang
        width: Appearance.sizes.traySlot + Appearance.padding.small * 2
        radius: Appearance.rounding.normal

        color: "transparent"
    }

    G2Rect {
        x: column.x + (column.width - width) / 2
        y: column.y + slide.value
        width: Appearance.sizes.traySlot
        height: Appearance.sizes.traySlot
        radius: Appearance.rounding.normal
        color: Appearance.colour.fillStrong
        opacity: lit.value
    }

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.sizes.trayGap

        Repeater {
            id: repeater

            model: ScriptModel {
                values: root.shown
            }

            delegate: TrayIcon {
                id: icon

                required property var modelData

                readonly property string key: root.keyFor(icon.modelData)

                width: column.width

                item: icon.modelData

                onRequested: deliberate => {
                    if (deliberate)
                        root.requested(icon.key, true);
                    else
                        root.hoveredKey = icon.key;
                }
                onHoveredChanged: if (!icon.hovered && root.hoveredKey === icon.key)
                    root.hoveredKey = ""

            }
        }
    }

    Component {
        id: trayMenu

        TrayMenu {
            Component.onCompleted: item = root.openItem
        }
    }
}
