pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import Quickshell.Services.Notifications

// One notification, on screen.
//
// A DISCRETE CARD that melts into the shell but never into its neighbours.
//
// It has no background of its own: it reports its rectangle and the chassis
// field draws it, so it joins the band it arrived from. What it does NOT do is
// join the card above and below it. Chaining every panel into one running field
// melted the panels into each other too, and three peers within melt distance
// fused into a single lumpy mass with pinches where the boundaries should have
// been. blob.frag blends each panel with the chassis ALONE and unions the
// results plainly, which is the distinction: melt where one thing emerges from
// another, never between siblings.
Item {
    id: root

    required property var entry
    required property real fullWidth

    signal dismissed

    readonly property var notification: entry?.notification ?? null
    readonly property bool urgent: !!notification && notification.urgency === NotificationUrgency.Critical

    // Arrival: slides in from the edge it belongs to, and fades up.
    property real reveal: 0

    // Where the card is, and how far you actually pulled. They differ while it
    // is resisting.
    property real dragX: 0
    property real pulled: 0

    readonly property real throwDistance: fullWidth * Appearance.sizes.dragDismissFraction
    readonly property bool committed: Math.abs(pulled) >= throwDistance

    // The countdown belongs to the ENTRY, not to this card. A Repeater over a
    // plain array rebuilds every delegate when the array changes, so state kept
    // here was reset by a neighbour being dismissed and nothing ever expired
    // after the first one.
    readonly property int timeout: entry?.timeout ?? 0
    readonly property real remaining: entry?.remaining ?? 0

    // PAUSED while the cursor is on it. A notification that expires from under
    // the pointer while you are reaching for its button is the single most
    // annoying thing a shell can do. Pushed to the entry so it survives a rebuild.
    readonly property bool held: drag.containsMouse || drag.pressed
    onHeldChanged: if (entry)
        entry.held = held

    width: fullWidth
    implicitHeight: body.implicitHeight + Appearance.padding.large * 2
    height: implicitHeight

    // One expression owns x: the arrival slide plus the throw.
    x: fullWidth * (1 - reveal) + dragX
    opacity: reveal * Math.max(0.1, 1 - Math.max(0, Math.abs(dragX) - throwDistance * Appearance.sizes.dragResistance) / (fullWidth * 0.6))

    Component.onCompleted: grow.target = 1

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

    // Resistance before the commit point, 1:1 after it. The card gives back only
    // half of the first fifth of the throw, so it feels like it is holding on;
    // past the commit point the slope changes and it tracks the pointer exactly.
    function resist(delta: real): real {
        const commit = root.throwDistance;
        const k = Appearance.sizes.dragResistance;
        const m = Math.abs(delta);
        const held = m < commit ? m * k : commit * k + (m - commit);
        return delta < 0 ? -held : held;
    }

    // NO BACKGROUND. The card reports its rectangle and the chassis field draws
    // it, so it melts into the band it arrived from. Drawing one here as well
    // would put the same translucent material over itself and the card would
    // come out heavier than the shell it belongs to.
    //
    // It still does not melt into its NEIGHBOURS: the field blends each panel
    // with the chassis alone and unions the results plainly. See blob.frag.

    // A critical notification is marked by a bar down its leading edge, not by a
    // differently coloured card. Colour alone is not a state cue, and a whole
    // card tinted red is a fire alarm for something that is merely important.
    G2Rect {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Appearance.padding.normal
        width: Math.max(2, Appearance.padding.small / 2)
        radius: width / 2
        color: Appearance.colour.accent
        visible: root.urgent
    }

    // How long it has left, along the bottom edge. Without it, a notification
    // vanishing mid-read reads as a glitch rather than as a timer.
    G2Rect {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Appearance.padding.normal
        width: Math.max(0, (parent.width - Appearance.padding.normal * 2) * root.remaining)
        height: 2
        radius: 1
        color: root.held ? Appearance.colour.accent : Appearance.colour.fillStronger
        visible: root.timeout > 0
    }

    Item {
        id: body

        x: Appearance.padding.large
        y: Appearance.padding.large
        width: root.fullWidth - Appearance.padding.large * 2
        implicitHeight: Math.max(badge.height, text.implicitHeight)

        // The sender's own icon when it gave one, and our bell when it did not.
        // An app that bothered to identify itself should be recognised by its
        // icon rather than by reading its name.
        G2Rect {
            id: badge

            width: Appearance.sizes.notificationBadge
            height: width
            radius: Appearance.rounding.small
            color: Appearance.colour.fill

            Image {
                anchors.fill: parent
                anchors.margins: 2
                source: root.notification?.image || root.notification?.appIcon || ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                visible: status === Image.Ready
                sourceSize.width: width
                sourceSize.height: height
            }

            Icon {
                anchors.centerIn: parent
                visible: !root.notification?.image && !root.notification?.appIcon
                name: root.urgent ? "priority_high" : "notifications"
                color: root.urgent ? Appearance.colour.accent : Appearance.colour.textDim
            }
        }

        Column {
            id: text

            anchors.left: badge.right
            anchors.leftMargin: Appearance.padding.normal
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 0

            StyledText {
                width: parent.width
                visible: !!root.notification?.appName
                text: root.notification?.appName ?? ""
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textFaint
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                text: root.notification?.summary ?? ""
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                visible: !!root.notification?.body
                text: root.notification?.body ?? ""
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textDim
                wrapMode: Text.Wrap
                // A notification is not a document.
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            Row {
                visible: (root.notification?.actions?.length ?? 0) > 0
                topPadding: Appearance.padding.normal
                spacing: Appearance.padding.small

                Repeater {
                    model: root.notification?.actions ?? []

                    delegate: G2Rect {
                        required property var modelData

                        implicitWidth: actionLabel.implicitWidth + Appearance.padding.normal * 2
                        implicitHeight: Math.max(Appearance.sizes.minTarget, actionLabel.implicitHeight + Appearance.padding.small * 2)
                        width: implicitWidth
                        height: implicitHeight
                        radius: Appearance.rounding.small
                        color: actionPress.containsMouse ? Appearance.colour.fillStrong : Appearance.colour.fill

                        StyledText {
                            id: actionLabel

                            anchors.centerIn: parent
                            text: modelData.text
                            font.pixelSize: Appearance.font.size.small
                        }

                        MouseArea {
                            id: actionPress

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                modelData.invoke();
                                root.dismissed();
                            }
                        }
                    }
                }
            }
        }
    }

    // Behind the contents, so it cannot eat the action buttons' clicks, but
    // still covering the whole card so the throw can start anywhere on it.
    MouseArea {
        id: drag

        // The anchor is kept in the PARENT's coordinates. `mouse.x` is relative
        // to this item and this item is what moves, so as the card slides right
        // by d, mouse.x falls by d for the same physical pointer; the invariant
        // is `root.x + mouse.x`.
        property real anchor: 0
        property real startedAt: 0
        property bool throwing: false

        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        preventStealing: true

        onPressed: mouse => {
            anchor = root.x + mouse.x;
            startedAt = root.dragX;
            throwing = false;
        }

        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const delta = root.x + mouse.x - anchor;
            if (!throwing && Math.abs(delta) < Appearance.sizes.dragThreshold)
                return;
            throwing = true;
            root.pulled = delta;
            root.dragX = root.resist(startedAt + delta);
        }

        onReleased: {
            if (!throwing || root.committed)
                return root.dismissed();
            // Abandoned short of the commit point: hand the offset to the spring
            // and let it walk home rather than snapping.
            settle.value = root.dragX;
            settle.target = 0;
            root.pulled = 0;
            throwing = false;
        }
    }
}
