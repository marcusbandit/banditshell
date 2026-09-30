pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property real border

    readonly property bool open: root.shown
    property bool shown: false

    readonly property Item maskItem: catcher

    property string restoreTo: ""

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    readonly property real cardWidth: Appearance.sizes.mediaPanelWidth
    readonly property real pad: Appearance.padding.large
    readonly property real innerWidth: root.cardWidth - root.pad * 2

    readonly property real artSize: Math.round(root.innerWidth / 4)

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

    function show(): void {
        if (root.shown)
            return;

        root.quip = root.quips[Math.floor(Math.random() * root.quips.length)];
        root.restoreTo = Hypr.focusedOn(root.screenName);
        root.shown = true;

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

    function volume(dir: int): void {
        if (!Audio.ready)
            return;
        Audio.setVolume(Audio.quantise(Audio.volume + dir * Appearance.sizes.volumeStep));
    }

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

    Item {
        id: keys

        Keys.onPressed: event => {
            const shift = event.modifiers & Qt.ShiftModifier;

            switch (event.key) {
            case Qt.Key_Escape:
                root.hide();
                break;
            case Qt.Key_Space:

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

        x: (root.width - panel.width) / 2
        y: root.border + panel.restY + (1 - reveal.value) * Appearance.padding.huge * 2
        width: root.cardWidth
        height: column.height + root.pad * 2
        visible: reveal.value > 0.001
        enabled: root.open

        transform: Scale {
            xScale: 0.85 + 0.15 * reveal.value
            yScale: xScale

            origin.x: panel.width / 2
            origin.y: panel.height / 2
        }

        opacity: Math.min(1, reveal.value * 1.6)

        SquircleRect {
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

            Item {
                width: parent.width
                height: Math.max(root.artSize, trackText.height)
                visible: Media.available

                SquircleRect {
                    id: art

                    anchors.verticalCenter: parent.verticalCenter

                    width: root.artSize
                    height: width
                    radius: Appearance.rounding.normal
                    color: Appearance.colour.fill

                    SquircleImage {
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

            Scrubber {
                width: parent.width
                visible: Media.available && (Media.length > 0 || Media.hasTrack)
                watched: root.open
            }

            MediaTransport {
                width: parent.width
                visible: Media.available
                zoom: 1.4
            }

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

                        SquircleRect {
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
