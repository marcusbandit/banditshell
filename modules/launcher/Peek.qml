pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import qs.modules.windows
import "search.js" as Search

Item {
    id: root

    property var row: null
    property bool wanted: false
    property real longestFrame: Infinity
    property bool growsLeft: false
    property string colour: ""

    signal colourPicked(string hex, bool done)

    readonly property bool animated: Config.values.launcher.animatePreview && !Appearance.lessMotion

    readonly property var toplevel: root.row?.kind === "window" ? Hyprland.toplevels.values.find(t => Hypr.windowAddress(t.address) === root.row.address) ?? null : null
    readonly property string peekPath: root.row?.peekPath ?? (root.row?.kind === "file" ? root.row.path : "")
    readonly property bool peekDir: root.row?.peekPath ? !!root.row.peekDir : !!root.row?.dir
    readonly property bool isFile: !!root.peekPath && !root.peekDir
    readonly property var clip: root.row?.kind === "clipboard" ? root.row.entry : null
    readonly property string clipText: root.row?.peekText ? root.row.peekText : root.clip && !root.clip.file && ((root.clip.text ?? "").length > 48 || (root.clip.text ?? "").trim().indexOf("\n") >= 0) ? root.clip.text : ""
    readonly property string picture: root.isFile && Search.isPicture(root.peekPath) ? root.peekPath : root.clip?.kind === "image" && root.clip.file ? root.clip.file : ""
    readonly property string pictureSource: root.row?.peekImage || (root.picture ? Search.fileUrl(root.picture) : "")
    readonly property string document: root.isFile && !root.picture && Search.isText(root.peekPath) && !Search.isSecretish(root.peekPath) ? root.peekPath : ""
    readonly property string folder: root.peekPath && root.peekDir ? root.peekPath : ""
    readonly property string listed: root.document || root.folder || (root.clipText ? "clipboard" : "")
    readonly property int hitLine: root.document ? root.row.line ?? 0 : 0
    readonly property int firstLine: Math.max(1, root.hitLine - 6)
    readonly property int lineCount: 32

    property var lines: []
    property string linesOf: ""

    readonly property string readKey: root.wanted && (root.document || root.folder) ? `${root.document || root.folder}:${root.firstLine}` : ""

    onReadKeyChanged: root.read()

    function read(): void {
        if (reader.running) {
            reader.owed = true;
            reader.running = false;
            return;
        }
        if (!root.readKey)
            return;
        reader.key = root.readKey;
        reader.command = root.folder ? ["ls", "-1Ap", "--group-directories-first", "--", root.folder] : ["sh", "-c", 'sed -n "$1" -- "$2" | cut -c1-300', "sh", `${root.firstLine},${root.firstLine + root.lineCount - 1}p;${root.firstLine + root.lineCount - 1}q`, root.document];
        reader.running = true;
    }

    Process {
        id: reader

        property string key: ""
        property bool owed: false

        onRunningChanged: {
            if (!reader.running && reader.owed) {
                reader.owed = false;
                root.read();
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (reader.key !== root.readKey)
                    return;
                root.lines = this.text.replace(/\t/g, "    ").split("\n").slice(0, root.lineCount).map(line => line.slice(0, 300));
                root.linesOf = reader.key;
            }
        }
    }

    readonly property bool textReady: root.clipText ? root.wanted : !!root.readKey && root.linesOf === root.readKey && root.lines.some(l => l.trim() !== "")
    readonly property var shownLines: root.clipText ? root.clipText.slice(0, 4000).replace(/\t/g, "    ").split("\n").slice(0, root.lineCount) : root.lines

    readonly property var windowSize: root.toplevel?.lastIpcObject?.size ?? null
    readonly property real aspect: root.toplevel ? (root.windowSize ? root.windowSize[0] / Math.max(1, root.windowSize[1]) : 16 / 9) : image.ready ? image.aspect : 16 / 10

    readonly property bool picking: !!root.colour
    readonly property bool paged: root.picking || !!root.listed

    readonly property bool ready: root.picking || (root.toplevel ? shot.ready : root.pictureSource ? image.ready : root.textReady)
    readonly property bool loading: !root.toplevel && !root.picking && !!root.pictureSource && image.status === Image.Loading
    readonly property bool shown: root.wanted && (root.picking || !!root.toplevel || !!root.pictureSource || !!root.listed) && (root.ready || root.loading && root.visible)

    readonly property real frame: Appearance.padding.small
    readonly property real span: Appearance.sizes.launcherWidth * 0.7
    readonly property real tallest: Appearance.sizes.launcherWidth * 0.8

    readonly property real fullWidth: root.paged ? Math.round(root.span + root.frame * 2) : Math.round(Math.min(root.span, root.tallest * root.aspect) + root.frame * 2)
    readonly property real fullHeight: root.picking ? Math.round(picker.implicitHeight + Appearance.padding.normal * 2) : root.listed ? Math.round(Math.min(root.tallest, page.implicitHeight + Appearance.padding.normal * 2)) : Math.round(Math.min(root.tallest, root.span / root.aspect) + root.frame * 2)
    readonly property size full: Qt.size(root.fullWidth, root.fullHeight)

    property size held: Qt.size(0, 0)

    function hold(): void {
        if (!root.ready)
            return;
        root.held = root.full;
        if (!root.animated || !root.visible) {
            frameWidth.snap();
            frameHeight.snap();
        }
    }

    onFullChanged: root.hold()
    onReadyChanged: root.hold()
    onAnimatedChanged: root.hold()

    Follow {
        id: frameWidth

        target: root.held.width
        speed: Appearance.animation.resizeSpeed
        epsilon: 0.5
        longestFrame: root.longestFrame
    }

    Follow {
        id: frameHeight

        target: root.held.height
        speed: Appearance.animation.resizeSpeed
        epsilon: 0.5
        longestFrame: root.longestFrame
    }

    width: Math.round(frameWidth.value)
    height: Math.round(frameHeight.value)

    opacity: fade.value
    visible: fade.value > 0.01
    scale: 0.96 + 0.04 * fade.value

    Follow {
        id: fade

        target: root.shown ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.01
        longestFrame: root.longestFrame
    }

    SquircleRect {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colour.surfaceSolid
        stroke: Appearance.colour.fillStrong
        strokeWidth: 1
    }

    Item {
        id: window

        anchors.fill: parent
        anchors.margins: root.frame
        clip: true

        layer.enabled: root.visible
        layer.effect: ShaderEffect {
            property real corner: Appearance.rounding.normal - root.frame
            property real power: Appearance.rounding.power
            property vector2d extent: Qt.vector2d(width, height)
            property vector4d crop: Qt.vector4d(0, 0, 1, 1)

            fragmentShader: Qt.resolvedUrl("../../components/squircle.frag.qsb")
        }

        Item {
            id: content

            x: root.growsLeft ? window.width - width : 0
            width: root.fullWidth - root.frame * 2
            height: root.fullHeight - root.frame * 2

            WindowView {
                id: shot

                anchors.fill: parent
                visible: !!root.toplevel && !root.picking

                window: root.wanted ? root.toplevel : null
                radius: Appearance.rounding.normal - root.frame
                live: root.wanted
            }

            SquircleImage {
                id: image

                anchors.fill: parent
                visible: !root.toplevel && !root.picking && !!root.pictureSource

                source: root.wanted ? root.pictureSource : ""
                radius: Appearance.rounding.normal - root.frame
                fillMode: Image.PreserveAspectFit
                decodeWidth: root.span
                decodeHeight: root.tallest
            }

            ColourPicker {
                id: picker

                anchors.fill: parent
                anchors.margins: Appearance.padding.normal - root.frame
                visible: root.picking

                seed: root.colour
                onPicked: (hex, done) => root.colourPicked(hex, done)
            }

            Item {
                anchors.fill: parent
                anchors.margins: Appearance.padding.normal - root.frame
                visible: !!root.listed && !root.picking
                clip: true

                Column {
                    id: page

                    width: parent.width

                    Repeater {
                        model: root.textReady ? root.shownLines : []

                        delegate: Item {
                            id: textLine

                            required property string modelData
                            required property int index

                            readonly property bool hit: root.firstLine + textLine.index === root.hitLine

                            width: page.width
                            height: lineText.implicitHeight

                            SquircleRect {
                                visible: textLine.hit
                                anchors.fill: parent
                                anchors.leftMargin: -Appearance.padding.small
                                anchors.rightMargin: -Appearance.padding.small
                                radius: Appearance.rounding.small
                                color: Appearance.colour.accentFill
                            }

                            StyledText {
                                id: lineText

                                width: parent.width
                                text: textLine.modelData || " "
                                wrapMode: root.clipText ? Text.Wrap : Text.NoWrap
                                elide: root.clipText ? Text.ElideNone : Text.ElideRight
                                font.pixelSize: Appearance.font.size.small
                                color: textLine.hit ? Appearance.colour.text : Appearance.colour.textDim
                            }
                        }
                    }
                }
            }
        }
    }
}
