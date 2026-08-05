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
// in a panel built for ten, and it TRAVELS to a new height rather than cutting
// to it: an open panel handed different content is one object changing shape,
// not a second panel taking the first one's place. That applies to a menu
// swapped for another and to a menu that grows under its own feet, which is the
// same event as far as the panel is concerned.
//
// The contents CROSS-FADE while it moves, which is why there are two page slots
// rather than one Loader. With one slot there is no way to keep showing the old
// menu for even a frame after the new one exists, so however smoothly the box
// travels, the thing inside it still cuts.
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

    // Which slot holds the menu on its way IN. The other holds whatever it
    // replaced, for as long as the fade still needs it.
    property int slot: 0

    // How tall the page in that slot wants to be, PUSHED by the page rather
    // than read back out of the Repeater: `itemAt` is a function call, so a
    // binding through it never re-evaluates when the page inside grows.
    property real pageHeight: 0

    // Armed when content arrives while the panel is shut. There is no previous
    // size to travel from then, so the first size an open takes, it takes at
    // once, and only the reveal animates.
    property bool unsized: false

    // implicitHeight is where the panel is GOING, height is where it IS.
    // Whoever places the panel wants the first (a menu is clamped against the
    // screen by the size it will settle at, never by a size it is passing
    // through); whoever draws or melts it wants the second.
    implicitWidth: fullWidth
    implicitHeight: Math.max(Appearance.sizes.menuMinHeight, Math.min(Math.min(Appearance.sizes.menuMaxHeight, available), pageHeight + Appearance.padding.large * 2))

    width: fullWidth * reveal
    height: grow.value
    visible: reveal > 0

    // Assigned, not grow.snap(): snap() reads the target, and the target is a
    // binding on the very property this handler is reacting to. Whether that
    // binding has re-evaluated yet is exactly the kind of ordering question
    // that works on one machine and not the next.
    onImplicitHeightChanged: if (root.unsized) {
        root.unsized = false;
        grow.value = root.implicitHeight;
    }

    // The reveal landing means the open is over, so a size that never arrived
    // (a menu whose height happens to equal the last one's) cannot leave the
    // flag armed to eat the next real resize.
    onRevealChanged: if (root.reveal === 1)
        root.unsized = false

    onBodyChanged: root.swap()

    // Move the incoming menu into the free slot and start the cross-fade.
    //
    // The page takes a COPY of the title and the body rather than binding to
    // them. Binding would mean both slots showing the new menu the instant it
    // is set, which is the cut this exists to avoid: the outgoing page has to
    // keep being what it was while it fades.
    function swap(): void {
        const next = 1 - root.slot;
        const page = pages.itemAt(next);
        if (page) {
            page.pageTitle = root.title;
            // CLEARED FIRST, so what arrives is always a NEW instance.
            //
            // Two menus are allowed to share one Component: every tray item
            // does, because they are the same menu about different applications
            // and the difference is a value the page reads on the way up. A
            // Loader handed the component it is already holding does not rebuild,
            // so crossing three tray icons faster than the fade settles left the
            // third one showing the first one's rows. Unloading is what makes the
            // page get built again, and being built again is when it reads which
            // application it is now about.
            page.pageBody = null;
            page.pageBody = root.body;
        }

        // Nothing to cross with while the panel is shut: the new page arrives
        // whole, at the size it asks for, and the reveal does the animating.
        const closed = root.reveal === 0;
        fade.value = closed ? 1 : 0;
        fade.target = 1;
        root.unsized = closed;
        root.slot = next;
    }

    Follow {
        id: grow

        target: root.implicitHeight
        speed: Appearance.anim.resizeSpeed
    }

    Follow {
        id: fade

        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    // Contents are laid out at full width and clipped by the panel while it
    // grows, so nothing reflows during the animation.
    Item {
        anchors.fill: parent
        clip: true

        Repeater {
            id: pages

            model: 2

            // NOT id: content. G2Rect's default property is called `content`, so
            // that id is shadowed inside any G2Rect below and every reference to
            // it silently resolves to the wrong thing.
            delegate: Column {
                id: page

                required property int index

                property string pageTitle: ""
                property Component pageBody: null

                readonly property bool current: index === root.slot

                x: Appearance.padding.large
                y: Appearance.padding.large
                width: root.fullWidth - Appearance.padding.large * 2
                spacing: Appearance.padding.normal

                // The outgoing page leaves faster than the incoming one arrives,
                // squared against the same clock. A straight cross-dissolve has
                // both at half opacity in the middle, which over two pages of
                // text is the moment it reads as neither; this way the old menu
                // is mostly gone by the time the new one is legible, and the ink
                // never doubles up.
                opacity: current ? fade.value : (1 - fade.value) * (1 - fade.value)
                // The arriving page is always the one on top, so the crossing
                // never depends on which slot happens to be first.
                z: current ? 1 : 0

                // The panel grows toward the INCOMING page, so a slot only
                // speaks while it is the current one. Both edges matter: the
                // second is the swap itself, the first is a menu resizing
                // later, under its own content.
                onImplicitHeightChanged: if (current)
                    root.pageHeight = implicitHeight
                onCurrentChanged: if (current)
                    root.pageHeight = implicitHeight

                StyledText {
                    text: page.pageTitle.toUpperCase()
                    color: Appearance.colour.textDim
                    font.pixelSize: Appearance.font.size.small
                }

                Separator {
                    width: page.width
                }

                // Loaded per menu, and thrown away when it closes: a menu that is
                // not on screen should not be watching PipeWire. The outgoing
                // page goes the moment the fade is done with it, for the same
                // reason.
                Loader {
                    width: page.width
                    active: root.reveal > 0 && (page.current || !fade.settled)
                    sourceComponent: page.pageBody

                    onLoaded: item.width = Qt.binding(() => page.width)
                }
            }
        }
    }
}
