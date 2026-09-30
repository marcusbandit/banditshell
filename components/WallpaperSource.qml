pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import qs.services

Item {
    id: root

    property string path: ""

    property bool playing: true

    property bool audible: false

    readonly property string kind: Wallpaper.kindOf(root.path)

    readonly property bool ready: loader.item?.ready ?? false

    readonly property bool blank: root.kind === "audio"

    Loader {
        id: loader

        anchors.fill: parent

        sourceComponent: {
            if (!root.path)
                return null;
            if (root.kind === "motion")
                return motion;
            if (root.kind === "video" || root.kind === "audio")
                return played;

            return still;
        }
    }

    Component {
        id: still

        Image {
            id: image

            readonly property bool ready: status === Image.Ready

            anchors.fill: parent
            source: root.path
            fillMode: Image.PreserveAspectCrop
            asynchronous: true

            sourceSize.width: Math.round(root.width * Screen.devicePixelRatio)
            sourceSize.height: Math.round(root.height * Screen.devicePixelRatio)
        }
    }

    Component {
        id: motion

        AnimatedImage {
            readonly property bool ready: status === AnimatedImage.Ready

            anchors.fill: parent
            source: root.path
            fillMode: AnimatedImage.PreserveAspectCrop
            asynchronous: true
            cache: false

            paused: !root.playing

        }
    }

    Component {
        id: played

        Item {
            id: playback

            readonly property bool ready: player.mediaStatus === MediaPlayer.LoadedMedia || player.mediaStatus === MediaPlayer.BufferedMedia || player.mediaStatus === MediaPlayer.BufferingMedia || player.mediaStatus === MediaPlayer.EndOfMedia

            anchors.fill: parent

            MediaPlayer {
                id: player

                source: root.path
                videoOutput: root.blank ? null : output
                audioOutput: AudioOutput {
                    muted: !root.audible
                }

                loops: MediaPlayer.Infinite

                onMediaStatusChanged: playback.apply()
            }

            function apply(): void {
                if (root.playing)
                    player.play();
                else
                    player.pause();
            }

            Connections {
                target: root

                function onPlayingChanged(): void {
                    playback.apply();
                }
            }

            Component.onCompleted: playback.apply()

            VideoOutput {
                id: output

                anchors.fill: parent
                visible: !root.blank
                fillMode: VideoOutput.PreserveAspectCrop
            }
        }
    }
}
