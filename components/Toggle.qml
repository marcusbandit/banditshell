import QtQuick
import qs.config

// A switch.
//
// Like Slider, it does not own its state: `checked` is bound to the thing it
// controls and `toggled` asks for a change. A switch that flips itself and then
// finds out the change failed is worse than one that waits.
Item {
    id: root

    property bool checked: false

    signal toggled

    implicitWidth: Appearance.sizes.toggleWidth
    implicitHeight: Appearance.sizes.toggleHeight

    G2Rect {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Appearance.colour.accent : Appearance.colour.fillStrong

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    // An explicit inset, not a derived one. `y` from `height`, `height` from
    // `width` and `width` from `y` is a binding cycle: Qt reports a loop and
    // picks an order, which is not a thing to leave to chance.
    G2Rect {
        readonly property real inset: Math.max(2, Math.round(root.height / 9))

        y: inset
        x: root.checked ? parent.width - width - inset : inset
        width: root.height - inset * 2
        height: width
        radius: height / 2
        color: root.checked ? Appearance.colour.accentText : Appearance.colour.text

        Behavior on x {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutBack
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -Appearance.padding.small
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
