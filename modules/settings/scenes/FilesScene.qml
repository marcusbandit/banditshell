pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.modules.settings
import "../catalogue.js" as Catalogue

Item {
    id: root

    readonly property real stageHeight: 464
    readonly property bool list: SettingsState.v("filesView") === "list"
    readonly property string sort: SettingsState.v("filesSort")
    readonly property bool reversed: SettingsState.v("filesReversed")
    readonly property bool hidden: SettingsState.v("filesHidden")
    readonly property real zoom: SettingsState.v("filesZoom")
    readonly property bool rendered: SettingsState.v("filesMarkdown") === "rendered"

    readonly property var files: [["Documents", "folder", "dir", 0, 3], ["Downloads", "folder", "dir", 0, 0, "14:05"], ["Pictures", "folder", "dir", 0, 12], ["Projects", "folder", "dir", 0, 1], ["notes.md", "description", "md", 4, 0, "09:12"], ["install.sh", "terminal", "sh", 2, 30], ["wallpaper.png", "image", "png", 2400, 6], ["todo.txt", "article", "txt", 1, 2], [".config", "folder", "dir", 0, 0, "11:40"], [".bashrc", "settings", "rc", 3, 90]]

    readonly property var shown: {
        const byName = (a, b) => a[0].replace(".", "").localeCompare(b[0].replace(".", ""));
        const by = {
            name: byName,
            mtime: (a, b) => a[4] - b[4] || (b[5] ?? "").localeCompare(a[5] ?? ""),
            size: (a, b) => b[3] - a[3],
            kind: (a, b) => a[2].localeCompare(b[2])
        }[root.sort] ?? ((a, b) => 0);
        const sign = root.reversed ? -1 : 1;
        return root.files.filter(f => root.hidden || !f[0].startsWith(".")).sort((a, b) => ((b[2] === "dir") - (a[2] === "dir")) || sign * by(a, b) || byName(a, b));
    }

    function valueOf(file: var): string {
        if (root.sort === "mtime")
            return file[4] === 0 ? `today ${file[5]}` : file[4] === 1 ? "yesterday" : `${file[4]} days ago`;
        if (file[2] === "dir" || (root.sort !== "size" && !root.list))
            return "";
        return file[3] > 1000 ? `${(file[3] / 1024).toFixed(1)} MB` : `${file[3]} KB`;
    }

    readonly property bool valued: root.sort === "mtime" || root.sort === "size"

    property int cursor: 0
    readonly property string current: root.shown[root.cursor % Math.max(1, root.shown.length)]?.[0] ?? ""
    readonly property string kind: root.current === "notes.md" ? "md" : root.current === "wallpaper.png" ? "img" : ""

    SceneClock {
        id: awake

        duration: (root.kind ? 1500 : 650) * Math.max(1, root.shown.length)
    }

    Timer {
        interval: root.kind ? 1500 : 650
        running: root.visible && awake.moving
        repeat: true
        onTriggered: root.cursor = (root.cursor + 1) % Math.max(1, root.shown.length)
    }

    Follow {
        id: open

        target: root.kind ? 0.38 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.002
    }

    Item {
        id: fb

        x: 14
        y: 14
        width: parent.width - 28
        height: parent.height - 14 - 44

        Row {
            id: crumbs

            spacing: 6

            Icon {
                name: "home"
                color: Appearance.colour.textFaint
            }

            StyledText {
                text: "~"
                color: Appearance.colour.textFaint
            }
        }

        Item {
            id: body

            y: crumbs.height + 8
            width: parent.width
            height: parent.height - y
            clip: true

            readonly property real previewWidth: body.width * open.value
            readonly property real itemsWidth: body.width - (open.value > 0.001 ? body.previewWidth + 8 : 0)
            readonly property real cell: Math.max(64 * root.zoom, root.shown.reduce((w, f) => Math.max(w, metrics.advanceWidth(f[0]), root.valued ? metrics.advanceWidth(root.valueOf(f)) : 0), 0) + 8)
            readonly property int columns: root.list ? 1 : Math.max(1, Math.floor((body.itemsWidth + 6) / (body.cell + 6)))
            readonly property real cellWidth: (body.itemsWidth - (body.columns - 1) * 6) / body.columns
            readonly property real tileHeight: root.list ? Appearance.font.line.small + 8 : Math.round(28 * root.zoom) + 16 + 4 + 12 + (root.valued ? Appearance.font.line.small : 0)
            readonly property real spacing: root.list ? 2 : 6
            readonly property real currentBottom: (Math.floor(root.cursor % Math.max(1, root.shown.length) / body.columns) + 1) * (body.tileHeight + body.spacing)

            FontMetrics {
                id: metrics

                font.family: Appearance.font.family
                font.pixelSize: Appearance.font.size.small
            }

            Grid {
                y: -Math.max(0, body.currentBottom - body.height)
                columns: body.columns
                columnSpacing: 6
                rowSpacing: body.spacing

                Repeater {
                    model: root.shown

                    delegate: Item {
                        id: fi

                        required property var modelData
                        required property int index

                        readonly property bool sel: !SettingsView.reduceMotion && fi.modelData[0] === root.current
                        readonly property bool dot: fi.modelData[0].startsWith(".")

                        width: body.cellWidth
                        height: body.tileHeight
                        opacity: fi.dot ? Appearance.opacity.trail : 1

                        SquircleRect {
                            anchors.fill: parent
                            radius: Appearance.rounding.small
                            color: fi.sel ? Appearance.colour.accentFill : "transparent"
                        }

                        Column {
                            visible: !root.list
                            anchors.centerIn: parent
                            spacing: 2
                            width: parent.width - 4

                            Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: fi.modelData[1]
                                size: Math.round(28 * root.zoom)
                                fill: 1
                                color: fi.sel ? Appearance.colour.accent : Appearance.colour.textFaint
                            }

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: fi.modelData[0]
                                elide: Text.ElideRight
                                font.family: Appearance.font.family
                                font.pixelSize: Appearance.font.size.small
                                renderType: Text.NativeRendering
                                color: fi.sel ? Appearance.colour.text : Appearance.colour.textDim
                            }

                            Text {
                                visible: root.valued
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: root.valueOf(fi.modelData)
                                font.family: Appearance.font.family
                                font.pixelSize: Appearance.font.size.small
                                renderType: Text.NativeRendering
                                color: Appearance.colour.textFaint
                            }
                        }

                        Row {
                            visible: root.list
                            x: 6
                            width: parent.width - 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: fi.modelData[1]
                                fill: 1
                                color: fi.sel ? Appearance.colour.accent : Appearance.colour.textFaint
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 28 - size.implicitWidth - 16
                                text: fi.modelData[0]
                                elide: Text.ElideRight
                                color: fi.sel ? Appearance.colour.text : Appearance.colour.textDim
                            }

                            StyledText {
                                id: size

                                anchors.verticalCenter: parent.verticalCenter
                                text: root.valueOf(fi.modelData)
                                color: Appearance.colour.textFaint
                            }
                        }
                    }
                }
            }

            Item {
                x: body.width - body.previewWidth
                width: body.previewWidth
                height: body.height
                clip: true
                visible: body.previewWidth > 0.5

                SquircleRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Appearance.colour.fillStrong
                }

                Column {
                    x: 10
                    y: 10
                    width: body.width * 0.38 - 20
                    spacing: 6
                    visible: root.kind === "md"

                    StyledText {
                        visible: root.rendered
                        text: "notes"
                    }

                    Repeater {
                        model: root.rendered ? [1, 0.6, 1] : []

                        delegate: SquircleRect {
                            required property real modelData

                            width: parent.width * modelData
                            height: 5
                            radius: 3
                            color: Appearance.colour.fillStronger
                        }
                    }

                    Repeater {
                        model: root.rendered ? [] : ["# notes", "- climbing 7", "- fix the tray"]

                        delegate: Text {
                            required property string modelData

                            text: modelData
                            font.family: Appearance.sizes.filesTerminalFont
                            font.pixelSize: Appearance.font.size.small
                            renderType: Text.NativeRendering
                            color: Appearance.colour.textDim
                        }
                    }
                }

                Rectangle {
                    x: 10
                    y: 10
                    width: body.width * 0.38 - 20
                    height: parent.height - 20
                    visible: root.kind === "img"
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "#3b2c5e"
                        }
                        GradientStop {
                            position: 0.45
                            color: "#3b2c5e"
                        }
                        GradientStop {
                            position: 0.6
                            color: "#e7a28f"
                        }
                        GradientStop {
                            position: 0.62
                            color: "#2b2349"
                        }
                        GradientStop {
                            position: 0.7
                            color: "#2b2349"
                        }
                        GradientStop {
                            position: 0.701
                            color: "#3c5677"
                        }
                        GradientStop {
                            position: 1
                            color: "#3c5677"
                        }
                    }
                }
            }
        }
    }

    SceneCaption {
        text: `${Catalogue.filesSortOrder(root.sort, root.reversed)}, ${Catalogue.filesFoldersNote(root.sort)}${root.hidden ? " · dotfiles shown" : ""}`
    }
}
