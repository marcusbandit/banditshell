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

    readonly property var history: root.speech ? ({
            search: text => Dictation.search(text),
            use: e => Dictation.use(e),
            forget: e => Dictation.drop(e)
        }) : ({
            search: text => Clipboard.search(text),
            use: e => Clipboard.copy(e),
            forget: e => Clipboard.remove(e)
        })

    readonly property var results: root.history.search(query.text)

    onResultsChanged: root.selected = Math.max(0, Math.min(root.selected, root.results.length - 1))

    readonly property var entry: root.results[root.selected] ?? null

    readonly property var current: root.expanded ? root.reading : root.entry

    property bool clearing: false

    readonly property int clearable: Clipboard.unpinned
    readonly property int pinnedCount: Clipboard.entries.length - root.clearable

    readonly property bool canClear: !root.speech && !root.searching && root.clearable > 0

    onCanClearChanged: if (!root.canClear)
        root.clearing = false

    onExpandedChanged: if (root.expanded)
        root.clearing = false

    function items(n: int): string {
        return n === 1 ? "1 item" : `${n} items`;
    }

    property string cleared: ""

    readonly property int clearedHold: 3000

    function show(): void {
        if (root.shown)
            return;
        root.restoreTo = Hypr.focusedOn(root.screenName);
        root.shown = true;
        root.selected = 0;
        root.hovered = -1;

        root.reading = null;
        root.clearing = false;
        root.stopSearch();
        list.reset();

        Qt.callLater(keys.forceActiveFocus);
    }

    function hide(): void {
        if (!root.shown)
            return;
        root.shown = false;
        root.reading = null;
        root.clearing = false;
        clearedLinger.stop();
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
        root.clearing = false;
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
        if (root.current)
            root.history.use(root.current);
        root.hide();
    }

    function pin(e: var): void {
        if (!e || root.speech)
            return;
        Clipboard.setPinned(e, !e.pinned);
        if (root.reading?.id === e.id)
            root.reading = Clipboard.entries.find(x => x.id === e.id) ?? null;
        root.follow(e.id);
    }

    function follow(id: string): void {
        const at = root.results.findIndex(e => e.id === id);
        if (at < 0)
            return;
        root.selected = at;
        list.reveal(at);
    }

    function discard(e: var): void {
        if (!e)
            return;
        const onScreen = root.reading?.id === e.id;
        root.history.forget(e);
        if (onScreen)
            root.collapse();
    }

    function askClear(): void {
        if (!root.canClear)
            return;
        sheet.close();
        root.clearing = true;
    }

    function clearHistory(): void {
        const gone = root.clearable;
        const kept = root.pinnedCount;
        root.clearing = false;
        root.cleared = kept > 0 ? `${gone} cleared, ${kept} pinned kept` : `${gone} cleared`;
        clearedLinger.restart();
        Clipboard.clear();
        root.selected = 0;
        list.reset();
    }

    function actionsFor(e: var): var {
        if (!e)
            return [];

        const acts = [
            {
                icon: "content_copy",
                label: root.speech ? "Use this" : "Copy",
                run: () => {
                    root.history.use(e);
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
                run: () => root.pin(e)
            });

        acts.push({
            icon: "delete",
            label: "Delete",
            run: () => root.discard(e)
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
        const pitch = list.count > 0 ? list.contentHeight / list.count : list.pitch;
        const page = Math.max(1, Math.floor(list.height / Math.max(1, pitch)) - 1);

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

            if (root.clearing && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                root.clearHistory();
                event.accepted = true;
                return;
            }

            if (root.commonKey(event)) {
                event.accepted = true;
                return;
            }

            switch (event.key) {

            case Qt.Key_Escape:
                Appearance.instantly();
                if (root.clearing)
                    root.clearing = false;
                else if (root.expanded)
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
                root.pin(root.current);
                break;
            case Qt.Key_X:
            case Qt.Key_Delete:
                root.discard(root.current);
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
        angle: Config.values.control.pullAngleEdge

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

        speed: Appearance.animation.revealSpeed
        target: root.expanded ? 1 : 0
        epsilon: 0.005
    }

    Follow {
        id: rise

        speed: Appearance.animation.revealSpeed
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
                        height: Math.max(tabStrip.height, field.height, clearBar.height)

                        Segments {
                            id: tabStrip

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter

                            options: root.tabs
                            current: root.tab
                            onPicked: index => root.setTab(index)
                        }

                        Row {
                            id: clearBar

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Appearance.padding.small

                            opacity: clearFade.value
                            visible: clearFade.value > 0.01

                            Follow {
                                id: clearFade

                                target: root.canClear ? 1 : 0
                                speed: Appearance.animation.revealSpeed
                                epsilon: Appearance.animation.fadeEpsilon
                                startsAtTarget: true
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.clearing && root.pinnedCount > 0
                                text: `${root.pinnedCount} pinned stay`
                                font.pixelSize: Appearance.font.size.small
                                color: Appearance.colour.text
                            }

                            Button {
                                visible: !root.clearing
                                style: "bare"
                                icon: "delete_sweep"
                                text: "Clear history"
                                onClicked: root.askClear()
                            }

                            Button {
                                visible: root.clearing
                                icon: "delete_sweep"
                                text: `Clear ${root.items(root.clearable)}`
                                alarm: true
                                onClicked: root.clearHistory()
                            }

                            Button {
                                visible: root.clearing
                                style: "bare"
                                text: "Cancel"
                                onClicked: root.clearing = false
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Appearance.padding.small

                            opacity: clearedFade.value
                            visible: clearedFade.value > 0.01

                            Follow {
                                id: clearedFade

                                target: clearedLinger.running && !root.canClear && !root.searching ? 1 : 0
                                speed: Appearance.animation.revealSpeed
                                epsilon: Appearance.animation.fadeEpsilon
                                startsAtTarget: true
                            }

                            Timer {
                                id: clearedLinger

                                interval: root.clearedHold
                            }

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "check"
                                size: Appearance.font.iconSize
                                color: Appearance.colour.text
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.cleared
                                font.pixelSize: Appearance.font.size.small
                                color: Appearance.colour.text
                            }
                        }

                        Item {
                            id: field

                            anchors.right: parent.right
                            anchors.left: tabStrip.right
                            anchors.leftMargin: Appearance.padding.large
                            anchors.verticalCenter: parent.verticalCenter
                            height: Appearance.font.line.small + Appearance.padding.small * 2

                            opacity: searchFade.value
                            visible: searchFade.value > 0.01

                            Follow {
                                id: searchFade

                                target: root.searching ? 1 : 0
                                speed: Appearance.animation.revealSpeed
                                epsilon: Appearance.animation.fadeEpsilon
                                startsAtTarget: true
                            }

                            SquircleRect {
                                anchors.fill: parent
                                pill: "place"
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
                                    color: Appearance.colour.textFaint
                                }
                            }
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
                        height: panel.visible ? Math.max(0, panel.fullHeight - y - Appearance.padding.large) : 0
                        clip: true

                        model: ScriptModel {
                            values: root.results
                        }

                        reuseItems: false
                        cacheBuffer: panel.visible ? list.pitch * 6 : 0

                        delegate: ClipboardRow {
                            required property var modelData

                            width: list.width
                            entry: modelData
                            selected: index === root.selected
                            going: root.clearing && !modelData.pinned

                            onActivated: {
                                root.selected = index;
                                root.accept();
                            }

                            onPinned: root.pin(modelData)

                            onMenu: (mx, my) => {
                                root.selected = index;
                                const at = mapToItem(panel, mx, my);
                                sheet.popup(at.x, at.y, root.actionsFor(modelData));
                            }
                            onDiscarded: root.discard(modelData)

                            onExpanded: {
                                root.selected = index;
                                root.reading = modelData;
                            }

                            onEntered: root.hovered = index
                            onExited: if (root.hovered === index)
                                root.hovered = -1
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

                        orientation: Qt.Horizontal

                        onWheel: event => {
                            if (event.pixelDelta.x === 0 && event.pixelDelta.y === 0) {
                                event.accepted = false;
                                return;
                            }
                            if (Math.abs(event.pixelDelta.x) <= Math.abs(event.pixelDelta.y))
                                return;
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
                            const step = Math.max(1, root.panelWidth * Config.values.control.pullTravel);
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

                ClipboardDetail {
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
