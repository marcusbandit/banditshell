pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import "urls.js" as Urls
import "markdown.js" as Markdown
import "tile-names.js" as TileNames
import "../../services/files-order.js" as FilesOrder
import "../../services/files-find.js" as Find
import "../../services/files-listing.js" as Listing

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

    property var listed: []
    readonly property var contents: root.listed.filter(e => Files.showHidden || !e.hidden)
    property string contentsError: ""

    property var seen: null
    property real readAt: 0
    readonly property string version: root.seen && Files.pathOf(root.seen) === root.path ? `?v=${root.seen.mtime}-${root.seen.size}` : ""

    function modeText(mode: int, width: real): string {
        const letters = Files.humanMode(mode);
        return detailInk.advanceWidth(letters) <= width ? letters : (mode & 511).toString(8).padStart(3, "0");
    }

    function spread(parts: var, width: real): string {
        const line = parts.join("  ·  ");
        return detailInk.advanceWidth(line) <= width ? line : parts.join("\n");
    }

    FontMetrics {
        id: detailInk

        font.family: Appearance.font.family
        font.pixelSize: Files.zoomed(Appearance.font.size.small)
    }

    readonly property var folderRows: FilesOrder.ordered(root.contents, Files.sort, Files.reversed)
    property string folderShown: ""

    onFolderRowsChanged: {
        const y = folderList.contentY;
        folderList.model = root.folderRows;
        if (root.folderShown === root.path) {
            folderList.forceLayout();
            folderList.contentY = Math.max(0, Math.min(y, folderList.maxScroll));
        } else {
            folderList.reset();
        }
        root.folderShown = root.path;
    }

    readonly property var player: playback.item

    readonly property bool soundMissing: playback.status === Loader.Error

    onPathChanged: {
        root.stat = null;
        root.listed = [];
        root.contentsError = "";
        root.player?.stop();
        body.content = "";
        later.stop();
        if (root.path)
            root.read();
    }

    onEntryChanged: root.follow()

    function follow(): void {
        if (!root.visible || !root.entry || Files.pathOf(root.entry) !== root.path)
            return;
        if (!root.seen) {
            root.seen = root.entry;
            return;
        }
        if (!Listing.stale(root.seen, root.entry))
            return;
        const wait = Listing.rereadIn(Date.now(), root.readAt);
        if (wait === 0)
            root.reread();
        else if (!later.running) {
            later.interval = wait;
            later.start();
        }
    }

    function read(): void {
        root.seen = root.entry && Files.pathOf(root.entry) === root.path ? root.entry : null;
        root.readAt = Date.now();
        statter.exec([Files.helper("bs-ls"), "--stat", root.path]);
        peek.exec([Files.helper("bs-ls"), root.path]);
    }

    function reread(): void {
        root.seen = root.entry;
        root.readAt = Date.now();
        statter.exec([Files.helper("bs-ls"), "--stat", root.path]);
        if (root.isFolder)
            peek.exec([Files.helper("bs-ls"), root.path]);
        if (body.path !== "" && root.entry.size <= Config.values.files.textMax)
            body.reload();
    }

    Timer {
        id: later

        onTriggered: if (Listing.stale(root.seen, root.entry))
            root.reread()
    }

    onVisibleChanged: {
        if (!root.visible)
            root.player?.stop();
        else
            root.follow();
    }

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

                    root.listed = answer.ok ? answer.entries : [];
                } catch (e) {
                    root.listed = [];
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
                id: titleMark

                anchors.verticalCenter: parent.verticalCenter

                fileClass: root.entry ? root.entry.class : "unknown"
                link: root.entry ? root.entry.link : false
                broken: root.entry ? root.entry.broken : false
                size: Files.zoomed(Appearance.font.iconSize)
            }

            StyledText {
                id: title

                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - titleMark.width - Appearance.padding.normal - (root.isMarkdown ? toggle.width + Appearance.padding.normal : 0))

                text: root.entry && title.width > 0 ? TileNames.heading(root.entry.name, line => titleInk.advanceWidth(line) <= title.width).join("\n") : ""

                font.pixelSize: Files.zoomed(Appearance.font.size.normal)
                maximumLineCount: 2
                elide: Text.ElideRight

                FontMetrics {
                    id: titleInk

                    font: title.font
                }
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

                InkIcon {
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
            id: facts

            width: parent.width

            text: {
                if (!root.entry)
                    return "";

                const size = root.isFolder ? `${root.contents.length} item${root.contents.length === 1 ? "" : "s"}` : Files.humanSize(root.entry.size);
                if (root.entry.trash)
                    return root.spread([size, `Trashed ${TimeFormat.dateText(new Date(root.entry.trashed * 1000), "year")} ${TimeFormat.time(new Date(root.entry.trashed * 1000), false)}`], facts.width);
                return root.spread([size, FilesFind.active ? Files.changedTime(root.entry.mtime) : Files.humanTime(root.entry.mtime)], facts.width);
            }
            font.pixelSize: Files.zoomed(Appearance.font.size.small)
            color: Appearance.colour.textFaint

            wrapMode: Text.Wrap
        }

        StyledText {
            id: owner

            width: parent.width
            visible: !!root.entry && !root.entry.trash && !!root.stat && !!root.stat.owner

            text: root.stat && root.stat.owner ? root.spread([root.stat.owner, root.modeText(root.stat.mode, owner.width)], owner.width) : ""
            font.pixelSize: Files.zoomed(Appearance.font.size.small)
            color: Appearance.colour.textFaint

            wrapMode: Text.Wrap
        }

        Item {
            id: where

            readonly property bool origin: !!root.entry && !!root.entry.trash
            readonly property string place: !root.entry ? "" : where.origin ? Files.originPlace(root.entry) : root.entry.dir ? Find.place(root.entry.dir, Files.home) : Find.place(Files.cwd, Files.home)
            readonly property string lead: where.origin ? "From " : ""

            width: parent.width
            visible: (FilesFind.active || where.origin) && where.place !== ""
            implicitHeight: whereText.implicitHeight

            Icon {
                id: whereGlyph

                visible: !where.origin
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                name: "folder"
                color: Appearance.colour.textDim
            }

            StyledText {
                id: whereText

                anchors.left: where.origin ? parent.left : whereGlyph.right
                anchors.leftMargin: where.origin ? 0 : Appearance.padding.small
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                text: where.lead + Find.fitPlace(where.place, Math.max(1, Math.floor(whereText.width / Math.max(1, whereDigit.advanceWidth)) - where.lead.length))
                font.pixelSize: Files.zoomed(Appearance.font.size.small)

                TextMetrics {
                    id: whereDigit

                    font: whereText.font
                    text: "0"
                }
            }
        }

        Button {
            visible: FilesFind.active && !!(root.entry && root.entry.key)

            text: "Show in folder"
            icon: "folder_open"
            style: "plate"

            onClicked: Files.goTo(root.path)
        }

        Button {
            visible: where.origin && !!root.entry.trash.path

            text: `Restore to ${Find.fitPlace(where.place, 24)}`
            icon: "undo"
            style: "plate"

            onClicked: Files.restore([root.entry])
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

            source: root.isImage ? Urls.fileUrl(root.path) + root.version : ""
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

                InkIcon {
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
            id: folderList

            anchors.fill: parent
            visible: root.isFolder && root.contents.length > 0
            clip: true

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
            document: root.path

            language: root.language
            wrap: true
        }

        Column {
            anchors.top: parent.top
            anchors.topMargin: Math.max(0, (parent.height - height) / 2)
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - Appearance.padding.large * 2
            spacing: Files.zoomed(Appearance.padding.normal)
            visible: !root.isImage && !root.isAudio && !root.isText && !(root.isFolder && root.contents.length > 0)

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter

                name: root.stat && !root.stat.readable || root.contentsError ? "lock" : root.isFolder ? "folder_open" : "visibility_off"
                size: Files.zoomed(Appearance.icon.huge)
                color: Appearance.colour.textFaint
            }

            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap

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
                font.pixelSize: Files.zoomed(Appearance.font.size.small)
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
