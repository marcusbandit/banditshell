pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.controls
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

    readonly property string moreKey: "tray:more"

    readonly property var everything: Config.values.sidebar.tray.enabled ? Tray.items : []
    readonly property var shown: root.everything.slice(0, Config.values.sidebar.tray.max)
    readonly property var folded: root.everything.slice(Config.values.sidebar.tray.max)
    readonly property int slotCount: root.shown.length + (root.folded.length > 0 ? 1 : 0)

    function markItem(key: string): void {
        const i = key === root.moreKey ? root.shown.length : root.shown.findIndex(item => root.keyFor(item) === key);
        if (i < 0)
            return;

        const cold = lit.value < 0.01;
        root.markedIndex = i;
        if (cold)
            slide.snap();
    }

    Follow {
        id: slide

        speed: Appearance.animation.trackSpeed
        target: root.markedIndex * root.pitch
    }

    Follow {
        id: lit

        speed: Appearance.animation.revealSpeed
        target: root.hoveredKey ? 1 : 0
        epsilon: 0.005
    }

    function keyFor(item: var): string {
        return `tray:${Tray.keyOf(item)}`;
    }

    readonly property var items: [...root.shown.map(i => ({
                key: root.keyFor(i),
                title: Tray.nameOf(i),
                body: trayMenu
            })), ...(root.folded.length > 0 ? [{
                    key: root.moreKey,
                    title: `${root.folded.length} more`,
                    body: moreMenu
                }] : [])]

    property var openItem: null

    function entryFor(key: string): var {
        const entry = root.items.find(i => i.key === key) ?? null;
        if (entry && key !== root.moreKey)
            root.openItem = root.shown.find(i => root.keyFor(i) === key) ?? null;
        return entry;
    }

    function iconFor(key: string): Item {
        if (key === root.moreKey)
            return folds;
        for (let i = 0; i < repeater.count; i++) {
            const item = repeater.itemAt(i);
            if (item?.key === key)
                return item;
        }
        return null;
    }

    implicitWidth: root.slotCount ? Appearance.sizes.traySlot : 0
    implicitHeight: root.slotCount ? column.implicitHeight : 0
    visible: root.slotCount > 0

    readonly property bool boxed: fill.color.a > 0
    readonly property real sideGap: (width - (root.boxed ? fill.width : Appearance.sizes.traySlot)) / 2
    readonly property real overhang: root.boxed ? Appearance.padding.small : 0

    SquircleRect {
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

    SquircleRect {
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
                tipped: !root.menusShown

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

        Item {
            id: folds

            width: column.width
            height: Appearance.sizes.traySlot
            visible: root.folded.length > 0

            readonly property bool hovered: foldMouse.containsMouse

            StyledText {
                anchors.centerIn: parent
                text: `+${root.folded.length}`
                color: folds.hovered ? Appearance.colour.text : Appearance.colour.textDim
                font.pixelSize: Appearance.font.size.small
            }

            MouseArea {
                id: foldMouse

                anchors.fill: parent
                anchors.topMargin: -Appearance.sizes.trayGap / 2
                anchors.bottomMargin: -Appearance.sizes.trayGap / 2
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onEntered: root.hoveredKey = root.moreKey
                onExited: if (root.hoveredKey === root.moreKey)
                    root.hoveredKey = ""
                onClicked: root.requested(root.moreKey, true)
            }

            HoverTip {
                text: root.menusShown ? "" : `${root.folded.length} more tray icons`
                asked: folds.hovered
            }
        }
    }

    Component {
        id: moreMenu

        TrayMore {
            items: root.folded
        }
    }

    Component {
        id: trayMenu

        TrayMenu {
            Component.onCompleted: item = root.openItem
        }
    }
}
