pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// One menu panel: its geometry and its contents. NOT its background.
//
// The panel does not draw a shape. It reports its rectangle to the chassis,
// which adds it to the shell's distance field, and the two melt together there.
// That is why this file has no fillets, no corner wedges and no joint geometry:
// there is nothing to join, because the panel and the bar are one field.
//
// It opens by GROWING its width from nothing. Growing is what the field makes
// look right: at small widths the panel sits entirely inside the melt distance,
// so it reads as a bulge swelling out of the body rather than as a rectangle
// appearing beside it.
Item {
    id: root

    property string title: ""
    // 0 while closed, 1 while open. Everything geometric derives from this, so
    // the caller only has to animate one number.
    property real reveal: 0

    readonly property real fullWidth: Appearance.sizes.menuWidth
    readonly property real cornerRadius: Appearance.rounding.large

    implicitWidth: fullWidth
    implicitHeight: Appearance.sizes.menuHeight

    width: fullWidth * reveal
    visible: reveal > 0

    // Contents are laid out at full width and clipped by the panel while it
    // grows, so nothing reflows during the animation.
    Item {
        anchors.fill: parent
        clip: true

        // NOT id: content. G2Rect's default property is called `content`, so that
        // id is shadowed inside any G2Rect below and every reference to it
        // silently resolves to the wrong thing.
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

            // PLACEHOLDER. Skeleton rows standing in for whatever this menu will
            // contain, so the shape and the motion can be judged before any of it
            // is wired up. The count comes from the space available, not from a
            // number typed here, so it stays right if the panel is resized
            // (~/.claude/rules/math-over-hardcoding.md).
            Column {
                width: parent.width
                spacing: Appearance.sizes.menuRowGap

                Repeater {
                    model: root.rowCount

                    delegate: G2Rect {
                        required property int index

                        // Ragged widths, so it reads as content rather than as a
                        // pattern. Derived from the index, not listed.
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

    readonly property int rowCount: {
        const row = Appearance.sizes.menuRowHeight + Appearance.sizes.menuRowGap;
        // Everything above the rows: padding, title, separator, the gaps between
        // them, and a footer's worth of room at the bottom.
        const used = Appearance.padding.large * 3 + Appearance.font.size.small * 2 + Appearance.padding.normal * 2 + 1;
        return Math.max(1, Math.floor((implicitHeight - used) / row));
    }
}
