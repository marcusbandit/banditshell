pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import Quickshell.Services.Notifications

// One notification, on screen.
//
// Like a menu panel it draws no background: it reports its rectangle and the
// chassis melts it in. It grows its WIDTH out of the right band for the same
// reason a menu does, so it reads as the shell swelling rather than as a card
// dropped on the desktop.
Item {
    id: root

    required property var entry
    required property real fullWidth

    signal dismissed

    readonly property var notification: entry?.notification ?? null
    readonly property bool urgent: !!notification && notification.urgency === NotificationUrgency.Critical

    property real reveal: 0

    // DRAG BEFORE CLICK.
    //
    // Throwing a notification off the edge is the primary way to be rid of it:
    // it is one continuous gesture, it works identically with a finger, a
    // touchpad or a mouse, and it is reversible right up until you let go, which
    // a click never is. Clicking still dismisses, because a mouse user who
    // expects it should not be told they are holding it wrong, but the drag is
    // the designed path and the click is the fallback.
    //
    // It throws RIGHT because this band is the right edge: the card leaves the
    // way it came in. Dragging back cancels.
    property real dragX: 0
    // How far you have actually moved. `dragX` is where the card is, which is
    // not the same thing while it is resisting.
    property real pulled: 0

    readonly property real throwDistance: fullWidth * Appearance.sizes.dragDismissFraction
    readonly property bool committed: Math.abs(pulled) >= throwDistance
    readonly property bool throwing: drag.throwing

    // Resistance before the commit point, 1:1 after it.
    //
    // The card gives back only half of the first fifth of the throw, so it feels
    // like it is holding on; past the commit point the slope changes and it
    // tracks the pointer exactly. That change is the signal that letting go will
    // now dismiss, and it is felt rather than read.
    function resist(delta: real): real {
        const commit = root.throwDistance;
        const k = Appearance.sizes.dragResistance;
        const m = Math.abs(delta);
        const held = m < commit ? m * k : commit * k + (m - commit);
        return delta < 0 ? -held : held;
    }

    width: fullWidth * reveal
    height: body.implicitHeight + Appearance.padding.large * 2

    // The whole card moves with the finger, and fades as it goes so the gesture
    // says what it will do before it is finished.
    x: base + dragX
    // Only starts fading once it is going. Before the commit point it stays
    // solid, because it is not leaving.
    opacity: Math.max(0.15, 1 - Math.max(0, Math.abs(dragX) - throwDistance * Appearance.sizes.dragResistance) / (fullWidth * 0.6))

    // Where the card sits when it is not being thrown. Set by the layout.
    property real base: 0

    Component.onCompleted: grow.target = 1

    Follow {
        id: grow

        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
        onValueChanged: root.reveal = value
    }

    // Springs home when a throw is abandoned. Not a fixed animation: the drag
    // can be released at any offset and any speed, and exponential smoothing is
    // correct from wherever it starts.
    Follow {
        id: settle

        speed: Appearance.anim.revealSpeed
        target: 0
        onValueChanged: if (!root.throwing)
            root.dragX = value
    }

    // Declared BEFORE the contents: a catch-all that comes last covers the
    // action buttons inside, and every one of them dismissed the notification
    // instead of doing what it said.
    MouseArea {
        id: drag

        // NO drag.target. `x` is bound to `base + dragX`, and Qt's built-in drag
        // assigns x imperatively, which destroys that binding and then fights
        // whatever re-establishes it: the card simply did not move. Tracking the
        // pointer and driving dragX keeps one owner for the position.
        //
        // The anchor is kept in the PARENT's coordinates, because `mouse.x` is
        // relative to this item and this item is what is moving: as the card
        // slides right by d, mouse.x falls by d for the same physical pointer.
        // `root.x + mouse.x` is invariant, which is the only thing safe to
        // measure against.
        property real anchor: 0
        property real startedAt: 0
        property bool throwing: false

        anchors.fill: parent
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
            // Judged on how far you PULLED, not on where the card ended up: the
            // card is deliberately behind your finger until the commit point.
            if (throwing && root.committed)
                return root.dismissed();
            if (!throwing)
                return root.dismissed();
            root.pulled = 0;
            // Abandoned mid-throw: hand the offset to the spring and let it walk
            // home rather than snapping.
            settle.value = root.dragX;
            settle.target = 0;
            throwing = false;
        }
    }

    // Contents at full width, clipped by the growing panel, so nothing reflows
    // while it arrives.
    Item {
        anchors.fill: parent
        clip: true

        Item {
            id: body

            x: Appearance.padding.large
            y: Appearance.padding.large
            width: root.fullWidth - Appearance.padding.large * 2
            implicitHeight: Math.max(glyph.implicitHeight, text.implicitHeight)

            Icon {
                id: glyph

                anchors.left: parent.left
                anchors.top: parent.top
                name: Notifs.icon(root.notification)
                color: root.urgent ? Appearance.colour.accent : Appearance.colour.textDim
            }

            Column {
                id: text

                anchors.left: glyph.right
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
                    // Long bodies are common and a notification is not a document.
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }

                // Whatever the sender offered. Rendered only when there is
                // something to render, so most notifications stay one block.
                Row {
                    visible: (root.notification?.actions?.length ?? 0) > 0
                    topPadding: Appearance.padding.small
                    spacing: Appearance.padding.small

                    Repeater {
                        model: root.notification?.actions ?? []

                        delegate: G2Rect {
                            required property var modelData

                            implicitWidth: actionLabel.implicitWidth + Appearance.padding.normal * 2
                            implicitHeight: actionLabel.implicitHeight + Appearance.padding.small * 2
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
    }

}
