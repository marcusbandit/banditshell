import QtQuick
import qs.config

// A pressable pill: a label, a target, and a visible answer to being touched.
//
// It exists because the shell had written this out by hand twice (the
// notification tray's "Clear", and every notification action button) and the two
// had already drifted: different heights, different radii, and one of them the
// same fill as the card it sat on, which made it a label that happened to be
// clickable rather than a button.
//
// Both numbers are DERIVED. The height is the label's own line box plus a
// padding tier, and the radius is half of that, so a pill stays a pill at any
// type size instead of at the one size someone measured. WCAG 2.2 SC 2.5.8's
// 24px floor sits underneath as a floor, not as the value.
Item {
    id: root

    property string text: ""
    property real labelSize: Appearance.font.size.small
    property bool interactive: true

    // A pill sits ON something, so its rest fill has to be a step above whatever
    // that is. `fillStrong` reads as a control over the bare surface AND over a
    // card's own `fill`, and the ladder being additive is what makes one value do
    // both: 0.145 over 0.07 lands clear of either alone.
    property color colour: Appearance.colour.fillStrong
    property color hoverColour: Appearance.colour.fillStronger

    readonly property bool hovered: root.interactive && press.containsMouse
    readonly property bool pressed: root.interactive && press.pressed

    signal clicked

    implicitWidth: label.implicitWidth + Appearance.padding.normal * 2
    implicitHeight: Math.max(Appearance.sizes.minTarget, label.implicitHeight + Appearance.padding.small * 2)
    width: implicitWidth
    height: implicitHeight

    // Pressing it MOVES it. A button is the one place someone is certain they did
    // something, so it is the cheapest place in the shell to be wrong about it
    // (DESIGN.md 2.3).
    scale: root.pressed ? 0.96 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Appearance.anim.fast
            easing.type: Easing.OutCubic
        }
    }

    G2Rect {
        anchors.fill: parent
        radius: height / 2
        color: root.hovered ? root.hoverColour : root.colour

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    StyledText {
        id: label

        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.normal
        anchors.rightMargin: Appearance.padding.normal

        text: root.text
        font.pixelSize: root.labelSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        // A pill that is narrower than its label has been capped on purpose by
        // whoever laid it out; it must lose characters rather than width.
        elide: Text.ElideRight
    }

    MouseArea {
        id: press

        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
