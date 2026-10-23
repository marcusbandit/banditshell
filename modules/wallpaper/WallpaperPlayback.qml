import QtQuick
import QtMultimedia

Item {
    id: root

    property string path: ""

    property bool playing: false

    property bool audible: false

    property bool blank: false

    readonly property bool ready: player.mediaStatus === MediaPlayer.LoadedMedia || player.mediaStatus === MediaPlayer.BufferedMedia || player.mediaStatus === MediaPlayer.BufferingMedia || player.mediaStatus === MediaPlayer.EndOfMedia

    function apply(): void {
        if (root.playing)
            player.play();
        else
            player.pause();
    }

    onPlayingChanged: root.apply()
    Component.onCompleted: root.apply()

    MediaPlayer {
        id: player

        source: root.path
        videoOutput: root.blank ? null : output
        audioOutput: AudioOutput {
            muted: !root.audible
        }

        loops: MediaPlayer.Infinite

        onMediaStatusChanged: root.apply()
    }

    VideoOutput {
        id: output

        anchors.fill: parent
        visible: !root.blank
        fillMode: VideoOutput.PreserveAspectCrop
    }
}
