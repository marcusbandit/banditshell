pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// The settings page itself: everything you can see of it, and nothing about
// where it is being drawn.
//
// A PLAIN Item, the way LockFace is, and for the same reason. The page is drawn
// twice in this shell - once by the shell's own surface and once by a real
// window - and the only way two surfaces can be trusted to be showing the same
// thing is for it to literally be the same component. Anything that leaked into
// here about which surface it was on would be the first thing to drift.
//
// It also means the page can be dropped into an ordinary window and
// screenshotted, which is how anything in here gets checked.
//
// A DISCRETE CARD, not a blob in the chassis field. The page is a peer of the
// windows it sits among rather than something emerging from the band, and melt
// belongs where one thing comes out of another (DESIGN.md section 14). The
// field's eight slots are also spoken for.
Item {
    id: root

    // WHICH SIDE OF THE HANDOVER THIS COPY IS ON.
    //
    // What the button offers differs, because the button is the handover. So does
    // the boundary of the page, and only the boundary: everything inside it is the
    // same drawing at the same size in both places.
    //
    // A card floating on the shell's blurred band owns its own edge, so it draws
    // its own corners and lets the band show through. A WINDOW does not own its
    // edge - the compositor draws a border, a corner and a shadow around every
    // other window on the desktop, and a page that brought its own would be
    // wearing two. So in a window the page stops at the frame it was given, and
    // fills it: opaque, square, right out to the corners the compositor is about
    // to cut. It is a window, and it should look like the others.
    property bool windowed: false

    signal handover

    readonly property real pad: Appearance.padding.large

    G2Rect {
        anchors.fill: parent

        radius: root.windowed ? 0 : Appearance.rounding.large
        color: root.windowed ? Appearance.colour.surfaceSolid : Appearance.colour.surface

        // The title sits in the card's own top-left rather than being centred,
        // because a page is read from its corner and a dialog is read from its
        // middle, and this is a page.
        StyledText {
            id: title

            x: root.pad
            y: root.pad

            text: "Settings"
            font.pixelSize: Appearance.font.size.large
            color: Appearance.colour.text
        }

        StyledText {
            anchors.left: title.left
            anchors.top: title.bottom
            anchors.topMargin: Appearance.padding.small

            text: root.windowed ? "a window, for now" : "drawn by the shell"
            color: Appearance.colour.textFaint
        }

        // THE BUTTON, at the bottom of the card rather than beside the title.
        //
        // It is not a title-bar control. What it does is change what kind of
        // thing the page is, which is a decision about the page, so it sits at
        // the end of it where the decisions go.
        G2Rect {
            id: button

            readonly property bool hovered: press.containsMouse

            x: root.pad
            y: parent.height - height - root.pad
            width: label.x + label.width + Appearance.padding.normal
            height: Math.round(Appearance.font.size.small * 4 / 3) + Appearance.padding.normal * 2
            radius: Appearance.rounding.normal

            color: button.hovered ? Appearance.colour.fillStrong : Appearance.colour.fill

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }

            Icon {
                id: mark

                x: Appearance.padding.normal
                anchors.verticalCenter: parent.verticalCenter

                // Out of the shell and into the desktop, or back in again. Two
                // directions of one gesture, so two arrows of one drawing.
                name: root.windowed ? "close_fullscreen" : "open_in_new"
                size: Appearance.font.iconSize
                color: button.hovered ? Appearance.colour.text : Appearance.colour.textDim
            }

            StyledText {
                id: label

                x: mark.x + mark.width + Appearance.padding.small
                anchors.verticalCenter: parent.verticalCenter

                text: root.windowed ? "Put it back" : "Pull it out"
                color: button.hovered ? Appearance.colour.text : Appearance.colour.textDim
            }

            MouseArea {
                id: press

                anchors.fill: parent
                hoverEnabled: true

                onClicked: root.handover()
            }
        }

        // WHICH CORNER THE PAGE GOES BACK INTO, said as a mark rather than as a
        // control.
        //
        // The page is closed by pushing it down and right into the corner it
        // grew out of (SettingsPanel's Pull), and a gesture nobody can discover
        // is no better than the keyboard shortcut nobody can press. So something
        // on the page has to point at it. NOT a close button: that is the small
        // permanent control this shell is built without, and it would also be a
        // lie about the mechanism, since what closes the page is a direction
        // rather than a target. NOT a titlebar either, for the reason the
        // handover button is at the bottom of the card and not beside the title.
        //
        // A CORNER GRIP is the one mark that says a diagonal. Ribs laid across
        // the push's own direction, thickening as the corner opens out, which is
        // the oldest "this corner is draggable" drawing there is and the only
        // one that carries an axis rather than just a spot. A horizontal handle
        // would say "drag me down"; a dot would say nothing.
        //
        // ONLY WHILE THE SHELL DRAWS IT. In a window the page cannot be pushed
        // anywhere, and a grip in the bottom-right of a floating window is a
        // resize handle that does not resize. This is the second thing the
        // boundary flag decides, and like the first it is about the page's edge
        // rather than about anything inside it.
        //
        // It takes no clicks of its own and must not: the Pull behind the page
        // already answers a press anywhere on the empty surface, so a MouseArea
        // here would be a smaller target sitting in the middle of a bigger one
        // that already works. It is drawn at the quietest weight any text on
        // this page uses, because it is an affordance and not the thing the page
        // is about.
        Item {
            id: grip

            // SIZED FROM THE RIBS, never the ribs from the size. The mark exists
            // to be a legible stack of lines, so the spacing between them is the
            // shell's smallest tier and the box is however big that many of them
            // at that pitch turn out to be, floored at the minimum target so the
            // whole thing is never smaller than something you could aim at.
            // Change `ribs` and the grip grows; nothing else needs touching.
            readonly property int ribs: 3
            readonly property real pitch: Appearance.padding.small
            readonly property real span: Math.max(Appearance.sizes.minTarget, grip.pitch * Math.SQRT2 * (grip.ribs + 1))

            x: parent.width - grip.span - root.pad
            y: parent.height - grip.span - root.pad
            width: grip.span
            height: grip.span

            visible: !root.windowed

            Repeater {
                model: grip.ribs

                G2Rect {
                    id: rib

                    required property int index

                    // HOW FAR THIS RIB IS FROM THE CORNER, measured along the
                    // push's own diagonal, and everything else about it follows
                    // from that one number (~/.claude/rules/math-over-hardcoding.md).
                    // The ribs divide the box's diagonal evenly, so the first and
                    // the last get the same air as the gaps between them rather
                    // than one of them landing on the corner itself.
                    readonly property real reach: (rib.index + 1) / (grip.ribs + 1) * grip.span / Math.SQRT2

                    // A chord across a square corner at perpendicular distance d
                    // is exactly 2d long, so the ribs widen as the corner opens
                    // out and the outermost one is the box's own diagonal. That
                    // is the whole shape of the mark, and it is arithmetic rather
                    // than three lengths chosen by eye.
                    width: rib.reach * 2
                    height: Appearance.font.stem
                    radius: rib.height / 2

                    // Centred on the foot of that perpendicular, then turned
                    // ACROSS the push rather than along it: a rib parallel to the
                    // gesture would read as a track to slide in, and this is a
                    // grip to shove. Negative because Qt's rotation is clockwise
                    // and the ribs run up and to the right.
                    x: grip.span - rib.reach / Math.SQRT2 - rib.width / 2
                    y: grip.span - rib.reach / Math.SQRT2 - rib.height / 2
                    rotation: -45

                    // The subtitle's weight, not the title's, and not the
                    // watermark tier below it: this is live and worth finding,
                    // and it is not what the page is for.
                    color: Appearance.colour.textFaint
                }
            }
        }
    }
}
