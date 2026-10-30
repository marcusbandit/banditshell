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
    signal emptyAsked

    implicitHeight: Math.max(buttons.implicitHeight, crumbs.implicitHeight, emptying.visible ? emptying.implicitHeight : 0, search.implicitHeight)

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

                implicitWidth: Math.max(Appearance.sizes.minTarget, Files.zoomed(Appearance.sizes.minTarget))
                implicitHeight: Math.max(Appearance.sizes.minTarget, Files.zoomed(Appearance.sizes.minTarget))

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
                    size: Files.zoomed(Appearance.font.iconSize)
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
        anchors.right: emptying.visible ? emptying.left : search.left
        anchors.rightMargin: Appearance.padding.normal

        visible: !Files.searching && !root.editing
        spacing: 0

        readonly property real gap: Appearance.padding.normal * 2
        readonly property real fold: foldText.implicitWidth + crumbs.gap
        readonly property real mark: markText.implicitWidth

        readonly property var fit: {
            const count = list.count;
            const items = [];
            let total = 0;
            for (let i = 0; i < count; ++i) {
                const item = list.itemAt(i);
                if (!item)
                    return {kept: 0, used: 0};
                items.push(item.natural);
                total += item.natural;
            }
            if (total <= crumbs.width)
                return {kept: 0, used: total};
            let sum = 0;
            for (let i = count - 1; i >= 0; --i) {
                const more = sum + items[i];
                if (i < count - 1 && more > crumbs.width - crumbs.fold)
                    return {kept: i + 1, used: sum};
                sum = more;
            }
            return {kept: 0, used: sum};
        }
        readonly property int kept: crumbs.fit.kept

        StyledText {
            id: foldText

            visible: false
            text: "…"
            font.pixelSize: Files.zoomed(Appearance.font.size.small)
        }

        StyledText {
            id: markText

            visible: false
            text: "›"
            leftPadding: Appearance.padding.hair
            rightPadding: Appearance.padding.hair
            font.pixelSize: Files.zoomed(Appearance.font.size.small)
        }

        Repeater {
            id: list

            model: Files.crumbs

            delegate: Item {
                id: crumb

                required property int index
                required property var modelData

                readonly property bool last: crumb.index === Files.crumbs.length - 1
                readonly property bool folded: crumb.index === crumbs.kept - 1
                readonly property real lead: crumb.index > 0 && !crumb.folded ? crumbs.mark : 0
                readonly property real natural: (crumb.index > 0 ? crumbs.mark : 0) + whole.implicitWidth + crumbs.gap

                visible: crumb.index >= crumbs.kept - 1
                implicitWidth: crumb.folded ? crumbs.fold : Math.min(crumb.natural, crumbs.width - (crumb.last && crumbs.kept > 0 ? crumbs.fold : 0))
                implicitHeight: label.implicitHeight + Appearance.padding.small * 2

                StyledText {
                    id: whole

                    visible: false
                    text: crumb.modelData.name
                    font.pixelSize: Files.zoomed(Appearance.font.size.small)
                }

                StyledText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: crumb.lead > 0

                    text: "›"
                    leftPadding: Appearance.padding.hair
                    rightPadding: Appearance.padding.hair
                    font.pixelSize: Files.zoomed(Appearance.font.size.small)
                    color: Appearance.colour.textFaint
                }

                SquircleRect {
                    anchors.fill: parent
                    anchors.leftMargin: crumb.lead

                    radius: Appearance.rounding.small
                    color: root.receiving === crumb.index ? Appearance.colour.accentFill : hover.hovered ? Appearance.colour.fill : "transparent"
                    stroke: root.receiving === crumb.index ? Appearance.colour.accent : "transparent"
                    strokeWidth: root.receiving === crumb.index ? Appearance.stroke.ring : 0
                }

                StyledText {
                    id: label

                    x: crumb.lead + crumbs.gap / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: crumb.implicitWidth - crumb.lead - crumbs.gap

                    elide: Text.ElideMiddle
                    text: crumb.folded ? "…" : crumb.modelData.name
                    font.pixelSize: Files.zoomed(Appearance.font.size.small)

                    color: crumb.last ? Appearance.colour.text : Appearance.colour.textDim
                }

                HoverTip {
                    host: crumb
                    asked: hover.hovered
                    text: hover.hovered && (label.truncated || crumb.folded) ? crumb.modelData.path : ""
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
        anchors.right: emptying.visible ? emptying.left : search.left
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

    Button {
        id: emptying

        anchors.right: search.left
        anchors.rightMargin: Appearance.padding.small
        anchors.verticalCenter: parent.verticalCenter
        visible: Files.trashTop && !Files.searching && !root.editing

        style: "ring"
        icon: "local_fire_department"
        text: "Empty Trash"
        zoom: Files.magnification
        interactive: Files.trashItems.length > 0

        onClicked: root.emptyAsked()
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

        implicitWidth: Files.searching ? Math.min(root.width - buttons.width - Appearance.padding.normal, Math.max(root.width * 0.5, scope.implicitWidth + Files.zoomed(160))) : search.shown ? root.width * 0.3 : glass.implicitWidth + Appearance.padding.normal
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
            size: Files.zoomed(Appearance.font.iconSize)
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

            zoom: Files.magnification
            width: Math.min(implicitWidth, search.width - Files.zoomed(120))

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: Files.searching

            readonly property string here: Conflicts.folderName(Files.cwd, Files.home)

            choices: [
                {label: Files.cwd === Files.home ? "Top of home" : `In ${scope.here.length > 16 ? `${scope.here.slice(0, 15)}…` : scope.here}`, value: "folder"},
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
