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
//
// A menu WANTING more height than the clamp allows SCROLLS inside it rather
// than being cut: the panel keeps exactly the size the clamp gives it and the
// body becomes a viewport onto the rest. The panel's own sizing must therefore
// keep reading the body's IMPLICIT height, never the viewport's actual one;
// see the page delegate for how that chain is kept honest.
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
            //
            // An ITEM now, no longer a Column, and the change is load-bearing. A
            // positioner reports the sum of its children's ACTUAL heights, and
            // the body below now lives in a viewport the panel clamps; a Column
            // would therefore have reported the clamped height as the wanted
            // height, the panel is sized FROM the wanted height, and the panel
            // would never again have asked to grow past wherever it already
            // was. The three children are placed by hand instead, so the wanted
            // size can keep coming from the body's own implicit height while
            // the viewport is free to be smaller than it.
            delegate: Item {
                id: page

                required property int index

                property string pageTitle: ""
                property Component pageBody: null

                readonly property bool current: index === root.slot

                x: Appearance.padding.large
                y: Appearance.padding.large
                width: root.fullWidth - Appearance.padding.large * 2

                // The height this page WANTS: the chrome plus the body's own
                // height, which is exactly the figure the Column used to add
                // up. Read from the flickable's CONTENT and never from the
                // flickable itself: the viewport is clamped by the panel and
                // the panel is clamped from this number, so a wanted size that
                // read the viewport back would be a circle that agrees with
                // whatever it last said, and no menu could ever grow.
                implicitHeight: view.y + view.contentHeight

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

                // A swap hands this slot a NEW menu, so the scroll goes home
                // first. The slots are permanent and only the Loader's cargo
                // changes, so the flickable outlives its contents, and without
                // this the position would outlive them too: a fresh menu
                // opening already halfway down its own list reads as broken,
                // because nobody scrolled it there. It fires twice per swap
                // (the body is cleared before it is set) and both writes say
                // the same harmless thing. The OUTGOING page keeps its scroll
                // while it fades, which is right: that position is what you
                // were looking at, and it resets when its own turn comes.
                onPageBodyChanged: view.contentY = 0

                StyledText {
                    id: heading

                    text: page.pageTitle.toUpperCase()
                    color: Appearance.colour.textDim
                    font.pixelSize: Appearance.font.size.small
                }

                Separator {
                    id: rule

                    y: heading.height + Appearance.padding.normal
                    width: page.width
                }

                // The body, in a VIEWPORT. A menu taller than the clamp used
                // to be cut at the bottom with no way to reach the rest by
                // wheel or by finger (the Sound menu with a dozen streams was
                // the case); now the panel stays exactly the size the clamp
                // computes and the overflow scrolls instead. The title and the
                // rule stay pinned above it rather than scrolling away with
                // the body: which menu you are in is not part of the document,
                // and the chrome is one line tall, so pinning it costs the
                // viewport almost nothing.
                Flickable {
                    id: view

                    // Half a pixel of slack for the two overflow tests below
                    // (interactive and clip), because both sides of those
                    // compares are the SAME length pushed through different
                    // arithmetic. The page's wanted height adds view.y to the
                    // content height, two fractional text-metric sums whose
                    // addition rounds to the nearest double; the panel then
                    // settles EXACTLY on the figure built from that, because
                    // Follow lands by assignment rather than by decay; and the
                    // viewport height subtracts the chrome back out, rounding
                    // once more. Algebra says the viewport equals the content
                    // whenever a menu fits, but the doubles land an ulp to
                    // either side of equal, with the sign a coin flip per menu.
                    // Landing LOW is the poisonous side: a fitting menu gets
                    // clip plus an interactive flickable owning a scroll range
                    // of a few ulps, and that phantom document swallows exactly
                    // the presses on the gaps between rows that the comment on
                    // `interactive` promises will fall through to the push-back
                    // Pull. An exact compare was rejected for that reason, and
                    // rounding both sides to whole pixels was rejected too: it
                    // only moves the same knife edge from the ulp to the
                    // half-pixel boundary that fractional text metrics sit on
                    // all day. Slack is the honest version, because content
                    // that overhangs by under half a pixel has nowhere to
                    // scroll TO, so nothing real is being declined. The
                    // notification tray states its compare exactly and is
                    // merely less exposed, not immune: its round trip adds one
                    // integer, which is exact until the sum crosses a binade.
                    readonly property real overflowSlack: 0.5

                    y: rule.y + rule.height + Appearance.padding.normal
                    width: page.width

                    // The viewport is whatever of the panel's LIVE height is
                    // left under the chrome. Live rather than settled, so the
                    // window onto the body grows with the panel's travel
                    // instead of popping to the destination size ahead of it.
                    height: Math.max(0, root.height - Appearance.padding.large * 2 - y)

                    // The body's natural height, through the Loader: no menu
                    // body sets an explicit height, so the loaded item sits at
                    // its implicit size and the Loader wraps it. This is the
                    // number the page's wanted size reads back out, which is
                    // what keeps the panel sized by the content rather than by
                    // the viewport.
                    contentHeight: bodyLoader.height

                    // Scrolls only when it has to, the notification tray's
                    // rule: a menu that fits is a panel, and a
                    // panel that always scrolled would be a document. While it
                    // fits this is inert, so a press on the gaps between rows
                    // still falls through to the push-back Pull behind the
                    // panel; once it overflows, a drag on the list is a scroll
                    // and the push is made from the padding ring around the
                    // body instead, which is the tray's arrangement exactly.
                    //
                    // AND ONLY WHILE CURRENT. An opacity of nought is not
                    // invisibility to input, so the outgoing page's flickable,
                    // still loaded until the fade lets go of it, would
                    // otherwise sit under the incoming one silently swallowing
                    // the presses that were meant to fall through to the Pull:
                    // an invisible document is not a thing anyone is trying to
                    // scroll, so it takes nothing.
                    interactive: page.current && contentHeight > height + overflowSlack
                    // Clip costs a batch and a fitting menu is the common
                    // case, so it is only paid for while the overflow exists.
                    // On OVERFLOW, not on interactive, and the difference is
                    // the outgoing page: it keeps its scroll position while it
                    // fades (that position is what you were looking at), and
                    // tying clip to the interactivity it just lost would
                    // unclip it mid-fade and slide its scrolled-away rows up
                    // over the title. The wrapper above already clips at the
                    // panel's edge, so nothing bleeds out of the panel either
                    // way; this clip is for scrolled content inside it.
                    clip: contentHeight > height + overflowSlack
                    // No rubber band. The overshoot is what makes a thrown
                    // list feel physical, and pure noise on a menu: the end of
                    // the streams is an answer, not a wall to bounce off.
                    boundsBehavior: Flickable.StopAtBounds

                    // Put the content back inside its own bounds when either
                    // side of the inequality moves under it, which Flickable
                    // does not do by itself: it fixes up after its OWN
                    // movements and shrugs at everybody else's. A menu resizes
                    // under its own feet constantly (a stream ends, a device
                    // leaves), and scrolled to the bottom that strands the
                    // viewport past the end of a list that no longer reaches
                    // it. Same lesson GlideList's settle() records, at a tenth
                    // of the machinery because there is no glide target to
                    // keep honest here. Never while a finger holds the
                    // content: the drag owns the position for as long as it
                    // lasts, and the release runs Flickable's own fixup
                    // anyway.
                    onContentHeightChanged: if (!dragging)
                        returnToBounds()
                    onHeightChanged: if (!dragging)
                        returnToBounds()

                    // Loaded per menu, and thrown away when it closes: a menu
                    // that is not on screen should not be watching PipeWire.
                    // The outgoing page goes the moment the fade is done with
                    // it, for the same reason.
                    Loader {
                        id: bodyLoader

                        width: page.width
                        active: root.reveal > 0 && (page.current || !fade.settled)
                        sourceComponent: page.pageBody

                        onLoaded: item.width = Qt.binding(() => page.width)
                    }
                }
            }
        }
    }
}
