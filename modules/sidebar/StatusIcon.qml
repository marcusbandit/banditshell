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

    // A DRAWN mark, instead of the glyph, for the indicators the icon font
    // cannot actually say. Signal strength and a charge level are meters, and a
    // font that has to name every state can only approximate one: it ran out of
    // wifi glyphs after four ragged steps and out of charging glyphs after six.
    //
    // Whatever is loaded here is handed the colour the glyph would have taken,
    // through a property it must call `colour`. That is the whole contract: a
    // mark lights up on hover and goes accent on alert without knowing why, and
    // this file still does not know what it is indicating.
    property Component mark: null

    signal activated

    readonly property bool hovered: mouse.containsMouse

    // Label tiers, not colours. Accent is kept for `alert` only, so a colour in
    // this bar always means something is wrong.
    readonly property color markColour: !root.available ? Appearance.colour.textFaint : root.alert ? Appearance.colour.accent : root.hovered || root.active ? Appearance.colour.text : Appearance.colour.textDim

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
        visible: !root.mark
        name: root.icon
        color: root.markColour

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    Loader {
        anchors.centerIn: parent
        active: !!root.mark
        sourceComponent: root.mark

        // Bound after the fact rather than declared: a Component cannot be
        // handed properties at construction, and the mark is written where
        // someone knows what it means, which is not here.
        onLoaded: item.colour = Qt.binding(() => root.markColour)
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    // NO TOOLTIP HERE, deliberately. Hovering one of these opens its menu, and
    // the menu's first line is its name: a label floating over the panel that
    // already says the same word is the clutter tooltips are supposed to cure.
}
