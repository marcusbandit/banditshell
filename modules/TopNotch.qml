import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.modules.media
import qs.services

Item {
    id: root

    property bool pinned: false

    property bool pulling: false
    property real pullProgress: 0

    readonly property bool stripHovered: zone.containsMouse
    property bool stripDwelt: false

    onStripHoveredChanged: if (!root.stripHovered)
        root.stripDwelt = false

    readonly property bool active: (root.stripHovered && root.stripDwelt) || notchZone.containsMouse || root.pinned || root.pulling
    readonly property Item maskItem: notchZone

    Timer {
        id: stripDwell

        interval: Appearance.anim.dwell
        running: root.stripHovered
        onTriggered: root.stripDwelt = true
    }

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

    readonly property Item grabItem: zone

    readonly property real descent: root.pulling ? root.pullProgress : drop.value

    property int border: Appearance.sizes.border

    readonly property real grab: Appearance.sizes.touchEdges ? Math.max(root.border, Appearance.sizes.minTarget) : root.border

    function dragTo(fraction: real): void {
        root.pulling = true;
        root.pullProgress = Math.max(0, Math.min(fraction, 1));
    }

    function dragEnd(open: bool): void {

        if (!root.pulling)
            return;
        root.pulling = false;

        drop.value = root.pullProgress;
        root.pullProgress = 0;
        root.pinned = open;
    }

    readonly property bool showsMedia: Media.hasTrack
    readonly property real contentWidth: Math.max(label.implicitWidth, showsMedia ? preview.implicitWidth : 0)
    readonly property real contentHeight: label.implicitHeight + (showsMedia ? Appearance.padding.large + preview.implicitHeight : 0)

    readonly property real notchWidth: wide.value + Appearance.padding.huge * 2
    readonly property real notchHeight: root.border + tall.value + Appearance.padding.large * 2

    readonly property real notchFull: root.border + root.contentHeight + Appearance.padding.large * 2

    readonly property var blobs: [
        {
            x: (width - notchWidth) / 2,
            y: -(notchHeight + Appearance.sizes.melt) * (1 - root.descent),
            w: notchWidth,
            h: notchHeight,
            radius: Appearance.rounding.large
        }
    ]

    onActiveChanged: {
        if (!root.active)
            return;
        wide.snap();
        tall.snap();

        Media.active?.positionChanged();
    }

    Follow {
        id: drop
        speed: Appearance.anim.revealSpeed
        target: root.active ? 1 : 0
        epsilon: 0.005
    }

    Follow {
        id: wide
        speed: Appearance.anim.resizeSpeed
        target: root.contentWidth
    }

    Follow {
        id: tall
        speed: Appearance.anim.resizeSpeed
        target: root.contentHeight
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds

        enabled: root.active
    }

    Pull {
        id: zone

        z: 1

        hoverEnabled: true
        height: root.grab
        width: root.notchWidth
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        dirX: 0
        dirY: 1

        angle: Appearance.sizes.pullAngleEdge

        travel: root.notchFull

        onTapped: root.pinned = !root.pinned

        onPulled: fraction => root.dragTo(fraction)
        onFinished: open => root.dragEnd(open)
    }

    Pull {
        id: putBack

        x: notchZone.x
        y: notchZone.y
        width: notchZone.width
        height: notchZone.height

        dirX: 0
        dirY: -1
        angle: Appearance.sizes.pullAngleEdge

        travel: root.notchFull

        onPulled: fraction => root.dragTo(1 - fraction)
        onFinished: open => root.dragEnd(!open)

    }

    MouseArea {
        id: notchZone

        hoverEnabled: true

        acceptedButtons: Qt.NoButton
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.notchWidth

        height: Math.max(root.border, root.notchHeight - (root.notchHeight + Appearance.sizes.melt) * (1 - root.descent))

        Item {
            id: content

            anchors.horizontalCenter: parent.horizontalCenter
            width: wide.value
            height: root.contentHeight
            y: parent.height - height - Appearance.padding.large
            opacity: root.descent

            StyledText {
                id: label

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top

                text: Qt.formatDateTime(clock.date, "HH:mm:ss")
                font.pixelSize: Appearance.font.size.large
            }

            MediaPreview {
                id: preview

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: implicitHeight
                visible: root.showsMedia

                watched: root.active
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
