pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import Quickshell.Services.Notifications

// One notification, on screen.
//
// A row INSIDE the tray, not a shape of its own in the chassis field. The tray
// makes the one join to the shell; see NotificationTray for why that beat both
// of the field-level arrangements this went through.
//
// So the background is a raised FILL rather than the shell's surface material.
// A veil over what is already there, not a second translucent sheet: stacking
// the surface on itself doubles its opacity and the card comes out heavier than
// the shell it belongs to.
Item {
    id: root

    required property var entry
    required property real fullWidth

    // ROOM TO READ, in the one place there is time to.
    //
    // A popup is a glance: it arrives over what you were doing, it leaves on its
    // own, and it is capped tight so a chatty app cannot take the screen. The
    // hub is the opposite gesture. You went to the corner and asked for it, and
    // nothing in it expires while you are looking, so the same caps there are
    // not restraint, they are an ellipsis on the thing you opened the tray to
    // read. Same card, told which of the two it is in.
    property bool roomy: false

    signal dismissed

    // THE SENDER'S OBJECT, AND IT IS HERE TO BE TALKED TO, NEVER TO BE READ.
    //
    // Every displayed field below comes off the ENTRY's snapshot instead, and
    // that swap is the whole of the fix for a tray full of blank plates.
    // Quickshell destroys this object when the SENDER closes the notification,
    // and a chatty app (Discord above all) closes and replaces its
    // notifications constantly, so a history drawn through this reference
    // filled up with tombstones: fifty unread and most of the cards a bell on a
    // bare fill row with no app, no summary and no body. What a notification
    // said is not the sender's to unsay by hanging up. See
    // services/NotifEntry.qml, which owns the copy and the argument for it.
    //
    // And it does not merely go empty, it goes SILENTLY STALE, which is why
    // every use of it below is guarded on `live` rather than on a null test.
    //
    // The READ is safe: destroying a QObject nulls a `var`'s referent, so the
    // engine hands back null rather than a dangling pointer and `?.`
    // short-circuits on it exactly as it would on anything else null. Measured
    // rather than assumed, because the opposite was written here once and it is
    // the kind of claim that gets correct code "hardened" by whoever reads it
    // next: a destroyed object held in a `var` compares === null, is falsy,
    // answers `?.` with undefined, and throws only through a bare `.`. The `?.`
    // in Notifs' teardown paths is doing real work and needs no help.
    //
    // What is NOT safe is the binding. Destruction emits no change signal, so
    // this expression is never re-evaluated and neither is anything written in
    // terms of it: `notification !== null` would be false the moment somebody
    // asked, and nothing asks. Every stale binding sits there answering with
    // whatever it computed while the sender was alive. `live` is a real
    // property with a real change signal behind it (NotifEntry flips it from
    // `closed`, which quickshell emits before it destroys anything), so it is
    // the only form of this question that wakes the things that depend on the
    // answer.
    readonly property var notification: entry?.notification ?? null

    // Whether there is anybody left on the other end to invoke an action on.
    // Nothing that DISPLAYS reads this; it gates talking back, and it gates the
    // action pills, because a button that cannot invoke is worse than no button.
    readonly property bool live: entry?.live ?? false

    // Off the entry's snapshotted urgency, never through the object above. A
    // critical alert from a sender that has hung up is still critical, and the
    // spine is the one place this design spends colour on a state, so it is the
    // one that could least afford to go quiet when the object died.
    readonly property bool urgent: entry?.urgency === NotificationUrgency.Critical

    // A CARD IS NEVER A BARE PLATE.
    //
    // Some senders really do post a notification with nothing in it: no app
    // name, no summary, no body, only an icon hint or an action. While the card
    // read through the dead-object path that shape was indistinguishable from
    // the bug, so there was nothing to tell apart and no reason to handle it.
    // Now that the words outlive their sender, a wordless card is a rare and
    // HONEST thing rather than a symptom, and it still has to say something: a
    // fill row with a bell in it and no text reads as the shell having lost the
    // notification, which is exactly the impression this whole change exists to
    // undo.
    //
    // So the shell answers in its own voice, in brackets and in the quiet
    // colour tier, and those two things together are what say the words are
    // OURS rather than the sender's. The rejected alternative was to invent a
    // plausible-looking headline, the app's name promoted or a flat
    // "Notification": that is the shell putting words in the sender's mouth,
    // and a card that looks like it was written is worse than one that admits
    // nothing was.
    readonly property bool wordless: !entry?.appName && !entry?.summary && !entry?.body

    // Arrival: unfolds downwards out of the tray and fades up. EXPONENTIAL,
    // because another notification can land on top of it mid-flight and it has
    // to retarget rather than finish a scripted move to a stale place.
    property real reveal: 0

    // Departure, 0 to 1, driving the same collapse in reverse. FIXED duration,
    // unlike the arrival, because the service has to know when it is done: see
    // Notifs.exitMs. Both ends read the one number, so they agree by
    // construction rather than by a callback that a destroyed card never sends.
    property real leave: 0
    readonly property bool leaving: entry?.leaving ?? false

    // How much of the row is actually there. The stack's height is the sum of
    // these, so the tray grows and shrinks by itself and the rows below a
    // departing one slide up without any of them being told to.
    readonly property real open: Math.max(0, reveal - leave)

    // Where the card is, and how far you actually pulled. They differ while it
    // is resisting.
    property real dragX: 0
    property real pulled: 0

    // Whether it was THROWN AWAY: 0 or +1, and never -1 any more.
    //
    // A card let go past the commit point should keep going. Without this it
    // stopped dead wherever the pointer stopped and then collapsed in place,
    // which reads as the throw being ignored and the card dying of something
    // else. The fling rides `leave`, so it is the same one motion as the
    // collapse rather than a second animation racing it.
    //
    // ONE DIRECTION, because only one direction throws anything away now: right,
    // out through the edge the tray hangs off. Left is a pin and a pin springs
    // home. See conclude().
    property int flung: 0

    readonly property real throwDistance: fullWidth * Appearance.sizes.dragDismissFraction

    // Committed by DISTANCE or by SPEED, either alone. Distance was the only
    // test, and it quietly demanded that every throw be a long one: a short
    // sharp flick, the most natural way a hand has of getting rid of
    // something, stopped well short of the commit line and the card walked
    // back home as if nothing had been said. A flick is an intention expressed
    // as speed, and asking it to also cover distance is asking it twice. The
    // distance test stays for the slow deliberate drag, which is the gesture
    // it was actually measuring all along.
    //
    // The speed arm only counts speed pointing AWAY from home. An unsigned
    // magnitude was tried first, and it read the cancel gesture as a throw:
    // drag a card out, think better of it, bring it briskly back and release
    // mid-return, and the return itself is fast enough to clear the
    // threshold, so the change of mind DELETED the card, off the wrong edge,
    // which is exactly the "dragging back cancels" promise of DESIGN.md 15
    // broken by the arm that was added to honour flicks. Speed only means
    // "throw" when it agrees with where the card is displaced, which is what
    // the product's sign tests; a genuine flick always passes, because the
    // flick's own travel is what put the card on that side of home in the
    // first place.
    readonly property bool committed: Math.abs(pulled) >= throwDistance || (pulled * drag.velocity > 0 && Math.abs(drag.velocity) >= Appearance.sizes.flickVelocity)

    // Where the card actually sits: the drag, plus however much of the fling has
    // played. At leave = 1 it is exactly one card-width clear of home.
    readonly property real throwX: dragX + flung * leave * Math.max(0, fullWidth - Math.abs(dragX))

    // The countdown itself belongs to the ENTRY and is not read here at all.
    // Nothing on the card draws it: see the removed progress rule below the
    // background. The card still PAUSES it, which is the part that matters.
    //
    // PAUSED while the cursor is on it. A notification that expires from under
    // the pointer while you are reaching for its button is the single most
    // annoying thing a shell can do. Pushed to the entry so it survives a rebuild.
    //
    // A HoverHandler, not the drag area's containsMouse. Qt gives hover to the
    // topmost item that takes it, so the moment the cursor reached an action
    // button the card decided it was no longer hovered and the countdown resumed
    // UNDER THE BUTTON someone was already aiming at: the exact bug this pause
    // exists to prevent, reintroduced by how it was measured. A HoverHandler is
    // passive and stays hovered while its own descendants are.
    readonly property bool held: hover.hovered || drag.pressed || root.pinned

    // REGISTERED WITH THE ENTRY, where this used to be `entry.held = held`.
    //
    // One entry can be in front of two cards at once: the hub can be open on
    // every monitor at the same time, and `pinned` is a term of the union above
    // and lives on the ENTRY, so a pin made here turns the card on the next
    // screen held as well. Each of them then wrote that one flag from its own
    // hover and the last writer won, so a pointer leaving this card resumed a
    // countdown the card on the other screen was still holding. The entry keeps
    // the cards instead and answers for itself; see NotifEntry.heldBy, which is
    // where the argument lives.
    //
    // AND THE ENTRY IT WAS SAID TO IS REMEMBERED, so the hold can be taken back
    // off the same object it was put on. `entry` is handed in once by the
    // delegate today and nothing swaps it, but a card that let go of whatever it
    // happened to be pointing at LATER would leave the entry it was actually
    // holding frozen for the rest of that entry's life, which is a bug that could
    // only appear long after the line that caused it.
    property var holding: null

    function holdEntry(): void {
        const want = root.held ? root.entry : null;
        if (root.holding === want)
            return;
        // `?.`, because the entry can be destroyed before this card is: Notifs
        // takes an entry out of the lists and destroys it, and the delegate that
        // list change tears down goes a turn later. A destroyed object reads as
        // null here (see the note on `notification` at the top of this file), so
        // that is the hold quietly ceasing to exist along with the thing it was
        // put on.
        root.holding?.release(root);
        root.holding = want;
        root.holding?.hold(root);
    }

    onHeldChanged: root.holdEntry()
    onEntryChanged: root.holdEntry()

    // PINNED: the touch answer to hover, and the pin a mouse never had.
    //
    // Everything above is an argument about a cursor. A HoverHandler receives no
    // touch events at all, so on a touchscreen `hovered` is false for the whole
    // life of every popup and the pause simply never happens: the notification
    // runs its five seconds out mid-sentence and there is nothing a finger can do
    // about it. The other disjunct, `drag.pressed`, DID pause it, and the price
    // of using it was the card itself: letting go of a press that never travelled
    // is a click, and a click dismisses (DESIGN.md 15), so the one touch gesture
    // that paused a notification was also the one that deleted it.
    //
    // TWO WAYS TO SET IT, and they mean the same thing. A swipe LEFT is the
    // deliberate one (see conclude: right throws away, left pins), and a
    // press-and-hold is the one a finger falls into while reading, which is the
    // same sentence said more slowly.
    //
    // ON THE ENTRY, never here. It has to outlive this card: the tray rebuilds
    // its delegates when it expands, and a pin that lived in a card would be lost
    // by the row beside it being dismissed. See NotifEntry.pinned, which also
    // says what a pin costs a dismissal.
    readonly property bool pinned: entry?.pinned ?? false

    function pin(on: bool): void {
        if (root.entry)
            root.entry.pinned = on;
    }

    // UNFOLDED: showing everything the sender said rather than the short form of
    // it. The chevron in the gutter is the only way in or out; see `fold` below
    // for why it is a control of its own and not the card's own click.
    //
    // On the entry for the reason the pin is, one line up: it has to outlive
    // this card. See NotifEntry.unfolded.
    readonly property bool unfolded: entry?.unfolded ?? false

    function unfold(on: bool): void {
        if (root.entry)
            root.entry.unfolded = on;
    }

    width: fullWidth
    implicitHeight: body.implicitHeight + Appearance.padding.normal * 2
    height: implicitHeight * open

    // CLIPPED, so the contents keep their real size while the row collapses.
    // Scaling them with it squashes the text, which reads as the notification
    // being crushed rather than closed.
    clip: true

    // One expression owns x: the throw, and nothing else. The row arrives by
    // unfolding rather than by sliding, so an arrival and a drag can never
    // fight over the same axis.
    x: throwX
    // FADES ON THE DISMISS SIDE ONLY. `Math.abs` used to be around `throwX`, from
    // when both directions threw the card away; a leftward pull is a pin now, and
    // something on its way to being KEPT must not look like it is leaving. The
    // unsigned term below is zero for a leftward offset, so the pin tracks at full
    // opacity and the only thing that fades is a departure.
    opacity: open * Math.max(0.1, 1 - Math.max(0, throwX - throwDistance * Appearance.sizes.dragResistance) / (fullWidth * 0.6))

    HoverHandler {
        id: hover
    }

    // Both doors, exactly as NotifEntry takes its snapshot through two: the
    // handler above covers a picture that becomes copyable while this card is
    // already on screen, and this covers the far commoner case of a card built
    // for an entry that wanted a copy before the card existed, which fires no
    // change signal because nothing changed.
    Component.onCompleted: {
        grow.target = 1;
        root.beginCopy();
    }

    // Reversible, because an entry that merely timed out RESETS: it leaves the
    // popups and stays in the tray as the same object. A delegate that outlives
    // that (the tray was open) would otherwise sit at leave = 1 forever, present
    // in the list and zero pixels tall.
    onLeavingChanged: {
        if (leaving) {
            exit.start();
        } else {
            exit.stop();
            leave = 0;
            flung = 0;
        }
    }

    NumberAnimation {
        id: exit

        target: root
        property: "leave"
        to: 1
        duration: Notifs.exitMs
        // OUT, not in-out. A dismissal is an answer to something someone just
        // did, so it has to start at full speed; easing into it spends the first
        // third of the animation looking like nothing happened.
        easing.type: Easing.OutCubic
    }

    Follow {
        id: grow

        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
        onValueChanged: root.reveal = value
    }

    Follow {
        id: settle

        speed: Appearance.anim.revealSpeed
        target: 0
        onValueChanged: if (!drag.throwing)
            root.dragX = value
    }

    // Resistance before the commit point, 1:1 after it. The card gives back only
    // half of the first fifth of the throw, so it feels like it is holding on;
    // past the commit point the slope changes and it tracks the pointer exactly.
    function resist(delta: real): real {
        const commit = root.throwDistance;
        const k = Appearance.sizes.dragResistance;
        const m = Math.abs(delta);
        const held = m < commit ? m * k : commit * k + (m - commit);
        return delta < 0 ? -held : held;
    }

    // Concentric with the tray by construction: an inner corner sits its own
    // inset in from the outer one, so a fixed radius here would read as pinched
    // at the top and loose at the bottom of the same shape.
    readonly property real radius: Math.max(Appearance.rounding.small, Appearance.rounding.large - Appearance.padding.normal)

    G2Rect {
        anchors.fill: parent
        radius: root.radius
        // It answers the cursor. A stack of cards that does nothing under the
        // pointer is the one place in this shell where nothing is alive, and the
        // lift also says which card a throw is about to take.
        color: root.held ? Appearance.colour.fillStrong : Appearance.colour.fill

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    // A critical notification is marked by a bar down its leading edge, not by a
    // differently coloured card. Colour alone is not a state cue, and a whole
    // card tinted red is a fire alarm for something that is merely important.
    //
    // It TAKES ROOM. Drawn at the same inset as the content it was sharing three
    // pixels with the app's badge plate, showing through it because a fill is a
    // veil rather than paint; a mark that has to be in front of something is not
    // a mark. `spine` below is what the content moves over by.
    G2Rect {
        id: spine

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Appearance.padding.normal
        width: Math.max(2, Appearance.padding.small / 2)
        radius: width / 2
        color: Appearance.colour.accent
        visible: root.urgent
    }

    readonly property real spineRoom: root.urgent ? spine.width + Appearance.padding.small : 0

    // NO PROGRESS RULE. There used to be a hairline along the bottom edge
    // draining with the timeout, on the argument that a card vanishing mid-read
    // reads as a glitch unless something counted it down.
    //
    // It buys less than it costs. The bar is a clock on a thing you did not ask
    // for and cannot usefully act on: knowing a notification has two seconds
    // left does not help, it only starts a race, and the countdown already stops
    // dead the moment the cursor arrives, so the one case where the remaining
    // time would matter is the one case it is not running. What is left is a
    // moving part on every card in the tray, drawing the eye to the corner that
    // has nothing to say.
    //
    // ONE padding tier inside the card, and it is the same one the tray puts
    // outside it, so the content sits two tiers in from the tray's edge without
    // either of them spending a bigger number. `large` here was 24 a side: 48px
    // of the card's width gone to air, on a card whose text column was already
    // the thing running out of room.
    Item {
        id: body

        x: Appearance.padding.normal + root.spineRoom
        y: Appearance.padding.normal
        width: root.fullWidth - Appearance.padding.normal * 2 - root.spineRoom
        // The mark's column and the text's, whichever is taller. The fold is
        // part of the mark's column and usually costs nothing, because the text
        // beside it is what made the card foldable in the first place; a card
        // whose long field is its summary alone can be an inch taller for it.
        implicitHeight: Math.max(badge.height + (fold.visible ? Appearance.padding.small + fold.height : 0), text.implicitHeight)

        // The sender's own icon when it gave one, our bell when it did not. An
        // app that bothered to identify itself should be recognised by its mark
        // rather than by reading its name.
        //
        // AND A PICTURE IS NOT A MARK. The spec has two fields here and they
        // answer different questions: `app_icon` is who sent this, the image
        // hint is what it is about. They were being read as one expression with
        // the picture merely winning, so every album cover, avatar and
        // screenshot preview was drawn at an app icon's size and centre-cropped
        // square to fill it. A 40px crop out of the middle of a screenshot is
        // not a small version of that screenshot, it is a swatch of it.
        //
        // So a card with a picture gets a picture: twice the size, and FITTED
        // rather than filled, so nothing is cut off. There is nothing behind it
        // to letterbox against, which was the reason to crop in the first place;
        // the plate is hidden under any image, so what a wide picture leaves
        // above and below it is the card, not a band of a different colour.
        Item {
            id: badge

            // BOTH OFF THE SNAPSHOT, AND BOTH ALREADY ANSWERED. The card asks
            // the entry what to draw and draws it; neither of these is a lookup
            // any more.
            //
            // `picture` used to be the raw `image` field and `mark` used to be
            // `Quickshell.iconPath(appIcon)` computed right here, and the pair
            // of them is what the tray full of identical bells was made of. The
            // resolution moved into services/NotifEntry.qml, which has the
            // whole argument: a picture that arrived as raw pixels has to be
            // copied to a file before its sender lets go of it, and an app_icon
            // is a name that has to be asked of the theme, of what you picked
            // for that application, and of the desktop entry, in that order.
            // Both are questions about WHAT WAS SENT rather than about how to
            // draw it, and both have to keep answering after the sender is
            // gone, which is the entry's whole job.
            readonly property string picture: root.entry?.picture ?? ""
            readonly property string mark: root.entry?.mark ?? ""

            readonly property bool marked: mark !== "" && sign.ready

            // NEITHER OF THEM LOADED is what the plate and the bell are for,
            // which is a narrower claim than the one that used to be made here.
            // The old expression picked ONE source, the picture when there was
            // one and the mark otherwise, so a card whose picture had died fell
            // straight past the sender's own mark to the generic bell: Discord
            // sends both an avatar and `discord`, and the avatar dying took the
            // Discord logo down with it. They are two images now precisely so
            // that losing the first uncovers the second.
            readonly property bool hasImage: badge.pictured || badge.marked

            // THE ROOM FOR A PICTURE IS TAKEN ON THE LOAD, NEVER ON THE STRING,
            // and that stays true now that the picture survives its sender.
            //
            // It used to be taken on the string, and a card whose sender had
            // gone came out twice as wide holding nothing: the load failed, the
            // plate and the bell came back, and they came back at double size
            // with a half-size glyph rattling around in them, which is a worse
            // card than the plain one it would have drawn had the picture never
            // been claimed. Depending on Qt's pixmap cache to paper over it made
            // it intermittent too, which is the hardest kind of wrong to be told
            // about.
            //
            // A copy of the picture is now taken at arrival (see `copier`
            // below), so the death this defended against is far rarer than it
            // was. Rarer is not never: a sender that hangs up inside the frame
            // or two the copy takes still gets away, and this is what makes that
            // card an ordinary one-square card wearing the sender's mark instead
            // of a double-width hole.
            readonly property bool pictured: picture !== "" && art.ready

            // Square either way, so the text column starts in the same place on
            // every card and a list of them reads as a column rather than as a
            // ragged edge. Which square depends on whether there is anything
            // worth looking at.
            //
            // TWICE THE BADGE, derived rather than configured. It is the same
            // slot doing a second job, so it has no business being a number
            // anyone can move independently: the day the badge changed, a
            // separate setting would quietly stop being twice it.
            width: Appearance.sizes.notificationBadge * (badge.pictured ? 2 : 1)
            height: width

            // The plate is only there to hold the glyph. Under an image it would
            // be a frame around something already square, and a step of fill
            // showing at the corners reads as the image not fitting.
            G2Rect {
                anchors.fill: parent
                radius: Appearance.rounding.small
                color: Appearance.colour.fillStrong
                visible: !badge.hasImage
            }

            Icon {
                anchors.centerIn: parent
                visible: !badge.hasImage
                // HALF THE PLATE, not the shell's text-side icon size. That one
                // is sized to sit beside a line of body text; dropped into a
                // plate three times its area it read as a mark lost in a box.
                size: Math.round(badge.width / 2)
                name: root.urgent ? "priority_high" : "notifications"
                color: root.urgent ? Appearance.colour.accent : Appearance.colour.textDim
            }

            // A MARK is cropped to fill and a PICTURE is fitted whole, and they
            // are TWO IMAGES because they are two facts.
            //
            // An app icon is square already, so filling its plate costs it
            // nothing and letterboxing it would leave a step of fill at the
            // corners, which reads as the icon not fitting. A picture is not
            // square and is the thing you are being shown, so the same crop that
            // is free for the one throws most of the other away. One item cannot
            // hold both fill modes, and more to the point one item cannot fall
            // back: an Image whose source failed shows nothing, and nothing is
            // what a Discord card was showing where its logo should have been.
            // Stacked, the picture simply covers the mark while it is there.
            //
            // Either way it is masked to the plate's curve, because an image is
            // the one shape that cannot go through G2Rect: it is a texture, not
            // a path, so it would keep its own square corners over the plate's.
            // See G2Image.

            // THE SENDER'S MARK, always exactly one badge, whatever the badge
            // itself is doing. Sized off the constant rather than anchored to
            // fill, because the badge doubles when a picture loads and this
            // would double with it: an icon re-decoded at twice the size to be
            // drawn at none of it, since it is hidden in exactly that case.
            G2Image {
                id: sign

                anchors.left: parent.left
                anchors.top: parent.top
                width: Appearance.sizes.notificationBadge
                height: width

                source: badge.mark
                fillMode: Image.PreserveAspectCrop
                radius: Appearance.rounding.small
                // Under the picture rather than instead of it. Both are the
                // sender's, and when there is a picture it is the more specific
                // of the two: a Discord avatar says which conversation this is,
                // where the Discord logo only says which application.
                visible: !badge.pictured
            }

            // SIZED OFF THE STRING WHERE THE BADGE IS SIZED OFF THE LOAD, which
            // is the one place those two questions have to be told apart. It
            // cannot simply fill the badge: `sourceSize` inside G2Image is
            // driven by this item's own size, so a picture whose box grew when
            // it loaded would be changing the decode that decides the box. That
            // is not a theoretical objection. Measured, Qt sees the ring, and
            // after the first replace it BREAKS the badge's width binding
            // outright: the badge stayed at a single square forever with a
            // fitted picture rattling around in it, and no warning anyone can
            // see at runtime.
            //
            // So the room a picture MIGHT need is claimed off the string, which
            // no load can move, and the decode happens once at the size it will
            // finally be drawn at. When there is no picture, or the picture is
            // dead, this box is bigger than the badge and draws nothing at all,
            // which costs a few pixels of empty item and is invisible.
            G2Image {
                id: art

                anchors.left: parent.left
                anchors.top: parent.top
                width: Appearance.sizes.notificationBadge * (badge.picture ? 2 : 1)
                height: width

                source: badge.picture
                fillMode: Image.PreserveAspectFit
                radius: Appearance.rounding.small
            }
        }

        // THE FOLD, in the gutter under the mark.
        //
        // A CONTROL OF ITS OWN, because every other way of asking was already
        // taken and means something else: a click on the card dismisses it, a
        // press-and-hold pins it, and both directions of a drag are spoken for.
        // A chevron is the one thing on a card that can be pressed without
        // meaning any of that (see components/Expander.qml, which is a target
        // rather than a decoration for exactly this reason).
        //
        // UNDER THE BADGE, which is the only room on a card that is already
        // empty: the mark is one square at the top of a column as tall as the
        // text beside it, so a foldable card has the space by construction and
        // nothing has to grow to hold this. It is anchored to the badge and not
        // to the bottom of the card so that it STAYS WHERE IT WAS PRESSED when
        // the card unfolds; a toggle that slides out from under the cursor it
        // was just clicked with is a toggle you cannot click twice.
        Expander {
            id: fold

            anchors.horizontalCenter: badge.horizontalCenter
            anchors.top: badge.bottom
            anchors.topMargin: Appearance.padding.small

            // Only when there is something behind the fold. Both slots are
            // asked, because either of them can be the one that was cut.
            visible: message.foldable || headline.foldable
            open: root.unfolded

            // NO TOOLTIP, which is the one thing an Expander normally insists
            // on. The tip is drawn beside its host, and its host here is in the
            // gutter with the message immediately to the right of it, so the
            // label landed ON TOP of the very text it was offering to show.
            // A chevron next to a line that is visibly cut short does not need
            // the sentence anyway.

            onToggled: root.unfold(!root.unfolded)
        }

        Column {
            id: text

            anchors.left: badge.right
            anchors.leftMargin: Appearance.padding.normal
            anchors.right: parent.right
            // Out of the pin's way, and only once the pin is actually there. See
            // pinMark: the two are flush against the same edge, so the mark's own
            // width plus a gap is exactly the room it needs.
            anchors.rightMargin: root.pinned ? pinMark.width + Appearance.padding.small : 0
            anchors.top: parent.top
            spacing: 0

            StyledText {
                width: parent.width
                visible: !!root.entry?.appName
                text: root.entry?.appName ?? ""
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textFaint
                elide: Text.ElideRight
            }

            // THE ONE THING THE CARD IS ABOUT, and it says so with COLOUR, not
            // with a size. The size above `small` is 27, because the pixel grid
            // has no step between them, and a 27px headline on a card this size
            // is not emphasis, it is a banner: the card grew half again as tall
            // and the tray started shouting over the desktop it belongs to.
            // Brightest label tier against a dim body carries the same hierarchy
            // for nothing (see ~/.claude/rules/type-scale.md).
            //
            // It WRAPS rather than eliding. A summary is a whole short sentence
            // often enough ("Connection Established") that a one-line cap turned
            // most notifications into an ellipsis, and a truncated headline reads
            // as broken where a wrapped one reads as written.
            //
            // It is also the slot that ANSWERS FOR THE CARD when there is
            // nothing at all to say. See `wordless`: the placeholder goes here
            // rather than in a row of its own, because a card with no words
            // still has the same shape as one with words, and adding a special
            // element for the empty case would be a second layout to keep in
            // step with the first. The quiet colour is what marks it as the
            // shell talking; the bright tier is reserved for what the sender
            // actually wrote.
            FoldedText {
                id: headline

                width: parent.width
                // Hidden when it is genuinely empty, which is a card that has
                // an app name or a body but no summary. An empty Text is not a
                // zero-height Text: it still reserves its whole line box, so
                // without this the column carried a blank line where the
                // headline would have been and the card read as having lost
                // something. It can never hide the wordless case away, because
                // that case is exactly when `full` is the placeholder.
                visible: !!full
                full: root.wordless ? "(no message)" : (root.entry?.summary ?? "")
                color: root.wordless ? Appearance.colour.textFaint : Appearance.colour.text
                unfolded: root.unfolded
                // A summary is a headline and is short in nearly every packet,
                // so its cap is the one it always had; the fold is what a
                // sender that writes a paragraph into it now runs into instead
                // of the elide.
                lines: root.roomy ? 4 : 2
            }

            // HOW FAR ALONG, when the sender bothered to say. Absent from nearly
            // every notification, so it collapses to nothing rather than
            // reserving a lane that is empty on all but one card in the tray.
            //
            // It exists because senders draw this themselves otherwise. Given
            // nowhere to put a proportion, a script writes one into the body out
            // of block characters, and that bar is at the mercy of the body's
            // font, its wrap, and its elide: on a card this width the line
            // arrives as a row of chunky glyphs with the figures truncated off
            // the end, which is the one thing the notification came to say.
            //
            // Above the body, not below it, because the body is where the
            // numbers that QUALIFY the proportion live ("1.6 / 3.5 GB, 8 MB/s").
            // The bar answers the question and the body explains the answer, so
            // the answer goes first.
            Item {
                id: meter

                readonly property real pct: root.entry?.progress ?? -1

                width: parent.width
                visible: pct >= 0
                // Padding carried here rather than as a gap on the Column, whose
                // spacing is 0 precisely so each row owns the space above it.
                height: visible ? row.implicitHeight + Appearance.padding.small : 0

                // Follow, not a Behavior. A progress hint lands whenever the
                // sender feels like it, so the target moves mid-flight, which is
                // the case a fixed-duration animation gets wrong: it restarts
                // from wherever it had got to and the bar visibly stutters. The
                // chase runs on the 0..100 percent rather than the 0..1
                // fraction, because Follow's epsilon is sized for pixel-scale
                // numbers and against a fraction it would land instantly.
                Follow {
                    id: chase

                    target: meter.pct
                    speed: Appearance.anim.revealSpeed
                }

                // Snapped on arrival so a card that opens at 40% opens AT 40%.
                // Sweeping up from zero every time the tray redraws would be an
                // animation of the card appearing, not of the download moving,
                // and the two read completely differently.
                Component.onCompleted: chase.snap()

                Item {
                    id: row

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    implicitHeight: Math.max(gauge.implicitHeight, figure.implicitHeight)
                    height: implicitHeight

                    Gauge {
                        id: gauge

                        anchors.left: parent.left
                        anchors.right: figure.left
                        anchors.rightMargin: Appearance.padding.small
                        anchors.verticalCenter: parent.verticalCenter

                        value: chase.value / 100
                    }

                    // The exact figure, in the body's own tier and colour, so it
                    // reads as part of what the sender said rather than as a
                    // label the shell bolted onto the bar.
                    StyledText {
                        id: figure

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        text: `${Math.round(meter.pct)}%`
                        font.pixelSize: Appearance.font.size.small
                        color: Appearance.colour.textDim
                    }
                }
            }

            FoldedText {
                id: message

                width: parent.width
                visible: !!root.entry?.body

                // BOTH FORMS, and the short one is the parser's when there is a
                // parser for this sender. See services/NotifBrief.qml: a
                // qBittorrent body is a release name, which is a filename
                // wearing four bracketed groups, and cutting the tail off it
                // cuts away the only part anybody wanted.
                full: root.entry?.body ?? ""
                brief: root.entry?.brief ?? ""
                unfolded: root.unfolded

                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textDim
                topPadding: Appearance.padding.small

                // A notification is not a document, but three lines is where the
                // fold has to be. Two was tried, to keep the cards short, and it
                // cut the 2FA code out of "Your verification code for The Movie
                // Database (TMDB) is: 4098" - which is the whole reason that
                // notification exists. A card is allowed to be one line box
                // taller than its neighbour; it is not allowed to hide the thing
                // it came to say behind a control.
                //
                // In the hub it is barely a fold at all. The tray is a Flickable
                // that scrolls once it outgrows the screen, so a long message
                // costs a scroll rather than the screen, and there is time to
                // read in there (see `roomy`).
                lines: root.roomy ? 12 : 3
            }

            // A FLOW, not a Row. The count is the sender's to choose and the
            // labels are the sender's to write, so nothing here can know whether
            // they fit: a Row let "Do not show this message again" run straight
            // out through the side of the card. This wraps whatever does not fit
            // onto the next line, and caps each pill at the column so a single
            // long one loses characters instead of the card losing its edge.
            Flow {
                id: actions

                width: parent.width

                // THE ONE PART OF THE CARD THAT DIES WITH THE SENDER, and it
                // has to, because an action is not information, it is a call
                // back to a process that is no longer listening. So this is the
                // one place `live` is allowed to change what is on screen: the
                // words stay forever and the buttons go when there is nobody to
                // press them at.
                //
                // The count comes off the snapshot and the liveness off the
                // flag, which is a pair rather than one test on purpose: the
                // snapshot remembers that there WERE actions (it is never
                // re-taken after the object dies), and `live` is the only thing
                // that can still tell you whether they mean anything.
                //
                // Invisible rather than emptied, so the row COLLAPSES: a Column
                // skips an invisible child entirely, where a visible Flow with
                // no pills in it would still spend its topPadding and leave the
                // card with a band of dead air under the body.
                visible: root.live && (root.entry?.hasActions ?? false)
                topPadding: Appearance.padding.normal
                spacing: Appearance.padding.small

                Repeater {
                    // The one read of `actions` there is, and the `live` test
                    // carries it for a reason that is NOT the optional chain
                    // beside it. `?.` would keep this expression from throwing
                    // on its own: the dead reference reads as null (see the
                    // property, where that is measured rather than assumed), so
                    // the chain would fall through to []. If that were the whole
                    // problem the chain alone would be enough.
                    //
                    // It is not. Nothing signals the death, so this binding is
                    // never re-evaluated and the Repeater keeps the array it
                    // built while the sender was alive: a list of Action objects
                    // that were destroyed along with the notification they
                    // belong to. Every delegate then reads `modelData.text` off
                    // one of them, and that bare `.` is the read that really
                    // does throw, once per pill, every time the row is rebuilt.
                    // `live` changes when the object dies and takes the model to
                    // [] with it, which is the only thing here that can.
                    //
                    // FILTERED THROUGH THE ENTRY, which is where the same test
                    // decides `hasActions` above: the spec's `default` action is
                    // what clicking the notification means and carries no label,
                    // so drawn as a pill it is a blank button that does nothing.
                    // See NotifEntry.pressable.
                    model: root.live ? (root.entry?.pressable(root.notification?.actions) ?? []) : []

                    delegate: Pill {
                        required property var modelData

                        text: modelData.text
                        width: Math.min(implicitWidth, actions.width)

                        onClicked: {
                            // Guarded even though the pills are already hidden
                            // when the sender is gone, because the two are not
                            // simultaneous: the press lands, the sender closes
                            // the notification in the same frame, and the
                            // release arrives here after the bindings above
                            // have taken the row away. That is a rare race and
                            // an unguarded invoke through a destroyed object is
                            // a TypeError in the log, which is a poor trade for
                            // one clause.
                            //
                            // The dismissal happens either way. Pressing a
                            // notification's button is a decision ABOUT the
                            // notification, and it stays made whether or not
                            // anybody was there to hear it; leaving the card
                            // sitting in the tray because the invoke missed
                            // would answer a deliberate act with nothing.
                            if (root.live)
                                modelData.invoke();
                            root.dismissed();
                        }
                    }
                }
            }
        }
    }

    // THE PIN, and the leftward pull's only feedback.
    //
    // It has to be both, because the two gestures differ by DIRECTION alone and
    // nothing else on the card would say which one is happening: a rightward pull
    // fades, and a leftward one deliberately does not (see `opacity`), so without
    // this a pin in progress would look like a dismissal that had changed its
    // mind. It rides the pull straight, so the mark is fully there exactly when
    // the gesture reaches its commit line.
    //
    // AFTER the body rather than beside the spine it sits opposite, because
    // declaration order is stacking order and the text column is what it shares
    // its corner with. Room is reserved for it only in the SETTLED state (see the
    // column's rightMargin): a text column that reflowed on every frame of a drag
    // would be the card rewriting itself under the hand.
    Icon {
        id: pinMark

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.padding.normal

        name: "push_pin"
        size: Appearance.font.size.small
        fill: 1
        color: Appearance.colour.accent
        opacity: root.pinned ? 1 : Math.min(1, Math.max(0, -root.pulled / root.throwDistance))
        visible: opacity > 0.01
    }

    // ------------------------------------------------------------------
    // THE COPY, AND WHY IT IS TAKEN IN A CARD AND NOT IN THE SERVICE.
    //
    // A notification that carries its avatar as raw pixels (Discord, and every
    // Electron app, because that is what libnotify's pixbuf call sends) hands
    // out a url into a provider its own object owns. When the sender hangs up,
    // and Discord hangs up constantly, the provider goes and the url resolves to
    // nothing. services/NotifEntry.qml has the measurements and the policy: what
    // is borrowed, where a copy goes, which copy is current. What is left is the
    // act of copying, and this is the only place in the shell that can perform
    // it.
    //
    // MEASURED, because the obvious home for this was the service and it does
    // not work there. Qt renders nothing for an item that is not in a window: an
    // Image inside a Singleton loads its pixels perfectly happily and then
    // `grabToImage` answers "item is not attached to a window" and returns
    // false, and a Canvas in the same position never paints at all, so `save()`
    // writes nothing and reports false. Both were tried in a throwaway
    // quickshell instance before a line of this was written. There is no
    // offscreen route; the pixels can only be got out through something that is
    // being drawn, and in this shell the things being drawn are cards.
    //
    // Which card does it does not matter, and every screen has one for the same
    // entry, so the entry carries the flag that stops them all doing it at once.
    // The one thing that DID matter is that a card exists at all for every
    // notification that arrives, and it does: Notifs puts each arrival at the
    // head of `popups` before the cap is applied, so the newest is never the one
    // pushed off the end, and the tray draws `popups` whenever it is not
    // expanded and `history` when it is. The arrival is in whichever of those
    // two the tray is showing.
    readonly property real copyCap: Appearance.sizes.notificationBadge * 4

    // The url that MIGHT want copying, or nothing. Read as one expression so the
    // handler below fires both when a picture becomes copyable and when a
    // replace hands the entry a different one; a bare flag would not, since it
    // is already true in the second case and stays true.
    //
    // ASKED OF `copyPath` AND NOT OF `wantsCopy`, which is the whole of what
    // this line has to get right. `wantsCopy` is the honest question and it was
    // what stood here, but it counts `copying` among its terms and `copying` is
    // the first thing the handler below writes: the binding fed the handler, the
    // handler fed the binding, and the running shell said "Binding loop detected
    // for property borrowedPicture" out loud for every picture that arrived. It
    // terminated on the second pass and the copy still landed, which is exactly
    // what made it worth fixing rather than leaving: a warning nobody can act on
    // in a log that is otherwise clean, resting on an ordering inside beginCopy
    // that was never chosen for that job. `copyPath` is the half of the same
    // question that no card ever writes to (borrowed pixels, and a directory to
    // put them in), so it changes when the picture does and stays put while the
    // copy is claimed.
    //
    // THE POLICY DID NOT MOVE HERE with it. This is a trigger and not a
    // decision: whether the copy is actually wanted is still `wantsCopy`, asked
    // once inside beginCopy where the claim is made, so the card goes on knowing
    // nothing about live-ness, caching or the claim itself. Duplicating those
    // terms in the condition would have silenced the loop too, and would have
    // put NotifEntry's policy in two files to do it.
    readonly property string borrowedPicture: root.entry?.copyPath ? root.entry.image : ""

    onBorrowedPictureChanged: root.beginCopy()

    // THE URL THIS CARD HAS A LOAD OF, which is the whole of its claim on the
    // entry's copy.
    //
    // The entry carries one flag for every screen's card, so it can say that
    // SOMEBODY is copying and can never say which of them: a card reading it
    // cannot tell its own claim from another card's. That is not a difference
    // the flag can be taught, because the entry has no business knowing that
    // cards exist at all (its own comments say so, and the whole of its policy
    // is written without them). So each card keeps its half of the fact here and
    // refuses to put down a claim it never took. Held from the moment the load
    // starts to the moment it ends, by whichever door: the copier's source is
    // non-empty exactly when this string is.
    property string claimed: ""

    // LATCHED rather than bound, which is the whole reason this is a function
    // and not a binding on `copier.source`. Claiming the copy sets the entry's
    // flag, the flag takes `wantsCopy` false, and a bound source would drop to
    // nothing on the same turn and cancel the load it had just started. Assigned
    // once, the load survives its own claim, and it survives the sender dying
    // halfway through it as well, which is the case worth surviving.
    //
    // `wantsCopy` IS THE ONLY GUARD LEFT. It used to be joined by a test that
    // this card's copier was not already loading that very url, which read like
    // caution and was the hole the duplicate copies came through: a card whose
    // claim had been dropped by someone else took the early return and never
    // re-asserted it, so the flag stayed down with a load still in flight and
    // the next card built started a second one of the same url. Nobody can drop
    // this card's claim any more (see releaseCopy), and `wantsCopy` counts the
    // flag among its terms, so arriving here at all means the copy is unclaimed
    // and this card is free to take it.
    function beginCopy(): void {
        const e = root.entry;
        if (!e || !e.wantsCopy)
            return;
        root.claimed = e.image;
        e.copying = true;
        copier.source = e.image;
    }

    // The pixels are in a texture; put them in a file.
    //
    // NAMED AFTER THE URL THE PIXELS CAME FROM, which is the one this card
    // latched and not whatever the entry is showing by now. Asking the entry for
    // `copyPath` here was the same question a moment later, and it answers about
    // the CURRENT picture: a replace landing during the load (Discord edits
    // constantly, and a full asynchronous decode is a wide window to land in)
    // filed the OLD pixels under the NEW url's name, keep() compared that name
    // against the same property and of course agreed with it, and the entry was
    // left holding the previous avatar under the current one's name with
    // `cached === copyPath` for good, so no correct copy was ever taken again. A
    // wrong picture rather than a missing one, which is the harder kind to
    // notice. Off the claim the two guards are finally different questions: this
    // one says what these bytes ARE, and keep() says whether that is still the
    // picture anybody wants.
    function finishCopy(): void {
        const e = root.entry;
        const claim = root.claimed;
        const target = e?.copyPathFor(claim) ?? "";
        if (!target)
            return root.releaseCopy();

        // A url and not a bare path. QQuickItemGrabResult has an overload for
        // each and the string one is the deprecated half; handing it a plain
        // "/home/..." is the shape most likely to be resolved to the wrong one
        // and fail silently.
        const ok = copier.grabToImage(result => {
            if (result.saveToFile(Qt.resolvedUrl(`file://${target}`)))
                e.keep(target);
            else
                console.warn(`Notifications: could not write ${target}; ${e.appName} keeps its picture only until its sender closes it.`);

            // AND LET GO ONLY IF THIS IS STILL THE PICTURE BEING HELD. A grab
            // answers a frame later at the earliest, and a replace landing in
            // that frame has already sent this card round again with a newer
            // claim and a newer load: releasing then would cancel a load that
            // has nothing to do with the bytes just written, and hand the entry
            // back a flag somebody (this card) is still using.
            if (root.claimed === claim)
                root.releaseCopy();
        });

        if (!ok)
            root.releaseCopy();
    }

    // LET GO OF THE CLAIM, and of nobody else's.
    //
    // Every door out of a load comes through here: the load that errored, the
    // grab that refused, the copy that landed, and the card being torn down. The
    // guard is the whole point of the function. The flag lives on the entry and
    // any card can write it, so this used to hand it back whether or not this
    // card had ever taken it, and on a machine with two outputs that is a card
    // per screen for the same notification: the tray on the OTHER screen
    // swapping between its popups and its history destroys a card that had
    // copied nothing, that card dropped the claim of the card that was mid-load,
    // and the next delegate built took the flag it found down and started a
    // second copy of the same url. Both landed on the same path, and the second
    // landing deleted the first one's file out from under `cached`.
    //
    // The picture goes on being drawn straight from the sender for as long as
    // the sender is there, which is exactly what happened before any of this
    // existed, so failing here costs the old behaviour and nothing more.
    function releaseCopy(): void {
        if (!root.claimed)
            return;
        root.claimed = "";
        copier.source = "";
        if (root.entry)
            root.entry.copying = false;
    }

    // AND IF THIS CARD GOES AWAY MID-COPY, the claim goes with it.
    //
    // The claim lives on the entry and the work lives on the card, and the card
    // is the shorter-lived of the two: the tray tears its delegates down every
    // time it swaps between showing the popups and showing the history, and a
    // grab whose item is destroyed never calls back. Without this the flag would
    // stay up for the life of the entry and no other card would ever try again,
    // which is a picture silently lost to a collapse that happened to land in
    // the wrong frame.
    //
    // DROPPED ONLY IF THIS CARD WAS HOLDING IT, which releaseCopy decides and
    // this line no longer has an opinion about. Dropping it unconditionally was
    // the same statement to write and a different thing to mean: every card of
    // every screen said it on the way out, including the ones that had never
    // copied anything.
    //
    // Handed to the card built in this one's place rather than to the cards
    // already standing. `beginCopy` runs from the completion handler as well as
    // from the trigger above, so a delegate replacing this one picks the copy up
    // as it is built, which is the collapse this is written for; a card already
    // up on another screen sees nothing change and does not start a second copy,
    // which is the half of this that used to go wrong.
    //
    // ...AND THE HOLD ON THE COUNTDOWN WITH IT, on the same signal because an
    // object gets exactly one of these handlers and the two are the same duty
    // said about two different things: this card holds a picture claim and a
    // countdown that both outlive it, and a card destroyed mid-hover would leave
    // its notification stopped forever with nothing left anywhere that could
    // start it again. See `holdEntry`.
    Component.onDestruction: {
        root.releaseCopy();
        root.holding?.release(root);
    }

    Image {
        id: copier

        // NOT BOUND. See beginCopy: the assignment is what keeps the load alive
        // across the flag that stops the other screens' cards from repeating it.

        // Invisible, and it still renders: grabToImage takes an effect reference
        // on the item exactly the way `layer.enabled` does, which is why
        // G2Image's own hidden Image can be fed to a MultiEffect. It draws
        // nothing on the card and takes no room in any layout, being a child of
        // the card's root rather than of the body.
        visible: false
        asynchronous: true
        smooth: true
        // Never cached. This image is loaded once, read once, and then wanted
        // by nobody, and every one of them is a different url, so leaving them
        // in Qt's pixmap cache would be holding a decoded avatar per
        // notification for the life of the shell: the leak this whole change
        // exists to avoid, moved from the sender's memory into ours.
        cache: false

        // FULL SIZE, decoded, then scaled down by the item. `sourceSize` is
        // deliberately not set: it would have to be computed from the loaded
        // size, which is the ring G2Image warns about one screenful up, and the
        // pictures that arrive this way are avatars rather than photographs.
        //
        // The cap is FOUR badges, derived from the slot this will be drawn in
        // rather than picked: the card draws a picture at two badges, so this
        // keeps a copy with a doubling of headroom for a screen with more pixels
        // than points, and refuses to spend disk on the rest.
        readonly property real shrink: Math.min(1, root.copyCap / Math.max(1, implicitWidth, implicitHeight))

        width: implicitWidth * shrink
        height: implicitHeight * shrink

        onStatusChanged: {
            if (copier.status === Image.Ready)
                root.finishCopy();
            else if (copier.status === Image.Error)
                root.releaseCopy();
        }
    }

    // Behind the contents, so it cannot eat the action buttons' clicks, but
    // still covering the whole card so the throw can start anywhere on it.
    MouseArea {
        id: drag

        // The anchor is kept in the PARENT's coordinates, on BOTH axes. `mouse.x`
        // is relative to this item and this item is what moves, so as the card
        // slides right by d, mouse.x falls by d for the same physical pointer;
        // the invariant is `root.x + mouse.x`, and `root.y + mouse.y` is the same
        // expression on the axis the card never travels along itself. It is
        // recorded all the same, because the arbitration below cannot judge which
        // way a gesture went without both numbers, and the vertical one is the
        // one that used to be missing entirely.
        property real anchorX: 0
        property real anchorY: 0
        property real startedAt: 0
        property bool throwing: false

        // How fast the hand is moving along the throw axis, in pixels per
        // MILLISECOND, smoothed with the same 0.4 as everything else: the
        // last single event before a finger lifts is noise as often as it is
        // direction, and the smoothing is what turns a stream of jittery
        // steps into one number that means "how fast was the hand actually
        // going". The step is measured between successive values of the
        // parent-frame dx rather than raw mouse.x, for the same reason the
        // anchor is kept in parent coordinates: the card is the thing that
        // moves, so its own frame is the one ruler that lies.
        //
        // Per millisecond and NOT per event, because `committed` compares
        // this number against a threshold. Per-event was tried, on the
        // argument that the bottom edge smoothed per event and seemed fine; a
        // MAGNITUDE in px per event is really px times the device's event
        // rate, and that rate spans nearly an order of magnitude across
        // ordinary pointing hardware. The same physical flick that committed
        // from a touchpad would have failed from a 1000Hz mouse, whose steps
        // are small precisely because they are frequent. Dividing each step by
        // its own elapsed time is what GlideList and the settings pager's
        // scroll axis already do, for the same reason: only time divides the
        // event rate back out. The bottom edge is on the clock now too; it was
        // reading a per-event magnitude against `pullReversal` and got away
        // with it only because nobody had swiped it from two devices in a row.
        //
        // A STREAM IS A THIRD RATE AGAIN, which is what settled the argument
        // for good. A touchpad's scroll events arrive at neither a mouse's rate
        // nor a mouse's step size, so the two-finger path below would have
        // needed its own threshold had this number not already been in a unit
        // that means one thing everywhere.
        property real velocity: 0
        property real lastDx: 0
        // When the last step landed, so its dt can be measured: a velocity in
        // real time needs real time.
        property real lastEvent: 0

        // Whether THIS press turned into a hold. `root.pinned` is the lasting
        // answer and outlives the gesture on purpose; this one is per press,
        // because the release has to know what it is the end of and not what some
        // earlier press decided.
        property bool holding: false

        // WHOSE GESTURE A STREAM IS, latched, and the one piece of state the
        // scroll path needs that the drag path gets for free.
        //
        // On the drag path the LIST settles this. A finger that sets off up or
        // down the screen makes the Flickable steal the grab, the card hears
        // `canceled` instead of `released`, and it is out of that gesture for
        // good; the axis test below can afford to be re-asked on every move
        // because in practice it is only ever asked twice. A scroll has no grab
        // to steal and nothing can take it off the card, so the same test asked
        // repeatedly would let a long read down the tray latch a throw the
        // moment the hand drifted sideways at the end of it, a hundred pixels
        // into somebody's scrolling. So the stream's axis is decided ONCE and
        // stays decided, which is what every other gesture in this shell does
        // and what the positive latch below already did.
        property bool scrolling: false

        // Whether the press went UP OR DOWN the screen far enough to have meant
        // it, which is not the same question as whether anything scrolled.
        //
        // The list only takes the gesture off this card when it can actually
        // move: `view.interactive` is false while the tray fits, which is most of
        // the time, and a Flickable that is not interactive steals nothing. So a
        // swipe up a stack of two popups is never taken away, arrives at the
        // release with `throwing` still false, and would be read as a click and
        // DELETE the card: the same bug the arbitration below fixes, in the one
        // case where handing the gesture over is not what fixes it.
        //
        // A click is a press that stayed where it was put. Once the finger has
        // travelled a threshold's worth up or down, whatever it was, it was not a
        // click, and the release owes it nothing.
        property bool wandered: false

        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        // ONLY ONCE THE CARD HAS COMMITTED TO A THROW, which is the other half of
        // the arbitration below.
        //
        // It was a constant `true`, and with that this MouseArea won the press
        // and never gave it back: the Flickable the cards live in could not take
        // the grab for a scroll, so a finger that pressed a card and swiped up
        // moved nothing at all, and the release then found `throwing` false and
        // read the whole thing as a click, which DISMISSED the notification you
        // had merely touched on the way past. The list could only be scrolled
        // from the twelve pixels of gap between two cards.
        //
        // False for the whole of the undecided part leaves the Flickable free to
        // steal the gesture the moment it decides the finger is scrolling; true
        // from the instant the card latches locks it out for the rest of the
        // throw, which is what the flag was there for in the first place.
        preventStealing: drag.throwing
        // The gesture ADVERTISES itself. Drag is the primary way to get rid of a
        // notification (DESIGN.md 15) and nothing on the card says so; a hand
        // that closes when you press is the cheapest way to say it.
        cursorShape: drag.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        // THE GESTURE ITSELF, in functions rather than inside the press
        // handlers, so the drag path and the two-finger path RUN the same
        // machinery instead of merely agreeing about it. Pull's own refactor,
        // at the same seam: a second copy would drift, and this is the copy
        // with every hard-won correction in it, the axis judged once, the
        // velocity divided by its own dt, the sign gate on the flick commit.
        //
        // The split falls exactly where the two inputs differ, which is only
        // the ORIGIN: a press has a place on the card and has to remember it, a
        // scroll reports motion and has nothing to remember. Everything after
        // the subtraction is common.

        // A new gesture. Everything the press used to zero, and nothing about
        // where it started, because that is the one thing the two inputs do not
        // share.
        function begin(): void {
            drag.startedAt = root.dragX;
            drag.throwing = false;
            drag.scrolling = false;
            drag.holding = false;
            drag.wandered = false;
            drag.velocity = 0;
            drag.lastDx = 0;
            drag.lastEvent = Date.now();
        }

        onPressed: mouse => {
            // A PRESS TAKES THE GESTURE OVER, and takes it over cleanly. Both
            // paths write one set of state, so a stream still running when a
            // hand lands has to be concluded before the press touches any of
            // it: concluded by its own rule, so a card two fingers had already
            // thrown is ANSWERED rather than left halfway off the screen with
            // nothing arriving to say which way it went. Left alone instead,
            // the stream would still be holding a total measured from where the
            // fingers began, and its next event would hand that stale distance
            // to a state the press had since zeroed, jumping the card a
            // card-width in one step. Pull's line, for Pull's reason.
            scroll.finish();

            drag.anchorX = root.x + mouse.x;
            drag.anchorY = root.y + mouse.y;
            drag.begin();
        }

        onPositionChanged: mouse => {
            if (!drag.pressed)
                return;

            drag.advance(root.x + mouse.x - drag.anchorX, root.y + mouse.y - drag.anchorY);
        }

        // One step, given how far the gesture has travelled IN TOTAL since it
        // began. Totals rather than steps, because the threshold, the
        // arbitration and the offset are all questions about the whole journey,
        // and because a path that reported steps would have to keep its own
        // running sum, which is this subtraction written a second time
        // somewhere it can go stale.
        function advance(dx: real, dy: real): void {
            // Smoothed on EVERY move, before the arbitration below has decided
            // whose gesture this is, exactly the way LaunchEdge does it. The
            // flick this number exists to catch is over almost as soon as it
            // has latched, so a velocity that only started counting once
            // `throwing` was true would have a couple of events of history at
            // the release where the smoothing needs a handful; the pre-latch
            // motion is real motion and it belongs in the average. Counting it
            // costs nothing when the gesture turns out to be the list's,
            // because an unlatched release never reads it.
            //
            // The dt clamp is GlideList's, both ends of it: a floor of one so
            // a burst of events landing inside the same millisecond cannot
            // divide toward infinity, a ceiling of a hundred so the first
            // step after the press, or after a mid-drag pause, reads as slow
            // rather than being spread over a stale timestamp.
            const now = Date.now();
            const dt = Math.max(1, Math.min(100, now - drag.lastEvent));
            drag.lastEvent = now;
            const step = dx - drag.lastDx;
            drag.lastDx = dx;
            drag.velocity += (step / dt - drag.velocity) * 0.4;

            // WHOSE GESTURE IS THIS: the card's, or the list's.
            //
            // Both of them begin as a press on a card and there is nothing in the
            // press itself to tell them apart, so the card takes no position at
            // all until one axis has won. Vertical wins and this returns without
            // latching, which leaves `preventStealing` false and the enclosing
            // Flickable free to take the grab and scroll with the finger; the card
            // then hears `canceled` instead of `released` and stays exactly where
            // it was.
            //
            // Horizontal has to do TWO things to win. It has to travel past the
            // threshold, so the wobble inside a click is not a throw, and it has
            // to dominate the vertical, so a flick that is mostly up the screen is
            // a scroll rather than a dismissal that happened to drift sideways. A
            // threshold on its own is not arbitration: the first few pixels of a
            // scroll cross it too, on whichever axis is being measured.
            //
            // Which is exactly what the old code did, and it is worth saying
            // plainly. There was not merely no arbitration here, there was no
            // vertical MEASUREMENT: the delta was the horizontal one and nothing
            // ever looked at dy, so a straight swipe up produced a delta of about
            // zero, never reached the threshold, never latched, and arrived at the
            // release indistinguishable from a click. Between that and a
            // `preventStealing` nobody could take back, swiping the list scrolled
            // nothing and deleted the notification you started on.
            //
            // Decided ONCE, like every other gesture in the shell: past this the
            // card owns the pointer and a throw that curves upward is still a
            // throw. Re-testing on every move would let the list snatch a card
            // that was already half way off the screen.
            if (!drag.throwing) {
                if (Math.abs(dy) >= Appearance.sizes.dragThreshold)
                    drag.wandered = true;
                if (Math.abs(dy) > Math.abs(dx))
                    return;
                if (Math.abs(dx) < Appearance.sizes.dragThreshold)
                    return;
                drag.throwing = true;
            }

            root.pulled = dx;
            root.dragX = root.resist(drag.startedAt + dx);
        }

        // THE STREAM'S OWN ARBITRATION, which is the same question the drag
        // path asks and the drag path only has to answer half of.
        //
        // Everything above is reachable by two fingers unchanged; the one thing
        // that is not is what happens when the gesture turns out to be the
        // LIST'S. A press hands itself over by simply not latching, because the
        // Flickable then steals the grab and the card is out of it. A stream
        // cannot be stolen, so the handing over has to be written down: once
        // the fingers have gone far enough up or down the screen to have meant
        // it, and further that way than sideways, this stream is the tray's for
        // the rest of its life and the card is finished with it. See
        // `scrolling` for why that has to LATCH where the drag path's version
        // does not.
        //
        // Both terms, and both for the reason the arbitration above gives: the
        // vertical has to dominate, so a throw that curves upward is still a
        // throw, and it has to clear the same threshold, so the first pixel of
        // noise in a sideways hand does not give the whole stream away.
        function stream(dx: real, dy: real): void {
            if (!drag.throwing) {
                if (drag.scrolling)
                    return;

                if (Math.abs(dy) > Math.abs(dx) && Math.abs(dy) >= Appearance.sizes.dragThreshold) {
                    drag.scrolling = true;
                    return;
                }
            }

            drag.advance(dx, dy);
        }

        // Long enough to be a decision rather than a press. See `pinned`: this is
        // the finger's way of saying what a cursor says by resting on the card,
        // and it is the only one it has.
        //
        // NOT DURING A THROW. Qt runs this timer off the press alone and never
        // cancels it for movement, so a card dragged out slowly and thought
        // better of would cross the interval on the way and come back silently
        // pinned. A hand on its way somewhere is not a hand reading something.
        onPressAndHold: {
            if (throwing)
                return;
            holding = true;
            root.pin(true);
        }

        onReleased: {
            // A click, which dismisses too: a mouse user who expects that should
            // not be told they are holding it wrong. It has no direction, so it
            // collapses in place rather than flinging.
            //
            // UNLESS the press became a hold. The two gestures differ only in how
            // long the finger stayed down, so a hold that dismissed on release
            // would hand the card back the instant you finished pinning it, and
            // "keep this one" and "throw this one away" would be the same motion
            // told apart by a stopwatch nobody can see. The keep survives; the
            // click that would have followed it does not happen.
            //
            // `holding` and not `root.pinned`, and the difference matters. A pin
            // outlives the press that made it, so guarding on it would mean a
            // pinned card could never be clicked away again, which takes back the
            // one thing DESIGN.md 15 promises a mouse user. This flag is about
            // this press only: hold once to pin, and a plain click afterwards
            // still dismisses (and a pinned card dismissed merely goes to the
            // hub, which is the whole point of the pin).
            //
            // ...and unless the finger wandered up or down the screen. See
            // `wandered`: a list too short to scroll never takes the gesture off
            // the card at all, so without this the arbitration above would only
            // save the tray that HAS somewhere to scroll to, and the two popups
            // you swipe at most often would go on deleting themselves.
            if (!drag.throwing) {
                if (!drag.holding && !drag.wandered)
                    root.dismissed();
                return;
            }

            drag.conclude();
        }

        // The end, however the input announced it: a lifted button, or a
        // touchpad stream that stopped sending.
        //
        // THE CLICK IS NOT IN HERE, and neither are the two things that veto
        // it, and that absence is the one part of this split worth checking
        // twice. A press that stayed where it was put is a click and a click
        // dismisses; a stream that travelled nowhere did NOTHING, because there
        // was no press for it to have been instead. `holding` and `wandered`
        // are both answers to that same question about a press, so all three
        // stay in onReleased together. Moved in here, two fingers resting on a
        // card would delete it, which is the shortest possible route to a tray
        // that empties itself.
        function conclude(): void {
            if (!drag.throwing)
                return;

            // RIGHT THROWS IT AWAY, LEFT PINS IT.
            //
            // The side is read off the drag OFFSET and never off the velocity,
            // which is what this branch used to pick a fling direction with. A
            // speed commit that reaches this line agrees with the offset by
            // construction, because `committed` refuses any whose velocity
            // opposes it (that shape is the cancel gesture, not a throw), and a
            // distance commit is out past the commit line on the offset's side
            // already. With two different OUTCOMES hanging off the sign rather
            // than two directions of the same one, reading it off the wrong
            // number would not merely fly the card oddly, it would keep the
            // notification you meant to throw away.
            if (root.committed && root.pulled > 0) {
                root.flung = 1;
                return root.dismissed();
            }

            // A PIN, and then home. It TOGGLES, so the gesture undoes itself:
            // there is no other way to take a pin off, and a swipe that could
            // only ever add one would be a decision with no way back.
            if (root.committed)
                root.pin(!root.pinned);

            // Abandoned short of the commit point, or pinned: hand the offset to
            // the spring and let it walk home rather than snapping. A pinned card
            // is one that STAYS, so it has to come back to where it was.
            settle.value = root.dragX;
            settle.target = 0;
            root.pulled = 0;
            drag.throwing = false;
        }

        // THE FLICKABLE TOOK IT, which is the arbitration above succeeding rather
        // than anything going wrong. A stolen grab arrives here instead of at
        // `onReleased`, and that difference is the whole reason this handler has
        // to exist: `onReleased` dismisses, and a gesture that turned out to
        // belong to the list must leave the card precisely as it found it.
        //
        // Usually nothing has moved, because a gesture can only be stolen while
        // the card has not latched and an unlatched card has not written a pixel.
        // The offset is walked home by the same spring the release uses anyway,
        // rather than assumed to be zero: a cancel also arrives when the window
        // loses the grab under a throw already in flight, and that one has a real
        // offset to give back.
        onCanceled: {
            settle.value = root.dragX;
            settle.target = 0;
            root.pulled = 0;
            drag.throwing = false;
            drag.holding = false;
            drag.wandered = false;
            drag.scrolling = false;
        }

        // THE SCROLL PATH: two fingers across a card throw it away, exactly as
        // dragging it does. The shell's rule (see components/ScrollGesture.qml)
        // rather than this card's idea, which is why the machinery above was
        // split out to be shared rather than a second throw written here.
        //
        // THIS IS THE DELICATE ONE, and the reason is geometry. Wheel events go
        // to the topmost item under the pointer and stop at the first one that
        // accepts, and the topmost item over a card is the card: it sits INSIDE
        // the tray's Flickable, so it is a descendant and is offered every
        // scroll before the list that the scroll is nearly always meant for. A
        // card that simply took what it was offered would be a tray that could
        // not be scrolled anywhere except the twelve pixels of gap between two
        // rows, which is the exact bug `preventStealing` above was narrowed to
        // fix, reintroduced through the other input.
        //
        // So the card gives the event BACK, on the same test and at the same
        // instant `preventStealing` goes true: `accepted` is false for the
        // whole of the undecided part and false forever once the stream has
        // been judged the list's, and it is true only while a throw is latched.
        // The event then carries on to the Flickable and the tray scrolls.
        //
        // THE UNDECIDED EVENTS GO TO THE LIST rather than being held back, and
        // that is the deliberate half of it. They cannot be handed on later:
        // QML has no way to re-dispatch an event it consumed, so anything held
        // back while the axis is being judged is simply lost, and losing the
        // first events of a scroll is losing the first events of EVERY scroll
        // in the tray, since the cards are what the tray is made of. Given
        // away, they cost a horizontal swipe almost nothing, because a swipe
        // sideways reports a vertical pixelDelta of about zero and the list
        // moves by that: the noise in a sideways hand, not a scroll.
        onWheel: wheel => {
            // A PRESS OWNS THE GESTURE WHILE IT LASTS. Both paths write one set
            // of state, so a scroll arriving mid-drag would be two inputs
            // steering the same throw. Refusing rather than ignoring, so the
            // event still reaches the list underneath.
            if (drag.pressed) {
                wheel.accepted = false;
                return;
            }

            // A MOUSE WHEEL IS NOT A SWIPE. feed() refuses it and sets
            // `accepted` false itself, so a notch falls straight through to the
            // Flickable and scrolls the tray exactly as it did before this
            // handler existed. Returning here rather than falling into the line
            // below, which would read `throwing` off whatever the last stream
            // left behind.
            if (!scroll.feed(wheel))
                return;

            wheel.accepted = drag.throwing;
        }

        ScrollGesture {
            id: scroll

            // A stream is a press, a total is a delta, and a lapse is a
            // release. The middle one goes through the stream's own arbitration
            // rather than straight into advance(): see stream() for the one
            // thing two fingers have to decide that a finger does not.
            onBegan: drag.begin()
            onMoved: (dx, dy) => drag.stream(dx, dy)
            onEnded: drag.conclude()
        }
    }
}
