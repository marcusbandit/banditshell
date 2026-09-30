pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import Quickshell.Services.Notifications

Item {
    id: root

    required property var entry
    required property real fullWidth

    property bool roomy: false

    signal dismissed

    readonly property var notification: entry?.notification ?? null

    readonly property bool live: entry?.live ?? false

    readonly property bool urgent: entry?.urgency === NotificationUrgency.Critical

    readonly property bool wordless: !entry?.appName && !entry?.summary && !entry?.body

    property real reveal: 0

    property real leave: 0
    readonly property bool leaving: entry?.leaving ?? false

    readonly property real open: Math.max(0, reveal - leave)

    property real dragX: 0
    property real pulled: 0

    property int flung: 0

    readonly property real throwDistance: fullWidth * Appearance.sizes.dragDismissFraction

    readonly property bool committed: Math.abs(pulled) >= throwDistance || (pulled * drag.velocity > 0 && Math.abs(drag.velocity) >= Appearance.sizes.flickVelocity)

    readonly property real throwX: dragX + flung * leave * Math.max(0, fullWidth - Math.abs(dragX))

    readonly property bool held: hover.hovered || drag.pressed || root.pinned

    property var holding: null

    function holdEntry(): void {
        const want = root.held ? root.entry : null;
        if (root.holding === want)
            return;

        root.holding?.release(root);
        root.holding = want;
        root.holding?.hold(root);
    }

    onHeldChanged: root.holdEntry()
    onEntryChanged: root.holdEntry()

    readonly property bool pinned: entry?.pinned ?? false

    function pin(on: bool): void {
        if (root.entry)
            root.entry.pinned = on;
    }

    readonly property bool unfolded: entry?.unfolded ?? false

    function unfold(on: bool): void {
        if (root.entry)
            root.entry.unfolded = on;
    }

    width: fullWidth
    implicitHeight: body.implicitHeight + Appearance.padding.normal * 2
    height: implicitHeight * open

    clip: true

    x: throwX

    opacity: open * Math.max(0.1, 1 - Math.max(0, throwX - throwDistance * Appearance.sizes.dragResistance) / (fullWidth * 0.6))

    HoverHandler {
        id: hover
    }

    Component.onCompleted: {
        grow.target = 1;
        root.beginCopy();
    }

    onLeavingChanged: {
        if (leaving) {
            exit.start();
        } else {
            exit.stop();
            leave = 0;
            flung = 0;
        }
    }

    NumberAnimation {
        id: exit

        target: root
        property: "leave"
        to: 1
        duration: Notifications.exitMs

        easing.type: Easing.OutCubic
    }

    Follow {
        id: grow

        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
        onValueChanged: root.reveal = value
    }

    Follow {
        id: settle

        speed: Appearance.anim.revealSpeed
        target: 0
        onValueChanged: if (!drag.throwing)
            root.dragX = value
    }

    function resist(delta: real): real {
        const commit = root.throwDistance;
        const k = Appearance.sizes.dragResistance;
        const m = Math.abs(delta);
        const held = m < commit ? m * k : commit * k + (m - commit);
        return delta < 0 ? -held : held;
    }

    readonly property real radius: Math.max(Appearance.rounding.small, Appearance.rounding.large - Appearance.padding.normal)

    SquircleRect {
        anchors.fill: parent
        radius: root.radius

        color: root.held ? Appearance.colour.fillStrong : Appearance.colour.fill

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    SquircleRect {
        id: spine

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Appearance.padding.normal
        width: Math.max(2, Appearance.padding.small / 2)
        radius: width / 2
        color: Appearance.colour.accent
        visible: root.urgent
    }

    readonly property real spineRoom: root.urgent ? spine.width + Appearance.padding.small : 0

    Item {
        id: body

        x: Appearance.padding.normal + root.spineRoom
        y: Appearance.padding.normal
        width: root.fullWidth - Appearance.padding.normal * 2 - root.spineRoom

        implicitHeight: Math.max(badge.height + (fold.visible ? Appearance.padding.small + fold.height : 0), text.implicitHeight)

        Item {
            id: badge

            readonly property string picture: root.entry?.picture ?? ""
            readonly property string mark: root.entry?.mark ?? ""

            readonly property bool marked: mark !== "" && sign.ready

            readonly property bool hasImage: badge.pictured || badge.marked

            readonly property bool pictured: picture !== "" && art.ready

            width: Appearance.sizes.notificationBadge * (badge.pictured ? 2 : 1)
            height: width

            SquircleRect {
                anchors.fill: parent
                radius: Appearance.rounding.small
                color: Appearance.colour.fillStrong
                visible: !badge.hasImage
            }

            Icon {
                anchors.centerIn: parent
                visible: !badge.hasImage

                size: Math.round(badge.width / 2)
                name: root.urgent ? "priority_high" : "notifications"
                color: root.urgent ? Appearance.colour.accent : Appearance.colour.textDim
            }

            SquircleImage {
                id: sign

                anchors.left: parent.left
                anchors.top: parent.top
                width: Appearance.sizes.notificationBadge
                height: width

                source: badge.mark
                fillMode: Image.PreserveAspectCrop
                radius: Appearance.rounding.small

                visible: !badge.pictured
            }

            SquircleImage {
                id: art

                anchors.left: parent.left
                anchors.top: parent.top
                width: Appearance.sizes.notificationBadge * (badge.picture ? 2 : 1)
                height: width

                source: badge.picture
                fillMode: Image.PreserveAspectFit
                radius: Appearance.rounding.small
            }
        }

        Expander {
            id: fold

            anchors.horizontalCenter: badge.horizontalCenter
            anchors.top: badge.bottom
            anchors.topMargin: Appearance.padding.small

            visible: message.foldable || headline.foldable
            open: root.unfolded

            onToggled: root.unfold(!root.unfolded)
        }

        Column {
            id: text

            anchors.left: badge.right
            anchors.leftMargin: Appearance.padding.normal
            anchors.right: parent.right

            anchors.rightMargin: root.pinned ? pinMark.width + Appearance.padding.small : 0
            anchors.top: parent.top
            spacing: 0

            StyledText {
                width: parent.width
                visible: !!root.entry?.appName
                text: root.entry?.appName ?? ""
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textFaint
                elide: Text.ElideRight
            }

            FoldedText {
                id: headline

                width: parent.width

                visible: !!full
                full: root.wordless ? "(no message)" : (root.entry?.summary ?? "")
                color: root.wordless ? Appearance.colour.textFaint : Appearance.colour.text
                unfolded: root.unfolded

                lines: root.roomy ? 4 : 2
            }

            Item {
                id: meter

                readonly property real pct: root.entry?.progress ?? -1

                width: parent.width
                visible: pct >= 0

                height: visible ? row.implicitHeight + Appearance.padding.small : 0

                Follow {
                    id: chase

                    target: meter.pct
                    speed: Appearance.anim.revealSpeed
                }

                Component.onCompleted: chase.snap()

                Item {
                    id: row

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    implicitHeight: Math.max(gauge.implicitHeight, figure.implicitHeight)
                    height: implicitHeight

                    Gauge {
                        id: gauge

                        anchors.left: parent.left
                        anchors.right: figure.left
                        anchors.rightMargin: Appearance.padding.small
                        anchors.verticalCenter: parent.verticalCenter

                        value: chase.value / 100
                    }

                    StyledText {
                        id: figure

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        text: `${Math.round(meter.pct)}%`
                        font.pixelSize: Appearance.font.size.small
                        color: Appearance.colour.textDim
                    }
                }
            }

            FoldedText {
                id: message

                width: parent.width
                visible: !!root.entry?.body

                full: root.entry?.body ?? ""
                brief: root.entry?.brief ?? ""
                unfolded: root.unfolded

                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textDim
                topPadding: Appearance.padding.small

                lines: root.roomy ? 12 : 3
            }

            Flow {
                id: actions

                width: parent.width

                visible: root.live && (root.entry?.hasActions ?? false)
                topPadding: Appearance.padding.normal
                spacing: Appearance.padding.small

                Repeater {

                    model: root.live ? (root.entry?.pressable(root.notification?.actions) ?? []) : []

                    delegate: Button {
                        required property var modelData

                        text: modelData.text
                        width: Math.min(implicitWidth, actions.width)

                        onClicked: {

                            if (root.live)
                                modelData.invoke();
                            root.dismissed();
                        }
                    }
                }
            }
        }
    }

    Icon {
        id: pinMark

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.padding.normal

        name: "push_pin"
        size: Appearance.font.size.small
        fill: 1
        color: Appearance.colour.accent
        opacity: root.pinned ? 1 : Math.min(1, Math.max(0, -root.pulled / root.throwDistance))
        visible: opacity > 0.01
    }

    readonly property real copyCap: Appearance.sizes.notificationBadge * 4

    readonly property string borrowedPicture: root.entry?.copyPath ? root.entry.image : ""

    onBorrowedPictureChanged: root.beginCopy()

    property string claimed: ""

    function beginCopy(): void {
        const e = root.entry;
        if (!e || !e.wantsCopy)
            return;
        root.claimed = e.image;
        e.copying = true;
        copier.source = e.image;
    }

    function finishCopy(): void {
        const e = root.entry;
        const claim = root.claimed;
        const target = e?.copyPathFor(claim) ?? "";
        if (!target)
            return root.releaseCopy();

        const ok = copier.grabToImage(result => {
            if (result.saveToFile(Qt.resolvedUrl(`file://${target}`)))
                e.keep(target);
            else
                console.warn(`Notifications: could not write ${target}; ${e.appName} keeps its picture only until its sender closes it.`);

            if (root.claimed === claim)
                root.releaseCopy();
        });

        if (!ok)
            root.releaseCopy();
    }

    function releaseCopy(): void {
        if (!root.claimed)
            return;
        root.claimed = "";
        copier.source = "";
        if (root.entry)
            root.entry.copying = false;
    }

    Component.onDestruction: {
        root.releaseCopy();
        root.holding?.release(root);
    }

    Image {
        id: copier

        visible: false
        asynchronous: true
        smooth: true

        cache: false

        readonly property real shrink: Math.min(1, root.copyCap / Math.max(1, implicitWidth, implicitHeight))

        width: implicitWidth * shrink
        height: implicitHeight * shrink

        onStatusChanged: {
            if (copier.status === Image.Ready)
                root.finishCopy();
            else if (copier.status === Image.Error)
                root.releaseCopy();
        }
    }

    MouseArea {
        id: drag

        property real anchorX: 0
        property real anchorY: 0
        property real startedAt: 0
        property bool throwing: false

        property real velocity: 0
        property real lastDx: 0

        property real lastEvent: 0

        property bool holding: false

        property bool scrolling: false

        property bool wandered: false

        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        preventStealing: drag.throwing

        cursorShape: drag.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        function begin(): void {
            drag.startedAt = root.dragX;
            drag.throwing = false;
            drag.scrolling = false;
            drag.holding = false;
            drag.wandered = false;
            drag.velocity = 0;
            drag.lastDx = 0;
            drag.lastEvent = Date.now();
        }

        onPressed: mouse => {

            scroll.finish();

            drag.anchorX = root.x + mouse.x;
            drag.anchorY = root.y + mouse.y;
            drag.begin();
        }

        onPositionChanged: mouse => {
            if (!drag.pressed)
                return;

            drag.advance(root.x + mouse.x - drag.anchorX, root.y + mouse.y - drag.anchorY);
        }

        function advance(dx: real, dy: real): void {

            const now = Date.now();
            const dt = Math.max(1, Math.min(100, now - drag.lastEvent));
            drag.lastEvent = now;
            const step = dx - drag.lastDx;
            drag.lastDx = dx;
            drag.velocity += (step / dt - drag.velocity) * 0.4;

            if (!drag.throwing) {
                if (Math.abs(dy) >= Appearance.sizes.dragThreshold)
                    drag.wandered = true;
                if (Math.abs(dy) > Math.abs(dx))
                    return;
                if (Math.abs(dx) < Appearance.sizes.dragThreshold)
                    return;
                drag.throwing = true;
            }

            root.pulled = dx;
            root.dragX = root.resist(drag.startedAt + dx);
        }

        function stream(dx: real, dy: real): void {
            if (!drag.throwing) {
                if (drag.scrolling)
                    return;

                if (Math.abs(dy) > Math.abs(dx) && Math.abs(dy) >= Appearance.sizes.dragThreshold) {
                    drag.scrolling = true;
                    return;
                }
            }

            drag.advance(dx, dy);
        }

        onPressAndHold: {
            if (throwing)
                return;
            holding = true;
            root.pin(true);
        }

        onReleased: {

            if (!drag.throwing) {
                if (!drag.holding && !drag.wandered)
                    root.dismissed();
                return;
            }

            drag.conclude();
        }

        function conclude(): void {
            if (!drag.throwing)
                return;

            if (root.committed && root.pulled > 0) {
                root.flung = 1;
                return root.dismissed();
            }

            if (root.committed)
                root.pin(!root.pinned);

            settle.value = root.dragX;
            settle.target = 0;
            root.pulled = 0;
            drag.throwing = false;
        }

        onCanceled: {
            settle.value = root.dragX;
            settle.target = 0;
            root.pulled = 0;
            drag.throwing = false;
            drag.holding = false;
            drag.wandered = false;
            drag.scrolling = false;
        }

        onWheel: wheel => {

            if (drag.pressed) {
                wheel.accepted = false;
                return;
            }

            if (!scroll.feed(wheel))
                return;

            wheel.accepted = drag.throwing;
        }

        ScrollGesture {
            id: scroll

            onBegan: drag.begin()
            onMoved: (dx, dy) => drag.stream(dx, dy)
            onEnded: drag.conclude()
        }
    }
}
