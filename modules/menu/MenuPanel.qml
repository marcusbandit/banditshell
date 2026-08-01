import QtQuick
import qs.config
import qs.components

// One menu panel, separating out of the chassis.
//
// It does NOT overlap the sidebar: its left edge sits exactly on the chassis's
// right edge, and the two right-angled joins where they meet are filleted with a
// CornerWedge in the same material. The result is one body with a smooth waist
// rather than a rectangle stuck onto a bar, which is the direction DESIGN.md
// section 2.1 calls metaball.
//
// It opens by GROWING its width from nothing, not by sliding a finished panel
// out from behind the bar. Growing keeps the rounded right edge correct the whole
// way and reads as the shape extruding out of the chassis.
Item {
    id: root

    property string title: ""
    // 0 while closed, 1 while open. Everything geometric derives from this, so
    // the caller only has to animate one number.
    property real reveal: 0

    readonly property real fullWidth: Appearance.sizes.menuWidth
    readonly property real joint: Appearance.sizes.menuJoint

    // The wedges are the width of the joint radius, so they cannot be drawn
    // before the panel is at least that wide. Fading them in over exactly that
    // stretch of the reveal hides the transition.
    readonly property real jointReveal: Math.max(0, Math.min(1, width / Math.max(1, wedgeTop.extent)))

    implicitWidth: fullWidth
    implicitHeight: Appearance.sizes.menuHeight

    width: fullWidth * reveal

    visible: reveal > 0

    // The fillets. Mirrored: the top join curves down into the bar, the bottom
    // join curves up into it.
    CornerWedge {
        id: wedgeTop

        corner: "bl"
        radius: root.joint
        color: Appearance.colour.surface
        opacity: root.jointReveal

        x: 0
        y: -extent
    }

    CornerWedge {
        corner: "tl"
        radius: root.joint
        color: Appearance.colour.surface
        opacity: root.jointReveal

        x: 0
        y: root.height
    }

    G2Rect {
        anchors.fill: parent

        // Square where it meets the bar, rounded where it faces the desktop.
        topLeftRadius: 0
        bottomLeftRadius: 0
        topRightRadius: Appearance.rounding.large
        bottomRightRadius: Appearance.rounding.large

        color: Appearance.colour.surface

        // Content is laid out at full width and clipped by the panel while it
        // grows, so nothing reflows during the animation.
        Item {
            anchors.fill: parent
            clip: true

            // NOT id: content. G2Rect's default property is called `content`, so
            // that id is shadowed inside any G2Rect below and every reference to
            // it silently resolves to the wrong thing.
            Column {
                id: stack

                x: Appearance.padding.large
                y: Appearance.padding.large
                width: root.fullWidth - Appearance.padding.large * 2
                spacing: Appearance.padding.normal

                StyledText {
                    text: root.title.toUpperCase()
                    color: Appearance.colour.textDim
                    font.pixelSize: Appearance.font.size.small
                }

                Separator {
                    width: parent.width
                }

                // PLACEHOLDER. Skeleton rows standing in for whatever this menu
                // will contain, so the shape and motion can be judged before any
                // of it is wired up. The count comes from the space available,
                // not from a number typed here, so it stays right if the panel
                // is resized (~/.claude/rules/math-over-hardcoding.md).
                Column {
                    width: parent.width
                    spacing: Appearance.sizes.menuRowGap

                    Repeater {
                        model: root.rowCount

                        delegate: G2Rect {
                            required property int index

                            // Ragged widths, so it reads as content rather than
                            // as a pattern. Derived from the index, not listed.
                            width: stack.width * (0.55 + 0.45 * Math.abs(Math.sin(index * 1.7)))
                            height: Appearance.sizes.menuRowHeight
                            radius: height / 2
                            color: Appearance.colour.fillStronger
                        }
                    }
                }
            }

            StyledText {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Appearance.padding.large

                text: "not wired up yet"
                color: Appearance.colour.textFaint
                font.pixelSize: Appearance.font.size.small
            }
        }
    }

    readonly property int rowCount: {
        const row = Appearance.sizes.menuRowHeight + Appearance.sizes.menuRowGap;
        // Everything above the rows: padding, title, separator, the gaps between
        // them, and a footer's worth of room at the bottom.
        const used = Appearance.padding.large * 3 + Appearance.font.size.small * 2 + Appearance.padding.normal * 2 + 1;
        return Math.max(1, Math.floor((implicitHeight - used) / row));
    }
}
