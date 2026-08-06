pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// THE WALLPAPER PICKER, and the second thing the bottom edge does.
//
// Swipe up and the launcher comes out of the bottom of the screen. Swipe up
// AGAIN, from the same edge, and the launcher goes and this takes its place:
// one gesture, repeated, walking through the two things that live down there.
// It is not a mode you enter and it is not a tab you press, it is the same
// motion asked twice, which is the only kind of second gesture worth having on
// a touchscreen.
//
// BUILT FOR A FINGER, and that is what makes it a different shape from
// everything else in this shell. The other panels are lists of rows because a
// row is a good target for a cursor and a good line of text; a wallpaper is not
// a line of text, it is a picture you recognise instantly and cannot name at
// all, so this is a row of big pictures you throw sideways with a flick. There
// is no search field, because you do not know what your wallpaper is called;
// there is no dense grid, because a grid of small pictures is a grid of small
// targets.
//
// THE CENTRE CARD IS ON THE ACTUAL DESKTOP. Scrubbing through the list puts
// each one up as it passes, full size, behind everything: a thumbnail cannot
// tell you whether a picture works with your windows on it, and this panel is
// deliberately narrow enough to leave most of the screen showing. Nothing is
// written until a card is tapped, so a scrub that ends in a dismissal leaves
// the setting exactly where it was.
Item {
    id: root

    // Where the shell's body ends and the screen begins: the bar's width. The
    // strip starts there rather than at the screen edge, because a card sliding
    // under the workspace column would be a card you cannot see the left third
    // of, and the column is the one thing on this screen that is always up.
    required property real originX
    required property real inset

    readonly property bool open: shown
    property bool shown: false

    readonly property var entries: Wallpaper.available

    // WHAT A CARD IS, and every other measurement in here comes off it.
    //
    // SIZED FROM THE SCREEN, not picked and not derived from the minimum
    // target. The floor for a touch target is 24px and a card that size would
    // clear it and be useless anyway: this is a picture you have to RECOGNISE,
    // and recognition needs area rather than reach. So the height is a fixed
    // share of the screen, which keeps the trade explicit in one number: how
    // much of the desktop the picker is allowed to cover while you are looking
    // at the desktop through it.
    //
    // A fifth. The panel comes out at a little over a quarter of the screen
    // with its caption and its air, which leaves three quarters of the live
    // preview showing, and the card is around 340x190 on a 1080p panel: big
    // enough to tell two forest photographs apart, which is the actual test.
    readonly property real cardHeight: Math.round(root.height * 0.18)
    // 16:9, because screens are, and a card that is not the shape of the thing
    // it depicts crops the picture twice.
    readonly property real cardWidth: Math.round(root.cardHeight / 9 * 16)
    readonly property real cardGap: Appearance.padding.normal

    // The panel is as wide as the screen it is on, less the bar and the frame.
    // A carousel that is narrower than the room it has sits in two dead strips
    // that look like they should scroll and do not.
    readonly property real panelWidth: Math.max(root.cardWidth, root.width - root.originX - root.inset)

    readonly property real panelHeight: Appearance.padding.large * 2 + caption.implicitHeight + Appearance.padding.normal + root.cardHeight + Appearance.padding.large

    // The whole screen while it is open, so a tap anywhere outside lands on the
    // shell and can dismiss it.
    readonly property Item maskItem: catcher

    readonly property var blobs: panel.height <= 0 ? [] : [
        {
            x: panel.x,
            y: panel.y,
            w: panel.width,
            h: panel.height,
            radius: Appearance.rounding.large
        }
    ]

    function show(): void {
        if (root.shown)
            return;
        root.shown = true;
        // Start where you already are. Opening a picker on the first file in
        // the folder rather than on the wallpaper you are looking at makes the
        // first thing it does an unasked-for change.
        strip.positionAt(Math.max(0, root.entries.indexOf(Wallpaper.current)));
        // DEFERRED, the launcher's reason: focus is only worth taking once the
        // window has actually asked the compositor for the keyboard, and that
        // follows from `shown` in the same pass this is running in.
        Qt.callLater(root.forceActiveFocus);
    }

    function hide(): void {
        if (!root.shown)
            return;
        root.shown = false;
        // NOTHING WAS DECIDED. The desktop goes back to the setting, which is
        // where it would have been all along if this had never opened.
        Wallpaper.preview = "";
    }

    function toggle(): void {
        if (root.shown)
            root.hide();
        else
            root.show();
    }

    // Chosen, which is the one gesture here that writes anything.
    function accept(path: string): void {
        Wallpaper.set(path);
        root.hide();
    }

    // THE KEYBOARD, on a surface built for a finger, and it is not a
    // contradiction: this panel takes the compositor's keyboard while it is up
    // (it has to, or Escape could not reach it), so the arrow keys are already
    // being delivered here and doing nothing. A row of things with one of them
    // centred is a list, whatever it is drawn as, and a list that ignores the
    // arrow keys is a list that feels broken to the half of the world that
    // reaches for them first.
    //
    // Escape is deliberately NOT here. ShellWindow owns that key for every
    // panel at once, in one ordered list, because which surface a dismissal is
    // for depends on what else is up; a local handler would take it out of that
    // order. See its Keys.onPressed.
    Keys.onLeftPressed: strip.positionAt(Math.max(0, strip.currentIndex - 1))
    Keys.onRightPressed: strip.positionAt(Math.min(root.entries.length - 1, strip.currentIndex + 1))
    Keys.onReturnPressed: if (strip.currentPath)
        root.accept(strip.currentPath)
    Keys.onEnterPressed: if (strip.currentPath)
        root.accept(strip.currentPath)

    // Pulled by hand, exactly the launcher's pair of calls and for exactly its
    // reasons: while `dragging` is true the panel's reveal is the HAND'S rather
    // than the animation's, so the top edge is where the finger is.
    property bool dragging: false
    property real dragProgress: 0

    readonly property real revealed: root.dragging ? root.dragProgress : rise.value

    function dragTo(fraction: real): void {
        root.dragging = true;
        root.dragProgress = Math.max(0, Math.min(fraction, 1));
    }

    function dragEnd(open: bool): void {
        root.dragging = false;
        rise.value = root.dragProgress;
        if (open)
            root.show();
        else
            root.hide();
        root.dragProgress = 0;
    }

    Follow {
        id: rise

        target: root.shown ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    // DECLARED FIRST so it sits UNDER the panel: a catch-all that comes last
    // swallows every tap meant for the thing it is supposed to be behind.
    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.open
        visible: root.open
        onClicked: root.hide()
    }

    // THE WAY BACK IN: push the panel down and it goes into the edge it rose
    // out of. The shell's one rule for getting rid of anything.
    //
    // A SIBLING of the panel wearing the panel's geometry rather than a child
    // filling it, for the reason ListLauncher's copy of this spells out: Pull
    // measures in its PARENT's coordinates, and a child of the panel has a
    // parent that is itself being dragged.
    Pull {
        id: putAway

        x: panel.x
        y: panel.y
        width: panel.width
        height: panel.height

        armed: root.open

        dirX: 0
        dirY: 1
        angle: Appearance.sizes.pullAngleEdge
        travel: root.panelHeight

        onPulled: fraction => root.dragTo(1 - fraction)
        onFinished: gone => root.dragEnd(!gone)
    }

    Item {
        id: panel

        readonly property real bandY: root.height - root.inset
        readonly property real restY: bandY - root.panelHeight

        // Against the bar rather than centred in the screen: the panel is what
        // is left of the width once the shell's own body has taken its share,
        // so its left edge is where that body ends.
        x: root.originX
        y: panel.bandY + (panel.restY - panel.bandY) * root.revealed

        width: root.panelWidth
        height: root.panelHeight * root.revealed
        visible: height > 0
        clip: true

        G2Rect {
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: Appearance.colour.surface
        }

        // WHAT YOU ARE LOOKING AT, said in words because a picture cannot say
        // its own name and because the kind matters: a file that turns out to
        // be a video behaves differently once it is on the desktop, and this is
        // where you find that out rather than after choosing it.
        Row {
            id: caption

            anchors.top: parent.top
            anchors.topMargin: Appearance.padding.large
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Appearance.padding.normal

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: strip.currentPath ? strip.currentPath.split("/").pop() : `nothing in ${Wallpaper.dir}`
                color: Appearance.colour.text
            }

            // ONLY WHEN THERE IS SOMETHING TO SAY. A still is what a wallpaper
            // is expected to be, so it gets no badge; the three that are not
            // get one, in the accent, because "this one moves" is state worth a
            // colour.
            Pill {
                anchors.verticalCenter: parent.verticalCenter
                visible: strip.currentKind && strip.currentKind !== "still"
                interactive: false
                colour: Appearance.colour.accentFill
                text: strip.currentKind === "motion" ? "GIF" : strip.currentKind === "video" ? "VIDEO" : "AUDIO"
            }
        }

        // THE STRIP.
        //
        // A ListView rather than a Row in a Flickable, for the snapping: a
        // carousel that stops between two cards has no centre, and the centre
        // is the whole interface here. StrictlyEnforceRange with both
        // preferred bounds at the middle means the view cannot rest anywhere
        // except with a card centred, and `currentIndex` is therefore always
        // the one being previewed.
        ListView {
            id: strip

            readonly property string currentPath: root.entries[currentIndex] ?? ""
            readonly property string currentKind: Wallpaper.kindOf(strip.currentPath)

            function positionAt(i: int): void {
                strip.currentIndex = i;
                strip.positionViewAtIndex(i, ListView.Center);
            }

            anchors.top: caption.bottom
            anchors.topMargin: Appearance.padding.normal
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.cardHeight

            orientation: ListView.Horizontal
            model: root.entries
            spacing: root.cardGap

            // The strip is centred by its own PADDING rather than by margins on
            // the view, so the first and last cards can reach the middle: a
            // view that stops with its first item at the left edge cannot
            // centre it, and the first wallpaper in the folder would be the one
            // you could never preview.
            leftMargin: (width - root.cardWidth) / 2
            rightMargin: leftMargin

            snapMode: ListView.SnapOneItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: (width - root.cardWidth) / 2
            preferredHighlightEnd: (width + root.cardWidth) / 2
            highlightMoveDuration: Appearance.anim.normal

            // Touch handles itself. This is for the mouse: a notch moves one
            // card rather than a number of pixels, because with snapping on,
            // pixels would be dragged back to the nearest card anyway and the
            // wheel would feel like it was fighting the view.
            WheelHandler {
                onWheel: event => {
                    if (event.angleDelta.y > 0 || event.angleDelta.x < 0)
                        strip.currentIndex = Math.max(0, strip.currentIndex - 1);
                    else
                        strip.currentIndex = Math.min(root.entries.length - 1, strip.currentIndex + 1);
                }
            }

            // LIVE, and this is the point of the whole panel. The card in the
            // middle is on the desktop behind you at full size while you decide
            // about it.
            onCurrentPathChanged: {
                if (root.open && strip.currentPath)
                    Wallpaper.preview = strip.currentPath;
            }

            delegate: Item {
                id: card

                required property string modelData
                required property int index

                readonly property bool centred: card.index === strip.currentIndex

                width: root.cardWidth
                height: root.cardHeight

                // The one off to the side is smaller and dimmer, so the strip
                // has a middle you can see rather than a row of equals. Scale
                // rather than size: a card that changed size would move its
                // neighbours, and the whole strip would breathe as it scrolled.
                scale: card.centred ? 1 : 0.88
                opacity: card.centred ? 1 : 0.55

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                // WHAT A CARD IS BEFORE ITS PICTURE ARRIVES, and what it stays
                // for a file that has no picture at all. A plate and the mark
                // for its kind, so a strip mid-decode is a strip of cards
                // rather than a row of holes.
                G2Rect {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Appearance.colour.fill

                    Icon {
                        anchors.centerIn: parent
                        size: Appearance.font.iconSize * 1.6
                        color: Appearance.colour.textGhost
                        name: {
                            const k = Wallpaper.kindOf(card.modelData);
                            if (k === "video")
                                return "movie";
                            if (k === "motion")
                                return "gif_box";
                            if (k === "audio")
                                return "music_note";
                            return "image";
                        }
                    }
                }

                G2Image {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    source: Wallpaper.faceOf(card.modelData)
                    fillMode: Image.PreserveAspectCrop
                }

                // THAT THIS ONE MOVES, on the card rather than only in the
                // caption above. The caption says it about the centred card,
                // which is the one you can already see; this is so the strip
                // can be SCANNED for the ones that are not simply a picture,
                // which is the one thing a thumbnail genuinely cannot show:
                // every card is a still, including the cards that are not.
                Pill {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Appearance.padding.small

                    readonly property string kind: Wallpaper.kindOf(card.modelData)

                    visible: kind && kind !== "still"
                    interactive: false
                    colour: Appearance.colour.accentFill
                    text: kind === "motion" ? "GIF" : kind === "video" ? "VIDEO" : "AUDIO"
                }

                // THE MARK ON THE ONE YOU ARE ALREADY WEARING. Not a selection
                // highlight: the centred card is what the middle of the strip
                // already says. This is the different fact that one of these
                // is the wallpaper you have.
                G2Rect {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: "transparent"
                    stroke: Appearance.colour.accent
                    strokeWidth: Appearance.font.stem * 2
                    visible: card.modelData === Wallpaper.current
                }

                // ONE TAP IS THE WHOLE INTERACTION. Not a tap to select and a
                // button to apply: the card is the thing and choosing it is the
                // only thing you can do to it. A card that is not centred
                // centres itself first, which is what a finger landing off to
                // the side of a carousel means everywhere else.
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (card.centred)
                            root.accept(card.modelData);
                        else
                            strip.positionAt(card.index);
                    }
                }
            }
        }
    }
}
