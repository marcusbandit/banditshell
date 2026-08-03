pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
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

    readonly property var notification: entry?.notification ?? null
    readonly property bool urgent: !!notification && notification.urgency === NotificationUrgency.Critical

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

    // Which way it was THROWN, if it was: -1, 0 or +1.
    //
    // A card let go past the commit point should keep going. Without this it
    // stopped dead wherever the pointer stopped and then collapsed in place,
    // which reads as the throw being ignored and the card dying of something
    // else. The fling rides `leave`, so it is the same one motion as the
    // collapse rather than a second animation racing it.
    property int flung: 0

    readonly property real throwDistance: fullWidth * Appearance.sizes.dragDismissFraction
    readonly property bool committed: Math.abs(pulled) >= throwDistance

    // Where the card actually sits: the drag, plus however much of the fling has
    // played. At leave = 1 it is exactly one card-width clear of home.
    readonly property real throwX: dragX + flung * leave * Math.max(0, fullWidth - Math.abs(dragX))

    // The countdown belongs to the ENTRY, not to this card. A Repeater over a
    // plain array rebuilds every delegate when the array changes, so state kept
    // here was reset by a neighbour being dismissed and nothing ever expired
    // after the first one.
    readonly property int timeout: entry?.timeout ?? 0
    readonly property real remaining: entry?.remaining ?? 0

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
    readonly property bool held: hover.hovered || drag.pressed
    onHeldChanged: if (entry)
        entry.held = held

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
    opacity: open * Math.max(0.1, 1 - Math.max(0, Math.abs(throwX) - throwDistance * Appearance.sizes.dragResistance) / (fullWidth * 0.6))

    HoverHandler {
        id: hover
    }

    Component.onCompleted: grow.target = 1

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

    // How long it has left, along the bottom edge. Without it, a notification
    // vanishing mid-read reads as a glitch rather than as a timer.
    //
    // A label tier when it is paused rather than the ACCENT. The accent is for
    // state that is wrong (the urgent bar above is the only one on this card),
    // and "you are touching it" is not that; brightening the same line says the
    // same thing without spending the one colour the shell reserves.
    G2Rect {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Appearance.padding.normal
        width: Math.max(0, (parent.width - Appearance.padding.normal * 2) * root.remaining)
        height: 2
        radius: 1
        color: root.held ? Appearance.colour.textDim : Appearance.colour.fillStronger
        visible: root.timeout > 0
    }

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
        implicitHeight: Math.max(badge.height, text.implicitHeight)

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

            // An icon NAME is not a URL. `appIcon` is a freedesktop name, so
            // handing it straight to an Image failed silently and every app that
            // sent one instead of a pixmap wore the generic bell. The theme has
            // to be asked; the nullable form returns "" rather than a
            // placeholder, which is what lets the glyph take over.
            readonly property string picture: root.notification?.image ?? ""
            readonly property string mark: root.notification?.appIcon ? Quickshell.iconPath(root.notification.appIcon, true) : ""

            readonly property string source: badge.picture || badge.mark
            readonly property bool hasImage: source !== "" && art.ready

            // Square either way, so the text column starts in the same place on
            // every card and a list of them reads as a column rather than as a
            // ragged edge. Which square depends on whether there is anything
            // worth looking at.
            //
            // TWICE THE BADGE, derived rather than configured. It is the same
            // slot doing a second job, so it has no business being a number
            // anyone can move independently: the day the badge changed, a
            // separate setting would quietly stop being twice it.
            width: Appearance.sizes.notificationBadge * (badge.picture ? 2 : 1)
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

            // A MARK is cropped to fill and a PICTURE is fitted whole.
            //
            // An app icon is square already, so filling its plate costs it
            // nothing and letterboxing it would leave a step of fill at the
            // corners, which reads as the icon not fitting. A picture is not
            // square and is the thing you are being shown, so the same crop that
            // is free for the one throws most of the other away.
            //
            // Either way it is masked to the plate's curve, because an image is
            // the one shape that cannot go through G2Rect: it is a texture, not
            // a path, so it would keep its own square corners over the plate's.
            // See G2Image.
            G2Image {
                id: art

                anchors.fill: parent
                source: badge.source
                fillMode: badge.picture ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                radius: Appearance.rounding.small
            }
        }

        Column {
            id: text

            anchors.left: badge.right
            anchors.leftMargin: Appearance.padding.normal
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 0

            StyledText {
                width: parent.width
                visible: !!root.notification?.appName
                text: root.notification?.appName ?? ""
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
            StyledText {
                width: parent.width
                text: root.notification?.summary ?? ""
                wrapMode: Text.Wrap
                maximumLineCount: root.roomy ? 4 : 2
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                visible: !!root.notification?.body
                text: root.notification?.body ?? ""
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textDim
                wrapMode: Text.Wrap
                // A notification is not a document, but three lines is where the
                // cap has to be. Two was tried, to keep the cards short, and it
                // elided the 2FA code out of "Your verification code for The
                // Movie Database (TMDB) is: 4098" - which is the whole reason
                // that notification exists. A card is allowed to be one line box
                // taller than its neighbour; it is not allowed to hide the thing
                // it came to say.
                //
                // In the hub it is barely a cap at all. The tray is a Flickable
                // that scrolls once it outgrows the screen, so a long message
                // costs a scroll rather than the screen, and the cap is only
                // still here to stop one deranged sender from making the list
                // unnavigable.
                maximumLineCount: root.roomy ? 12 : 3
                elide: Text.ElideRight
                topPadding: Appearance.padding.small
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
                visible: (root.notification?.actions?.length ?? 0) > 0
                topPadding: Appearance.padding.normal
                spacing: Appearance.padding.small

                Repeater {
                    model: root.notification?.actions ?? []

                    delegate: Pill {
                        required property var modelData

                        text: modelData.text
                        width: Math.min(implicitWidth, actions.width)

                        onClicked: {
                            modelData.invoke();
                            root.dismissed();
                        }
                    }
                }
            }
        }
    }

    // Behind the contents, so it cannot eat the action buttons' clicks, but
    // still covering the whole card so the throw can start anywhere on it.
    MouseArea {
        id: drag

        // The anchor is kept in the PARENT's coordinates. `mouse.x` is relative
        // to this item and this item is what moves, so as the card slides right
        // by d, mouse.x falls by d for the same physical pointer; the invariant
        // is `root.x + mouse.x`.
        property real anchor: 0
        property real startedAt: 0
        property bool throwing: false

        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        preventStealing: true
        // The gesture ADVERTISES itself. Drag is the primary way to get rid of a
        // notification (DESIGN.md 15) and nothing on the card says so; a hand
        // that closes when you press is the cheapest way to say it.
        cursorShape: drag.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        onPressed: mouse => {
            anchor = root.x + mouse.x;
            startedAt = root.dragX;
            throwing = false;
        }

        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const delta = root.x + mouse.x - anchor;
            if (!throwing && Math.abs(delta) < Appearance.sizes.dragThreshold)
                return;
            throwing = true;
            root.pulled = delta;
            root.dragX = root.resist(startedAt + delta);
        }

        onReleased: {
            // A click, which dismisses too: a mouse user who expects that should
            // not be told they are holding it wrong. It has no direction, so it
            // collapses in place rather than flinging.
            if (!throwing)
                return root.dismissed();

            if (root.committed) {
                root.flung = root.pulled < 0 ? -1 : 1;
                return root.dismissed();
            }

            // Abandoned short of the commit point: hand the offset to the spring
            // and let it walk home rather than snapping.
            settle.value = root.dragX;
            settle.target = 0;
            root.pulled = 0;
            throwing = false;
        }
    }
}
