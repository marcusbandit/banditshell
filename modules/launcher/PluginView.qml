pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.modules.controls
import "../../services/plugin-protocol.js" as Protocol
import "../../services/ranking.js" as Ranking

Item {
    id: root

    property string typed: ""

    signal leave(var what)
    signal launch(var what)
    signal back
    signal retitle(string text)

    readonly property var view: PluginHost.page?.view ?? null
    readonly property var source: PluginHost.page?.source ?? null
    readonly property string kind: root.view?.kind ?? ""
    readonly property string viewId: root.view?.id ?? ""

    property string filter: ""
    property int selected: 0
    property int field: 0
    property int actionAt: -1
    property var values: ({})
    property var missing: []
    property string shownId: ""

    readonly property var shown: root.kind === "list" ? Protocol.listed(root.view, root.filter, (label, typed) => Ranking.place(label, typed)) : []
    readonly property var actions: root.view?.actions ?? []
    readonly property real rowPitch: Math.max(Appearance.sizes.rowHeight, Appearance.sizes.launcherIcon + Appearance.padding.small * 2)

    onViewChanged: {
        if (!root.view)
            return;
        root.retitle(root.view.title);
        root.values = root.kind === "form" ? Protocol.formValues(root.view, {}) : {};
        root.missing = [];
        if (root.viewId === root.shownId) {
            root.selected = Math.max(0, Math.min(root.selected, root.shown.length - 1));
            root.actionAt = Math.min(root.actionAt, root.actions.length - 1);
            return;
        }
        root.shownId = root.viewId;
        root.filter = "";
        root.selected = 0;
        root.field = 0;
        root.actionAt = -1;
        wheel.stop();
        scroller.contentY = 0;
        focusSoon.restart();
    }

    Component.onCompleted: root.viewChanged()

    function setValue(key: string, value: var): void {
        root.values = Object.assign({}, root.values, {
            [key]: value
        });
        root.missing = root.missing.filter(k => k !== key);
    }

    function targetId(): string {
        return root.kind === "list" ? root.shown[root.selected]?.id ?? root.viewId : root.viewId;
    }

    function run(doing: var, action: string, item: string): void {
        if (Protocol.local(doing) || doing.refusal)
            root.source?.doLocal(doing);
        else
            root.source?.activateIn(item, action, root.viewId);
    }

    function runAction(index: int): void {
        const action = root.actions[index];
        if (action)
            root.run(action, action.id, root.targetId());
        else if (root.kind === "detail")
            root.source?.activateIn(root.viewId, "", root.viewId);
    }

    function runItem(item: var): void {
        const enter = Protocol.enterOf(item);
        if (enter.local)
            root.run(enter.local, "", item.id);
        else
            root.source?.activateIn(item.id, enter.action, root.viewId);
    }

    function submit(): void {
        root.missing = Protocol.formMissing(root.view, root.values);
        if (!root.missing.length)
            root.source?.submit(root.viewId, Protocol.formValues(root.view, root.values));
    }

    function reveal(item: var): void {
        if (!item)
            return;
        const top = item.y + body.y;
        if (top < wheel.goal)
            wheel.scrollTo(top);
        else if (top + item.height > wheel.goal + scroller.height)
            wheel.scrollTo(top + item.height - scroller.height);
    }

    function move(delta: int): void {
        if (root.kind === "list") {
            root.selected = Math.max(0, Math.min(root.shown.length - 1, root.selected + delta));
            root.reveal(listRepeater.itemAt(root.selected));
        } else if (root.kind === "form")
            root.focusField(Math.max(0, Math.min(root.view.fields.length, root.field + delta)));
    }

    function focusField(index: int): void {
        root.field = index;
        const item = fieldRepeater.itemAt(index);
        if (item) {
            item.takeFocus();
            root.reveal(item);
        } else
            submitButton.forceActiveFocus();
    }

    function cycleAction(delta: int): void {
        const count = root.actions.length;
        if (!count)
            return;
        const next = root.actionAt + delta;
        root.actionAt = next >= count ? -1 : next < -1 ? count - 1 : next;
    }

    function claimKey(event: var): bool {
        const page = scroller.height - Appearance.font.line.normal * 2;
        switch (event.key) {
        case Qt.Key_Down:
            if (root.kind === "detail")
                wheel.scrollTo(wheel.goal + Appearance.font.line.normal * 3);
            else
                root.move(1);
            return true;
        case Qt.Key_Up:
            if (root.kind === "detail")
                wheel.scrollTo(wheel.goal - Appearance.font.line.normal * 3);
            else
                root.move(-1);
            return true;
        case Qt.Key_PageDown:
            wheel.scrollTo(wheel.goal + page);
            return true;
        case Qt.Key_PageUp:
            wheel.scrollTo(wheel.goal - page);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (root.actionAt >= 0)
                root.runAction(root.actionAt);
            else if (root.kind === "list") {
                if (root.shown[root.selected])
                    root.runItem(root.shown[root.selected]);
            } else if (root.kind === "form")
                root.submit();
            else
                root.runAction(0);
            return true;
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            if (root.kind === "form")
                root.move(event.key === Qt.Key_Tab ? 1 : -1);
            else
                root.cycleAction(event.key === Qt.Key_Tab ? 1 : -1);
            return true;
        }
        return false;
    }

    function fieldKey(event: var): void {
        if (event.key === Qt.Key_Escape) {
            root.back();
            event.accepted = true;
        } else if (root.claimKey(event))
            event.accepted = true;
    }

    property Timer focusSoon: Timer {
        interval: 1
        onTriggered: {
            if (root.kind === "list")
                filterInput.forceActiveFocus();
            else if (root.kind === "form")
                root.focusField(0);
        }
    }

    readonly property real footerHeight: root.actions.length || root.kind === "form" ? Appearance.sizes.rowHeight + Appearance.padding.normal * 2 : 0

    implicitHeight: Math.max(Appearance.sizes.rowHeight * 6, scroller.contentHeight + root.footerHeight)

    Item {
        id: filterLine

        visible: root.kind === "list"
        x: Appearance.padding.normal
        width: root.width - Appearance.padding.normal * 2
        height: visible ? Appearance.sizes.rowHeight : 0

        Icon {
            id: filterIcon

            anchors.verticalCenter: parent.verticalCenter
            name: "filter_list"
            color: Appearance.colour.textFaint
        }

        TextInput {
            id: filterInput

            anchors.left: filterIcon.right
            anchors.leftMargin: Appearance.padding.normal
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.filter
            font.family: Appearance.font.family
            font.pixelSize: Appearance.font.size.normal
            color: Appearance.colour.text
            selectionColor: Appearance.colour.accent
            selectedTextColor: Appearance.colour.accentText
            clip: true
            onTextEdited: {
                root.filter = text;
                root.selected = 0;
            }
            Keys.onPressed: event => root.fieldKey(event)

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: !filterInput.text
                text: root.view?.placeholder ?? ""
                font.pixelSize: Appearance.font.size.normal
                color: Appearance.colour.textFaint
            }
        }
    }

    Flickable {
        id: scroller

        y: filterLine.height
        width: root.width
        height: root.height - root.footerHeight - filterLine.height
        contentHeight: body.implicitHeight + Appearance.padding.large
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        WheelStep {
            id: wheel

            flick: scroller
        }

        Column {
            id: body

            x: Appearance.padding.normal
            y: Appearance.padding.small
            width: scroller.width - Appearance.padding.normal * 2
            spacing: Appearance.padding.normal

            StyledText {
                visible: root.kind === "detail" && text !== ""
                width: body.width
                text: root.view?.text ?? ""
                font.pixelSize: Appearance.font.size.normal
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
            }

            Repeater {
                model: root.kind === "detail" ? root.view.facts : []

                delegate: Row {
                    id: fact

                    required property var modelData

                    width: body.width
                    spacing: Appearance.padding.normal

                    StyledText {
                        width: Math.round(body.width * 0.3)
                        text: fact.modelData.label
                        font.pixelSize: Appearance.font.size.small
                        color: Appearance.colour.textFaint
                        elide: Text.ElideRight
                    }

                    StyledText {
                        width: body.width - Math.round(body.width * 0.3) - Appearance.padding.normal
                        text: fact.modelData.value
                        font.pixelSize: Appearance.font.size.small
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                    }
                }
            }

            StyledText {
                visible: root.kind === "list" && !root.shown.length
                text: root.filter ? `Nothing matches “${root.filter}”` : "Nothing here yet"
                font.pixelSize: Appearance.font.size.normal
                color: Appearance.colour.textFaint
            }

            Repeater {
                id: listRepeater

                model: root.kind === "list" ? root.shown : []

                delegate: MenuRow {
                    id: line

                    required property var modelData
                    required property int index

                    width: body.width
                    iconSize: Appearance.sizes.launcherIcon
                    rowHeight: root.rowPitch
                    labelSize: Appearance.font.size.normal
                    inlineDetail: true
                    icon: line.modelData.icon.name ?? (line.modelData.icon.glyph || line.modelData.icon.file ? "" : "chevron_right")
                    glyph: line.modelData.icon.glyph ?? ""
                    iconSource: line.modelData.icon.file ? Protocol.fileUrl(line.modelData.icon.file) : ""
                    label: line.modelData.title
                    detail: line.modelData.refusal || line.modelData.subtitle
                    selected: line.index === root.selected
                    onActivated: {
                        root.selected = line.index;
                        root.runItem(line.modelData);
                    }
                }
            }

            Repeater {
                id: fieldRepeater

                model: root.kind === "form" ? root.view.fields : []

                delegate: Column {
                    id: entry

                    required property var modelData
                    required property int index

                    readonly property var value: root.values[entry.modelData.key]
                    readonly property bool lacking: root.missing.includes(entry.modelData.key)
                    readonly property bool typing: entry.modelData.type === "text" || entry.modelData.type === "secret"

                    function takeFocus(): void {
                        if (entry.typing)
                            input.forceActiveFocus();
                        else
                            holder.forceActiveFocus();
                    }

                    function step(by: int): void {
                        const choices = entry.modelData.choices;
                        const at = choices.findIndex(c => c.value === entry.value);
                        root.setValue(entry.modelData.key, choices[(at + by + choices.length) % choices.length].value);
                    }

                    width: body.width
                    spacing: Appearance.padding.small

                    StyledText {
                        text: entry.lacking ? `${entry.modelData.title} · needed` : entry.modelData.title
                        font.pixelSize: Appearance.font.size.small
                        color: entry.lacking ? Appearance.colour.alarm : Appearance.colour.textFaint
                    }

                    Item {
                        id: holder

                        width: entry.width
                        height: Appearance.sizes.rowHeight
                        activeFocusOnTab: false

                        Keys.onPressed: event => {
                            if (entry.modelData.type === "toggle" && event.key === Qt.Key_Space) {
                                root.setValue(entry.modelData.key, !entry.value);
                                event.accepted = true;
                            } else if (entry.modelData.type === "choice" && (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Space)) {
                                entry.step(event.key === Qt.Key_Left ? -1 : 1);
                                event.accepted = true;
                            } else
                                root.fieldKey(event);
                        }

                        SquircleRect {
                            anchors.fill: parent
                            radius: Appearance.rounding.small
                            color: Appearance.colour.fill
                            stroke: (input.activeFocus || holder.activeFocus) ? Appearance.colour.accent : entry.lacking ? Appearance.colour.alarm : "transparent"
                            strokeWidth: Appearance.stroke.ring
                        }

                        TextInput {
                            id: input

                            visible: entry.typing
                            anchors.fill: parent
                            anchors.leftMargin: Appearance.padding.normal
                            anchors.rightMargin: Appearance.padding.normal
                            verticalAlignment: TextInput.AlignVCenter
                            text: entry.typing ? String(entry.value ?? "") : ""
                            echoMode: entry.modelData.type === "secret" ? TextInput.Password : TextInput.Normal
                            font.family: Appearance.font.family
                            font.pixelSize: Appearance.font.size.normal
                            color: Appearance.colour.text
                            selectionColor: Appearance.colour.accent
                            selectedTextColor: Appearance.colour.accentText
                            clip: true
                            onTextEdited: root.setValue(entry.modelData.key, text)
                            onActiveFocusChanged: if (activeFocus)
                                root.field = entry.index
                            Keys.onPressed: event => root.fieldKey(event)

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !input.text
                                text: entry.modelData.placeholder
                                font.pixelSize: Appearance.font.size.normal
                                color: Appearance.colour.textFaint
                            }
                        }

                        Toggle {
                            visible: entry.modelData.type === "toggle"
                            anchors.right: parent.right
                            anchors.rightMargin: Appearance.padding.normal
                            anchors.verticalCenter: parent.verticalCenter
                            checked: !!entry.value
                            onToggled: root.setValue(entry.modelData.key, !entry.value)
                        }

                        Segments {
                            visible: entry.modelData.type === "choice"
                            anchors.left: parent.left
                            anchors.leftMargin: Appearance.padding.small
                            anchors.verticalCenter: parent.verticalCenter
                            options: entry.modelData.choices.map(c => c.title)
                            current: Math.max(0, entry.modelData.choices.findIndex(c => c.value === entry.value))
                            onPicked: index => root.setValue(entry.modelData.key, entry.modelData.choices[index].value)
                        }
                    }
                }
            }
        }
    }

    Row {
        id: footer

        visible: root.footerHeight > 0
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Appearance.padding.normal
        x: Appearance.padding.normal
        spacing: Appearance.padding.small

        Button {
            id: submitButton

            visible: root.kind === "form"
            size: 0
            text: root.view?.submit ?? ""
            onClicked: root.submit()
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Space) {
                    root.submit();
                    event.accepted = true;
                } else
                    root.fieldKey(event);
            }
        }

        Repeater {
            model: root.actions

            delegate: Button {
                id: act

                required property var modelData
                required property int index

                size: 0
                icon: act.modelData.icon
                text: act.modelData.title
                checkable: true
                checked: act.index === root.actionAt
                onClicked: root.runAction(act.index)
                onToggled: root.runAction(act.index)
            }
        }
    }
}
