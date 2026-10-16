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

    readonly property var toplevel: root.row?.kind === "window" ? Hyprland.toplevels.values.find(t => Hypr.windowAddress(t.address) === root.row.address) ?? null : null
    readonly property string peekPath: root.row?.peekPath ?? (root.row?.kind === "file" ? root.row.path : "")
    readonly property bool peekDir: root.row?.peekPath ? !!root.row.peekDir : !!root.row?.dir
    readonly property bool isFile: !!root.peekPath && !root.peekDir
    readonly property var clip: root.row?.kind === "clipboard" ? root.row.entry : null
    readonly property string clipText: root.row?.peekText ? root.row.peekText : root.clip && !root.clip.file && ((root.clip.text ?? "").length > 48 || (root.clip.text ?? "").trim().indexOf("\n") >= 0) ? root.clip.text : ""
    readonly property string picture: root.isFile && Search.isPicture(root.peekPath) ? root.peekPath : root.clip?.kind === "image" && root.clip.file ? root.clip.file : ""
    readonly property string document: root.isFile && !root.picture && Search.isText(root.peekPath) ? root.peekPath : ""
    readonly property string folder: root.peekPath && root.peekDir ? root.peekPath : ""
    readonly property string listed: root.document || root.folder || (root.clipText ? "clipboard" : "")
    readonly property int hitLine: root.document ? root.row.line ?? 0 : 0
    readonly property int firstLine: Math.max(1, root.hitLine - 6)
    readonly property int lineCount: 32

    property var lines: []
    property string linesOf: ""

    readonly property string readKey: root.wanted && (root.document || root.folder) ? `${root.document || root.folder}:${root.firstLine}` : ""

    onReadKeyChanged: {
        reader.running = false;
        if (!root.readKey)
            return;
        reader.key = root.readKey;
        reader.command = root.folder ? ["ls", "-1Ap", "--group-directories-first", "--", root.folder] : ["sed", "-n", `${root.firstLine},${root.firstLine + root.lineCount - 1}p;${root.firstLine + root.lineCount - 1}q`, "--", root.document];
        reader.running = true;
    }

    Process {
        id: reader

        property string key: ""

        stdout: StdioCollector {
            onStreamFinished: {
                if (reader.key !== root.readKey)
                    return;
                root.lines = this.text.replace(/\t/g, "    ").split("\n").slice(0, root.lineCount);
                root.linesOf = reader.key;
            }
        }
    }

    readonly property bool textReady: root.clipText ? root.wanted : !!root.readKey && root.linesOf === root.readKey && root.lines.some(l => l.trim() !== "")
    readonly property var shownLines: root.clipText ? root.clipText.replace(/\t/g, "    ").split("\n").slice(0, root.lineCount) : root.lines

    readonly property var windowSize: root.toplevel?.lastIpcObject?.size ?? null
    readonly property real aspect: root.toplevel ? (root.windowSize ? root.windowSize[0] / Math.max(1, root.windowSize[1]) : 16 / 9) : image.ready ? image.aspect : 16 / 10

    readonly property bool ready: root.toplevel ? shot.ready : root.picture ? image.ready : root.textReady
    readonly property bool shown: root.wanted && (!!root.toplevel || !!root.picture || !!root.listed) && root.ready

    readonly property real frame: Appearance.padding.small
    readonly property real span: Appearance.sizes.launcherWidth * 0.7
    readonly property real tallest: Appearance.sizes.launcherWidth * 0.8

    width: root.listed ? Math.round(root.span + root.frame * 2) : Math.round(Math.min(root.span, root.tallest * root.aspect) + root.frame * 2)
    height: root.listed ? Math.round(Math.min(root.tallest, page.implicitHeight + Appearance.padding.normal * 2)) : Math.round(Math.min(root.tallest, root.span / root.aspect) + root.frame * 2)

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

    DropShadow {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        blur: Appearance.padding.large
        offset.y: Math.round(Appearance.padding.small / 2)
    }

    SquircleRect {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colour.surfaceSolid
        stroke: Appearance.colour.fillStrong
        strokeWidth: 1
    }

    WindowView {
        id: shot

        anchors.fill: parent
        anchors.margins: root.frame
        visible: !!root.toplevel

        window: root.wanted ? root.toplevel : null
        radius: Appearance.rounding.normal - root.frame
        live: root.wanted
    }

    SquircleImage {
        id: image

        anchors.fill: parent
        anchors.margins: root.frame
        visible: !root.toplevel && !!root.picture

        source: root.wanted && root.picture ? Search.fileUrl(root.picture) : ""
        radius: Appearance.rounding.normal - root.frame
        fillMode: Image.PreserveAspectFit
        decodeWidth: root.span
        decodeHeight: root.tallest
    }

    Item {
        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        visible: !!root.listed
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
