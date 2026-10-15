pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.controls

Item {
    id: root

    required property real border

    readonly property bool open: root.shown
    property bool shown: false

    readonly property Item maskItem: catcher

    property string restoreTo: ""

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    readonly property real pad: Appearance.padding.large
    readonly property real artSize: Math.round(Appearance.sizes.mediaPanelWidth * 4 / 7)
    readonly property real lyricsWidth: Math.round(Appearance.sizes.mediaPanelWidth * 15 / 14)
    readonly property real gutter: Appearance.padding.huge

    readonly property bool showsLyrics: Lyrics.enabled && Lyrics.ready && Media.available

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

    property string quip: "nothing is playing"

    property bool holding: false

    property rect origin: Qt.rect(0, 0, 0, 0)
    readonly property bool grown: root.origin.width > 0
    readonly property real lead: 1 - Math.pow(1 - reveal.value, 1.7)

    function showFrom(from: rect): void {
        if (root.shown)
            return;
        root.origin = from;
        root.show();
    }

    function show(): void {
        if (root.shown)
            return;

        root.quip = root.quips[Math.floor(Math.random() * root.quips.length)];
        root.restoreTo = Hypr.focusedOn(root.screenName);
        root.shown = true;
        root.hold(true);
        Media.sync();

        Qt.callLater(keys.forceActiveFocus);
    }

    function hide(): void {
        if (!root.shown)
            return;
        root.shown = false;
        root.hold(false);
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

    function hold(want: bool): void {
        if (want === root.holding)
            return;
        root.holding = want;
        if (want)
            Lyrics.hold();
        else
            Lyrics.release();
    }

    Component.onDestruction: root.hold(false)

    function volume(dir: int): void {
        if (!Audio.ready)
            return;
        Audio.setVolume(Audio.quantise(Audio.volume + dir * Config.values.volume.step));
    }

    function seek(dir: int, big: bool): void {
        const amount = big ? Config.values.media.seekLarge : Config.values.media.seekSmall;
        Media.seekBy(dir * amount);
    }

    function toggleLyrics(): void {
        Config.set("media.lyrics", !Lyrics.enabled);
    }

    Follow {
        id: reveal

        speed: root.grown ? Appearance.animation.resizeSpeed * 0.6 : Appearance.animation.revealSpeed
        target: root.shown ? 1 : 0
        epsilon: 0.005

        onValueChanged: if (reveal.value === 0 && !root.shown)
            root.origin = Qt.rect(0, 0, 0, 0)
    }

    Follow {
        id: stage

        speed: Appearance.animation.resizeSpeed
        target: root.showsLyrics ? 1 : 0
        epsilon: 0.002
    }

    Follow {
        id: tall

        speed: Appearance.animation.resizeSpeed
        target: column.height
    }

    onShownChanged: if (root.shown && reveal.value < 0.01) {
        stage.snap();
        tall.snap();
    }

    Item {
        id: keys

        Keys.onPressed: event => {
            const shift = event.modifiers & Qt.ShiftModifier;

            switch (event.key) {
            case Qt.Key_Escape:
                root.hide();
                break;
            case Qt.Key_Space:
                if (!event.isAutoRepeat)
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
                if (!event.isAutoRepeat)
                    Audio.toggleMute();
                break;
            case Qt.Key_L:
                if (!event.isAutoRepeat)
                    root.toggleLyrics();
                break;
            case Qt.Key_S:
                if (!event.isAutoRepeat)
                    Media.toggleShuffle();
                break;
            case Qt.Key_R:
                if (!event.isAutoRepeat)
                    Media.cycleLoop();
                break;
            case Qt.Key_Tab:
                Media.cycle(1);
                break;
            case Qt.Key_Backtab:
                Media.cycle(-1);
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

    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.open
        visible: root.open

        onClicked: root.hide()
    }

    Item {
        id: grow

        readonly property real t: root.lead
        readonly property rect to: Qt.rect(panel.restX, panel.restTop, panel.width, panel.height)

        x: root.origin.x + (to.x - root.origin.x) * t
        y: root.origin.y + (to.y - root.origin.y) * t
        width: root.origin.width + (to.width - root.origin.width) * t
        height: root.origin.height + (to.height - root.origin.height) * t
        visible: root.grown && reveal.value > 0.001 && reveal.value < 0.999
        opacity: Math.min(1, t * 4) * (1 - Math.max(0, (reveal.value - 0.85) / 0.15))

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.normal + (Appearance.rounding.large - Appearance.rounding.normal) * grow.t
            color: Appearance.colour.surface
        }

        ArtGlow {
            anchors.fill: parent
            radius: Appearance.rounding.normal + (Appearance.rounding.large - Appearance.rounding.normal) * grow.t
            source: Media.available ? Media.artUrl : ""
            moving: false
            opacity: 0.62
        }
    }

    ArtCrossfade {
        readonly property real t: root.lead
        readonly property rect to: Qt.rect(panel.restX + root.pad, panel.restTop + root.pad, root.artSize, root.artSize)

        x: root.origin.x + (to.x - root.origin.x) * t
        y: root.origin.y + (to.y - root.origin.y) * t
        width: root.artSize
        height: root.artSize
        transformOrigin: Item.TopLeft
        scale: (root.origin.width + (root.artSize - root.origin.width) * t) / Math.max(1, root.artSize)
        radius: Appearance.rounding.normal
        source: Media.available ? Media.artUrl : ""
        visible: root.grown && reveal.value > 0.001 && reveal.value < 0.999
        opacity: 1 - Math.max(0, (reveal.value - 0.85) / 0.15)
    }

    Item {
        id: panel

        readonly property real restY: (root.height - panel.height) / 2
        readonly property real restX: Math.round((root.width - panel.width) / 2)
        readonly property real restTop: root.border + panel.restY

        x: panel.restX
        y: panel.restTop + (root.grown ? 0 : (1 - reveal.value) * Appearance.padding.huge * 2)
        width: root.pad * 2 + root.artSize + stage.value * (root.gutter + root.lyricsWidth)
        height: tall.value + root.pad * 2
        visible: reveal.value > 0.001
        enabled: root.open

        transform: Scale {
            xScale: root.grown ? 0.97 + 0.03 * reveal.value : 0.85 + 0.15 * reveal.value
            yScale: xScale

            origin.x: panel.width / 2
            origin.y: panel.height / 2
        }

        opacity: root.grown ? Math.max(0, (reveal.value - 0.8) / 0.2) : Math.min(1, reveal.value * 1.6)

        MouseArea {
            anchors.fill: parent
        }

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: Appearance.colour.surface
        }

        ArtGlow {
            anchors.fill: parent
            radius: Appearance.rounding.large
            source: Media.available ? Media.artUrl : ""
            moving: panel.visible
            opacity: 0.62
        }

        Column {
            id: column

            x: root.pad
            y: root.pad
            width: root.artSize
            spacing: root.pad

            Item {
                width: parent.width
                height: width
                visible: Media.available

                DropShadow {
                    anchors.fill: art
                    radius: Appearance.rounding.normal
                    blur: Appearance.padding.normal
                    offset.y: Appearance.padding.small / 2
                    opacity: art.ready ? 0.7 : 0
                }

                SquircleRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Appearance.colour.fill
                    visible: !art.ready

                    Icon {
                        anchors.centerIn: parent
                        size: Math.round(root.artSize / 3)
                        name: "music_note"
                        color: Appearance.colour.textFaint
                    }
                }

                ArtCrossfade {
                    id: art

                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    source: Media.artUrl
                }

                SquircleRect {
                    anchors.fill: parent
                    visible: Media.canRaise
                    radius: Appearance.rounding.normal
                    color: Appearance.colour.scrim
                    opacity: raise.containsMouse ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animation.fast
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: Appearance.padding.small

                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            size: Appearance.font.iconSize * 1.6
                            name: "open_in_new"
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: `open ${Media.app}`
                        }
                    }
                }

                MouseArea {
                    id: raise

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: Media.canRaise
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Media.raise()
                }
            }

            Column {
                width: parent.width
                spacing: Appearance.padding.small / 2
                visible: Media.available

                CrossfadeText {
                    width: parent.width
                    text: Media.title
                    pixelSize: Appearance.font.size.normal
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }

                CrossfadeText {
                    width: parent.width
                    text: Media.artist
                    color: Appearance.colour.textDim
                    visible: !!Media.artist
                }

                CrossfadeText {
                    width: parent.width
                    text: Media.album || Media.app
                    color: Appearance.colour.textFaint
                    visible: !!Media.album || !!Media.app
                }
            }

            Scrubber {
                width: parent.width
                visible: Media.available && (Media.length > 0 || Media.hasTrack)
                watched: root.open
            }

            MediaTransport {
                width: parent.width
                visible: Media.available
                zoom: 1.3
                extended: true
            }

            Item {
                width: parent.width
                height: Math.max(chips.height, lyricsButton.height)
                visible: Media.available

                PlayerChips {
                    id: chips

                    anchors.left: parent.left
                    anchors.right: lyricsButton.left
                    anchors.rightMargin: Appearance.padding.small
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    id: lyricsButton

                    readonly property string tip: {
                        if (!Lyrics.enabled)
                            return "show lyrics";
                        switch (Lyrics.state) {
                        case "synced":
                        case "plain":
                            return "hide lyrics";
                        case "loading":
                            return "looking for lyrics";
                        case "instrumental":
                            return "instrumental, no lyrics";
                        case "failed":
                            return "could not reach lrclib.net";
                        case "missing":
                            return "no lyrics found for this one";
                        default:
                            return Media.isAdvert || Media.isEpisode ? "no lyrics for this" : "lyrics";
                        }
                    }

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(Appearance.sizes.minTarget, lyricsIcon.implicitWidth + Appearance.padding.small * 2)
                    height: width

                    scale: lyricsPress.pressed ? Appearance.press.ring : lyricsPress.containsMouse ? Appearance.press.ringHover : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.animation.fast
                            easing.type: Easing.OutCubic
                        }
                    }

                    Icon {
                        id: lyricsIcon

                        anchors.centerIn: parent
                        name: "lyrics"
                        fill: Lyrics.enabled && Lyrics.ready ? 1 : 0
                        color: !Lyrics.enabled ? Appearance.colour.textFaint : Lyrics.ready ? Appearance.colour.text : Appearance.colour.textGhost

                        SequentialAnimation on opacity {
                            running: Lyrics.loading && root.open
                            loops: Animation.Infinite
                            alwaysRunToEnd: true

                            NumberAnimation {
                                to: 0.35
                                duration: Appearance.animation.slow
                            }
                            NumberAnimation {
                                to: 1
                                duration: Appearance.animation.slow
                            }
                        }
                    }

                    MouseArea {
                        id: lyricsPress

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Lyrics.state === "failed")
                                Lyrics.retry();
                            else
                                root.toggleLyrics();
                        }
                    }

                    HoverTip {
                        text: lyricsPress.containsMouse ? lyricsButton.tip : ""
                    }
                }
            }

            Item {
                width: parent.width
                height: emptyColumn.height
                visible: !Media.available

                Column {
                    id: emptyColumn

                    width: parent.width
                    spacing: root.pad

                    SquircleRect {
                        width: parent.width
                        height: Math.round(parent.width * 0.6)
                        radius: Appearance.rounding.normal
                        color: Appearance.colour.fill

                        Icon {
                            anchors.centerIn: parent
                            size: Math.round(root.artSize / 4)
                            name: "music_off"
                            color: Appearance.colour.textGhost
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Appearance.padding.small

                        StyledText {
                            width: parent.width
                            text: "nothing is playing"
                            font.pixelSize: Appearance.font.size.normal
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            width: parent.width
                            text: `"${root.quip}"`
                            color: Appearance.colour.textFaint
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }

        Item {
            x: root.pad + root.artSize + root.gutter * stage.value
            y: root.pad
            width: Math.max(0, panel.width - x - root.pad)
            height: column.height
            clip: true
            visible: stage.value > 0.01

            LyricsView {
                width: root.lyricsWidth
                height: parent.height
                opacity: stage.value * stage.value
                live: root.open && root.showsLyrics
            }
        }
    }
}
