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
//
// Its HEIGHT comes from its contents, so a two-row menu does not look abandoned
// in a panel built for ten.
Item {
    id: root

    property string title: ""
    property Component body: null

    // 0 while closed, 1 while open. Everything geometric derives from this, so
    // the caller only has to animate one number.
    property real reveal: 0

    readonly property real fullWidth: Appearance.sizes.menuWidth
    readonly property real cornerRadius: Appearance.rounding.large

    // How much room there actually is. A configured maximum is a preference;
    // this is a fact, and content clipped by the bottom of the screen is a bug
    // rather than a long menu.
    property real available: Appearance.sizes.menuMaxHeight

    implicitWidth: fullWidth
    implicitHeight: Math.max(Appearance.sizes.menuMinHeight, Math.min(Math.min(Appearance.sizes.menuMaxHeight, available), stack.implicitHeight + Appearance.padding.large * 2))

    width: fullWidth * reveal
    visible: reveal > 0

    // Contents are laid out at full width and clipped by the panel while it
    // grows, so nothing reflows during the animation.
    Item {
        anchors.fill: parent
        clip: true

        // NOT id: content. G2Rect's default property is called `content`, so
        // that id is shadowed inside any G2Rect below and every reference to it
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

            // Loaded per menu, and thrown away when it closes: a menu that is
            // not on screen should not be watching PipeWire.
            Loader {
                width: parent.width
                active: root.reveal > 0
                sourceComponent: root.body

                onLoaded: item.width = Qt.binding(() => stack.width)
            }
        }
    }
}
