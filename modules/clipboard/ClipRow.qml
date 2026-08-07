pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// ONE THING THAT WAS COPIED.
//
// A launcher row is a NAME: short, and recognised before it is read. This is a
// fragment of whatever you were doing, and the only thing that tells one of them
// from the three others copied out of the same file is how much of it you can
// see. So the row is generous, the picture is a picture rather than a caption
// saying there is one, and the kind is a mark you can find by shape before you
// have read any of the text.
//
// THROWN AWAY RATHER THAN DISMISSED (DESIGN.md 15). The row follows the hand and
// fades as it goes, so the gesture says what it will do before it is finished,
// and dragging back cancels. Clicking still copies, because a mouse user who
// expects that should not be told they are holding it wrong.
Item {
    id: root

    required property var entry
    required property int index

    // WHICH ROW THE KEYBOARD IS ON, and separately which one the pointer is
    // over. Two questions, and NiagaraLauncher's note says why they must not be
    // one: hover used to move the selection, and it cannot, because the pointer
    // is not the only thing that moves. Type a letter and the list under a
    // perfectly still cursor is a different list. So hover is only a look.
    property bool selected: false

    signal activated
    signal pinned
    signal discarded
    // What the pointer is doing, reported up so the list can hold one hovered
    // index rather than each row holding its own opinion.
    signal entered
    signal exited

    readonly property bool isImage: root.entry.kind === "image" && !!root.entry.file
    readonly property bool hovered: hover.hovered

    // How far the hand has thrown it, in pixels, and which way. Signed, because
    // a row can be thrown to either side and the fade is the same on both.
    property real thrown: 0
    property bool throwing: false

    readonly property real throwFull: Math.max(1, root.width * Appearance.sizes.dragDismissFraction)
    readonly property real throwFraction: Math.min(1, Math.abs(root.thrown) / root.throwFull)

    implicitHeight: (root.isImage ? Appearance.sizes.clipboardPreview : Math.max(Appearance.sizes.rowHeight, body.implicitHeight + Appearance.padding.normal * 2)) + Appearance.padding.small

    // WHERE THE ROW IS, which is where the hand left it or where it is returning
    // from. A Follow rather than a Behavior: the throw ends at whatever distance
    // the hand happened to reach, and a fixed duration over a variable distance
    // is a different speed every time.
    Follow {
        id: slide

        speed: Appearance.anim.revealSpeed
        target: root.throwing ? root.thrown : 0
    }

    // Resisted, so the row reads as attached to the list rather than loose on
    // it: it moves with the hand and less far than the hand, which is what says
    // "this will come back" right up until it does not.
    readonly property real offset: slide.value * Appearance.sizes.dragResistance

    Item {
        id: card

        x: root.offset
        width: root.width
        height: root.height - Appearance.padding.small
        // Fades as it goes, so the gesture states its outcome before the release
        // decides it. Never all the way to nothing while the hand is still on
        // it: an invisible row that could still be dragged back would be a
        // gesture with nothing to reverse.
        opacity: 1 - root.throwFraction * 0.7

        G2Rect {
            anchors.fill: parent
            // The full radius, not the small one. MenuRow's note: at 9px on a
            // 48px row the G2 ramp has no budget left and renders as the plain
            // circular arc it exists to replace.
            radius: Appearance.rounding.normal
            color: root.selected ? Appearance.colour.fillStrong : Appearance.colour.fill
            opacity: root.selected || root.hovered ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        // WHAT IS ON THE CLIPBOARD RIGHT NOW, marked by a rule down the leading
        // edge rather than by a fill. A fill is already saying two other things
        // here (hover, and where the keyboard is), and a third weight of the
        // same light would be indistinguishable from both. A rule at the accent
        // is the one piece of state in this list worth a hue: which of these you
        // would get by pasting without opening this at all.
        G2Rect {
            x: Appearance.padding.small
            anchors.verticalCenter: parent.verticalCenter
            width: Appearance.font.stem
            height: parent.height - Appearance.padding.normal * 2
            radius: width / 2
            color: Appearance.colour.accent
            visible: Clipboard.current === root.entry.id
        }

        // THE MARK: what kind of thing this is, found by shape before it is
        // read. A picture is its own mark, because a thumbnail answers "which
        // screenshot" and the word "image" never does.
        Item {
            id: markSlot

            x: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter

            // A THUMBNAIL KEEPS THE PICTURE'S OWN PROPORTIONS, which is the
            // whole of why it is worth showing. The plate is as tall as the row
            // and as wide as that height and the aspect say, so a wide
            // screenshot is a wide plate and a phone screenshot is a narrow one,
            // and the SHAPE is already half the recognition before any of the
            // content is.
            //
            // Clamped at both ends, because neither extreme is recognisable: a
            // panorama would take the row and leave no room for anything else,
            // and a single tall column would come out a sliver too narrow to
            // show what it is of. The clamps are ratios rather than pixels, so
            // they hold at any preview size.
            readonly property real minAspect: 0.5
            readonly property real maxAspect: 2.5

            // TAKEN FROM THE ENTRY, not from the live decode, and never gated on
            // `ready`. Both of those were the flicker.
            //
            // Reading the loaded image's aspect makes the width depend on a
            // decode whose size depends on the width, which does not settle; and
            // falling back to 1 whenever `ready` went false meant every reload
            // that loop caused also snapped the plate back to square, so the
            // thumbnail pulsed between square and its real shape indefinitely.
            // The service remembers each picture's size the first time anything
            // measures it, so the shape is known before the file is opened, on
            // every appearance after the first, and across restarts.
            // The true pixels first, the measured ratio second, square only
            // while neither is known yet.
            readonly property real known: root.entry.w > 0 && root.entry.h > 0 ? root.entry.w / root.entry.h : root.entry.aspect > 0 ? root.entry.aspect : 0
            readonly property real aspect: known > 0 ? Math.max(minAspect, Math.min(known, maxAspect)) : 1

            width: root.isImage ? Math.round(height * aspect) : Appearance.sizes.clipboardIcon
            height: root.isImage ? parent.height - Appearance.padding.normal * 2 : Appearance.sizes.clipboardIcon

            // No Behavior on width. An animation here was smoothing over the
            // oscillation rather than a real transition: with the size known up
            // front the plate is simply the right shape when it is built, and a
            // width that animates on creation would be motion answering nothing.

            G2Image {
                id: thumb

                anchors.fill: parent
                visible: root.isImage
                source: root.isImage ? `file://${root.entry.file}` : ""
                radius: Appearance.rounding.small
                fillMode: Image.PreserveAspectCrop

                // THE DECODE IS PINNED TO THE HEIGHT, which is the row's and owes
                // nothing to the picture. Left at the item's own size it would
                // follow the width, and the width follows the aspect: see this
                // property's note in G2Image.
                decodeWidth: 0
                decodeHeight: markSlot.height

                // Measured once, then written down. On the STATUS, not on the
                // implicit width: the width settles before the delegate's entry
                // is bound, so a handler on it fired once with no entry to
                // report against and never again, and every picture stayed
                // square. Ready is the moment both facts exist.
                //
                // Reported on every load, because a rebuilt delegate has no
                // memory of its own; the service drops what it already knows.
                onStatusChanged: if (thumb.status === Image.Ready && thumb.implicitSourceHeight > 0)
                    Clipboard.noteAspect(root.entry.id, thumb.implicitSourceWidth / thumb.implicitSourceHeight)
            }

            // A PICTURE THAT IS NOT THERE, which is not hypothetical: an entry
            // imported from clipse points at a file clipse's own `-clean` may
            // since have reaped, and the copy this shell takes at import can
            // fail on a full disk. Saying so is better than an empty plate that
            // reads as a picture still loading.
            Icon {
                anchors.centerIn: parent
                visible: root.isImage && thumb.status === Image.Error
                name: "broken_image"
                size: Appearance.sizes.clipboardIcon
                color: Appearance.colour.textFaint
            }

            // A SWATCH, for the one kind that is a colour rather than about one.
            // Six characters of hex say nothing about which green they are, and
            // this says it without being read at all.
            G2Rect {
                anchors.centerIn: parent
                width: Appearance.font.iconSize
                height: width
                radius: height / 2
                visible: root.entry.kind === "colour"
                color: root.swatch
                stroke: Appearance.colour.separator
                strokeWidth: Appearance.font.stem
            }

            Icon {
                anchors.centerIn: parent
                visible: !root.isImage && root.entry.kind !== "colour"
                name: Clipboard.markFor(root.entry.kind)
                size: Appearance.sizes.clipboardIcon
                color: root.selected ? Appearance.colour.text : Appearance.colour.textFaint

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }
        }

        Column {
            id: body

            anchors.left: markSlot.right
            anchors.leftMargin: Appearance.padding.normal
            anchors.right: trailing.left
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.padding.small / 2

            StyledText {
                width: parent.width
                text: root.title
                color: root.selected ? Appearance.colour.text : Appearance.colour.textDim
                // Wrapped rather than run off, and capped: a paste is not a
                // paragraph you read here, it is one you recognise. Beyond the
                // cap the row would be showing content at the expense of the
                // rows around it, which is the only thing that makes this list
                // scannable.
                maximumLineCount: root.isImage ? 1 : Appearance.sizes.clipboardLines
                wrapMode: Text.Wrap
                elide: Text.ElideRight

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            // WHAT IT IS AND WHEN, in the quietest tier there is. Hierarchy by
            // colour rather than by size: there are three sizes in this shell
            // and a timestamp is not what a view is about.
            StyledText {
                width: parent.width
                text: root.detail
                color: Appearance.colour.textFaint
                elide: Text.ElideRight
            }
        }

        Row {
            id: trailing

            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.padding.small

            // KEPT. Shown always when it is on, and on hover when it is not, so
            // the way to pin a thing is discoverable by pointing at it and the
            // fact that a thing IS pinned never depends on pointing at it.
            Item {
                width: Appearance.sizes.minTarget
                height: Appearance.sizes.minTarget
                visible: root.entry.pinned || root.hovered

                Icon {
                    anchors.centerIn: parent
                    name: "keep"
                    fill: root.entry.pinned ? 1 : 0
                    size: Appearance.font.iconSize
                    color: root.entry.pinned ? Appearance.colour.accent : pinPress.containsMouse ? Appearance.colour.text : Appearance.colour.textFaint

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }

                MouseArea {
                    id: pinPress

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pinned()
                }

                HoverTip {
                    text: root.entry.pinned ? "Let go of this" : "Keep this"
                }
            }
        }
    }

    // WHAT THE ROW IS CALLED.
    //
    // A PICTURE IS NOT CALLED ANYTHING, and pretending otherwise was the first
    // version's mistake: entries recorded here are named by content hash, so the
    // row read "7863a832a145258e88df11e15f59896d.png", which is a filename that
    // exists only so two identical screenshots share one file and which tells a
    // person nothing whatsoever. The thumbnail is the identifier. What the line
    // beside it can usefully add is the one thing the thumbnail cannot show at
    // that size, which is how big the picture actually is.
    readonly property string title: {
        if (!root.isImage)
            return Clipboard.summarise(root.entry);
        // THE RECORDED size, read off the file's own header when it was
        // captured, so the caption is right on the frame the row is built rather
        // than changing under the eye a moment later. Never the decode's: that
        // reports the size of the copy asked for, which is the row's height, and
        // captioning a screenshot with the size of its thumbnail would be a
        // measurement the interface did not make.
        if (root.entry.w > 0)
            return `${root.entry.w} × ${root.entry.h}`;
        return thumb.status === Image.Error ? "Picture (missing)" : "Picture";
    }

    // WHAT KIND, AND WHEN. Assembled here rather than in the service because it
    // is a sentence for a person to read and the service's job is the fact.
    readonly property string detail: {
        const parts = [];
        parts.push(root.entry.kind);
        const bytes = Clipboard.size(root.entry.bytes);
        if (bytes)
            parts.push(bytes);
        if (root.entry.kind === "files" || root.entry.kind === "audio" || root.entry.kind === "video" || root.entry.kind === "document") {
            const missing = (root.entry.mimes ?? []).filter(m => !m).length;
            if (missing)
                parts.push(missing === (root.entry.paths ?? []).length ? "gone" : `${missing} gone`);
        }
        parts.push(Clipboard.age(root.entry.recorded));
        return parts.join("  ·  ");
    }

    // A colour entry's actual colour, guarded: the text passed a shape test, not
    // a parse, and Qt turns an unparseable string into an error on the console
    // plus whatever it felt like drawing.
    readonly property color swatch: {
        const t = (root.entry.text ?? "").trim();
        const hex = t.startsWith("#") ? t : `#${t}`;
        return /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(hex) ? hex : Appearance.colour.textFaint;
    }

    // A HANDLER, not a MouseArea, so it composes: Qt hands hover to the topmost
    // MouseArea only, and the pin button above is one. With a MouseArea here the
    // row would go un-hovered the moment the pointer reached its own controls,
    // which is exactly when the controls need to be visible.
    //
    // It is also the only thing that reports hover: a MouseArea's press calls
    // setHovered itself, so on a touchscreen a tap would light the row up as
    // though a cursor were resting on it and leave it lit after the finger left.
    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hover.hovered)
                root.entered();
            else
                root.exited();
        }
    }

    // THE PRESS, and the throw.
    //
    // Hand-rolled on a MouseArea, and DELIBERATELY WITHOUT ScrollGesture, which
    // is the one place in this shell a drag does not also answer two fingers.
    // The reason is that the motion is already spoken for on both axes: two
    // fingers up and down is the list scrolling, and two fingers across is the
    // panel changing tabs. A row that also claimed the horizontal stream would
    // take the first event of every tab swipe made over a row, which is every
    // tab swipe. The gesture is not lost to anyone: a finger on a screen and a
    // press-drag on a touchpad both arrive here as a press, which is what a
    // throw is on every input this shell runs on.
    MouseArea {
        id: press

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        // No hoverEnabled: the handler above owns hover, and a MouseArea that
        // enabled it would take hover away from the pin button it sits under.

        property real fromX: 0
        property real fromY: 0
        property bool moved: false
        property bool spent: false
        property bool held: false
        property real velocity: 0
        property real lastAt: 0
        property real lastX: 0

        onPressed: mouse => {
            press.fromX = mouse.x;
            press.fromY = mouse.y;
            press.moved = false;
            press.spent = false;
            press.held = false;
            press.velocity = 0;
            press.lastX = 0;
            press.lastAt = Date.now();
        }

        onPositionChanged: mouse => {
            if (!press.pressed || press.spent)
                return;

            const dx = mouse.x - press.fromX;
            const dy = mouse.y - press.fromY;

            // The recognition distance, and the shell's own rather than Qt's:
            // 6px, because a touchpad flick covers less ground than a finger and
            // should still commit (DESIGN.md 15).
            if (!press.moved && Math.hypot(dx, dy) < Appearance.sizes.dragThreshold)
                return;

            // WHICH WAY IT SET OFF, decided ONCE and never revisited, which is
            // Pull's rule and is here for Pull's reason: a gesture that could
            // change its mind about what it IS partway through would let a
            // wandering hand start scrolling the list and finish by throwing a
            // row away. A press that set off downward is the list being dragged
            // and this row has no business capturing it, so it is spent for the
            // rest of this press rather than merely ignored this frame.
            if (!press.moved) {
                if (Math.abs(dx) <= Math.abs(dy)) {
                    press.spent = true;
                    return;
                }
                press.moved = true;
                root.throwing = true;
                press.preventStealing = true;
            }

            const now = Date.now();
            const dt = Math.max(1, Math.min(100, now - press.lastAt));
            press.lastAt = now;
            press.velocity += ((dx - press.lastX) / dt - press.velocity) * 0.4;
            press.lastX = dx;

            root.thrown = dx;
        }

        onReleased: {
            press.preventStealing = false;

            if (!press.moved) {
                // A press that went the wrong way is not a tap. It was a gesture
                // aimed at the list, and answering it by copying would paste
                // something because somebody scrolled.
                if (!press.held && !press.spent)
                    root.activated();
                press.spent = false;
                root.throwing = false;
                return;
            }

            // COMMITTED BY MOMENTUM, not by position, which is what makes a
            // flick work and a slow deliberate push equally work. Away and still
            // moving away goes; far enough and not coming back goes; anything
            // else returns. `flickVelocity` is in pixels per millisecond here,
            // the same unit the velocity above is smoothed in.
            const away = Math.sign(root.thrown) === Math.sign(press.velocity) && Math.abs(press.velocity) > Appearance.sizes.flickVelocity;
            const far = root.throwFraction >= 1 && Math.abs(press.velocity) < Appearance.sizes.pullReversal;

            if (away || far) {
                // Sent the rest of the way rather than vanishing, so the row
                // leaves in the direction it was thrown instead of blinking out
                // from wherever the hand let go.
                root.thrown = Math.sign(root.thrown) * root.width;
                root.discarded();
                return;
            }

            root.throwing = false;
            root.thrown = 0;
        }

        onCanceled: {
            // A cancel is not a release: the grab was taken away, nobody decided
            // anything, and the row goes back.
            press.preventStealing = false;
            press.moved = false;
            press.spent = false;
            root.throwing = false;
            root.thrown = 0;
        }

        // A press held down is the touch equivalent of the right button, and
        // both land on the same thing: keeping it. The latch stops the release
        // above from also reading as a tap and copying the entry the hold was
        // meant to pin.
        onPressAndHold: {
            press.held = true;
            root.pinned();
        }

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.pinned();
        }
    }
}
