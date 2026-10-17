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

    property var origin: null
    property bool fromIsland: false
    readonly property bool grown: !!root.origin
    readonly property real flown: root.grown ? reveal.value : 1
    readonly property real late: Math.max(0, (root.flown - 0.4) / 0.6)
    readonly property point ride: root.grown ? Qt.point(hull.x, hull.y) : Qt.point(0, 0)

    function showFrom(from: var): void {
        if (root.shown)
            return;
        root.origin = from;
        root.show();
    }

    function mix(a: real, b: real): real {
        return a + (b - a) * root.flown;
    }

    function tone(a: color, b: color): color {
        const t = root.flown;
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    function rest(item: Item): point {
        let x = panel.restX;
        let y = panel.restTop;
        for (let p = item; p && p !== content; p = p.parent) {
            x += p.x;
            y += p.y;
        }
        return Qt.point(x, y);
    }

    function flight(from: var, item: Item, centred: bool): point {
        if (!root.grown || !from)
            return root.ride;
        const at = root.rest(item);
        const x = centred ? from.x + (from.width - item.width) / 2 : from.x;
        const y = centred ? from.y + (from.height - item.height) / 2 : from.y;
        return Qt.point((x - at.x) * (1 - root.flown), (y - at.y) * (1 - root.flown));
    }

    function arrives(from: var): real {
        return !root.grown || from ? 1 : root.late;
    }

    function warm(): void {
        Lyrics.prefetch();
    }

    function show(): void {
        if (root.shown)
            return;

        root.fromIsland = !!root.origin;
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
        root.origin = null;
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

        speed: root.grown ? Appearance.animation.resizeSpeed * 0.5 : Appearance.animation.revealSpeed
        target: root.shown ? 1 : 0
        epsilon: 0.002
    }

    Follow {
        id: stage

        speed: Appearance.animation.resizeSpeed
        target: root.showsLyrics ? 1 : 0
        epsilon: 0.002
    }

    Follow {
        id: tall

        speed: root.shown && reveal.value < 1 ? 0 : Appearance.animation.resizeSpeed
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
                Appearance.instantly();
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
        id: panel

        readonly property real restY: (root.height - panel.height) / 2
        readonly property real restX: Math.round((root.width - panel.width) / 2)
        readonly property real restTop: root.border + panel.restY

        x: panel.restX
        y: panel.restTop + (root.grown ? 0 : (1 - reveal.value) * Appearance.padding.huge * 2 * (root.fromIsland ? -1 : 1))
        width: root.pad * 2 + root.artSize + stage.value * (root.gutter + root.lyricsWidth)
        height: tall.value + root.pad * 2
        visible: reveal.value > 0.001
        enabled: root.open

        transform: Scale {
            xScale: root.grown ? 1 : 0.85 + 0.15 * reveal.value
            yScale: xScale

            origin.x: panel.width / 2
            origin.y: panel.height / 2
        }

        opacity: root.grown ? 1 : Math.min(1, reveal.value * 1.6)

        MouseArea {
            anchors.fill: parent
        }

        DropShadow {
            x: hull.x
            y: hull.y
            width: hull.width
            height: hull.height
            radius: hull.radius
            opacity: 0.8 * (1 - root.flown)
            visible: opacity > 0.01
        }

        Item {
            id: hull

            readonly property var from: root.origin?.body ?? null
            readonly property real radius: hull.from ? root.mix(root.origin?.radius ?? Appearance.rounding.large, Appearance.rounding.large) : Appearance.rounding.large
            readonly property real power: hull.from ? root.mix(root.origin?.power ?? Appearance.rounding.power, Appearance.rounding.power) : Appearance.rounding.power

            x: hull.from ? (hull.from.x - panel.restX) * (1 - root.flown) : 0
            y: hull.from ? (hull.from.y - panel.restTop) * (1 - root.flown) : 0
            width: hull.from ? root.mix(hull.from.width, panel.width) : panel.width
            height: hull.from ? root.mix(hull.from.height, panel.height) : panel.height
            clip: root.flown < 1

            SquircleRect {
                anchors.fill: parent
                radius: hull.radius
                cornerPower: hull.power
                color: root.grown ? root.tone(Appearance.colour.ink, Appearance.colour.surface) : Appearance.colour.surface
            }

            SquircleRect {
                anchors.fill: parent
                radius: hull.radius
                cornerPower: hull.power
                stroke: Appearance.colour.seam
                strokeWidth: Appearance.sizes.seam
                opacity: 1 - root.flown
                visible: opacity > 0.01
            }

            ArtGlow {
                anchors.fill: parent
                radius: hull.radius
                source: Media.available ? Media.artUrl : ""
                moving: panel.visible
                opacity: root.grown ? root.mix(root.origin?.glow ?? 0, 0.62) : 0.62
            }

            Item {
                id: content

                x: -hull.x
                y: -hull.y
                width: panel.width
                height: panel.height

                Column {
                    id: column

                    x: root.pad
                    y: root.pad
                    width: root.artSize
                    spacing: root.pad

                    Item {
                        id: artBox

                        readonly property var from: root.origin?.cover ?? null
                        readonly property point by: root.flight(artBox.from, artBox, false)
                        readonly property real size: artBox.from ? root.mix(artBox.from.width / artBox.width, 1) : 1
                        readonly property real corner: Appearance.rounding.normal / artBox.size

                        width: parent.width
                        height: width
                        visible: Media.available

                        transform: [
                            Scale {
                                xScale: artBox.size
                                yScale: artBox.size
                            },
                            Translate {
                                x: artBox.by.x
                                y: artBox.by.y
                            }
                        ]

                        Item {
                            anchors.fill: parent

                            DropShadow {
                                anchors.fill: art
                                radius: artBox.corner
                                blur: Appearance.padding.normal / artBox.size
                                offset.y: Appearance.padding.small / 2 / artBox.size
                                opacity: art.ready ? 0.7 : 0
                            }

                            SquircleRect {
                                anchors.fill: parent
                                radius: artBox.corner
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
                                radius: artBox.corner
                                source: Media.artUrl
                            }

                            SquircleRect {
                                anchors.fill: parent
                                visible: Media.canRaise
                                radius: artBox.corner
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
                    }

                    Item {
                        width: parent.width
                        height: lines.height
                        visible: Media.available

                        Column {
                            id: lines

                            width: parent.width
                            spacing: Appearance.padding.small / 2

                            Item {
                                id: titleLine

                                readonly property var from: root.origin?.title ?? null
                                readonly property real start: (root.origin?.titleSize ?? Appearance.font.size.normal) / Appearance.font.size.normal
                                readonly property real size: titleLine.from ? root.mix(titleLine.start, 1) : 1
                                readonly property point by: root.flight(titleLine.from, titleLine, false)

                                width: parent.width
                                height: title.implicitHeight
                                baselineOffset: title.baselineOffset
                                opacity: root.arrives(titleLine.from)

                                transform: [
                                    Scale {
                                        xScale: titleLine.size
                                        yScale: titleLine.size
                                    },
                                    Translate {
                                        x: titleLine.by.x
                                        y: titleLine.by.y
                                    }
                                ]

                                Item {
                                    width: titleLine.from ? root.mix(titleLine.from.width / titleLine.start, titleLine.width) : titleLine.width
                                    height: titleLine.from ? root.mix(title.implicitHeight / Math.max(1, title.lineCount), titleLine.height) : titleLine.height
                                    clip: root.flown < 1

                                    CrossfadeText {
                                        id: title

                                        width: titleLine.width
                                        text: Media.title
                                        pixelSize: Appearance.font.size.normal
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                    }
                                }
                            }

                            Item {
                                id: artistLine

                                readonly property var from: root.origin?.artist ?? null
                                readonly property point by: artistLine.from ? root.flight(artistLine.from, artistLine, false) : titleLine.by

                                width: parent.width - beat.width - Appearance.padding.small
                                height: artist.implicitHeight
                                baselineOffset: artist.baselineOffset
                                visible: !!Media.artist
                                opacity: root.arrives(artistLine.from)

                                transform: Translate {
                                    x: artistLine.by.x
                                    y: artistLine.by.y
                                }

                                Item {
                                    width: artistLine.from ? root.mix(artistLine.from.width, artistLine.width) : artistLine.width
                                    height: artistLine.height
                                    clip: root.flown < 1

                                    CrossfadeText {
                                        id: artist

                                        width: artistLine.width
                                        text: Media.artist
                                        color: Appearance.colour.textDim
                                    }
                                }
                            }

                            Item {
                                id: albumLine

                                readonly property var from: root.origin?.album ?? null
                                readonly property point by: albumLine.from ? root.flight(albumLine.from, albumLine, false) : titleLine.by

                                width: parent.width - beat.width - Appearance.padding.small
                                height: album.implicitHeight
                                baselineOffset: album.baselineOffset
                                visible: !!Media.album || !!Media.app
                                opacity: root.arrives(albumLine.from)

                                transform: Translate {
                                    x: albumLine.by.x
                                    y: albumLine.by.y
                                }

                                Item {
                                    width: albumLine.from ? root.mix(albumLine.from.width, albumLine.width) : albumLine.width
                                    height: albumLine.height
                                    clip: root.flown < 1

                                    CrossfadeText {
                                        id: album

                                        width: albumLine.width
                                        text: Media.album || Media.app
                                        color: Appearance.colour.textFaint
                                    }
                                }
                            }
                        }

                        Equalizer {
                            id: beat

                            readonly property Item last: albumLine.visible ? albumLine : artistLine.visible ? artistLine : titleLine
                            readonly property var from: root.origin?.beat ?? null
                            readonly property point by: root.flight(beat.from, beat, false)

                            anchors.right: parent.right
                            y: beat.last.y + beat.last.baselineOffset - beat.height
                            playing: Media.playing
                            color: Appearance.colour.accent
                            opacity: root.arrives(beat.from)

                            transform: Translate {
                                x: beat.by.x
                                y: beat.by.y
                            }
                        }
                    }

                    Scrubber {
                        id: scrub

                        readonly property var from: root.origin?.scrub ?? null
                        readonly property point by: root.flight(scrub.from, scrub, false)

                        width: scrub.from ? root.mix(scrub.from.width, parent.width) : parent.width
                        visible: Media.available && (Media.length > 0 || Media.hasTrack)
                        watched: root.open
                        opacity: root.arrives(scrub.from)

                        transform: Translate {
                            x: scrub.by.x
                            y: scrub.by.y
                        }
                    }

                    MediaTransport {
                        id: transport

                        readonly property var from: root.origin?.transport ?? null
                        readonly property real start: (root.origin?.transportZoom ?? transport.zoom) / transport.zoom
                        readonly property real size: transport.from ? root.mix(transport.start, 1) : 1
                        readonly property point by: root.flight(transport.from, transport, true)

                        width: parent.width
                        visible: Media.available
                        zoom: 1.3
                        extended: true
                        opacity: root.arrives(transport.from)

                        transform: [
                            Scale {
                                origin.x: transport.width / 2
                                origin.y: transport.height / 2
                                xScale: transport.size
                                yScale: transport.size
                            },
                            Translate {
                                x: transport.by.x
                                y: transport.by.y
                            }
                        ]
                    }

                    Item {
                        width: parent.width
                        height: Math.max(chips.height, lyricsButton.height)
                        visible: Media.available
                        opacity: root.arrives(null)

                        transform: Translate {
                            x: root.ride.x
                            y: root.ride.y
                        }

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
                                    running: Lyrics.loading && root.open && !Appearance.lessMotion
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
                    opacity: root.arrives(null)

                    transform: Translate {
                        x: root.ride.x
                        y: root.ride.y
                    }

                    LyricsView {
                        width: root.lyricsWidth
                        height: parent.height
                        opacity: stage.value * stage.value
                        live: root.open && root.showsLyrics
                    }
                }
            }
        }
    }
}
