pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property real originX
    required property real inset

    readonly property bool open: shown
    property bool shown: false

    readonly property real drawnHeight: panel.height
    readonly property int resultCount: results.length
    readonly property string scrollInfo: `row ${root.selected} of ${root.results.length}, at ${Math.round(list.contentY)}/${Math.round(list.maxScroll)}`

    readonly property real panelWidth: Appearance.sizes.launcherWidth

    property bool collapseToCentre: false

    readonly property Item maskItem: catcher

    readonly property var results: Apps.search(query.text)
    property int selected: 0

    readonly property var answer: Calc.answer(query.text)

    property bool answerHolds: false

    onAnswerChanged: root.answerHolds = !!root.answer

    readonly property real rowPitch: Math.max(Appearance.sizes.rowHeight, Appearance.sizes.launcherIcon + Appearance.padding.small * 2)

    readonly property var blobs: panel.height <= 0 ? [] : [
        {
            x: panel.x,
            y: panel.y,
            w: panel.width,
            h: panel.height,
            radius: Appearance.rounding.large,
            smooth: Math.min(Appearance.sizes.melt, Math.min(panel.width, panel.height) / 2)
        }
    ]

    property string restoreTo: ""

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    function show(): void {

        if (!root.shown)
            root.restoreTo = Hypr.focusedOn(root.screenName);

        root.collapseToCentre = false;
        root.unsized = true;
        root.shown = true;
        query.text = "";
        root.selected = 0;

        Qt.callLater(query.forceActiveFocus);
    }

    function hide(): void {

        root.collapseToCentre = !panel.bottomAnchored;
        root.shown = false;
        query.focus = false;
        Hypr.restoreFocus(root.restoreTo);
        root.restoreTo = "";
    }

    function toggle(): void {
        if (root.shown)
            root.hide();
        else
            root.show();
    }

    property bool dragging: false
    property real dragProgress: 0

    readonly property real revealed: root.dragging ? root.dragProgress : rise.value

    function dragTo(fraction: real): void {
        root.dragging = true;
        root.dragProgress = Math.max(0, Math.min(fraction, 1));
    }

    function dragEnd(open: bool): void {
        root.dragging = false;

        rise.value = root.dragProgress;
        if (open) {

            if (!root.shown)
                root.show();
        } else {
            root.hide();

            root.collapseToCentre = false;
        }

        root.dragProgress = 0;
    }

    function accept(): void {

        if (root.answerHolds && root.answer) {
            Clipboard.copy({
                text: root.answer.text
            });
            root.hide();
            return;
        }

        const entry = root.results[root.selected];
        if (entry) {
            Apps.launch(entry);

            root.restoreTo = "";
            Hypr.claimNextWindow();
        }
        root.hide();
    }

    function move(delta: int): void {

        root.answerHolds = false;
        const n = root.results.length;
        if (n <= 0)
            return;
        root.moveTo((root.selected + delta + n) % n);
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
        speed: Appearance.anim.resizeSpeed
        epsilon: 0.5
    }

    Follow {
        id: rise

        target: root.shown ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
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

    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.open
        visible: root.open
        onClicked: root.hide()
    }

    Pull {
        id: putAway

        x: panel.x
        y: panel.y
        width: panel.width
        height: panel.height

        armed: root.open

        dirX: 0
        dirY: 1

        angle: Appearance.sizes.pullAngleEdge

        travel: panel.implicitHeight

        onPulled: fraction => root.dragTo(1 - fraction)

        onFinished: gone => root.dragEnd(!gone)
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

                        Keys.onPressed: event => {
                            const page = Math.max(1, Math.floor(list.height / root.rowPitch) - 1);

                            switch (event.key) {
                            case Qt.Key_Escape:
                                root.hide();
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                root.accept();
                                break;
                            case Qt.Key_Down:
                            case Qt.Key_Tab:
                                root.move(1);
                                break;
                            case Qt.Key_Up:
                            case Qt.Key_Backtab:
                                root.move(-1);
                                break;
                            case Qt.Key_PageDown:
                                root.moveTo(root.selected + page);
                                break;
                            case Qt.Key_PageUp:
                                root.moveTo(root.selected - page);
                                break;
                            case Qt.Key_Home:
                                root.moveTo(0);
                                break;
                            case Qt.Key_End:
                                root.moveTo(root.results.length - 1);
                                break;
                            default:
                                return;
                            }
                            event.accepted = true;
                        }

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

                    reuseItems: true
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
