pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// The media controller: Super+M pops it in the middle of the screen, and it
// gets out of the way the same way.
//
// WHY IT IS NOT A MENU. Every menu in this shell hangs off the sidebar and
// lives on hover, because the bar is where the cursor already is when you want
// one. This is the opposite kind of object: it is summoned by a chord from
// wherever the hands happen to be, it is worked entirely from the keyboard
// (space, the arrows, escape) while the cursor is still busy in whatever
// window was open, and when it is done it goes away on its own terms rather
// than on a cursor's. The calculator and the power panel are this object's
// kin - summoned by name, keyboard taken outright - and neither of them is a
// menu either. See CalculatorPanel.qml for the full argument.
//
// WHY IT FLOATS IN THE MIDDLE instead of melting out of the band. The
// calculator arrives from the band and is a blob in the chassis's field,
// because a thing you operate while standing at the bar should grow out of
// the bar. This one answers a chord pressed from the middle of the desk: it
// has no edge it came from, and drawing a melt from the sidebar to the centre
// of the screen would claim a connection that does not exist. So it is the
// CheatSheet's kind of object - a document floating clear of every band,
// contributing no blob - and it pops rather than slides: it rises the last
// stretch and scales into place from just under its final size, which is the
// vocabulary a dialog owns and no panel in this shell had used yet.
//
// THE QUEUE IS TOLD HONESTLY. MPRIS has no "what plays next": the Player
// interface carries one track at a time, and the TrackList side-interface
// that could carry the rest is implemented by nothing the user runs (checked:
// Spotify and the browser each ship Player and nothing else). So when more
// than one player is alive the card shows the others' now-playing - what
// plays soon if you switch, one press away - and when there is only one, it
// says plainly whose queue it cannot see rather than drawing a fake one.
Item {
    id: root

    // The band, for the two edges the card keeps away from: it is centred, but
    // a centre is only meaningful if the card cannot argue its way over the
    // chassis on a very small screen.
    required property real border

    readonly property bool open: root.shown
    property bool shown: false

    // The whole screen while it is out, so a click anywhere off the card puts
    // it away. The power panel's construction, word for word: summoned by a
    // key rather than reached for, so there is no edge to leave.
    readonly property Item maskItem: catcher

    // The window that had the keyboard before this took it. Exclusive focus
    // makes the compositor unfocus the window underneath and letting go does
    // not hand it back; every panel here that takes the keyboard keeps this
    // for the same reason. See SessionMenu.qml.
    property string restoreTo: ""

    // WHICH SCREEN THIS CARD IS ON, asked of the window per
    // modules/SettingsCorner.qml's idiom: the screen is a fact about the
    // surface, not about the card.
    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    // The card's width is the one configured number; everything inside it is
    // derived, so the whole card rescales from that one key.
    readonly property real cardWidth: Appearance.sizes.mediaPanelWidth
    readonly property real pad: Appearance.padding.large
    readonly property real innerWidth: root.cardWidth - root.pad * 2

    // The art at a quarter of the card: the Niagara proportion, which
    // MediaPreview already keeps, at floating-card scale.
    readonly property real artSize: Math.round(root.innerWidth / 4)

    // WHAT AN EMPTY CARD SAYS. "Nothing is playing" is the fact, but a fact
    // repeated verbatim every time is a system message, and this card is not a
    // system message: it is the shell putting on a face while it waits. So it
    // keeps a book of quips - every one about the same honest nothing, most
    // borrowed from the music that is not playing - and rolls a fresh one each
    // time the card is summoned, so the empty state is never the same twice.
    // The practical line beneath stays practical; the joke is the headline,
    // not the instructions. No how-to underneath: nobody opens a floating
    // card to be told which applications play music.
    readonly property var quips: [
        "enjoy the silence",
        "the sound of silence",
        "silence is golden",
        "nothing else matters",
        "the sound of nothing, in hi-fi",
        "in the key of zzz",
        "this bar is a whole rest",
        "a whole rest, every bar",
        "every note still unplayed",
        "the beat drops eventually",
        "a dramatic pause",
        "the longest intermission",
        "the longest interval",
        "the band has gone home",
        "the stage is dark",
        "the curtain is down",
        "the speakers are dreaming",
        "the subwoofer hibernates",
        "the metronome is asleep",
        "the tape ran out",
        "the radio is between stations",
        "static, but polite",
        "the jukebox wants coins",
        "no disc inserted",
        "not playing pigstep",
        "*cave sounds*",
        "*eerie cave noise*",
        "the note blocks are silent",
        "no mellohi either",
        "the playlist called in sick",
        "your headphones are on strike",
        "the earworm is unfed",
        "the needle is up",
        "the vinyl found its run-out groove",
        "even the crickets rehearsed more",
        "*crickets*",
        "hush",
        "shh",
        "hush now",
        "quiet, please",
        "the quiet room",
        "all ears, nothing to hear",
        "the equalizer is flatlining",
        "zero decibels, infinite potential",
        "frequency: none",
        "amplitude: zero",
        "no waves on this shore",
        "the wave was here a minute ago",
        "fade out complete",
        "rewind to when it played",
        "nowhere, fast",
        "between two songs, forever",
        "the encore has not started",
        "tuning up",
        "the warm-up has not begun",
        "the mixer board is dark",
        "nobody is on the mic",
        "the instruments all rest",
        "fermata on nothing",
        "the lullaby is unsung",
        "white noise, minus the noise",
        "the quiet storm",
        "sing it yourself, why don't you",
        "whistle your own theme",
        "the melody is on strike",
        "you could hear a pin drop"
    ]

    // The line the empty card is wearing this time. Seeded with the plain
    // fact, and rolled on every show, so two summons in a row can disagree.
    property string quip: "nothing is playing"

    // ---------------------------------------------------------------
    // LIFETIME, on the power panel's shape.

    function show(): void {
        if (root.shown)
            return;
        // A fresh quip per summon: the roll happens on the way in, so the
        // card never wears the same empty line twice in a row unless the
        // book itself is that small. (It is not.)
        root.quip = root.quips[Math.floor(Math.random() * root.quips.length)];
        root.restoreTo = Hypr.focusedOn(root.screenName);
        root.shown = true;
        // DEFERRED: the surface asks the compositor for the keyboard only once
        // `open` has propagated; focus forced before that lands in a surface
        // with no keys to give. See ShellWindow's keyboardFocus.
        Qt.callLater(keys.forceActiveFocus);
    }

    function hide(): void {
        if (!root.shown)
            return;
        root.shown = false;
        keys.focus = false;
        Hypr.restoreFocus(root.restoreTo);
        root.restoreTo = "";
    }

    function toggle(): void {
        if (root.shown)
            root.hide();
        else
            root.show();
    }

    // THE WHOLE-VOLUME STEPS, for the up/down arrows. The same quantise and
    // the same step the volume rail and the sound menu use, so every way of
    // turning the sound down on this machine moves by the same amount.
    function volume(dir: int): void {
        if (!Audio.ready)
            return;
        Audio.setVolume(Audio.quantise(Audio.volume + dir * Appearance.sizes.volumeStep));
    }

    // ONE SEEK, sized by the modifier. Small is "a few seconds"; large is for
    // really moving around. Gated on the player advertising seek at all, the
    // same gate the scrubber's input sits behind.
    function seek(dir: int, big: bool): void {
        const amount = big ? Appearance.sizes.mediaSeekLarge : Appearance.sizes.mediaSeekSmall;
        Media.seekBy(dir * amount);
    }

    Follow {
        id: reveal

        speed: Appearance.anim.revealSpeed
        target: root.shown ? 1 : 0
        epsilon: 0.005
    }

    // THE KEYS, on an item of their own: the panel is invisible until the
    // reveal has moved off zero, and an invisible item cannot hold focus.
    // SessionMenu learned this first; the shape is now the rule.
    Item {
        id: keys

        Keys.onPressed: event => {
            const shift = event.modifiers & Qt.ShiftModifier;

            switch (event.key) {
            case Qt.Key_Escape:
                root.hide();
                break;
            case Qt.Key_Space:
                // One toggle per press. Holding space repeating on the auto-
                // repeat is a strobe, and nothing else here wants it either.
                if (!event.isRepeat)
                    Media.toggle();
                break;
            case Qt.Key_Left:
                root.seek(-1, shift);
                break;
            case Qt.Key_Right:
                root.seek(1, shift);
                break;
            case Qt.Key_Up:
                root.volume(1);
                break;
            case Qt.Key_Down:
                root.volume(-1);
                break;
            case Qt.Key_N:
                Media.next();
                break;
            case Qt.Key_P:
                Media.previous();
                break;
            case Qt.Key_M:
                if (!event.isRepeat)
                    Audio.toggleMute();
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                Media.raise();
                break;
            default:
                return;
            }

            event.accepted = true;
        }
    }

    // DECLARED BEFORE THE CARD: declaration order is input order, so anything
    // that is not the card is this catcher's press, and the press puts the
    // card away.
    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.open
        visible: root.open

        onClicked: root.hide()
    }

    // THE CARD. Rises the last stretch and scales into place, both off the one
    // reveal: one follower because the pop is one motion, and arithmetic
    // rather than staged animations so the parts cannot arrive out of step.
    Item {
        id: panel

        readonly property real restY: (root.height - panel.height) / 2

        x: (root.width - panel.width) / 2
        y: root.border + panel.restY + (1 - reveal.value) * Appearance.padding.huge * 2
        width: root.cardWidth
        height: column.height + root.pad * 2
        visible: reveal.value > 0.001
        enabled: root.open

        transform: Scale {
            xScale: 0.85 + 0.15 * reveal.value
            yScale: xScale
            // About the card's own centre, so it pops out of the middle of the
            // screen rather than out of its top-left corner.
            origin.x: panel.width / 2
            origin.y: panel.height / 2
        }

        // Opacity runs ahead of the scale: the card is fully there by the time
        // it is most of the way to size, which is what makes the motion read
        // as "appeared" rather than as "grew".
        opacity: Math.min(1, reveal.value * 1.6)

        G2Rect {
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: Appearance.colour.surface
        }

        Column {
            id: column

            x: root.pad
            y: root.pad
            width: root.innerWidth
            spacing: root.pad

            // THE TRACK, in the notch preview's Niagara layout at card scale:
            // the art exactly as tall as everything beside it, so the block
            // reads as one object. Same construction, one press of a bigger
            // paper. The block grows to its text: a long title wraps to two
            // lines rather than cutting off mid-thought - the notch elides
            // because the notch has no room, and the card does.
            Item {
                width: parent.width
                height: Math.max(root.artSize, trackText.height)
                visible: Media.available

                G2Rect {
                    id: art

                    anchors.verticalCenter: parent.verticalCenter

                    width: root.artSize
                    height: width
                    radius: Appearance.rounding.normal
                    color: Appearance.colour.fill

                    G2Image {
                        anchors.fill: parent
                        source: Media.artUrl
                        radius: art.radius
                    }

                    Icon {
                        anchors.centerIn: parent
                        visible: !Media.artUrl
                        size: Math.round(root.artSize / 2)
                        name: "music_note"
                        color: Appearance.colour.textFaint
                    }
                }

                Column {
                    id: trackText

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: art.right
                    anchors.leftMargin: root.pad
                    anchors.right: parent.right
                    spacing: Appearance.padding.small

                    // THE TITLE, the one thing on the card set in the large
                    // tier: it is the thing the card exists to say. Two lines
                    // before it will elide, and never fewer than the whole
                    // thought when two lines hold it.
                    StyledText {
                        width: parent.width
                        text: Media.title
                        font.pixelSize: Appearance.font.size.large
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        maximumLineCount: 2
                    }

                    StyledText {
                        width: parent.width
                        text: Media.artist
                        color: Appearance.colour.textDim
                        visible: !!Media.artist
                        elide: Text.ElideRight
                    }

                    StyledText {
                        width: parent.width
                        text: !!Media.album ? Media.album : Media.app
                        color: Appearance.colour.textFaint
                        visible: !!Media.album || !!Media.app
                        elide: Text.ElideRight
                    }
                }
            }

            // Where the track is, and the wheel and the drag to move it: the
            // ONE scrubber, the same the notch and the menu draw. Its wave is
            // a clock, so it is told when it is being watched. A track with
            // no length yet - or a live stream that never has one - shows the
            // live shape rather than vanishing.
            Scrubber {
                width: parent.width
                visible: Media.available && (Media.length > 0 || Media.hasTrack)
                watched: root.open
            }

            // The transport. The one set of media buttons in the shell, the
            // ring marking the control you aim at.
            MediaTransport {
                width: parent.width
                visible: Media.available
            }

            // ---------------------------------------------------------
            // COMING UP, as far as MPRIS can honestly say.

            Separator {
                width: parent.width
                visible: Media.available
            }

            StyledText {
                width: parent.width
                visible: Media.available && Media.players.length > 1
                text: "ALSO PLAYING"
                color: Appearance.colour.textFaint
            }

            // The other players, each with what it would play if you switched.
            // Choosing one is the whole row: Media keeps the chosen player
            // while it lasts, so the card turns to it without anything else
            // being told.
            Repeater {
                model: Media.available ? Media.players.filter(p => p !== Media.active) : []

                delegate: MenuRow {
                    required property var modelData

                    width: root.innerWidth
                    icon: modelData.isPlaying ? "play_arrow" : "pause"
                    label: modelData.identity || "player"
                    detail: modelData.trackTitle || ""
                    onActivated: Media.choose(modelData)
                }
            }

            // One player alive, so there is nothing to switch to and no
            // TrackList to read: the honest answer. Faint, because it is the
            // card admitting a limit, not telling you anything.
            Row {
                width: parent.width
                visible: Media.available && Media.players.length <= 1
                spacing: Appearance.padding.small

                Icon {
                    name: "queue_music"
                    color: Appearance.colour.textGhost
                }

                StyledText {
                    text: `the queue lives in ${Media.app}`
                    color: Appearance.colour.textGhost
                }
            }

            // THE EMPTY CARD. No player registered, so there is no track to
            // draw and the card says so in the track's own layout: the same
            // art square, the fact as the headline, and the quip of the day
            // beneath it as a subtitle. An empty card that keeps its shape
            // reads as "waiting"; a collapsed one with an apology at the
            // bottom reads as broken. No instructions: nobody summons a
            // floating card to be told which applications play music.
            Item {
                width: parent.width
                height: emptyColumn.height
                visible: !Media.available

                Column {
                    id: emptyColumn

                    width: parent.width
                    spacing: Appearance.padding.normal

                    Row {
                        spacing: root.pad

                        G2Rect {
                            id: emptyArt

                            width: root.artSize
                            height: width
                            radius: Appearance.rounding.normal
                            color: Appearance.colour.fill

                            Icon {
                                anchors.centerIn: parent
                                size: Math.round(root.artSize / 2)
                                name: "music_note"
                                color: Appearance.colour.textGhost
                            }
                        }

                        Column {
                            anchors.verticalCenter: emptyArt.verticalCenter
                            width: root.innerWidth - root.artSize - root.pad
                            spacing: Appearance.padding.small

                            // The fact, in the body tier: at the large tier
                            // Monocraft's letters outrun the slot beside the
                            // art square, and a fixed phrase may neither elide
                            // nor wander. The shell carries hierarchy in
                            // colour, not size (see Appearance), so the bright
                            // normal line reads as the headline regardless.
                            StyledText {
                                width: parent.width
                                text: "nothing is playing"
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                width: parent.width
                                text: `\"${root.quip}\"`
                                color: Appearance.colour.textFaint
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }
        }
    }
}
