import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property real rowHeight: Appearance.sizes.rowHeight

    property bool tappable: false

    default property alias content: slot.data

    readonly property real discSize: Appearance.sizes.minTarget
    readonly property real discSpace: root.discSize + Appearance.padding.small

    signal tapped
    signal dismissed

    property real dragX: 0
    property real pulled: 0

    readonly property real throwDistance: Math.max(1, root.width) * Config.values.control.dragDismissFraction

    readonly property real fade: {
        const held = root.throwDistance * Config.values.control.dragResistance;
        const past = Math.max(0, root.dragX - held);
        return Math.max(0, 1 - past / Math.max(1, root.width - held));
    }

    function resist(delta: real): real {
        const commit = root.throwDistance;
        const k = Config.values.control.dragResistance;
        return delta < commit ? delta * k : commit * k + (delta - commit);
    }

    implicitWidth: parent ? parent.width : 0
    implicitHeight: root.rowHeight
    height: implicitHeight

    Follow {
        id: settle

        speed: Appearance.anim.revealSpeed
        onValueChanged: if (!pointer.throwing)
            root.dragX = value
    }

    MouseArea {
        id: pointer

        property real fromX: 0
        property real fromY: 0
        property real startedAt: 0

        property bool throwing: false

        property bool wandered: false

        property bool scrolling: false

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.tappable ? Qt.PointingHandCursor : Qt.ArrowCursor

        function begin(): void {
            pointer.startedAt = root.dragX;
            pointer.throwing = false;
            pointer.wandered = false;
            pointer.scrolling = false;

            settle.value = root.dragX;
            settle.target = root.dragX;
        }

        function advance(dx: real, dy: real): void {
            if (!pointer.throwing) {
                if (Math.abs(dy) >= Config.values.control.dragThreshold)
                    pointer.wandered = true;

                if (Math.abs(dy) > dx)
                    return;
                if (dx < Config.values.control.dragThreshold)
                    return;
                pointer.throwing = true;
            }

            root.pulled = dx;
            root.dragX = root.resist(Math.max(0, pointer.startedAt + dx));
        }

        function stream(dx: real, dy: real): void {
            if (!pointer.throwing) {
                if (pointer.scrolling)
                    return;
                if (Math.abs(dy) > dx && Math.abs(dy) >= Config.values.control.dragThreshold) {
                    pointer.scrolling = true;
                    return;
                }
            }
            pointer.advance(dx, dy);
        }

        function conclude(): void {
            if (!pointer.throwing)
                return;

            if (root.pulled >= root.throwDistance) {
                root.dismissed();
                return;
            }

            settle.value = root.dragX;
            settle.target = 0;
            root.pulled = 0;
            pointer.throwing = false;
        }

        onPressed: mouse => {
            scroll.finish();
            pointer.fromX = pointer.x + mouse.x;
            pointer.fromY = pointer.y + mouse.y;
            pointer.begin();
        }

        onPositionChanged: mouse => {
            if (pointer.pressed)
                pointer.advance(pointer.x + mouse.x - pointer.fromX, pointer.y + mouse.y - pointer.fromY);
        }

        onReleased: {
            if (!pointer.throwing) {
                if (!pointer.wandered && root.tappable)
                    root.tapped();
                return;
            }
            pointer.conclude();
        }

        onCanceled: {
            settle.value = root.dragX;
            settle.target = 0;
            root.pulled = 0;
            pointer.throwing = false;
            pointer.wandered = false;
            pointer.scrolling = false;
        }

        onWheel: wheel => {
            if (pointer.pressed) {
                wheel.accepted = false;
                return;
            }

            if (!scroll.feed(wheel))
                return;

            wheel.accepted = pointer.throwing;
        }

        ScrollGesture {
            id: scroll

            armed: !pointer.pressed

            onBegan: pointer.begin()
            onMoved: (dx, dy) => pointer.stream(dx, dy)
            onEnded: pointer.conclude()
        }
    }

    Item {
        id: shifted

        x: root.dragX
        width: root.width
        height: root.height
        opacity: root.fade

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colour.fill

            opacity: pointer.containsMouse || pointer.pressed ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Item {
            id: slot

            anchors.fill: parent
        }

        Item {
            id: disc

            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.small
            anchors.verticalCenter: parent.verticalCenter

            width: root.discSize
            height: width
            opacity: pointer.containsMouse || discPress.containsMouse ? 1 : 0

            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }

            SquircleRect {
                anchors.fill: parent
                radius: height / 2
                color: discPress.containsMouse ? Appearance.colour.fillStronger : Appearance.colour.fillStrong
            }

            Icon {
                anchors.centerIn: parent

                name: "close"

                size: Appearance.font.size.small
                color: Appearance.colour.textDim
            }

            MouseArea {
                id: discPress

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.dismissed()
            }
        }
    }
}
