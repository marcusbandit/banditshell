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
// The contents ARRIVE AT ONCE and the page they replaced fades out from under
// them, which is why there are two page slots rather than one Loader. With one
// slot there is no way to keep showing the old menu for even a frame after the
// new one exists, so however smoothly the box travels, the thing inside it
// still cuts. What must never be delayed is the ARRIVAL: the menu just pointed
// at is legible on the frame it is built, whatever state the services behind it
// are in, and the panel travels to fit it afterwards rather than the other way
// round. See the page delegate's opacity and the viewport's height.
//
// A menu WANTING more height than the clamp allows SCROLLS inside it rather
// than being cut: the panel keeps exactly the size the clamp gives it and the
// body becomes a viewport onto the rest. The panel's own sizing must therefore
// keep reading the body's IMPLICIT height, never the viewport's actual one;
// see the page delegate for how that chain is kept honest.
//
// AND SOME MENUS ARE ALREADY BUILT WHEN YOU POINT AT THEM. See `warm`.
Item {
    id: root

    property string title: ""
    property Component body: null

    // WHICH menu, which is not the same question as which Component (see
    // Menus.show: every tray item shares one). It decides which page the menu
    // is built into, so it must be set BEFORE `body`, which is what actually
    // triggers the swap.
    property string key: ""

    // THE MENUS THAT ARE BUILT BEFORE THEY ARE ASKED FOR: `[{key, body}, ...]`.
    //
    // The panel used to hold exactly two pages and throw a menu away the moment
    // it faded, so pointing at a gauge meant BUILDING its menu, in one frame,
    // between the cursor arriving and the panel opening. A wifi menu is a
    // squircle, a meter, a chevron, a password field and a folded-up layer per
    // network, times seven networks, plus the adapter's own layer: something
    // like fifty vector shapes, every one of them a new scene-graph node,
    // assembled while the compositor was waiting for a frame. That is the lag.
    // It was worst on the wifi menu because the wifi menu is the biggest, and it
    // was paid again on every single crossing, because nothing was kept.
    //
    // So a menu named here gets a page OF ITS OWN, loaded asynchronously at
    // startup, never destroyed, and never rebuilt. Pointing at its gauge shows
    // an object that has existed for minutes; the frame that used to build the
    // menu now only has to fade it in.
    //
    // NOT EVERY MENU, and the two that are excluded say why. A tray menu is one
    // Component shared by however many items are in the tray, and it reads which
    // one it is about as it is built (TrayIcons.trayMenu), so it MUST be rebuilt
    // per open; it uses the spare pair below, exactly as before. The clock's two
    // panels are simply not what anybody complained about, and each of them is
    // a page of live state that would go on computing all day for a menu nobody
    // has opened. What is warmed is what a hand sweeps across.
    //
    // WHAT IT COSTS is that a warm menu is alive while it is off screen, so
    // anything expensive it does has to be gated: `showing` below is how it is
    // told, and NetworkMenu's scanner and BluetoothMenu's discovery are what
    // are gated on it.
    property var warm: []

    // How many pages are NOT owned by a menu: the pair every other menu is built
    // into on the way in, alternating so the one arriving and the one leaving
    // are never the same page. Two, because a cross-fade is between two things.
    readonly property int spare: 2

    readonly property var pageModel: {
        const list = [];
        for (let i = 0; i < root.spare; i++)
            list.push({});
        return list.concat(root.warm);
    }

    // Where a menu is built. Its own page if it has one, otherwise whichever of
    // the spare pair is not currently showing.
    function pageFor(key: string): int {
        for (let i = 0; i < root.warm.length; i++)
            if (root.warm[i].key === key)
                return root.spare + i;
        return root.slot < root.spare ? (root.slot + 1) % root.spare : 0;
    }

    // 0 while closed, 1 while open. Everything geometric derives from this, so
    // the caller only has to animate one number.
    property real reveal: 0

    readonly property real fullWidth: Appearance.sizes.menuWidth
    readonly property real cornerRadius: Appearance.rounding.large

    // How much room there actually is. A configured maximum is a preference;
    // this is a fact, and content clipped by the bottom of the screen is a bug
    // rather than a long menu.
    property real available: Appearance.sizes.menuMaxHeight

    // Which page holds the menu on its way IN, and which one it replaced.
    //
    // THE OUTGOING PAGE IS NAMED, where it used to be "the other one". With two
    // pages that was the same sentence; with a page per warm menu it is four
    // different pages, and a fade written as "everything that is not current"
    // would have brought all of them up out of nothing on every crossing. Only
    // the page actually being left behind is on the fade's clock.
    property int slot: 0
    property int prevSlot: -1

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
        const next = root.pageFor(root.key);
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
            //
            // A WARM PAGE IS EXEMPT, and for the same reason stated backwards:
            // it holds one menu and only ever that menu, so there is nothing it
            // could be showing the wrong contents of, and rebuilding it would
            // throw away the very object this whole arrangement exists to keep.
            if (!page.warm) {
                page.pageBody = null;
                page.pageBody = root.body;
            }
        }

        // Nothing to cross with while the panel is shut, so the page being
        // replaced is not faded out of an empty panel, it is simply already
        // gone: the fade lands on 1 rather than starting from it, which is the
        // outgoing page's opacity at nought (see the delegate). The arriving
        // page never reads this either way, being at full strength from the
        // start, which is not the same thing as hiding what it replaces; what
        // `closed` still decides is whether the first size is taken or
        // travelled to, which is `unsized` below.
        const closed = root.reveal === 0;
        fade.value = closed ? 1 : 0;
        fade.target = 1;
        root.unsized = closed;
        root.prevSlot = root.slot;
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

            model: root.pageModel

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
                required property var modelData

                // A page that BELONGS to one menu rather than being lent out.
                // See root.warm. The test is "was it given a body up front",
                // because that is exactly what owning one means here.
                readonly property bool warm: !!page.modelData.body

                property string pageTitle: ""
                // A binding for a warm page, which swap() never assigns to, and
                // a plain value for a spare one, whose binding evaluates to
                // null once and is then written over per open.
                property Component pageBody: page.modelData.body ?? null

                readonly property bool current: index === root.slot

                // THE ONE BEING LEFT BEHIND, named rather than inferred; see
                // root.prevSlot.
                readonly property bool leaving: index === root.prevSlot && !fade.settled

                // On screen at all, which is what a body is told through
                // `showing` below and what its Loader stays alive for. The
                // panel's own reveal is in it because a closed panel shows
                // nothing however the pages feel about it: without that term a
                // warm menu would go on scanning for the rest of the session,
                // having been the last one open.
                readonly property bool live: root.reveal > 0 && (page.current || page.leaving)

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

                // THE INCOMING PAGE IS AT FULL STRENGTH FROM THE FRAME IT IS
                // BUILT. Only the outgoing one is on a clock.
                //
                // Both used to be, the incoming rising and the outgoing falling
                // squared against the same number, and that is precisely what
                // made switching menus feel slow. Crossing from one gauge to the
                // next, the first frames showed the menu just left at full
                // strength and the one now being pointed at at nothing, and the
                // hundred milliseconds after that showed both at once, which
                // over two pages of text reads as neither. Move down a column of
                // icons at any ordinary speed and the panel never once showed
                // the menu the cursor was actually on. A menu must arrive with
                // whatever it has and fill in as its services answer; nothing
                // about the arrival may wait on a clock, because "not finished
                // loading" is the normal state of a menu about a live machine
                // and not a reason to go on showing a different one.
                //
                // The outgoing page still LEAVES rather than being cut, and it
                // leaves squared, so one frame on it is at a bit over half
                // strength and by the fourth it is down to a tenth.
                //
                // WHAT THAT COSTS IS A DOUBLE IMAGE, and it is written down as
                // what it is rather than as the z below makes it sound. A page
                // draws no background: it is a heading, a rule and a body
                // standing over the chassis field, because the panel is a hole
                // in that field rather than a surface (the class comment says
                // so). Ordering the draw is therefore ALL the z does, the
                // arriving page occludes nothing, and for as long as the fade
                // lasts the two pages' ink adds wherever both of them put ink on
                // the same line. Every menu's heading sits on exactly the same
                // line, so crossing from the Sound gauge to the Network one
                // shows both words superimposed, at FULL strength on the swap
                // frame itself: swap() assigns fade.value = 0 and a Qt timer
                // does not tick on the frame it was started, so the outgoing
                // page renders at least one whole frame before any decay begins.
                // Under a tenth of a second all told, and that is the entire
                // price of arriving at once.
                //
                // Three alternatives, all worse. Cutting the outgoing page takes
                // the second slot's whole reason with it: the panel is one
                // object changing its contents, and an object does not change by
                // jump cut. Giving the page an opaque fill would occlude
                // properly and cannot be had here, a fill being a rectangle
                // drawn inside the melt. Seeding fade.value above 0 in the open
                // case, the way the closed case seeds it to 1, would take the
                // peak off the double image and shorten it by a frame, and the
                // only honest seed is one step of the fade's own decay: Follow
                // does not publish its step, so that number would be this file's
                // private copy of Follow's tick, wrong the moment either moves.
                //
                // A PAGE THAT IS NEITHER is at nothing, rather than at the
                // outgoing page's opacity. With two pages those were the same
                // number; with a page per warm menu, "not current" is four
                // pages, and the previous form would have faded all of them up
                // together on every crossing.
                opacity: current ? 1 : leaving ? (1 - fade.value) * (1 - fade.value) : 0
                // And a page at nothing is not drawn at all. Opacity zero still
                // walks the subtree; there are six of these now, five of them
                // idle at any moment, and a menu is a hundred-odd items.
                visible: opacity > 0
                // The arriving page is always the one on top, so the crossing
                // never depends on which slot happens to be first.
                z: current ? 1 : 0

                // The panel grows toward the INCOMING page, so a slot only
                // speaks while it is the current one. Both edges matter: the
                // second is the swap itself, the first is a menu resizing
                // later, under its own content.
                onImplicitHeightChanged: if (current)
                    root.pageHeight = implicitHeight

                onCurrentChanged: if (current) {
                    // THE ONE CASE A WARM PAGE IS NOT ALREADY BUILT: somebody
                    // reached the bar inside the second or two the incubator
                    // takes at startup. Finishing it here costs exactly what
                    // building it used to cost, and only then, which is the
                    // worst this can ever be rather than what it always was.
                    if (bodyLoader.status === Loader.Loading)
                        bodyLoader.forceCompletion();
                    root.pageHeight = implicitHeight;
                    // A warm page's body never changes, so the scroll reset
                    // below never fires for it. Coming back to a menu should
                    // still put you at the top of it: that position is where
                    // the menu starts, not where you left it.
                    view.contentY = 0;
                }

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

                    // The viewport is whatever of the panel's SETTLED height is
                    // left under the chrome. Settled, not live, and that is the
                    // difference between the content waiting on the box and the
                    // box travelling to fit content that is already in place.
                    //
                    // Live was what it used to be, so that the window onto the
                    // body grew with the travel rather than popping to the
                    // destination ahead of it. What that actually bought was a
                    // couple of hundred milliseconds after every swap in which
                    // the viewport was SHORTER than the menu inside it: a menu
                    // that fits perfectly well arrived as a clipped, scrolling
                    // document and only settled into being a panel once the
                    // travel landed. That is exactly the "it has not finished
                    // loading" the switch is meant not to have, and it was not
                    // only cosmetic, because `interactive` below is decided by
                    // the same comparison: for that window a drag on a slider in
                    // a menu just switched to was read as a drag on a list and
                    // scrolled it instead.
                    //
                    // Nothing pops, because the wrapper above clips at the
                    // panel's live edge: the rows are laid out where they will
                    // finally sit and the panel's edge sweeps down over them.
                    // That is what the width has always done (contents at full
                    // width, revealed by a panel growing over them), and it is
                    // what the class comment means by implicitHeight being where
                    // the panel is GOING: a layout question is asked of the
                    // destination, and only the drawing and the melt want the
                    // size it happens to be passing through.
                    //
                    // No loop, though the two sizes now name each other in the
                    // same file: the page's wanted height reads the body's own
                    // implicit height through `contentHeight` below and never
                    // this, and `pageHeight` is pushed by hand rather than
                    // bound, so nothing here can be asked for its own answer.
                    height: Math.max(0, root.implicitHeight - Appearance.padding.large * 2 - y)

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
                    //
                    // A WARM PAGE INVERTS ALL OF THAT (see root.warm): it is
                    // built at startup, off the frame clock, and kept. What
                    // does not change is the sentence above, only who is
                    // responsible for it: the menu is still not allowed to
                    // watch anything while it is off screen, and `showing`
                    // below is how it is told which it is. A body that declares
                    // no such property is one with nothing to switch off.
                    Loader {
                        id: bodyLoader

                        width: page.width
                        active: page.warm || page.live
                        // Off the frame clock: the incubator builds these
                        // between frames, so four menus' worth of shapes cost
                        // the startup nothing visible. It only ever applies to
                        // the warm ones; a spare page is being loaded because
                        // somebody is looking at it, and MenuPanel's whole
                        // opening rule is that the menu is legible on the frame
                        // it is built.
                        asynchronous: page.warm
                        sourceComponent: page.pageBody

                        onLoaded: {
                            item.width = Qt.binding(() => page.width);
                            if (item.showing !== undefined)
                                item.showing = Qt.binding(() => page.live);
                        }
                    }
                }
            }
        }
    }
}
