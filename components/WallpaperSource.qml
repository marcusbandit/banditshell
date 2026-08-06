pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import qs.config
import qs.services

// ONE WALLPAPER, whatever kind of file it turns out to be.
//
// The surface above this holds two of these and cross-fades between them, and
// that surface must not know or care whether it is fading a photograph into a
// video or a video into an SVG. So everything that differs by format is in
// here, and what leaves is the same three things every time:
//
//   path      what to show; assign it and this builds whatever can draw it
//   ready     it has decoded far enough to be worth showing
//   playing   whether the thing that moves is moving (ignored by stills)
//
// `ready` is the whole reason this is not three elements at the call site. A
// wallpaper swap is only invisible if the new one is already decoded when it
// arrives, and "decoded" is `Image.Ready` for a picture, the same for a GIF's
// first frame, and a media status for a video. Three spellings of one fact,
// which is exactly what a component is for.
//
// NOTHING IS EVER BUILT FOR A KIND IT IS NOT. A Loader per kind rather than
// three elements with `visible` on them: a MediaPlayer that exists is a decoder
// thread and a hardware surface whether or not anyone is looking at it, and the
// point of the gate above is to not pay for those.
Item {
    id: root

    // The file to draw. Empty builds nothing at all, which is the state a slot
    // is in before it has ever been used.
    property string path: ""

    // Whether motion should be running. A still ignores it; a GIF and a video
    // both stop where they are rather than rewinding, because this is a pause
    // for the sake of the GPU and resuming from the beginning would turn every
    // workspace change into a restart of the animation.
    property bool playing: true

    // Whether the file's own sound is allowed out. Off by default and off in
    // practice: a desktop that makes noise at you is a desktop nobody keeps.
    // See config/Config.qml's `wallpaper.audio`.
    property bool audible: false

    readonly property string kind: Wallpaper.kindOf(root.path)

    // Decoded far enough that showing it will not be a blank frame.
    readonly property bool ready: loader.item?.ready ?? false

    // An audio file has no picture in it, so there is nothing to fade to and
    // the black behind the whole surface is the picture. It still counts as
    // ready the moment the player has it, or the cross-fade above would wait
    // forever for a frame that is never coming.
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
            // Everything else including SVG, and including a file whose
            // extension this shell has never heard of: Image knows more formats
            // than any list here can, so an unknown one is worth handing to it
            // rather than refusing on the strength of its name.
            return still;
        }
    }

    // --------------------------------------------------------------- still

    Component {
        id: still

        Image {
            id: image

            readonly property bool ready: status === Image.Ready

            anchors.fill: parent
            source: root.path
            fillMode: Image.PreserveAspectCrop
            asynchronous: true

            // Decoded at the size it is DRAWN at, not the file's own: a 4K png
            // on a 1080p screen is four times the memory for no pixels anyone
            // can see.
            //
            // AND IT IS WHAT MAKES SVG WORK. An SVG has no pixels of its own,
            // so Qt rasterises it at whatever size it is told and then scales
            // that bitmap like any other: left unset, it rasterises at the
            // document's nominal size, which is usually a few hundred pixels,
            // and a wallpaper-sized blur is what reaches the screen. Set, the
            // curves are drawn at the screen's own resolution, which is the one
            // thing a vector wallpaper is for.
            sourceSize.width: root.width
            sourceSize.height: root.height
        }
    }

    // -------------------------------------------------------------- motion

    Component {
        id: motion

        AnimatedImage {
            readonly property bool ready: status === AnimatedImage.Ready

            anchors.fill: parent
            source: root.path
            fillMode: AnimatedImage.PreserveAspectCrop
            asynchronous: true
            cache: false

            // WHERE IT STOPS, not whether it exists. A paused AnimatedImage
            // holds its current frame on screen and decodes nothing, which is
            // the whole point: the desktop keeps its picture and the GPU keeps
            // its cycles.
            paused: !root.playing

            // NO sourceSize. An animated image decoded to a fixed size loses
            // its frame cache between frames in Qt, which turns a paused-most-
            // of-the-time GIF into a full re-decode every time it resumes. A
            // GIF is small by construction; this is the one place the memory is
            // worth spending.
        }
    }

    // --------------------------------------------------- video, and audio

    Component {
        id: played

        Item {
            id: playback

            // BufferedMedia is "playing and has data ahead of it"; LoadedMedia
            // is "opened, first frame available, not started". Either is enough
            // to put on screen, and an audio file only ever reaches the second
            // one before it is told to play.
            readonly property bool ready: player.mediaStatus === MediaPlayer.LoadedMedia || player.mediaStatus === MediaPlayer.BufferedMedia || player.mediaStatus === MediaPlayer.BufferingMedia || player.mediaStatus === MediaPlayer.EndOfMedia

            anchors.fill: parent

            MediaPlayer {
                id: player

                source: root.path
                videoOutput: root.blank ? null : output
                audioOutput: AudioOutput {
                    muted: !root.audible
                }

                // A wallpaper has no end. `loops` rather than restarting on
                // EndOfMedia: the handler way leaves a black frame between the
                // last frame and the first while the player seeks, and on a
                // short clip that black frame arrives every few seconds.
                loops: MediaPlayer.Infinite

                // PLAY AND PAUSE, never stop. Stopping releases the decoder and
                // seeks to zero, so the next empty workspace would restart the
                // clip AND pay the open cost again; pausing holds the frame that
                // is already on screen and costs nothing to leave there.
                //
                // Bound through a handler rather than a `playbackState` binding
                // because playbackState is not writable: it is what the player
                // is doing, and play()/pause() are how you ask.
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
