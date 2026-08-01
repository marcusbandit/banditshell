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

    // A plate that rises out of the panel under the cursor: lit from above, with
    // a hairline where its edge catches the light.
    G2Rect {
        anchors.fill: parent
        radius: Appearance.rounding.small

        color: Appearance.colour.surfaceTop
        colorBottom: Appearance.colour.surface
        borderColor: Appearance.colour.bevel
        borderWidth: Appearance.depth.bevelWidth

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

        color: !root.available ? Appearance.colour.textFaint : root.alert ? Appearance.colour.accentDim : root.hovered ? Appearance.colour.accent : root.active ? Appearance.colour.text : Appearance.colour.textDim

        scale: root.hovered ? 1.12 : 1

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutBack
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
