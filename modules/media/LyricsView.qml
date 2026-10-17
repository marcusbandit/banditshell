pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property bool live: false

    property real time: 0
    property int current: -1

    readonly property bool synced: Lyrics.synced

    readonly property real anchorY: root.height * 0.34
    readonly property real fade: Appearance.padding.huge * 2

    property bool browsing: false
    property real browseTarget: 0

    readonly property real maxScroll: Math.max(0, column.height - root.height + root.fade)
    readonly property real minScroll: -root.fade

    readonly property Item focusItem: {
        if (!root.synced || lines.count === 0)
            return null;
        return lines.itemAt(Math.max(0, root.current));
    }

    readonly property real followTarget: root.focusItem ? root.focusItem.y + root.focusItem.height / 2 - root.anchorY : 0

    function tick(): void {
        root.time = Media.now();
        root.current = Lyrics.indexAt(root.time);
    }

    FrameAnimation {
        running: root.live && root.synced

        onTriggered: root.tick()
    }

    Connections {
        target: Lyrics

        function onLinesChanged(): void {
            root.reset();
        }

        function onPlainLinesChanged(): void {
            root.reset();
        }
    }

    function reset(): void {
        root.browsing = false;
        root.browseTarget = root.minScroll;
        root.tick();
        Qt.callLater(scroll.snap);
    }

    onLiveChanged: if (root.live) {
        root.tick();
        Qt.callLater(scroll.snap);
    }

    Follow {
        id: scroll

        target: root.browsing || !Lyrics.synced ? root.browseTarget : root.followTarget
        speed: Appearance.animation.scrollSpeed * 0.55
        epsilon: 0.2
    }

    Timer {
        id: comeBack

        interval: 3500

        onTriggered: root.browsing = false
    }

    Item {
        id: viewport

        anchors.fill: parent
        clip: true

        layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: edges
            maskThresholdMin: 0.0
            maskSpreadAtMin: 1.0
        }

        Column {
            id: column

            width: parent.width
            y: -scroll.value

            Repeater {
                id: lines

                model: Lyrics.lines

                delegate: LyricLine {
                    current: root.current
                    time: root.time
                    seekable: Media.canSeek

                    onPicked: at => {
                        root.browsing = false;
                        Media.seekTo(Math.max(0, at - Lyrics.lead));
                    }
                }
            }

            Repeater {
                model: Lyrics.plain ? Lyrics.plainLines : []

                delegate: StyledText {
                    required property string modelData

                    x: Appearance.padding.normal
                    width: column.width - Appearance.padding.normal * 2
                    height: modelData === "" ? Appearance.font.line.small : implicitHeight + Appearance.padding.small
                    text: modelData
                    wrapMode: Text.Wrap
                    font.pixelSize: Appearance.font.size.normal
                    color: Appearance.colour.textDim
                }
            }

            Item {
                width: parent.width
                height: credit.implicitHeight + Appearance.padding.huge

                StyledText {
                    id: credit

                    x: Appearance.padding.normal
                    anchors.bottom: parent.bottom
                    width: parent.width - Appearance.padding.normal * 2
                    wrapMode: Text.Wrap
                    text: (Lyrics.writers.length > 0 ? `written by ${Lyrics.writers.join(", ")}\n` : "") + (Lyrics.plain ? `lyrics from ${Lyrics.source}, not synced` : `lyrics from ${Lyrics.source}`) + (Lyrics.spicyAbsent && Lyrics.spotifyId ? "\nword timing needs Spicy Lyrics in Spotify: run install.sh" : "")
                    color: Appearance.colour.textFaint
                }
            }
        }
    }

    Item {
        id: edges

        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            width: parent.width
            height: root.fade
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 1
                    color: "white"
                }
            }
        }

        Rectangle {
            y: root.fade
            width: parent.width
            height: Math.max(0, parent.height - root.fade * 2)
            color: "white"
        }

        Rectangle {
            y: parent.height - root.fade
            width: parent.width
            height: root.fade
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "white"
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => {
            if (!root.browsing) {
                root.browsing = true;
                root.browseTarget = scroll.value;
            }
            const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * Appearance.font.line.normal * 2;
            root.browseTarget = Math.max(root.minScroll, Math.min(root.maxScroll, root.browseTarget - delta));
            comeBack.restart();
        }
    }
}
