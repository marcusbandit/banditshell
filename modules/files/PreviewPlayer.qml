import QtQuick
import QtMultimedia

MediaPlayer {
    readonly property bool playing: playbackState === MediaPlayer.PlayingState
    property string loaded: ""

    audioOutput: AudioOutput {}
}
