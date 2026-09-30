pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property int receiving: -1
    property bool editing: false

    implicitHeight: Math.max(buttons.implicitHeight, crumbs.implicitHeight, field.implicitHeight + Appearance.padding.small * 2)

    function edit(): void {
        root.editing = true;
        entry.text = Files.cwd;
        entry.forceActiveFocus();
        entry.selectAll();
    }

    function stopEditing(): void {
        root.editing = false;
        Files.focus = "grid";
    }

    Row {
        id: buttons

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        spacing: 0

        Repeater {
            model: [
                {
                    icon: "arrow_back",
                    enabled: Files.back.length > 0,
                    run: () => Files.goBack()
                },
                {
                    icon: "arrow_forward",
                    enabled: Files.forward.length > 0,
                    run: () => Files.goForward()
                },
                {
                    icon: "arrow_upward",
                    enabled: Files.cwd !== "/",
                    run: () => Files.go(Files.parentOf(Files.cwd))
                }
            ]

            delegate: Item {
                id: button

                required property var modelData

                implicitWidth: Appearance.sizes.minTarget
                implicitHeight: Appearance.sizes.minTarget

                G2Rect {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.small / 2

                    radius: Appearance.rounding.small
                    color: press.containsMouse && button.modelData.enabled ? Appearance.colour.fill : "transparent"
                }

                Icon {
                    id: glyph

                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: glyph.inkOffsetX
                    anchors.verticalCenterOffset: glyph.inkOffsetY

                    name: button.modelData.icon
                    color: button.modelData.enabled ? Appearance.colour.text : Appearance.colour.textGhost
                }

                MouseArea {
                    id: press

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: button.modelData.enabled
                    cursorShape: Qt.PointingHandCursor

                    onClicked: button.modelData.run()
                }
            }
        }
    }

    Row {
        id: crumbs

        anchors.left: buttons.right
        anchors.leftMargin: Appearance.padding.small
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: search.left
        anchors.rightMargin: Appearance.padding.normal

        visible: !Files.searching && !root.editing
        spacing: 0

        readonly property bool crowded: {
            let sum = 0;
            for (let i = 0; i < list.count; ++i)
                sum += list.itemAt(i)?.naturalWidth ?? 0;
            return sum > width;
        }

        readonly property real usedBeforeLast: {
            let sum = 0;
            for (let i = 0; i < list.count - 1; ++i)
                sum += list.itemAt(i)?.width ?? 0;
            return sum;
        }

        Repeater {
            id: list

            model: Files.crumbs

            delegate: Item {
                id: crumb

                required property int index
                required property var modelData

                readonly property bool last: crumb.index === Files.crumbs.length - 1
                readonly property real naturalWidth: label.implicitWidth + Appearance.padding.normal * 2

                implicitWidth: Math.min(naturalWidth, crumbs.crowded ? (crumb.last ? crumbs.width - crumbs.usedBeforeLast : crumbs.width / Files.crumbs.length) : naturalWidth)
                implicitHeight: label.implicitHeight + Appearance.padding.small * 2

                G2Rect {
                    anchors.fill: parent

                    radius: Appearance.rounding.small
                    color: root.receiving === crumb.index ? Appearance.colour.accentFill : hover.hovered ? Appearance.colour.fill : "transparent"
                    stroke: root.receiving === crumb.index ? Appearance.colour.accent : "transparent"
                    strokeWidth: root.receiving === crumb.index ? Appearance.font.stem : 0
                }

                StyledText {
                    id: label

                    anchors.centerIn: parent
                    width: crumb.implicitWidth - Appearance.padding.normal * 2

                    elide: Text.ElideMiddle
                    text: crumb.modelData.name
                    font.pixelSize: Appearance.sizes.filesText

                    color: crumb.last ? Appearance.colour.text : Appearance.colour.textFaint
                }

                HoverTip {
                    host: crumb
                    asked: hover.hovered
                    text: hover.hovered && label.truncated ? crumb.modelData.path : ""
                }

                HoverHandler {
                    id: hover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: Files.go(crumb.modelData.path)
                }
            }
        }
    }

    MouseArea {
        anchors.left: crumbs.left
        anchors.right: crumbs.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        visible: !root.editing
        acceptedButtons: Qt.LeftButton

        z: -1

        onClicked: root.edit()
    }

    G2Rect {
        anchors.left: buttons.right
        anchors.leftMargin: Appearance.padding.small
        anchors.right: search.left
        anchors.rightMargin: Appearance.padding.normal
        anchors.verticalCenter: parent.verticalCenter

        implicitHeight: entry.implicitHeight + Appearance.padding.small * 2
        visible: root.editing

        radius: Appearance.rounding.small
        color: Appearance.colour.fill
        stroke: Appearance.colour.accent
        strokeWidth: Appearance.font.stem

        TextInput {
            id: entry

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Appearance.padding.normal

            font.family: Appearance.font.family
            font.pixelSize: Appearance.sizes.filesText
            color: Appearance.colour.text
            selectionColor: Appearance.colour.accent
            selectedTextColor: Appearance.colour.accentText
            selectByMouse: true
            renderType: Text.NativeRendering

            clip: true

            function resolve(text: string): string {
                let out = text.trim();
                if (out.startsWith("~"))
                    out = Files.home + out.slice(1);
                if (out.length > 1 && out.endsWith("/"))
                    out = out.slice(0, -1);
                return out;
            }

            Keys.onReturnPressed: {
                const to = entry.resolve(entry.text);
                root.stopEditing();
                if (to)
                    Files.go(to);
            }

            Keys.onEscapePressed: root.stopEditing()
        }
    }

    Item {
        id: search

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: Files.searching ? root.width * 0.4 : glass.implicitWidth + Appearance.padding.normal
        implicitHeight: field.implicitHeight + Appearance.padding.small * 2

        G2Rect {
            anchors.fill: parent
            visible: Files.searching

            radius: Appearance.rounding.small
            color: Appearance.colour.fill
        }

        Icon {
            id: glass

            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.small
            anchors.verticalCenter: parent.verticalCenter

            name: "search"
            color: Files.searching ? Appearance.colour.text : Appearance.colour.textGhost
        }

        TextInput {
            id: field

            anchors.left: glass.right
            anchors.right: parent.right
            anchors.leftMargin: Appearance.padding.small
            anchors.rightMargin: Appearance.padding.small
            anchors.verticalCenter: parent.verticalCenter

            visible: Files.searching

            focus: Files.searching
            activeFocusOnTab: false

            font.family: Appearance.font.family
            font.pixelSize: Appearance.sizes.filesText
            color: Appearance.colour.text
            selectionColor: Appearance.colour.accent
            selectedTextColor: Appearance.colour.accentText
            renderType: Text.NativeRendering
            clip: true

            text: Files.search
            onTextChanged: Files.setSearch(text)

            Keys.onReturnPressed: {
                Files.setSearching(false);
                Files.focus = "grid";
            }

            Keys.onEscapePressed: {
                Files.setSearch("");
                Files.setSearching(false);
                Files.focus = "grid";
            }
        }

        TapHandler {
            onTapped: {
                Files.setSearching(true);
                Files.focus = "grid";
            }
        }
    }

    function crumbAt(position: point): int {
        if (Files.searching || root.editing)
            return -1;
        const local = crumbs.mapFromItem(root, position.x, position.y);
        const item = crumbs.childAt(local.x, local.y);
        return item && item.index !== undefined ? item.index : -1;
    }

    function pathAt(position: point): string {
        const index = root.crumbAt(position);
        return index < 0 ? "" : Files.crumbs[index].path;
    }
}
