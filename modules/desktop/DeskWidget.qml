pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import "placement.js" as Placement

Item {
    id: root

    required property string key
    required property string output
    required property GlassSource backdrop
    property rect area: Qt.rect(0, 0, 0, 0)
    property real gap: Appearance.padding.large
    property var heights: ({})
    property string fallbackSize: "medium"
    property bool clearAtRest: false
    property bool backed: false

    property Component small
    property Component medium
    property Component large

    property bool expanded: false
    property bool peeking: false
    property bool dragging: false
    property bool dragged: false
    property point grabAt: Qt.point(0, 0)
    property point dragTo: Qt.point(0, 0)
    property real restHeight: 0

    readonly property string rest: Placement.validSize(DesktopLayout.sizeOf(root.key, root.fallbackSize), root.fallbackSize)
    readonly property string form: root.expanded ? "large" : root.peeking ? Placement.sizeUp(root.rest) : root.rest
    readonly property bool hovered: hover.hovered
    readonly property bool held: grip.pressed || root.dragging
    readonly property bool lifted: root.form !== root.rest || root.dragging || hover.hovered
    readonly property var saved: DesktopLayout.placeOf(root.output, root.key)
    readonly property var place: Placement.isPlace(root.saved) ? root.saved : Placement.stacked(root.key, root.heights, root.gap)
    readonly property var spot: Placement.topLeft(root.place, root.width, root.height, root.area)
    readonly property Item shown: root.form === "small" ? smallView.item : root.form === "large" ? largeView.item : mediumView.item
    readonly property real shownHeight: root.shown ? root.shown.implicitHeight : 0
    readonly property Item badge: badgeButton.visible ? badgeButton : null

    signal opened
    signal tapped(real x, real y)
    signal moved
    signal menuAsked(real x, real y)

    function toggle(): void {
        if (root.rest === "large")
            return;
        root.expanded = !root.expanded;
        if (root.expanded)
            root.opened();
    }

    function close(): void {
        root.expanded = false;
        root.peeking = false;
    }

    function pin(): void {
        DesktopLayout.resize(root.key, root.form);
        root.close();
    }

    function noteRest(): void {
        if (root.form === root.rest && root.shownHeight > 0)
            root.restHeight = root.shownHeight;
    }

    function drop(): void {
        DesktopLayout.place(root.output, root.key, Placement.placeAt(root.dragTo.x, root.dragTo.y, root.width, root.height, root.area));
        root.dragging = false;
        root.moved();
    }

    onVisibleChanged: if (!root.visible)
        root.close()
    onShownHeightChanged: root.noteRest()
    onFormChanged: root.noteRest()
    onRestChanged: root.noteRest()

    x: root.dragging ? root.dragTo.x : root.spot.x
    y: root.dragging ? root.dragTo.y : root.spot.y
    width: wide.value
    height: tall.value
    z: root.dragging ? 30 : root.expanded ? 20 : root.lifted ? 10 : 0

    Follow {
        id: wide

        target: root.shown ? root.shown.implicitWidth : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.5
        onTargetChanged: if (wide.value <= 0)
            wide.snap()
    }

    Follow {
        id: tall

        target: root.shownHeight
        speed: Appearance.animation.revealSpeed
        epsilon: 0.5
        onTargetChanged: if (tall.value <= 0)
            tall.snap()
    }

    Follow {
        id: raised

        target: root.expanded || root.dragging ? 1 : root.lifted ? 0.6 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: Appearance.animation.fadeEpsilon
        startsAtTarget: true
    }

    Follow {
        id: backing

        target: root.backed ? 1 : 0
        speed: Appearance.animation.settleSpeed
        epsilon: Appearance.animation.fadeEpsilon
        startsAtTarget: true
    }

    Timer {
        interval: Appearance.animation.dwell
        running: hover.hovered && !root.dragging && !root.peeking && !root.expanded && root.rest === "small"
        onTriggered: root.peeking = true
    }

    Timer {
        interval: 400
        running: !hover.hovered && !badgeHover.hovered && root.peeking && !root.dragging
        onTriggered: root.peeking = false
    }

    Glass {
        anchors.fill: parent
        backdrop: root.backdrop
        origin: Qt.point(root.x, root.y)
        opacity: root.clearAtRest ? Math.min(1, Math.max(raised.value / 0.6, backing.value)) : 1
        frosting: 0.85 * raised.value
        sheen: 0.14 + 0.1 * raised.value
        lift: 0.025 + 0.035 * raised.value
        ceiling: 0.5 - 0.15 * raised.value
        saturation: 0.9 - 0.2 * raised.value
    }

    MouseArea {
        id: grip

        property point pressAt: Qt.point(0, 0)

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        onPressed: m => {
            if (m.button !== Qt.LeftButton)
                return;
            root.dragged = false;
            grip.pressAt = grip.mapToItem(root.parent, m.x, m.y);
            root.grabAt = Qt.point(grip.pressAt.x - root.x, grip.pressAt.y - root.y);
        }

        onPositionChanged: m => {
            if (!(grip.pressedButtons & Qt.LeftButton))
                return;
            const at = grip.mapToItem(root.parent, m.x, m.y);
            if (!root.dragging && Math.hypot(at.x - grip.pressAt.x, at.y - grip.pressAt.y) < Appearance.padding.small)
                return;
            root.dragging = true;
            root.dragged = true;
            root.dragTo = Qt.point(at.x - root.grabAt.x, at.y - root.grabAt.y);
        }

        onReleased: m => {
            if (m.button === Qt.LeftButton && root.dragging)
                root.drop();
        }

        onCanceled: {
            if (root.dragging)
                root.drop();
        }

        onClicked: m => {
            if (m.button === Qt.RightButton) {
                const at = grip.mapToItem(root.parent, m.x, m.y);
                root.menuAsked(at.x, at.y);
            } else if (!root.dragged) {
                root.tapped(m.x, m.y);
                root.toggle();
            }
        }
    }

    HoverHandler {
        id: hover
    }

    Item {
        anchors.fill: parent
        clip: true

        FormView {
            id: smallView

            name: "small"
            face: root.small
        }

        FormView {
            id: mediumView

            name: "medium"
            face: root.medium
        }

        FormView {
            id: largeView

            name: "large"
            face: root.large
        }
    }

    Item {
        id: badgeButton

        readonly property bool leftSide: Placement.badgeSide(root.place) === "left"

        width: Math.round(Appearance.font.iconSize * 1.6)
        height: badgeButton.width
        x: badgeButton.leftSide ? -Math.round(badgeButton.width / 3) : root.width - Math.round(badgeButton.width * 2 / 3)
        y: -Math.round(badgeButton.height / 3)
        visible: badgeFade.value > 0.002
        opacity: badgeFade.value

        Follow {
            id: badgeFade

            target: root.form !== root.rest && !root.dragging ? 1 : 0
            speed: Appearance.animation.revealSpeed
            epsilon: Appearance.animation.fadeEpsilon
            startsAtTarget: true
        }

        Glass {
            anchors.fill: parent
            backdrop: root.backdrop
            origin: Qt.point(root.x + badgeButton.x, root.y + badgeButton.y)
            radius: badgeButton.width / 2
            power: 2
            frosting: 1
            sheen: badgeHover.hovered ? 0.35 : 0.22
            lift: badgeHover.hovered ? 0.12 : 0.07
            ceiling: 0.3
        }

        Icon {
            anchors.centerIn: parent
            name: "push_pin"
            size: Appearance.icon.small
            fill: badgeHover.hovered ? 1 : 0
            color: Appearance.colour.text
        }

        HoverHandler {
            id: badgeHover
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.pin()
        }

        FloatingTooltip {
            text: "Keep this size"
            shown: badgeHover.hovered
        }
    }

    component FormView: Item {
        id: view

        required property string name
        property Component face

        readonly property bool current: root.form === view.name
        readonly property Item item: loader.item

        width: loader.item ? loader.item.implicitWidth : 0
        height: loader.item ? loader.item.implicitHeight : 0
        x: root.place.side === "right" ? root.width - view.width : 0
        y: root.place.edge === "bottom" ? root.height - view.height : 0
        opacity: fade.value
        visible: fade.value > 0.002

        Follow {
            id: fade

            target: view.current ? 1 : 0
            speed: Appearance.animation.revealSpeed
            epsilon: Appearance.animation.fadeEpsilon
            startsAtTarget: true
        }

        Loader {
            id: loader

            anchors.fill: parent
            active: view.current || fade.value > 0.002
            sourceComponent: view.face
        }
    }
}
