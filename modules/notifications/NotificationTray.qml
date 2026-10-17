pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property real inset

    required property real edgeInset

    readonly property real panelWidth: Appearance.sizes.notificationWidth

    property bool pinned: false

    property bool pulling: false

    property real pushBack: 0

    readonly property bool armsHovered: cornerTop.containsMouse || cornerSide.containsMouse
    property bool dwellMet: false

    onArmsHoveredChanged: if (!root.armsHovered)
        root.dwellMet = false

    readonly property bool summoned: root.armsHovered && root.dwellMet
    readonly property bool resting: trayHover.hovered

    Timer {
        id: armsDwell

        interval: Appearance.animation.dwell
        running: root.armsHovered
        onTriggered: root.dwellMet = true
    }

    readonly property bool opening: root.summoned || root.pulling || root.pinned
    readonly property bool attended: root.opening || root.resting

    property bool courted: false

    readonly property bool expanded: root.courted || root.pulling || root.pinned

    readonly property bool wantsEscape: root.pinned

    property bool keyboardHeld: false

    function claimKeys(): void {
        if (root.wantsEscape && !root.keyboardHeld)
            keys.forceActiveFocus();
    }

    onWantsEscapeChanged: {
        if (root.wantsEscape)
            Qt.callLater(root.claimKeys);
        else
            keys.focus = false;
    }

    onOpeningChanged: if (root.opening) {
        grace.stop();
        root.courted = true;
    }

    onAttendedChanged: {
        if (root.attended)
            grace.stop();
        else
            grace.restart();
    }

    Timer {
        id: grace

        interval: Appearance.animation.grace
        onTriggered: root.courted = false
    }

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    readonly property bool mine: !root.screenName || !Focus.offStageScreen || root.screenName === Focus.offStageScreen

    readonly property bool corner: Config.values.notifications.placement !== "island"

    readonly property var shown: root.mine ? Notifications.popups : []

    readonly property var items: root.expanded ? Notifications.history : root.corner ? root.shown : []

    readonly property bool any: root.items.length > 0 || root.expanded

    readonly property var groups: Notifications.threadsOf(root.items)

    property var opened: []

    function toggleThread(id: string): void {
        root.opened = root.opened.includes(id) ? root.opened.filter(i => i !== id) : [...root.opened, id];
    }

    function letGo(entry: var): void {
        if (root.expanded)
            Notifications.forget(entry);
        else
            Notifications.dismiss(entry);
    }

    onItemsChanged: if (root.expanded)
        Notifications.markSeen()

    component Slot: Item {
        id: slot

        required property var entry
        property int count: 1
        property bool countOpen: false
        property string density: "alert"

        signal countTapped
        signal letGo(var gone)

        width: parent.width
        height: card.height + Appearance.padding.normal * card.open

        NotificationCard {
            id: card

            width: slot.width
            entry: slot.entry
            density: slot.density
            count: slot.count
            countOpen: slot.countOpen
            collapses: true
            keepLeaves: false

            onCountTapped: slot.countTapped()
            onReleased: slot.letGo(slot.entry)
            onKept: if (slot.entry)
                slot.entry.pinned = !slot.entry.pinned
        }
    }

    onExpandedChanged: {
        if (root.expanded) {
            Notifications.pause(root);
            Notifications.markSeen();
        } else {
            Notifications.resume(root);
        }
    }

    Component.onDestruction: Notifications.resume(root)

    NotificationCopier {
        entries: root.expanded ? Notifications.history : root.shown
    }

    readonly property Item maskItem: tray

    readonly property Item grabItem: corner

    property var blobs: []

    function sync(): void {
        if (tray.height <= 0) {
            root.blobs = [];
            return;
        }
        root.blobs = [
            {
                x: tray.x,
                y: 0,
                w: tray.width,
                h: tray.y + tray.height,
                radius: Appearance.rounding.large,

                smooth: Math.min(Appearance.sizes.melt, tray.height / 2)
            }
        ];
    }

    onAnyChanged: Qt.callLater(root.sync)
    onWidthChanged: Qt.callLater(root.sync)

    readonly property real armLength: Appearance.sizes.cornerZone

    MouseArea {
        id: cornerTop

        hoverEnabled: true
        anchors.top: parent.top
        anchors.right: parent.right
        width: root.armLength
        height: root.edgeInset
    }

    MouseArea {
        id: cornerSide

        hoverEnabled: true
        anchors.top: parent.top
        anchors.right: parent.right
        width: root.edgeInset
        height: root.armLength
    }

    readonly property real grab: Math.max(root.edgeInset + Appearance.padding.normal, Appearance.sizes.minTarget)

    Pull {
        id: corner

        dirX: -1
        dirY: 1

        travel: Math.hypot(root.width, root.height) * Config.values.control.pullTravel

        anchors.top: parent.top
        anchors.right: parent.right
        width: root.grab
        height: root.grab

        z: 1

        onPulled: root.pulling = true

        onFinished: open => {
            root.pulling = false;
            root.pinned = open;
        }

        onTapped: root.pinned = !root.pinned
    }

    Pull {
        id: push

        x: tray.x
        y: tray.y
        width: tray.width
        height: tray.height

        visible: tray.visible

        dirX: 1
        dirY: 0

        angle: Config.values.control.pullAngleEdge

        travel: root.panelWidth

        onPulled: fraction => root.pushBack = fraction

        onFinished: open => {

            if (open)
                root.pinned = false;

            shove.value = root.pushBack;
            shove.target = open && !root.any ? 1 : 0;
        }

    }

    Follow {
        id: shove

        speed: Appearance.animation.revealSpeed
        epsilon: 0.005
        target: 0
        onValueChanged: if (!push.pulling)
            root.pushBack = value

        onSettledChanged: if (shove.settled && shove.target === 1) {
            shove.target = 0;
            shove.snap();
        }
    }

    Item {
        id: tray

        x: root.width - root.panelWidth * (1 - root.pushBack)
        y: root.inset
        width: root.panelWidth

        opacity: 1 - root.pushBack

        readonly property real contentHeight: Math.min(list.height, root.height - root.inset * 2)

        readonly property real pad: Appearance.padding.normal * Math.min(1, contentHeight / Appearance.padding.normal)

        height: contentHeight + pad

        visible: root.any || tray.contentHeight > 0 || root.pushBack > 0

        onXChanged: Qt.callLater(root.sync)
        onYChanged: Qt.callLater(root.sync)
        onHeightChanged: Qt.callLater(root.sync)

        HoverHandler {
            id: trayHover
        }

        Flickable {
            id: view

            x: Appearance.padding.normal
            y: tray.pad
            width: tray.width - Appearance.padding.normal * 2

            height: Math.max(0, tray.height - tray.pad)

            contentHeight: list.height
            interactive: contentHeight > height
            clip: interactive
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: list

                width: view.width

                spacing: 0

                Item {
                    id: headerSlot

                    readonly property real open: reveal.value

                    width: parent.width

                    height: (header.implicitHeight + Appearance.padding.normal) * open
                    clip: true
                    visible: open > 0

                    Follow {
                        id: reveal

                        speed: Appearance.animation.revealSpeed
                        epsilon: 0.005
                        target: root.expanded ? 1 : 0
                    }

                    Item {
                        id: header

                        width: parent.width
                        implicitHeight: clearAll.implicitHeight

                        Button {
                            id: clearAll

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            visible: Notifications.count > 0
                            text: "Clear"

                            onClicked: Notifications.clear()
                        }
                    }
                }

                Repeater {

                    model: ScriptModel {
                        values: root.groups
                        objectProp: "id"
                    }

                    delegate: Column {
                        id: group

                        required property var modelData

                        readonly property bool open: root.opened.includes(group.modelData.id)
                        readonly property string density: root.expanded ? "page" : "alert"

                        function letGo(entry: var, whole: bool): void {
                            const all = whole ? group.modelData.entries.slice() : [entry];
                            for (const e of all)
                                root.letGo(e);
                        }

                        width: list.width

                        Slot {
                            entry: group.modelData.newest
                            count: group.modelData.entries.length
                            countOpen: group.open
                            density: group.density

                            onCountTapped: root.toggleThread(group.modelData.id)
                            onLetGo: gone => group.letGo(gone, !group.open)
                        }

                        Repeater {
                            model: ScriptModel {
                                values: group.open ? group.modelData.entries.slice(1) : []
                            }

                            delegate: Slot {
                                required property var modelData

                                entry: modelData
                                density: group.density

                                onLetGo: gone => group.letGo(gone, false)
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: keys

        Keys.onPressed: event => {

            if (event.key === Qt.Key_Escape) {
                root.pinned = false;
                event.accepted = true;
            }
        }
    }
}
