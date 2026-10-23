pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import "urls.js" as Urls
import "markdown.js" as Markdown

Item {
    id: root

    required property var entry
    required property string path

    property var stat: null

    readonly property bool isMarkdown: root.language === "markdown"
    readonly property bool rendered: root.isMarkdown && Files.markdownRendered
    readonly property bool isFolder: root.entry && root.entry.kind === "dir"
    readonly property bool isImage: root.entry && root.entry.class === "image" && !root.entry.broken
    readonly property bool isAudio: root.entry && root.entry.class === "audio"
    readonly property bool isText: root.stat && root.stat.text && root.stat.size <= Config.values.files.textMax

    readonly property var languages: ({
            c: ["c", "h", "cpp", "cc", "cxx", "hpp", "hh"],
            css: ["css", "scss", "sass", "less"],
            javascript: ["js", "jsx", "mjs", "cjs", "ts", "tsx"],
            json: ["json"],
            python: ["py"],
            qml: ["qml"],
            shell: ["sh", "bash", "zsh", "fish"],
            sql: ["sql"],
            toml: ["toml"],
            yaml: ["yaml", "yml"],
            html: ["html", "htm", "xml", "svg"],
            diff: ["diff", "patch"],
            markdown: ["md", "markdown"]
        })

    readonly property string language: {
        const ext = root.entry ? root.entry.ext : "";
        if (!ext)
            return "";
        for (const name in root.languages)
            if (root.languages[name].includes(ext))
                return name;
        return "";
    }

    property var contents: []
    property string contentsError: ""

    readonly property var player: playback.item

    readonly property bool soundMissing: playback.status === Loader.Error

    onPathChanged: {
        root.stat = null;
        root.contents = [];
        root.contentsError = "";
        root.player?.stop();
        body.content = "";
        if (!root.path)
            return;

        statter.exec([Files.helper("bs-ls"), "--stat", root.path]);

        peek.exec([Files.helper("bs-ls"), root.path]);
    }

    onVisibleChanged: if (!root.visible)
        root.player?.stop()

    Connections {
        target: Files

        function onWindowOpenChanged(): void {
            if (!Files.windowOpen)
                root.player?.stop();
        }
    }

    Process {
        id: peek

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const answer = JSON.parse(text);
                    if (answer.path !== root.path)
                        return;
                    root.contentsError = answer.ok ? "" : answer.error;

                    root.contents = answer.ok ? answer.entries.filter(e => Files.showHidden || !e.hidden).sort((a, b) => {
                        if ((a.kind === "dir") !== (b.kind === "dir"))
                            return a.kind === "dir" ? -1 : 1;
                        return a.name.localeCompare(b.name, undefined, {numeric: true, sensitivity: "base"});
                    }) : [];
                } catch (e) {
                    root.contents = [];
                }
            }
        }
    }

    Process {
        id: statter

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const answer = JSON.parse(text);

                    if (answer.path === root.path)
                        root.stat = answer.ok ? answer : null;
                } catch (e) {
                    root.stat = null;
                }
            }
        }
    }

    Column {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Appearance.padding.small

        Row {
            width: parent.width
            spacing: Appearance.padding.normal

            FileMark {
                anchors.verticalCenter: parent.verticalCenter

                fileClass: root.entry ? root.entry.class : "unknown"
                link: root.entry ? root.entry.link : false
                broken: root.entry ? root.entry.broken : false
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Appearance.font.iconSize - Appearance.padding.normal - (root.isMarkdown ? toggle.width + Appearance.padding.normal : 0)

                text: root.entry ? root.entry.name : ""

                font.pixelSize: Appearance.font.size.normal
                elide: Text.ElideMiddle
            }

            Item {
                id: toggle

                anchors.verticalCenter: parent.verticalCenter

                visible: root.isMarkdown
                implicitWidth: Appearance.sizes.minTarget
                implicitHeight: Appearance.sizes.minTarget

                SquircleRect {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.hair

                    radius: Appearance.rounding.small
                    color: root.rendered ? Appearance.colour.fillStrong : togglepress.containsMouse ? Appearance.colour.fill : "transparent"
                }

                Icon {
                    id: toggleGlyph

                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: toggleGlyph.inkOffsetX
                    anchors.verticalCenterOffset: toggleGlyph.inkOffsetY

                    name: root.rendered ? "article" : "code"
                    size: Files.zoomed(Appearance.font.iconSize)
                    color: root.rendered ? Appearance.colour.text : Appearance.colour.textDim
                }

                MouseArea {
                    id: togglepress

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: Files.toggleMarkdown()
                }
            }
        }

        StyledText {
            width: parent.width

            text: {
                if (!root.entry)
                    return "";

                const size = root.isFolder ? `${root.contents.length} item${root.contents.length === 1 ? "" : "s"}` : Files.humanSize(root.entry.size);
                const parts = [size, Files.humanTime(root.entry.mtime)];
                if (root.stat && root.stat.owner)
                    parts.push(`${root.stat.owner} ${Files.humanMode(root.stat.mode)}`);
                return parts.join("  ·  ");
            }
            font.pixelSize: Files.zoomed(Appearance.font.size.small)
            color: Appearance.colour.textFaint

            elide: Text.ElideRight
        }

        Separator {
            width: parent.width
        }
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: Appearance.padding.normal

        SquircleImage {
            anchors.fill: parent
            visible: root.isImage

            source: root.isImage ? Urls.fileUrl(root.path) : ""
            fillMode: Image.PreserveAspectFit
            radius: Appearance.rounding.small
        }

        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: Appearance.padding.large
            visible: root.isAudio

            FileMark {
                anchors.horizontalCenter: parent.horizontalCenter

                fileClass: "audio"
                size: Appearance.icon.hero
            }

            Item {
                id: transport

                anchors.horizontalCenter: parent.horizontalCenter

                implicitWidth: transport.ring
                implicitHeight: transport.ring

                readonly property real ring: Appearance.font.iconSize + Appearance.padding.normal * 2

                scale: pressScale.value

                Follow {
                    id: pressScale

                    target: press.pressed ? Appearance.press.ring : press.containsMouse ? Appearance.press.ringHover : 1
                    speed: Appearance.animation.revealSpeed
                    epsilon: Appearance.animation.fadeEpsilon
                    startsAtTarget: true
                }

                SquircleRect {
                    anchors.fill: parent

                    pill: "object"
                    stroke: Appearance.colour.text
                    strokeWidth: Appearance.stroke.ring
                }

                Icon {
                    id: playGlyph

                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: playGlyph.inkOffsetX
                    anchors.verticalCenterOffset: playGlyph.inkOffsetY

                    name: root.player?.playing ? "pause" : "play_arrow"
                }

                MouseArea {
                    id: press

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        playback.active = true;
                        if (!root.player)
                            return;
                        if (root.player.loaded !== root.path) {
                            root.player.loaded = root.path;
                            root.player.source = Urls.fileUrl(root.path);
                        }
                        if (root.player.playing)
                            root.player.pause();
                        else
                            root.player.play();
                    }
                }
            }

            Slider {
                width: parent.width

                enabled: (root.player?.duration ?? 0) > 0
                value: root.player?.position ?? 0
                to: Math.max(1, root.player?.duration ?? 0)
                onMoved: v => root.player.position = v
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter

                text: root.soundMissing ? "playing it needs qt6-multimedia" : `${Files.humanDuration(root.player?.position ?? 0)} / ${Files.humanDuration(root.player?.duration ?? 0)}`
                color: Appearance.colour.textFaint
            }
        }

        GlideList {
            anchors.fill: parent
            visible: root.isFolder && root.contents.length > 0
            clip: true

            model: root.contents

            delegate: Row {
                id: line

                required property var modelData

                spacing: Appearance.padding.small

                FileMark {
                    anchors.verticalCenter: parent.verticalCenter

                    fileClass: line.modelData.class
                    link: line.modelData.link
                    broken: line.modelData.broken
                    size: Appearance.icon.small
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter

                    text: line.modelData.name
                    font.pixelSize: Files.zoomed(Appearance.font.size.small)
                    color: Appearance.colour.textDim
                    elide: Text.ElideRight
                }
            }
        }

        Flickable {
            id: scroller

            anchors.fill: parent
            visible: root.isText && root.rendered
            clip: true

            contentHeight: document.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            WheelStep {
                flick: scroller
            }

            Text {
                id: document

                width: parent.width

                text: root.rendered ? Markdown.inert(Markdown.flattenHeadings(body.content)) : ""
                textFormat: Text.MarkdownText
                wrapMode: Text.Wrap

                font.family: Appearance.font.family
                font.pixelSize: Files.zoomed(Appearance.font.size.small)
                renderType: Text.NativeRendering
                color: Appearance.colour.text
                linkColor: Appearance.colour.accent

                onLinkActivated: link => System.openWith(link)
            }
        }

        CodeBlock {
            anchors.fill: parent
            visible: root.isText && !root.rendered

            text: body.content

            language: root.language
            wrap: true
        }

        Column {
            anchors.centerIn: parent
            spacing: Appearance.padding.normal
            visible: !root.isImage && !root.isAudio && !root.isText && !(root.isFolder && root.contents.length > 0)

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter

                name: root.stat && !root.stat.readable || root.contentsError ? "lock" : root.isFolder ? "folder_open" : "visibility_off"
                size: Appearance.icon.huge
                color: Appearance.colour.textFaint
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter

                text: {
                    if (!root.entry)
                        return "nothing selected";
                    if (root.stat && !root.stat.readable)
                        return "not readable";
                    if (root.isFolder)
                        return root.contentsError ? root.contentsError : "empty folder";
                    if (root.stat && root.stat.text)
                        return "too large to preview";
                    return "no preview";
                }
                color: Appearance.colour.textFaint
            }
        }
    }

    FileView {
        id: body

        property string content: ""

        path: root.isText ? root.path : ""
        printErrors: false
        blockLoading: false

        onLoaded: body.content = body.text()
        onLoadFailed: body.content = ""
    }

    Loader {
        id: playback

        active: false
        source: Qt.resolvedUrl("PreviewPlayer.qml")
    }
}
