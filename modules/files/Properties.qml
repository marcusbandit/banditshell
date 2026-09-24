pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// EVERYTHING KNOWN ABOUT ONE FILE, on request.
//
// The preview panel says what is IN a file; this says what it IS - where, how
// big, who owns it, what the mode bits are, what it points at. The two are
// deliberately different questions: one is glanced at constantly and the other
// is asked for once in a while, and putting the second in the panel would make
// every selection carry a block of numbers nobody was reading.
Item {
    id: root

    property string path: ""
    property var stat: null

    function show(path: string): void {
        root.path = path;
        root.stat = null;
        root.opacity = 1;
        statter.exec([Files.helper("bs-ls"), "--stat", path]);
    }

    function close(): void {
        root.opacity = 0;
    }

    visible: opacity > 0
    opacity: 0

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.anim.fast
            easing.type: Easing.OutQuad
        }
    }

    Process {
        id: statter

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const answer = JSON.parse(text);
                    root.stat = answer.ok ? answer : null;
                } catch (e) {
                    root.stat = null;
                }
            }
        }
    }

    // The rows, as data. A field with nothing in it is not drawn at all rather
    // than drawn empty: a symlink has a target and a regular file does not, and
    // a blank "Points at" line is a question the card cannot answer.
    readonly property var rows: {
        const s = root.stat;
        if (!s)
            return [];

        const out = [
            {label: "Where", value: Files.parentOf(s.path)},
            {label: "Kind", value: s.kind === "dir" ? "Folder" : `${s.class}${s.ext ? ` (.${s.ext})` : ""}`},
            {label: "Size", value: Files.humanSize(s.size)},
            {label: "Modified", value: Qt.formatDateTime(new Date(s.mtime * 1000), "d MMM yyyy  HH:mm")},
            {label: "Owner", value: `${s.owner}:${s.group}`},
            {label: "Mode", value: `${Files.humanMode(s.mode)}  (${s.mode.toString(8)})`}
        ];

        if (s.target)
            out.push({label: "Points at", value: s.target});
        if (!s.readable)
            out.push({label: "Readable", value: "no"});

        return out;
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.colour.scrim

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    G2Rect {
        anchors.centerIn: parent

        implicitWidth: Math.min(root.width - Appearance.padding.huge * 2, 520)
        implicitHeight: body.implicitHeight + Appearance.padding.large * 2

        radius: Appearance.rounding.large
        color: Appearance.colour.surfaceSolid
        stroke: Appearance.colour.separator
        strokeWidth: Appearance.font.stem

        Column {
            id: body

            anchors.centerIn: parent
            width: parent.width - Appearance.padding.large * 2
            spacing: Appearance.padding.normal

            Row {
                width: parent.width
                spacing: Appearance.padding.normal

                FileMark {
                    anchors.verticalCenter: parent.verticalCenter

                    fileClass: root.stat ? root.stat.class : "unknown"
                    link: root.stat ? root.stat.link : false
                    broken: root.stat ? root.stat.broken : false
                    size: Appearance.font.iconSize * 1.6
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Appearance.font.iconSize * 1.6 - Appearance.padding.normal

                    text: root.stat ? root.stat.name : "…"
                    font.pixelSize: Appearance.font.size.normal
                    elide: Text.ElideMiddle
                }
            }

            Separator {
                width: parent.width
            }

            Repeater {
                model: root.rows

                delegate: Row {
                    id: line

                    required property var modelData

                    width: body.width
                    spacing: Appearance.padding.normal

                    StyledText {
                        // A LABEL COLUMN THAT LINES UP, in characters rather
                        // than pixels: Monocraft is monospaced, so the widest
                        // label plus a space IS the column, and it stays right
                        // at any type size.
                        width: Appearance.font.size.small * 0.6 * 10

                        text: line.modelData.label
                        color: Appearance.colour.textFaint
                    }

                    StyledText {
                        width: line.width - Appearance.font.size.small * 0.6 * 10 - Appearance.padding.normal

                        text: line.modelData.value
                        elide: Text.ElideMiddle
                    }
                }
            }

            StyledText {
                width: parent.width

                text: "Escape to close"
                color: Appearance.colour.textFaint
            }
        }
    }
}
