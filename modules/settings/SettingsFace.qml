pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    Keys.onPressed: event => {
        if (event.key !== Qt.Key_Escape)
            return;
        if (root.deep)
            Settings.back();
        else
            Settings.hide();
        event.accepted = true;
    }

    readonly property real gutter: Appearance.sizes.settingsGutter
    readonly property real pad: Appearance.padding.large
    readonly property real railWidth: Appearance.sizes.settingsRail

    readonly property real railRow: Appearance.sizes.settingsRailRow

    readonly property real railFoot: Appearance.padding.large

    readonly property string current: Settings.page || Settings.pages[0].key
    readonly property var entry: Settings.entry(root.current)
    readonly property bool deep: !!root.entry?.parent

    property string query: ""

    property real currentRowY: 0
    property bool currentRowSeen: false
    readonly property real markHeight: root.railRow * 0.6

    onQueryChanged: railSlide.snap()

    function revealRow(y: real): void {
        if (y < railBody.position)
            railBody.scrollTo(y - Appearance.padding.small);
        else if (y + root.railRow > railBody.position + railBody.height)
            railBody.scrollTo(y + root.railRow - railBody.height + Appearance.padding.small);
    }

    function matches(p: var): bool {
        const q = root.query.trim().toLowerCase();
        if (!q)
            return true;
        return p.title.toLowerCase().includes(q)
            || p.blurb.toLowerCase().includes(q)
            || (p.group ?? "").toLowerCase().includes(q)
            || (p.keywords ?? []).some(k => k.toLowerCase().includes(q));
    }

    readonly property var shownGroups: Settings.groups.filter(g => Settings.pages.some(p => p.group === g && root.matches(p)))

    SquircleRect {
        anchors.fill: parent

        radius: 0
        color: Appearance.colour.surfaceSolid

        Item {
            id: rail

            x: 0
            y: 0
            width: root.railWidth
            height: parent.height

            Column {
            id: railHead

            width: parent.width
            topPadding: root.gutter
            spacing: 0

            StyledText {
                id: titleText

                x: root.pad
                text: "Settings"
                font.pixelSize: Appearance.font.size.large
                color: Appearance.colour.text
            }

            Item {
                width: parent.width
                height: Appearance.padding.small
            }

            Item {
                x: root.pad
                width: parent.width - root.pad * 2
                height: root.railRow

                SquircleRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.small
                    color: Appearance.colour.fillStrong
                }

                TextInput {
                    id: searchInput

                    anchors.fill: parent
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.rightMargin: Appearance.padding.normal
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true

                    font.family: Appearance.font.family
                    font.pixelSize: Appearance.font.size.small
                    renderType: Text.NativeRendering
                    color: Appearance.colour.text
                    selectionColor: Appearance.colour.accent
                    selectedTextColor: Appearance.colour.accentText

                    onTextChanged: root.query = text

                    Keys.onEscapePressed: {
                        if (text !== "") {
                            text = "";
                            root.query = "";
                        } else
                            Settings.hide();
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !searchInput.text
                        text: "search settings"
                        color: Appearance.colour.textFaint
                        font.pixelSize: Appearance.font.size.small
                    }
                }
            }

            Item {
                width: parent.width
                height: Appearance.padding.small
            }
            }

            SettingsPane {
                id: railBody

                x: 0
                y: railHead.height
                width: rail.width
                height: rail.height - railHead.height - root.railFoot

                Rectangle {
                    z: 1
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Appearance.padding.huge
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "transparent"
                        }
                        GradientStop {
                            position: 1
                            color: Appearance.colour.surface
                        }
                    }
                }

                Column {
                id: sections

                width: railBody.width
                spacing: 0

                Repeater {
                    model: root.shownGroups

                    delegate: Column {
                        id: groupCol

                        required property string modelData

                        width: rail.width
                        spacing: 0

                        StyledText {
                            x: root.pad
                            width: rail.width - root.pad * 2

                            text: groupCol.modelData.toUpperCase()
                            color: Appearance.colour.textFaint
                            font.pixelSize: Appearance.font.size.small
                            font.letterSpacing: Appearance.font.stem
                            topPadding: Appearance.padding.large
                            bottomPadding: Appearance.padding.small
                        }

                        Repeater {
                            model: Settings.pages.filter(p => p.group === groupCol.modelData && root.matches(p))

                            delegate: RailRow {}
                        }
                    }
                }

                StyledText {
                    visible: root.query !== "" && root.shownGroups.length === 0
                    x: root.pad
                    width: parent.width - root.pad * 2
                    text: `nothing matches "${root.query}"`
                    wrapMode: Text.Wrap
                    color: Appearance.colour.textFaint
                    topPadding: Appearance.padding.normal
                }
                }

                SquircleRect {
                    id: slideMark

                    x: 0
                    y: railSlide.value + (root.railRow - root.markHeight) / 2
                    width: Appearance.font.stem * 2
                    height: root.markHeight
                    radius: Appearance.font.stem
                    color: Appearance.colour.accent
                    opacity: root.currentRowSeen ? 1 : 0
                }

                Follow {
                    id: railSlide

                    target: root.currentRowY

                    speed: Appearance.anim.railSpeed
                    epsilon: 0.5
                }

                Connections {
                    target: Settings

                    function onOpenChanged(): void {
                        railSlide.snap();
                        root.revealRow(root.currentRowY);
                    }
                }
            }
        }

        Rectangle {
            x: root.railWidth
            width: Appearance.font.stem
            height: parent.height
            color: Appearance.colour.separator
        }

        SettingsPane {
            id: content

            x: root.railWidth + Appearance.font.stem
            width: parent.width - root.railWidth - Appearance.font.stem
            height: parent.height
            inset: root.gutter

            Column {
                x: root.gutter
                y: root.gutter
                width: content.width - root.gutter * 2
                spacing: Appearance.padding.normal

                Item {
                    readonly property bool arrow: !!root.entry?.parent

                    width: parent.width
                    height: name.implicitHeight

                    Item {
                        id: back

                        readonly property real slot: Math.max(Appearance.sizes.minTarget, Appearance.font.iconSize + Appearance.padding.small * 2)

                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.arrow ? back.slot + Appearance.padding.small : 0
                        height: back.slot
                        visible: parent.arrow

                        SquircleRect {
                            width: back.slot
                            height: back.slot
                            radius: Appearance.rounding.normal
                            color: Appearance.colour.fill
                            opacity: backTap.containsMouse ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }
                        }

                        Icon {
                            x: (back.slot - width) / 2
                            anchors.verticalCenter: parent.verticalCenter
                            name: "arrow_back"
                            color: backTap.containsMouse ? Appearance.colour.text : Appearance.colour.textDim
                        }

                        MouseArea {
                            id: backTap

                            width: back.slot
                            height: back.slot
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Settings.back()
                        }
                    }

                    StyledText {
                        id: name

                        anchors.left: back.right
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.entry?.title ?? ""
                        font.pixelSize: Appearance.font.size.large
                        color: Appearance.colour.text
                        wrapMode: Text.Wrap
                    }
                }

                Loader {
                    id: pageLoader

                    width: parent.width

                    source: root.current ? `pages/${root.current.charAt(0).toUpperCase() + root.current.slice(1)}Page.qml` : ""

                    onLoaded: arrive.restart()

                    NumberAnimation {
                        id: arrive

                        target: pageLoader
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Appearance.anim.fast
                    }
                }
            }

            onPageChanged: content.drag(0)
            readonly property string page: root.current
        }
    }

    component RailRow: Item {
        id: railRow

        required property var modelData

        signal activated

        readonly property bool isCurrent: Settings.sectionOf(root.current) === modelData.key

        width: rail.width
        height: root.railRow

        onIsCurrentChanged: publish()
        onYChanged: publish()

        onVisibleChanged: if (isCurrent)
            Qt.callLater(publish)

        Component.onCompleted: publish()

        function publish(): void {
            if (!isCurrent)
                return;
            root.currentRowSeen = visible;
            Qt.callLater(() => {
                root.currentRowY = railRow.mapToItem(sections, 0, 0).y;
                root.revealRow(root.currentRowY);
            });
        }

        SquircleRect {
            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.normal
            anchors.rightMargin: Appearance.padding.normal
            radius: Appearance.rounding.small
            color: Appearance.colour.fill
            opacity: railRow.isCurrent || rowTap.containsMouse ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Icon {
            x: root.pad
            anchors.verticalCenter: parent.verticalCenter
            name: railRow.modelData.icon
            color: railRow.isCurrent ? Appearance.colour.text : Appearance.colour.textDim
        }

        StyledText {
            x: root.pad + Appearance.font.iconSize + root.pad
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - root.pad
            text: railRow.modelData.title
            color: railRow.isCurrent ? Appearance.colour.text : Appearance.colour.textDim
        }

        MouseArea {
            id: rowTap

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.query = "";
                searchInput.text = "";
                Settings.setPage(railRow.modelData.key);
                railRow.activated();
            }
        }
    }
}
