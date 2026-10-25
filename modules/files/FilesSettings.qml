pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import "keys.js" as Chords

Item {
    id: root

    property bool up: false

    signal dismissed

    function show(): void {
        root.up = true;
        Qt.callLater(root.forceActiveFocus);
    }

    function close(): void {
        root.rebinding = "";
        root.up = false;
        root.dismissed();
    }

    visible: root.up || fade.value > 0
    opacity: fade.value
    focus: root.up

    property string rebinding: ""

    readonly property var keyNames: Chords.names(Qt)

    function chordOf(event: var): string {
        return Chords.chordOf(Qt, root.keyNames, event.key, event.modifiers, event.text);
    }

    readonly property var labels: ({
            terminal: "Show or hide the terminal",
            preview: "Show or hide the preview panel",
            sidebar: "Show or hide the sidebar",
            hidden: "Show or hide hidden files",
            back: "Back",
            forward: "Forward",
            parent: "Go to the parent folder",
            home: "Go home",
            "focus:grid": "Put the keyboard on the files",
            "focus:preview": "Put the keyboard on the preview",
            "focus:terminal": "Put the keyboard on the terminal",
            left: "Move left",
            right: "Move right",
            up: "Move up",
            down: "Move down",
            first: "First file",
            last: "Last file",
            open: "Open",
            search: "Search in this folder",
            copypath: "Copy the path",
            all: "Select everything",
            copy: "Copy",
            cut: "Cut",
            paste: "Paste",
            newfolder: "New folder",
            newfile: "New file",
            rename: "Rename",
            trash: "Move to trash",
            destroy: "Delete permanently",
            undo: "Undo the last delete, move, rename or paste",
            properties: "Properties",
            path: "Type a path",
            view: "Switch between icons and list",
            zoomin: "Bigger",
            zoomout: "Smaller",
            zoomreset: "Reset the size",
            settings: "These settings"
        })

    function rowsOf(map: var): var {
        const out = [];
        for (const chord in map)
            out.push({chord: chord, action: map[chord]});

        return out.sort((a, b) => (root.labels[a.action] ?? a.action).localeCompare(root.labels[b.action] ?? b.action));
    }

    function rebind(which: string, from: string, to: string): void {
        if (!to || to === from)
            return;

        const map = which === "keys" ? Files.chords : Files.gridKeys;
        const next = {};
        for (const chord in map)
            if (chord !== from && chord !== to)
                next[chord] = map[chord];
        next[to] = map[from];
        Config.set(`files.${which}`, next);
    }

    Keys.onPressed: event => {
        if (root.rebinding) {
            if (event.key === Qt.Key_Control || event.key === Qt.Key_Alt || event.key === Qt.Key_Shift || event.key === Qt.Key_Meta)
                return;
            event.accepted = true;

            if (event.key === Qt.Key_Escape) {
                root.rebinding = "";
                return;
            }

            const cut = root.rebinding.indexOf(":");
            root.rebind(root.rebinding.slice(0, cut), root.rebinding.slice(cut + 1), root.chordOf(event));
            root.rebinding = "";
            return;
        }

        if (event.key === Qt.Key_Escape) {
            root.close();
            event.accepted = true;
        }
    }

    Follow {
        id: fade

        target: root.up ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: Appearance.animation.fadeEpsilon
        startsAtTarget: true
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.colour.scrim

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    SquircleRect {
        anchors.centerIn: parent

        implicitWidth: Math.min(root.width - Appearance.padding.huge * 2, 640)
        implicitHeight: Math.min(root.height - Appearance.padding.huge * 2, 720)

        radius: Appearance.rounding.large
        color: Appearance.colour.surfaceSolid
        stroke: Appearance.colour.separator
        strokeWidth: Appearance.stroke.ring

        Row {
            id: header

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.padding.large

            spacing: Appearance.padding.normal

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "settings"
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter

                text: "File browser settings"
                font.pixelSize: Appearance.font.size.normal
            }
        }

        Separator {
            id: headRule

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.topMargin: Appearance.padding.normal
        }

        Flickable {
            id: scroller

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: headRule.bottom
            anchors.bottom: parent.bottom
            anchors.margins: Appearance.padding.large

            clip: true
            contentHeight: body.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            WheelStep {
                flick: scroller
            }

            Column {
                id: body

                width: parent.width
                spacing: Appearance.padding.large

                Setting {
                    width: body.width
                    label: "View"

                    SettingChoice {
                        choices: [
                            {label: "Icons", value: "icons"},
                            {label: "List", value: "list"}
                        ]
                        chosen: Files.view
                        onChose: value => Config.set("files.view", value)
                    }
                }

                Setting {
                    width: body.width
                    label: "Size"
                    detail: `${Math.round(Files.magnification * 100)}% · text ${Files.zoomed(Appearance.font.size.small)}px`

                    SettingChoice {
                        choices: [
                            {label: "Smaller", value: -0.1},
                            {label: "Reset", value: 0},
                            {label: "Bigger", value: 0.1}
                        ]
                        chosen: 0
                        onChose: value => Files.zoom(value)
                    }
                }

                Setting {
                    width: body.width
                    label: "Hidden files"

                    Toggle {
                        checked: Files.showHidden
                        onToggled: Config.set("files.hidden", !Files.showHidden)
                    }
                }

                Setting {
                    width: body.width
                    label: "Sort by"

                    SettingChoice {
                        choices: [
                            {label: "Name", value: "name"},
                            {label: "Size", value: "size"},
                            {label: "Changed", value: "mtime"},
                            {label: "Kind", value: "kind"}
                        ]
                        chosen: Files.sort
                        onChose: value => Config.set("files.sort", value)
                    }
                }

                Setting {
                    width: body.width
                    label: "Markdown"

                    SettingChoice {
                        choices: [
                            {label: "Rendered", value: "rendered"},
                            {label: "Raw", value: "raw"}
                        ]
                        chosen: Files.markdownRendered ? "rendered" : "raw"
                        onChose: value => Config.set("files.markdown", value)
                    }
                }

                Repeater {
                    model: [
                        {
                            which: "keys",
                            title: "Keys, anywhere in the window"
                        },
                        {
                            which: "grid",
                            title: "Keys, while the files have focus"
                        }
                    ]

                    delegate: Column {
                        id: group

                        required property var modelData

                        width: body.width
                        spacing: Appearance.padding.small

                        StyledText {
                            text: group.modelData.title
                            font.pixelSize: Appearance.font.size.normal
                            bottomPadding: Appearance.padding.small
                        }

                        Repeater {
                            model: root.rowsOf(group.modelData.which === "keys" ? Files.chords : Files.gridKeys)

                            delegate: Item {
                                id: binding

                                required property var modelData

                                readonly property string id: `${group.modelData.which}:${binding.modelData.chord}`
                                readonly property bool waiting: root.rebinding === binding.id

                                width: group.width
                                height: Appearance.sizes.filesRow * 1.2

                                SquircleRect {
                                    anchors.fill: parent

                                    radius: Appearance.rounding.small
                                    color: binding.waiting ? Appearance.colour.accentFill : press.containsMouse ? Appearance.colour.fill : "transparent"
                                    stroke: binding.waiting ? Appearance.colour.accent : "transparent"
                                    strokeWidth: binding.waiting ? Appearance.stroke.ring : 0
                                }

                                StyledText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Appearance.padding.normal
                                    anchors.right: chord.left
                                    anchors.rightMargin: Appearance.padding.normal
                                    anchors.verticalCenter: parent.verticalCenter

                                    text: root.labels[binding.modelData.action] ?? binding.modelData.action
                                    font.pixelSize: Files.zoomed(Appearance.font.size.small)
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    id: chord

                                    anchors.right: parent.right
                                    anchors.rightMargin: Appearance.padding.normal
                                    anchors.verticalCenter: parent.verticalCenter

                                    text: binding.waiting ? "press a key…" : binding.modelData.chord
                                    font.pixelSize: Files.zoomed(Appearance.font.size.small)
                                    color: binding.waiting ? Appearance.colour.accent : Appearance.colour.textDim
                                }

                                MouseArea {
                                    id: press

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        root.rebinding = binding.waiting ? "" : binding.id;
                                        root.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
