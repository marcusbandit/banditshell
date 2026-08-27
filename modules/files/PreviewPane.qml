pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// THE THING ITSELF, beside the grid.
//
// The grid says what a file is; this says what is in it. Which means it is the
// one part of the browser that is allowed to be expensive, and the whole design
// is about spending that only when asked: the panel loads what is SELECTED, one
// file at a time, and everything it does is torn down the moment the selection
// moves. A folder of albums does not decode forty songs to show you a list.
//
// Audio in particular loads NOTHING until it is played. A MediaPlayer with a
// source set has already opened the file and read its headers; that is fine for
// one and absurd for a directory, so the source is set on the first press and
// not before.
Item {
    id: root

    required property var entry
    required property string path

    // What the helper knows about this one file: owner, mode, and the one
    // question an extension cannot answer, which is whether the body is text.
    property var stat: null

    readonly property bool isImage: root.entry && root.entry.class === "image" && !root.entry.broken
    readonly property bool isAudio: root.entry && root.entry.class === "audio"
    readonly property bool isText: root.stat && root.stat.text && root.stat.size <= Appearance.sizes.filesTextMax

    // WHAT LANGUAGE AN EXTENSION IS, for the highlighter next door.
    //
    // Written language-to-extensions rather than the other way round, because
    // that is the direction the knowledge actually runs: "shell is .sh, .bash,
    // .zsh and .fish" is one fact, and the inverted table is four entries that
    // have to agree. Adding a language is one line here.
    //
    // The names are components/highlight.js's own, and an extension that is not
    // in this table answers "", which is that file's signal to fall back to
    // detecting from the content. That fallback is why the table can afford to
    // be short: a file it has never heard of is not a file it gets wrong, it is
    // a file it looks at.
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

    onPathChanged: {
        root.stat = null;
        player.stop();
        body.content = "";
        if (root.path)
            statter.exec([Files.helper("bs-ls"), "--stat", root.path]);
    }

    Process {
        id: statter

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const answer = JSON.parse(text);
                    // The selection may have moved while this was running, and a
                    // panel describing the previous file under the current one's
                    // name is worse than a panel showing nothing yet.
                    if (answer.path === root.path)
                        root.stat = answer.ok ? answer : null;
                } catch (e) {
                    root.stat = null;
                }
            }
        }
    }

    // ------------------------------------------------------------ the header

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
                width: parent.width - Appearance.font.iconSize - Appearance.padding.normal

                text: root.entry ? root.entry.name : ""
                // The one thing this panel is about, at the one size reserved
                // for that (~/.claude/rules/type-scale.md).
                font.pixelSize: Appearance.font.size.normal
                elide: Text.ElideMiddle
            }
        }

        StyledText {
            width: parent.width

            // Size, when, and who: three facts on one line, at the quiet weight,
            // because they are what you glance at rather than what you came for.
            text: {
                if (!root.entry)
                    return "";
                const parts = [Files.humanSize(root.entry.size), Files.humanTime(root.entry.mtime)];
                if (root.stat && root.stat.owner)
                    parts.push(`${root.stat.owner} ${Files.humanMode(root.stat.mode)}`);
                return parts.join("  ·  ");
            }
            color: Appearance.colour.textFaint
            // ELIDED, because this line is three facts joined with dots and the
            // last of them is a permission string that is always the same width:
            // without this the panel's own width decides how much of the OWNER'S
            // NAME you get, and it runs out under the window's edge.
            elide: Text.ElideRight
        }

        Separator {
            width: parent.width
        }
    }

    // ------------------------------------------------------------ the body

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: Appearance.padding.normal

        // A PICTURE, whole. PreserveAspectFit rather than the grid's crop: the
        // tile is a thumbnail and may crop to fill its square, but this is the
        // one place you came to actually look at the thing.
        G2Image {
            anchors.fill: parent
            visible: root.isImage

            source: root.isImage ? `file://${root.path}` : ""
            fillMode: Image.PreserveAspectFit
            radius: Appearance.rounding.small
        }

        // SOUND. The transport is Niagara's idiom, the same as the shell's own
        // (modules/media/MediaTransport.qml): bare glyphs, and a ring around the
        // one control you actually press. Not that component itself - it is
        // wired to MPRIS and this is a file on disk - but deliberately the same
        // shape, so the shell has one way of drawing a play button.
        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: Appearance.padding.large
            visible: root.isAudio

            FileMark {
                anchors.horizontalCenter: parent.horizontalCenter

                fileClass: "audio"
                size: Appearance.font.iconSize * 3
            }

            Item {
                id: transport

                anchors.horizontalCenter: parent.horizontalCenter

                implicitWidth: transport.ring
                implicitHeight: transport.ring

                readonly property real ring: Appearance.font.iconSize + Appearance.padding.normal * 2

                // The answer to the cursor is MOTION, not colour - the same rule
                // the shell's own transport keeps (modules/media/MediaTransport)
                // and the same swell a slider's bead has. This is a play button
                // in that idiom deliberately: not that component, which is wired
                // to MPRIS while this is a file on disk, but the same shape, so
                // the shell has one way of drawing the thing you press.
                scale: press.pressed ? 0.94 : press.containsMouse ? 1.12 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutBack
                    }
                }

                G2Rect {
                    anchors.fill: parent

                    radius: width / 2
                    stroke: Appearance.colour.text
                    strokeWidth: Appearance.font.stem
                }

                Icon {
                    id: playGlyph

                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: playGlyph.inkOffsetX
                    anchors.verticalCenterOffset: playGlyph.inkOffsetY

                    name: player.playing ? "pause" : "play_arrow"
                }

                MouseArea {
                    id: press

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        // THE FIRST PRESS IS WHAT OPENS THE FILE. Everything
                        // above this line has read nothing but the name: a
                        // MediaPlayer with a source set has already opened the
                        // file and read its headers, which is fine for one and
                        // absurd for a directory of them.
                        // COMPARED AS A STRING, and that is not fussiness.
                        // `source` is a url, which is an OBJECT: `source === ""`
                        // is false even when it is empty, so the version that
                        // read that way never assigned anything at all and the
                        // button played silence. It also means switching files
                        // reloads, since the url it should hold has changed.
                        const url = `file://${root.path}`;
                        if (String(player.source) !== url)
                            player.source = url;
                        if (player.playing)
                            player.pause();
                        else
                            player.play();
                    }
                }
            }

            Slider {
                width: parent.width

                enabled: player.duration > 0
                value: player.position
                to: Math.max(1, player.duration)
                onMoved: v => player.position = v
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter

                text: `${Files.humanDuration(player.position)} / ${Files.humanDuration(player.duration)}`
                color: Appearance.colour.textFaint
            }
        }

        // TEXT, coloured by the shell's own highlighter. A preview panel that
        // showed source code as grey prose would be throwing away the one thing
        // that makes code readable at a glance, and the machinery for it is
        // already here (components/CodeBlock.qml).
        //
        // FILLING, not inside a Flickable. CodeBlock scrolls itself - its list
        // is anchored to its own bottom edge - so a wrapper that gave it a
        // content height instead of a real one left it exactly zero pixels tall
        // and the panel drew a correct header over nothing at all.
        CodeBlock {
            anchors.fill: parent
            visible: root.isText

            text: body.content
            // The extension IS the language here, which is the one place a file
            // browser has an advantage over a clipboard: the highlighter has to
            // guess from content when all it has is a paste, and this knows.
            language: root.language
            wrap: true
        }

        // WHY THERE IS NOTHING TO SHOW, when there is nothing to show. "Binary"
        // and "too big to read" and "you may not read this" are three different
        // answers and the panel should not give the same blank to all of them.
        Column {
            anchors.centerIn: parent
            spacing: Appearance.padding.normal
            visible: !root.isImage && !root.isAudio && !root.isText

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter

                name: root.stat && !root.stat.readable ? "lock" : root.entry && root.entry.kind === "dir" ? "folder_open" : "visibility_off"
                size: Appearance.font.iconSize * 2
                color: Appearance.colour.textGhost
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter

                text: {
                    if (!root.entry)
                        return "nothing selected";
                    if (root.stat && !root.stat.readable)
                        return "not readable";
                    if (root.entry.kind === "dir")
                        return "folder";
                    if (root.stat && root.stat.text)
                        return "too large to preview";
                    return "no preview";
                }
                color: Appearance.colour.textFaint
            }
        }
    }

    // The bytes, read only once the helper has said this is text and small
    // enough. `blockLoading` off, because a big file read on the UI thread is a
    // window that stops answering the mouse.
    FileView {
        id: body

        // NOT called `text`. FileView already has a text() FUNCTION, and a
        // property of that name shadows it: the read would call a string.
        property string content: ""

        path: root.isText ? root.path : ""
        printErrors: false
        blockLoading: false

        onLoaded: body.content = body.text()
        onLoadFailed: body.content = ""
    }

    MediaPlayer {
        id: player

        readonly property bool playing: playbackState === MediaPlayer.PlayingState

        audioOutput: AudioOutput {}
    }
}
