pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.controls

LauncherConcept {
    id: root

    surface: panel
    input: query
    view: list
    rowPitch: Math.max(Appearance.sizes.rowHeight, Appearance.sizes.launcherIcon + Appearance.padding.small * 2)
    travel: panel.implicitHeight

    readonly property int resultCount: results.length
    readonly property string scrollInfo: `row ${root.selected} of ${root.results.length}, at ${Math.round(list.contentY)}/${Math.round(list.maxScroll)}`

    readonly property real panelWidth: Appearance.sizes.launcherWidth

    property bool collapseToCentre: false

    readonly property var results: Apps.search(query.text)
    property int selected: 0

    onShowing: {
        root.collapseToCentre = false;
        root.unsized = true;
    }

    onCleared: root.selected = 0

    onHidden: root.collapseToCentre = !panel.bottomAnchored

    onDropped: stayedOpen => {
        if (!stayedOpen)
            root.collapseToCentre = false;
    }

    function accept(): void {
        if (root.copyAnswer())
            return;

        const entry = root.results[root.selected];
        if (entry)
            root.launch(() => Apps.launch(entry));
        else
            root.hide();
    }

    function move(delta: int): void {
        root.answerHolds = false;
        const n = root.results.length;
        if (n <= 0)
            return;
        root.moveTo((root.selected + delta + n) % n);
    }

    function page(rows: int): void {
        root.moveTo(root.selected + rows);
    }

    function claimKey(event: var): bool {
        switch (event.key) {
        case Qt.Key_Home:
            root.moveTo(0);
            return true;
        case Qt.Key_End:
            root.moveTo(root.results.length - 1);
            return true;
        }
        return false;
    }

    function chooseRow(index: int): void {
        root.answerHolds = false;
        root.selected = index;
        root.accept();
    }

    function moveTo(index: int): void {
        root.answerHolds = false;
        const n = root.results.length;
        if (n <= 0)
            return;
        root.selected = Math.max(0, Math.min(index, n - 1));
        list.reveal(root.selected);
    }

    onResultsChanged: {
        root.selected = 0;
        list.reset();
    }

    Follow {
        id: grow

        target: panel.implicitHeight
        speed: Appearance.animation.resizeSpeed
        epsilon: 0.5
    }

    property bool unsized: false

    Connections {
        target: panel

        function onImplicitHeightChanged(): void {
            if (root.unsized) {
                root.unsized = false;
                grow.value = panel.implicitHeight;
            }
        }
    }

    Item {
        id: panel

        readonly property real barOffset: Appearance.padding.large + field.height / 2

        readonly property real restY: root.height / 2 - barOffset

        readonly property real bandY: root.height - root.inset
        readonly property bool bottomAnchored: restY + grow.value >= bandY - 1

        x: (root.width - width) / 2

        y: root.collapseToCentre ? restY + (grow.value - height) / 2 : bandY + (restY - bandY) * root.revealed

        width: root.panelWidth

        implicitHeight: Math.min(root.height - restY - root.inset, Appearance.padding.large * 2 + field.height + Appearance.padding.normal * 2 + separator.height + answerRow.height + (answerRow.visible ? Appearance.padding.normal : 0) + list.needed)

        height: grow.value * root.revealed

        visible: height > 0

        Item {
            anchors.fill: parent
            clip: true

            Column {
                id: layout

                x: Appearance.padding.large
                y: Appearance.padding.large
                width: root.panelWidth - Appearance.padding.large * 2
                spacing: Appearance.padding.normal

                Item {
                    id: field

                    width: parent.width
                    implicitHeight: Math.max(searchGlyph.implicitHeight, query.implicitHeight)
                    height: implicitHeight

                    Icon {
                        id: searchGlyph

                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter
                        width: Appearance.sizes.launcherIcon
                        size: Appearance.font.size.normal
                        name: "search"
                        color: Appearance.colour.textFaint
                    }

                    TextInput {
                        id: query

                        anchors.left: searchGlyph.right
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        font.family: Appearance.font.family
                        font.pixelSize: Appearance.font.size.normal
                        renderType: Text.NativeRendering
                        color: Appearance.colour.text
                        selectionColor: Appearance.colour.accent
                        selectedTextColor: Appearance.colour.accentText
                        clip: true

                        Keys.onPressed: event => root.pressKey(event)

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !query.text

                            text: "Search"
                            font.pixelSize: Appearance.font.size.normal
                            color: Appearance.colour.textFaint
                        }
                    }
                }

                Separator {
                    id: separator

                    width: parent.width
                }

                AnswerRow {
                    id: answerRow

                    width: parent.width
                    iconSize: Appearance.sizes.launcherIcon
                    rowHeight: root.rowPitch
                    labelSize: Appearance.font.size.normal

                    result: root.answer
                    expression: query.text
                    holds: root.answerHolds

                    onCopied: {
                        root.answerHolds = true;
                        root.accept();
                    }
                }

                GlideList {
                    id: list

                    readonly property real needed: Math.max(1, root.results.length) * root.rowPitch

                    width: parent.width
                    height: Math.max(0, panel.height - y - Appearance.padding.large)
                    clip: true

                    model: ScriptModel {
                        values: root.results
                    }

                    cacheBuffer: root.rowPitch * 4

                    delegate: MenuRow {
                        required property var modelData
                        required property int index

                        width: list.width
                        iconSize: Appearance.sizes.launcherIcon
                        rowHeight: root.rowPitch

                        labelSize: Appearance.font.size.normal
                        inlineDetail: true

                        iconSource: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                        icon: "apps"
                        label: modelData.name ?? ""
                        detail: modelData.genericName || modelData.comment || ""

                        selected: index === root.selected && !root.answerHolds

                        onActivated: root.chooseRow(index)
                    }

                    StyledText {
                        id: empty

                        visible: !root.results.length && !root.answer
                        text: query.text ? "nothing matches" : "no applications found"
                        color: Appearance.colour.textFaint
                        font.pixelSize: Appearance.font.size.small
                    }
                }
            }
        }
    }
}
