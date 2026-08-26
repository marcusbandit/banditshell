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

    // A MARK INSTEAD OF, OR IN FRONT OF, THE WORDS.
    //
    // A pill with no text is a ROUND pill, not a wide one with a glyph rattling
    // about in it: the radius is already half the height, so dropping the width
    // to match makes a circle without a second rule being written. That is the
    // shape a control with one mark in it wants, and it is what lets a row of
    // them read as a row of buttons rather than as a sentence.
    //
    // Icon AND text together is the third case and is deliberately allowed: a
    // control whose mark is not self-evident can carry both until it is.
    property string icon: ""

    // Material Symbols treats FILL as a state axis, so a pill that is ON can say
    // so with the same mark rather than a different one. See components/Icon.qml.
    property real iconFill: 0

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

    // How much of the width the mark and the space after it claim, 0 when there
    // is no mark. Its own property because the width below is built from the
    // label's INTRINSIC width rather than from the row's: a caller may cap this
    // pill (NotificationCard does), the label then narrows to fit and elides,
    // and a width measured off the row it lives in would chase itself.
    readonly property real markSpan: root.icon ? root.labelSize + (root.text ? Appearance.padding.small : 0) : 0

    // A MARK ON ITS OWN GETS A CIRCLE, which is the height and not a width of
    // its own: anything else is a number picked to look round.
    implicitWidth: root.text ? label.implicitWidth + root.markSpan + Appearance.padding.normal * 2 : implicitHeight
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

    // MARK THEN WORDS, centred as one thing. A Row rather than two anchored
    // children so the pair has a single width to size the pill from, and so a
    // pill with only one of the two needs no case anywhere.
    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.icon && root.text ? Appearance.padding.small : 0

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: !!root.icon
            name: root.icon
            fill: root.iconFill
            // The mark is set to the LABEL's size rather than to the icon
            // tier's, or a pill with a glyph in it is taller than the pill
            // beside it holding a word.
            size: root.labelSize
            color: label.color
        }

        StyledText {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            visible: !!root.text
            width: visible ? Math.min(implicitWidth, root.width - Appearance.padding.normal * 2 - root.markSpan) : 0

            text: root.text
            font.pixelSize: root.labelSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            // A pill that is narrower than its label has been capped on purpose by
            // whoever laid it out; it must lose characters rather than width.
            elide: Text.ElideRight
        }
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
