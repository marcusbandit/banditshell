pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// The transport, in Niagara's idiom: THE RING IS THE HIERARCHY.
//
// Niagara Launcher's media widget draws skip-back and skip-forward as bare
// glyphs and puts the one control you actually press inside an outlined circle,
// about twice their size. That is the whole design, and it is worth copying
// exactly because of what it does NOT do: no filled button, no raised surface,
// no second colour. Three controls in one light, and the important one is the
// one with a boundary drawn round it.
//
// It suits this shell better than the filled disc that was here before. A solid
// shape on a translucent material is the loudest thing that can be put on it,
// and DESIGN.md's whole argument about depth is that a fill should mean "you are
// here" rather than "this is a button".
//
// Sizes are derived, not chosen: the ring is the glyph plus a padding tier on
// each side, which lands on Niagara's own ratio of about 2.2, and the stroke is
// the pixel font's stem, so the outline is made of the same material as the type
// above it.
Item {
    id: root

    // Every target is the ring's size, drawn or not: a skip button that is only
    // as big as its glyph is a 20px target, and WCAG 2.2 SC 2.5.8 puts the floor
    // at 24. The ring is what you see; the size is what you can hit.
    readonly property real glyph: Appearance.font.iconSize
    readonly property real ring: root.glyph + Appearance.padding.normal * 2

    implicitWidth: row.implicitWidth
    implicitHeight: root.ring

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Appearance.padding.large

        Repeater {
            model: [
                {
                    icon: "skip_previous",
                    action: "previous",
                    enabled: !!Media.active?.canGoPrevious
                },
                {
                    icon: Media.playing ? "pause" : "play_arrow",
                    action: "toggle",
                    enabled: true,
                    primary: true
                },
                {
                    icon: "skip_next",
                    action: "next",
                    enabled: !!Media.active?.canGoNext
                }
            ]

            delegate: Item {
                id: button

                required property var modelData

                width: root.ring
                height: root.ring

                // The answer to the cursor is MOTION, not colour. Same rule the
                // workspace plates keep and the same swell the slider's bead
                // has: a control that only changes shade under the pointer says
                // it noticed, and one that moves says it is ready.
                scale: press.pressed ? 0.94 : press.containsMouse ? 1.12 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutBack
                    }
                }

                // Only the primary is drawn with a boundary. That is the entire
                // difference between the three, and it is enough.
                G2Rect {
                    anchors.fill: parent
                    visible: !!button.modelData.primary
                    radius: width / 2
                    color: "transparent"
                    stroke: Appearance.colour.text
                    strokeWidth: Appearance.font.stem
                }

                Icon {
                    anchors.centerIn: parent
                    size: root.glyph
                    name: button.modelData.icon
                    color: button.modelData.enabled ? Appearance.colour.text : Appearance.colour.textFaint
                }

                MouseArea {
                    id: press

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: button.modelData.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (button.modelData.action === "toggle")
                            Media.toggle();
                        else if (button.modelData.action === "next")
                            Media.next();
                        else
                            Media.previous();
                    }
                }
            }
        }
    }
}
