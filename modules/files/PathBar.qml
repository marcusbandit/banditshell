pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.controls
import "../../services/files-conflicts.js" as Conflicts

Item {
    id: root

    property int receiving: -1
    property bool editing: false

    signal dismissed

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
        root.dismissed();
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

                SquircleRect {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.hair

                    radius: Appearance.rounding.small
                    color: press.containsMouse && button.modelData.enabled ? Appearance.colour.fill : "transparent"
                }

                InkIcon {
                    id: glyph

                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: glyph.inkOffsetX
                    anchors.verticalCenterOffset: glyph.inkOffsetY

                    name: button.modelData.icon
                    color: button.modelData.enabled ? Appearance.colour.text : Appearance.colour.textFaint
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

                SquircleRect {
                    anchors.fill: parent

                    radius: Appearance.rounding.small
                    color: root.receiving === crumb.index ? Appearance.colour.accentFill : hover.hovered ? Appearance.colour.fill : "transparent"
                    stroke: root.receiving === crumb.index ? Appearance.colour.accent : "transparent"
                    strokeWidth: root.receiving === crumb.index ? Appearance.stroke.ring : 0
                }

                StyledText {
                    id: label

                    anchors.centerIn: parent
                    width: crumb.implicitWidth - Appearance.padding.normal * 2

                    elide: Text.ElideMiddle
                    text: crumb.modelData.name
                    font.pixelSize: Files.zoomed(Appearance.font.size.small)

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

    SquircleRect {
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
        strokeWidth: Appearance.stroke.ring

        TextInput {
            id: entry

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Appearance.padding.normal

            font.family: Appearance.font.family
            font.pixelSize: Files.zoomed(Appearance.font.size.small)
            color: Appearance.colour.text
            selectionColor: Appearance.colour.accent
            selectedTextColor: Appearance.colour.accentText
            selectByMouse: true
            renderType: Text.NativeRendering

            clip: true

            function resolve(text: string): string {
                let out = text.trim();
                if (out.startsWith("~"))
                    out = System.home + out.slice(1);
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

        readonly property bool shown: Files.searching || Files.search !== ""
        readonly property string status: {
            if (!FilesFind.home || !search.shown)
                return "";
            if (FilesFind.slashed)
                return "names only, no /";
            if (FilesFind.tooShort)
                return "keep typing";
            if (!FilesFind.active)
                return "";
            if (FilesFind.running)
                return Files.visible.length > 0 ? `${Files.visible.length.toLocaleString()} so far…` : "searching…";
            if (FilesFind.failed)
                return "could not search";
            if (FilesFind.stopped)
                return "stopped";
            if (FilesFind.capped)
                return `first ${FilesFind.limit.toLocaleString()}`;
            return Files.visible.length === 1 ? "1 found" : `${Files.visible.length.toLocaleString()} found`;
        }

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: Files.searching ? root.width * 0.5 : search.shown ? root.width * 0.3 : glass.implicitWidth + Appearance.padding.normal
        implicitHeight: Math.max(field.implicitHeight + Appearance.padding.small * 2, scope.visible ? scope.height : 0)

        SquircleRect {
            id: well

            anchors.left: parent.left
            anchors.right: scope.visible ? scope.left : parent.right
            anchors.rightMargin: scope.visible ? Appearance.padding.small : 0
            anchors.verticalCenter: parent.verticalCenter
            height: field.implicitHeight + Appearance.padding.small * 2
            visible: search.shown

            radius: Appearance.rounding.small
            color: Appearance.colour.fill
            stroke: Files.searching ? Appearance.colour.accent : "transparent"
            strokeWidth: Files.searching ? Appearance.stroke.ring : 0
        }

        Icon {
            id: glass

            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.small
            anchors.verticalCenter: parent.verticalCenter

            name: "search"
            color: search.shown ? Appearance.colour.text : Appearance.colour.textFaint
        }

        TextInput {
            id: field

            anchors.left: glass.right
            anchors.right: said.left
            anchors.leftMargin: Appearance.padding.small
            anchors.rightMargin: Appearance.padding.small
            anchors.verticalCenter: parent.verticalCenter

            visible: search.shown

            focus: Files.searching
            activeFocusOnTab: false

            font.family: Appearance.font.family
            font.pixelSize: Files.zoomed(Appearance.font.size.small)
            color: Appearance.colour.text
            selectionColor: Appearance.colour.accent
            selectedTextColor: Appearance.colour.accentText
            renderType: Text.NativeRendering
            clip: true

            text: Files.search
            onTextChanged: Files.setSearch(text)

            Keys.onReturnPressed: {
                const entry = Files.search.trim() ? Files.current : null;
                Files.setSearching(false);
                Files.focus = "grid";
                Files.open(entry);
            }

            Keys.onDownPressed: {
                Files.setSearching(false);
                Files.focus = "grid";
            }

            Keys.onTabPressed: FilesFind.toggleScope()
            Keys.onBacktabPressed: FilesFind.toggleScope()

            Keys.onEscapePressed: {
                if (FilesFind.running) {
                    FilesFind.stop();
                    return;
                }
                Files.setSearch("");
                Files.setSearching(false);
                Files.focus = "grid";
            }
        }

        StyledText {
            id: said

            anchors.right: well.right
            anchors.rightMargin: search.status ? Appearance.padding.normal : 0
            anchors.verticalCenter: parent.verticalCenter
            visible: search.shown

            text: search.status
            font.pixelSize: Files.zoomed(Appearance.font.size.small)
            color: Appearance.colour.textFaint
        }

        TapHandler {
            onTapped: {
                Files.setSearching(true);
                Files.focus = "grid";
            }
        }

        SettingChoice {
            id: scope

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: Files.searching

            readonly property string here: Conflicts.folderName(Files.cwd, Files.home)

            choices: [
                {label: `Only ${scope.here.length > 16 ? `${scope.here.slice(0, 15)}…` : scope.here}`, value: "folder"},
                {label: "All of home", value: "home"}
            ]
            chosen: FilesFind.scope
            onChose: value => FilesFind.setScope(value)
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
