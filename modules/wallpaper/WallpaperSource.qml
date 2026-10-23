pragma ComponentBehavior: Bound

import QtQuick
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

        Loader {
            id: playback

            readonly property bool ready: playback.item?.ready ?? false

            anchors.fill: parent
            source: Qt.resolvedUrl("WallpaperPlayback.qml")

            onLoaded: {
                playback.item.playing = Qt.binding(() => root.playing);
                playback.item.audible = Qt.binding(() => root.audible);
                playback.item.blank = Qt.binding(() => root.blank);
                playback.item.path = Qt.binding(() => root.path);
            }
        }
    }
}
