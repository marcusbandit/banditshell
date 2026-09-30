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

    readonly property bool open: root.shown
    property bool shown: false

    property int tab: 0
    readonly property var tabs: ["Clipboard", "Transcription"]

    readonly property bool speech: root.tab === 1

    property bool searching: false
    property int selected: 0

    property int hovered: -1

    property var reading: null

    readonly property bool expanded: !!root.reading

    property string restoreTo: ""

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    readonly property real panelWidth: Math.min(Appearance.sizes.clipboardWidth, root.width - root.originX - root.inset * 2)

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

    readonly property Item maskItem: catcher

    readonly property var results: root.speech ? Dictation.search(query.text) : Clipboard.search(query.text)

    readonly property var entry: root.results[root.selected] ?? null

    function show(): void {
        if (root.shown)
            return;
        root.restoreTo = Hypr.focusedOn(root.screenName);
        root.shown = true;
        root.selected = 0;
        root.hovered = -1;

        root.reading = null;
        root.stopSearch();
        list.reset();

        Qt.callLater(keys.forceActiveFocus);
    }

    function hide(): void {
        if (!root.shown)
            return;
        root.shown = false;
        root.reading = null;
        sheet.close();
        root.stopSearch();
        keys.focus = false;

        Hypr.restoreFocus(root.restoreTo);
        root.restoreTo = "";
    }

    function toggle(): void {
        if (root.shown)
            root.hide();
        else
            root.show();
    }

    function startSearch(): void {
        root.searching = true;
        Qt.callLater(query.forceActiveFocus);
    }

    function stopSearch(): void {
        root.searching = false;
        query.text = "";
        if (root.shown)
            Qt.callLater(keys.forceActiveFocus);
    }

    function move(delta: int): void {
        const n = root.results.length;
        if (n <= 0)
            return;

        root.moveTo((root.selected + delta + n) % n);
    }

    function moveTo(index: int): void {
        const n = root.results.length;
        if (n <= 0)
            return;
        root.selected = Math.max(0, Math.min(index, n - 1));
        list.reveal(root.selected);
    }

    function expand(): void {
        const e = root.entry;
        if (!e)
            return;

        sheet.close();
        root.reading = e;
    }

    function collapse(): void {
        if (!root.expanded)
            return;
        root.reading = null;

        if (root.shown && !root.searching)
            Qt.callLater(keys.forceActiveFocus);
    }

    function accept(): void {
        const e = root.expanded ? root.reading : root.entry;
        if (e) {
            if (root.speech)
                Dictation.use(e);
            else
                Clipboard.copy(e);
        }
        root.hide();
    }

    function pinCurrent(): void {
        const e = root.entry;

        if (!e || root.speech)
            return;
        Clipboard.setPinned(e, !e.pinned);
        root.follow(e.id);
    }

    function follow(id: string): void {
        const at = root.results.findIndex(e => e.id === id);
        if (at < 0)
            return;
        root.selected = at;
        list.reveal(at);
    }

    function discardCurrent(): void {
        const e = root.entry;
        if (!e)
            return;
        if (root.speech)
            Dictation.drop(e);
        else
            Clipboard.remove(e);

        root.selected = Math.max(0, Math.min(root.selected, root.results.length - 1));
    }

    function actionsFor(e: var): var {
        if (!e)
            return [];

        const acts = [
            {
                icon: "content_copy",
                label: root.speech ? "Use this" : "Copy",
                run: () => {
                    if (root.speech)
                        Dictation.use(e);
                    else
                        Clipboard.copy(e);
                    root.hide();
                }
            }
        ];

        const paths = Clipboard.pathsOf(e);
        if (paths.length)
            acts.push({
                icon: "file_copy",
                label: paths.length === 1 ? "Copy path" : `Copy ${paths.length} paths`,
                run: () => {
                    Clipboard.copyPath(e);
                    root.hide();
                }
            });

        if (!root.speech)
            acts.push({
                icon: "keep",
                label: e.pinned ? "Let go of this" : "Keep this",
                run: () => {
                    Clipboard.setPinned(e, !e.pinned);
                    root.follow(e.id);
                }
            });

        acts.push({
            icon: "delete",
            label: "Delete",
            run: () => {
                if (root.speech)
                    Dictation.drop(e);
                else
                    Clipboard.remove(e);
                root.selected = Math.max(0, Math.min(root.selected, root.results.length - 1));
            }
        });

        return acts;
    }

    function setTab(index: int): void {
        if (index === root.tab)
            return;
        root.tab = Math.max(0, Math.min(index, root.tabs.length - 1));
        sheet.close();

        root.reading = null;
        root.stopSearch();
        root.selected = 0;
        list.reset();
    }

    function commonKey(event: var): bool {
        const page = Math.max(1, Math.floor(list.height / Math.max(1, list.pitch)) - 1);

        switch (event.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.accept();
            return true;

        case Qt.Key_Right:
            root.expand();
            return true;
        case Qt.Key_Left:
            root.collapse();
            return true;

        case Qt.Key_Down:
            if (root.expanded)
                return false;
            root.move(1);
            return true;
        case Qt.Key_Up:
            if (root.expanded)
                return false;
            root.move(-1);
            return true;
        case Qt.Key_PageDown:
            root.moveTo(root.selected + page);
            return true;
        case Qt.Key_PageUp:
            root.moveTo(root.selected - page);
            return true;

        case Qt.Key_Tab:
            root.setTab((root.tab + 1) % root.tabs.length);
            return true;
        case Qt.Key_Backtab:
            root.setTab((root.tab - 1 + root.tabs.length) % root.tabs.length);
            return true;
        }
        return false;
    }

    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.open
        visible: root.open
        onClicked: root.hide()
    }

    Item {
        id: keys

        Keys.onPressed: event => {

            if (sheet.open) {
                switch (event.key) {
                case Qt.Key_Down:
                case Qt.Key_J:
                    sheet.move(1);
                    break;
                case Qt.Key_Up:
                case Qt.Key_K:
                    sheet.move(-1);
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    sheet.activate(sheet.selected);
                    break;
                default:
                    sheet.close();
                    break;
                }
                event.accepted = true;
                return;
            }

            if (root.commonKey(event)) {
                event.accepted = true;
                return;
            }

            switch (event.key) {

            case Qt.Key_Escape:
                if (root.expanded)
                    root.collapse();
                else
                    root.hide();
                break;

            case Qt.Key_Slash:
                root.startSearch();
                break;
            case Qt.Key_J:
                if (!root.expanded)
                    root.move(1);
                break;
            case Qt.Key_K:
                if (!root.expanded)
                    root.move(-1);
                break;

            case Qt.Key_L:
                root.expand();
                break;
            case Qt.Key_H:
                root.collapse();
                break;
            case Qt.Key_Home:
                root.moveTo(0);
                break;
            case Qt.Key_End:
                root.moveTo(root.results.length - 1);
                break;
            case Qt.Key_P:
                root.pinCurrent();
                break;
            case Qt.Key_X:
            case Qt.Key_Delete:
                root.discardCurrent();
                break;
            default:
                return;
            }
            event.accepted = true;
        }
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

        travel: panel.fullHeight

        onPulled: fraction => root.pushTo(fraction)
        onFinished: gone => root.pushEnd(gone)

    }

    property bool pushing: false
    property real pushOut: 0

    readonly property real revealed: root.pushing ? root.pushOut : rise.value

    function pushTo(fraction: real): void {
        if (!root.open)
            return;
        root.pushing = true;
        root.pushOut = 1 - Math.max(0, Math.min(fraction, 1));
    }

    function pushEnd(gone: bool): void {

        if (!root.pushing)
            return;
        root.pushing = false;

        rise.value = root.pushOut;
        root.pushOut = 0;
        if (gone)
            root.hide();
    }

    Follow {
        id: turn

        speed: Appearance.anim.revealSpeed
        target: root.expanded ? 1 : 0
        epsilon: 0.005
    }

    Follow {
        id: rise

        speed: Appearance.anim.revealSpeed
        target: root.shown ? 1 : 0

        epsilon: 0.005
    }

    Item {
        id: panel

        readonly property real bandY: root.height - root.inset
        readonly property real fullHeight: root.height - root.inset * 2

        x: root.originX + (root.width - root.originX - root.panelWidth) / 2
        width: root.panelWidth

        height: fullHeight * root.revealed
        y: bandY - height

        visible: height > 0

        Item {
            id: viewport

            anchors.fill: parent
            clip: true

            Item {
                id: pages

                width: viewport.width * 2
                height: viewport.height
                x: -turn.value * viewport.width

                Item {
                    id: listPage

                    width: viewport.width
                    height: viewport.height

            Item {
                id: header

                x: Appearance.padding.large
                y: Appearance.padding.large
                width: parent.width - Appearance.padding.large * 2
                height: Math.max(tabStrip.height, field.height)

                Segments {
                    id: tabStrip

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    options: root.tabs
                    current: root.tab
                    onPicked: index => root.setTab(index)
                }

                Item {
                    id: field

                    anchors.right: parent.right
                    anchors.left: tabStrip.right
                    anchors.leftMargin: Appearance.padding.large
                    anchors.verticalCenter: parent.verticalCenter
                    height: Math.round(Appearance.font.size.small * 4 / 3) + Appearance.padding.small * 2

                    opacity: root.searching ? 1 : 0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                        }
                    }

                    SquircleRect {
                        anchors.fill: parent
                        radius: height / 2
                        color: Appearance.colour.fill
                    }

                    Icon {
                        id: searchGlyph

                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter
                        name: "search"
                        size: Appearance.font.iconSize
                        color: Appearance.colour.textFaint
                    }

                    TextInput {
                        id: query

                        anchors.left: searchGlyph.right
                        anchors.leftMargin: Appearance.padding.small
                        anchors.right: parent.right
                        anchors.rightMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter

                        font.family: Appearance.font.family
                        font.pixelSize: Appearance.font.size.small
                        renderType: Text.NativeRendering
                        color: Appearance.colour.text
                        selectionColor: Appearance.colour.accent
                        selectedTextColor: Appearance.colour.accentText
                        clip: true

                        Keys.onPressed: event => {
                            if (root.commonKey(event)) {
                                event.accepted = true;
                                return;
                            }

                            if (event.key === Qt.Key_Escape) {
                                root.stopSearch();
                                event.accepted = true;
                            }

                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !query.text
                            text: root.speech ? "Search what you said" : "Search what you copied"
                            color: Appearance.colour.textGhost
                        }
                    }
                }

                StyledText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.searching
                    text: "/  to search"
                    color: Appearance.colour.textGhost
                }
            }

            Separator {
                id: rule

                anchors.top: header.bottom
                anchors.topMargin: Appearance.padding.normal
                x: Appearance.padding.large
                width: parent.width - Appearance.padding.large * 2
            }

            GlideList {
                id: list

                readonly property real pitch: Appearance.sizes.rowHeight + Appearance.padding.small

                anchors.top: rule.bottom
                anchors.topMargin: Appearance.padding.normal
                x: Appearance.padding.large
                width: parent.width - Appearance.padding.large * 2
                height: Math.max(0, panel.fullHeight - y - Appearance.padding.large)
                clip: true

                model: ScriptModel {
                    values: root.results
                }

                reuseItems: false
                cacheBuffer: list.pitch * 6

                delegate: ClipRow {
                    required property var modelData

                    width: list.width
                    entry: modelData
                    selected: index === root.selected

                    onActivated: {
                        root.selected = index;
                        root.accept();
                    }

                    onPinned: if (!root.speech)
                        Clipboard.setPinned(modelData, !modelData.pinned)

                    onMenu: (mx, my) => {
                        root.selected = index;
                        const at = mapToItem(panel, mx, my);
                        sheet.popup(at.x, at.y, root.actionsFor(modelData));
                    }
                    onDiscarded: {
                        if (root.speech)
                            Dictation.drop(modelData);
                        else
                            Clipboard.remove(modelData);
                    }

                    onExpanded: {
                        root.selected = index;
                        root.reading = modelData;
                    }

                    onEntered: root.hovered = index
                    onExited: if (root.hovered === index)
                        root.hovered = -1
                }

                remove: Transition {
                    NumberAnimation {
                        property: "opacity"
                        to: 0
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutCubic
                    }
                }

                displaced: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutCubic
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: !root.results.length
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colour.textFaint

                    text: {
                        if (query.text)
                            return "Nothing matches.";
                        if (!root.speech)
                            return "Nothing has been copied yet.";
                        if (!Dictation.present)
                            return "The dictation daemon is not running.\n`voice up` starts it.";
                        return "Nothing has been dictated yet.\nSUPER + R starts.";
                    }
                }
            }

            WheelHandler {
                id: pager

                property bool spent: false

                onWheel: event => {

                    if (event.pixelDelta.x === 0 && event.pixelDelta.y === 0) {
                        event.accepted = false;
                        return;
                    }

                    if (Math.abs(event.pixelDelta.x) <= Math.abs(event.pixelDelta.y)) {
                        event.accepted = false;
                        return;
                    }

                    event.accepted = true;
                    swipe.feed(event);
                }
            }

            ScrollGesture {
                id: swipe

                armed: root.open

                onBegan: pager.spent = false

                onMoved: (dx, dy) => {

                    if (pager.spent)
                        return;
                    const step = Math.max(1, root.panelWidth * Appearance.sizes.pullTravel);
                    if (Math.abs(dx) < step)
                        return;
                    pager.spent = true;

                    if (dx < 0)
                        root.expand();
                    else
                        root.collapse();
                }
            }
                }

                ClipDetail {
                    id: detail

                    x: listPage.width
                    width: viewport.width
                    height: viewport.height

                    entry: root.reading

                    onBack: root.collapse()
                    onAccepted: root.accept()
                }
            }
        }

        ActionSheet {
            id: sheet

            anchors.fill: parent

            Connections {
                target: list

                function onContentYChanged(): void {
                    sheet.close();
                }
            }

            onClosed: if (root.shown && !root.searching)
                Qt.callLater(keys.forceActiveFocus)
        }
    }
}
