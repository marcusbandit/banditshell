import QtQuick
import qs.config
import qs.components

// One system indicator.
//
// It deliberately does not know what it indicates. A service binds `icon`,
// `active`, `alert` and `available`, and connects `activated` to whatever menu
// the thing opens. Until those services exist it renders its placeholder glyph
// and still reacts to the cursor, so wiring one up later is a few bindings
// rather than a rewrite.
Item {
    id: root

    property string icon
    property bool active: false     // the thing is on / connected
    property bool alert: false      // wants attention
    property bool available: true   // this machine has one at all

    signal activated

    readonly property bool hovered: mouse.containsMouse

    implicitWidth: Appearance.sizes.statusSlot
    implicitHeight: Appearance.sizes.statusSlot

    G2Rect {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        // A step above the group's own container fill, or hovering inside the
        // container would not read as anything.
        color: Appearance.colour.fillStrong
        opacity: root.hovered ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    Icon {
        anchors.centerIn: parent
        text: root.icon

        // Label tiers, not colours. Accent is kept for `alert` only, so a colour
        // in this bar always means something is wrong.
        color: !root.available ? Appearance.colour.textFaint : root.alert ? Appearance.colour.accent : root.hovered || root.active ? Appearance.colour.text : Appearance.colour.textDim

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
