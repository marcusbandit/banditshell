pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import "catalogue.js" as Catalogue

Column {
    id: root

    property var row: ({})

    readonly property string key: root.row.k ?? ""
    readonly property string kind: root.row.kind ?? ""
    readonly property var value: root.key ? SettingsState.v(root.key) : undefined
    readonly property bool off: !!root.row.dis && !!root.row.dis(SettingsState)
    readonly property bool bad: !!root.row.bad && !!root.row.bad(SettingsState)
    readonly property string stateText: String(Catalogue.val(root.row.state, SettingsState) ?? "")
    readonly property string pendingText: String(Catalogue.val(root.row.pending, SettingsState) ?? "")
    readonly property var offer: Catalogue.val(root.row.offer, SettingsState) ?? null
    readonly property var heldText: Catalogue.val(root.row.held, SettingsState) ?? null
    readonly property bool held: root.heldText !== null
    readonly property bool typing: root.kind === "text" && (controls.item?.editing ?? false)
    readonly property var combos: root.row.keys ? SettingsKeys.combosFor(root.row.keys) : []
    readonly property bool hasLayer: !!root.row.layer
    readonly property bool unrolled: SettingsView.isOpen(root.row.uid ?? "")
    readonly property var choices: {
        if (root.kind !== "choice" && root.kind !== "seg")
            return [];
        const list = Catalogue.options(root.row, SettingsState);
        if (root.value !== undefined && root.value !== "" && !list.some(o => Catalogue.same(o[0], root.value)))
            list.push([root.value, String(root.value)]);
        return list;
    }
    readonly property bool resettable: !!root.key && SettingsState.resettable(root.key)
    readonly property var fallback: root.resettable ? SettingsState.defaultOf(root.key) : undefined
    readonly property bool changed: !root.off && !root.held && Catalogue.changed(root.value, root.fallback)
    readonly property string fallbackText: root.resettable ? String(Catalogue.show(root.row, root.fallback, SettingsState)) : ""
    readonly property real besideControls: {
        const parts = [root.combos.length > 0 ? shortcut.width : -1, root.row.extra ? extra.width : -1, root.hasLayer ? more.width : -1].filter(w => w >= 0);
        return parts.reduce((a, b) => a + b + Appearance.padding.normal, 0);
    }
    readonly property bool slotted: !!Catalogue.PAGE_BY_ID[root.row.page]?.resets
    readonly property real slotRoom: root.slotted ? resetSlot.width + Appearance.padding.normal : 0
    readonly property real afterControls: (root.row.extra ? extra.width + Appearance.padding.normal : 0) + (root.hasLayer ? more.width + Appearance.padding.normal : 0)
    readonly property string groupKey: root.row.group?.rows?.[0]?.uid ?? ""
    property real segNatural: 0
    property real segCompact: 0
    readonly property real lineRoom: frame.inner - root.besideControls - root.slotRoom
    readonly property real inlineRoom: root.lineRoom - frame.leadWidth - frame.need - frame.gapX
    readonly property bool segFit: root.segNatural > root.inlineRoom && (root.segCompact <= root.inlineRoom || root.segNatural > root.lineRoom)
    readonly property bool cramped: root.kind === "seg" && root.segCompact > root.lineRoom
    readonly property string shape: root.held ? "held" : root.cramped ? "choice" : root.kind
    readonly property bool flashing: !!SettingsView.flash && !!root.row.uid && SettingsView.flash.uid === root.row.uid

    width: parent ? parent.width : 0

    onCrampedChanged: if (!root.cramped && root.unrolled)
        SettingsView.setOpen(root.row.uid, false)

    function noteTail(width: real): void {
        SettingsView.noteTail(root.row.uid ?? "", root.groupKey, width < 0 ? -1 : width + root.afterControls);
    }

    function set(next: var): void {
        SettingsState.set(root.key, next);
    }

    function toggleOpen(): void {
        SettingsView.setOpen(root.row.uid, !root.unrolled);
    }

    function activate(): void {
        if (root.off || root.held)
            return;
        if (root.kind === "toggle")
            root.set(!root.value);
        else if (root.shape === "choice" || root.hasLayer)
            root.toggleOpen();
        else if (root.kind === "text" || root.kind === "secret")
            controls.item?.take?.();
    }

    SettingsRowFrame {
        id: frame

        width: root.width
        icon: root.row.icon ?? ""
        label: Catalogue.labelOf(root.row)
        detail: root.stateText
        detailColour: root.bad ? Appearance.colour.alarm : Appearance.colour.textFaint
        detailLines: root.bad ? 3 : root.row.lines ?? 1
        pending: root.pendingText
        off: root.off
        flashStamp: root.flashing ? SettingsView.flash.at : 0
        interactive: !root.held && (root.kind === "toggle" || root.shape === "choice" || root.hasLayer)
        onActivated: root.activate()
        onPointed: SettingsView.hovered = root.row

        Row {
            id: shortcut

            anchors.verticalCenter: parent.verticalCenter
            visible: root.combos.length > 0
            spacing: Appearance.padding.small

            Repeater {
                model: root.combos

                delegate: Row {
                    id: alternative

                    required property string modelData
                    required property int index

                    spacing: Appearance.padding.small

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: alternative.index > 0
                        text: "or"
                        color: Appearance.colour.textFaint
                    }

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: hintText.implicitWidth + Appearance.padding.normal
                        height: hintText.implicitHeight + Appearance.padding.small

                        SquircleRect {
                            anchors.fill: parent
                            radius: Appearance.rounding.small
                            color: "transparent"
                            stroke: Appearance.colour.separator
                            strokeWidth: 1
                        }

                        StyledText {
                            id: hintText

                            anchors.centerIn: parent
                            text: SettingsKeys.hint(alternative.modelData)
                            color: Appearance.colour.textDim
                        }
                    }
                }
            }
        }

        Loader {
            id: controls

            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: root.held ? heldControl : ({
                    toggle: toggleControl,
                    seg: segControl,
                    slider: sliderControl,
                    step: stepControl,
                    choice: choiceControl,
                    text: textControl,
                    secret: secretControl,
                    path: pathControl,
                    button: buttonControl
                })[root.kind] ?? null
        }

        SettingsTool {
            id: extra

            anchors.verticalCenter: parent.verticalCenter
            visible: !!root.row.extra
            icon: root.row.extra?.icon ?? ""
            tip: root.row.extra?.tip ?? ""
            onClicked: SettingsActions.run(root.row.extra.act, root.row, extra)
        }

        SettingsTool {
            id: more

            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasLayer
            icon: "expand_more"
            turned: root.unrolled
            tip: root.unrolled ? "fold" : "more"
            onClicked: root.toggleOpen()
        }

        Item {
            id: resetSlot

            anchors.verticalCenter: parent.verticalCenter
            visible: root.slotted
            width: reset.implicitWidth
            height: 1

            SettingsTool {
                id: reset

                anchors.centerIn: parent
                visible: root.resettable && !root.held && (root.changed || shown.value > 0)
                enabled: root.changed
                opacity: shown.value
                icon: "restart_alt"
                tip: `reset to default, ${root.fallbackText || "empty"}`
                onClicked: {
                    frame.pulse();
                    SettingsState.reset(root.key);
                }

                Follow {
                    id: shown

                    target: root.changed ? 1 : 0
                    speed: Appearance.animation.revealSpeed
                    epsilon: Appearance.animation.fadeEpsilon
                    startsAtTarget: true
                }
            }
        }
    }

    Item {
        parent: frame
        x: (controls.parent?.x ?? 0) + controls.x
        y: frame.height - Appearance.padding.small
        width: controls.width
        height: 0
        visible: places.active
        z: 1

        Loader {
            id: places

            readonly property int count: places.item?.shown.length ?? 0

            width: parent.width
            active: !!root.row.places

            sourceComponent: SettingsPlaces {
                width: places.width
                active: root.typing
                query: root.typing ? controls.item.draft : ""
                saved: String(root.value ?? "")
                uid: root.row.uid ?? ""
                onPicked: text => controls.item.choose(text)
            }
        }
    }

    Flow {
        width: root.width
        visible: !!root.offer && !root.off && !(places.item?.wanted ?? false)
        leftPadding: frame.padX + frame.leadWidth
        rightPadding: frame.padX
        bottomPadding: Appearance.padding.small
        spacing: Appearance.padding.normal

        StyledText {
            width: Math.min(implicitWidth, parent.width - parent.leftPadding - parent.rightPadding)
            height: Math.max(implicitHeight, Appearance.button.height(0))
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
            text: root.offer?.text ?? ""
            color: root.offer?.alarm ? Appearance.colour.alarm : Appearance.colour.text
        }

        Repeater {
            model: root.offer?.buttons ?? []

            delegate: Button {
                required property var modelData

                size: 0
                text: modelData[0]
                onClicked: root.set(modelData[1])
            }
        }
    }

    MenuLayer {
        width: root.width
        open: root.hasLayer && root.unrolled

        Repeater {
            model: root.hasLayer ? root.row.layer : []

            delegate: Loader {
                id: cell

                required property var modelData

                width: root.width - Appearance.padding.large
                source: Qt.resolvedUrl("SettingsCell.qml")
                onLoaded: item.row = Qt.binding(() => cell.modelData)
            }
        }
    }

    MenuLayer {
        id: choiceLayer

        width: root.width
        open: root.shape === "choice" && root.unrolled

        Repeater {
            model: root.shape === "choice" && (root.unrolled || choiceLayer.visible) ? root.choices : []

            delegate: SettingsRowFrame {
                id: option

                required property var modelData

                readonly property bool chosen: Catalogue.same(option.modelData[0], root.value)

                width: parent ? parent.width : 0
                icon: option.chosen ? "check" : "radio_button_unchecked"
                label: String(option.modelData[1])
                selected: option.chosen
                lead: root.row.swatches ? swatch : null
                off: (Catalogue.val(root.row.unavailable, SettingsState) ?? []).some(u => Catalogue.same(u, option.modelData[0]))
                Component {
                    id: swatch

                    Row {
                        spacing: Appearance.padding.small

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: option.chosen ? "check" : "radio_button_unchecked"
                            color: option.iconColour
                        }

                        SquircleRect {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            radius: 6
                            color: Appearance.roleColour(String(option.modelData[0]))
                        }
                    }
                }

                onActivated: {
                    SettingsView.setOpen(root.row.uid, false);
                    root.set(option.modelData[0]);
                }
            }
        }
    }

    Component {
        id: heldControl

        StyledText {
            text: String(root.heldText)
            color: Appearance.colour.textDim
        }
    }

    Component {
        id: toggleControl

        Toggle {
            checked: !!root.value
            enabled: !root.off
            onToggled: root.set(!root.value)
        }
    }

    Component {
        id: segControl

        Item {
            implicitWidth: root.cramped ? asChoice.implicitWidth : segments.implicitWidth
            implicitHeight: root.cramped ? asChoice.implicitHeight : segments.implicitHeight

            Segments {
                id: segments

                visible: !root.cramped
                options: root.choices.map(o => String(o[1]))
                swatches: root.row.swatches ? root.choices.map(o => Appearance.roleColour(String(o[0]))) : []
                current: Math.max(0, root.choices.findIndex(o => Catalogue.same(o[0], root.value)))
                enabled: !root.off
                onPicked: i => root.set(root.choices[i][0])
                fit: root.segFit
                onNaturalChanged: root.segNatural = natural
                onCompactChanged: root.segCompact = compact
                Component.onCompleted: {
                    root.segNatural = natural;
                    root.segCompact = compact;
                }
            }

            Loader {
                id: asChoice

                anchors.verticalCenter: parent.verticalCenter
                active: root.cramped
                sourceComponent: choiceControl
            }
        }
    }

    Component {
        id: sliderControl

        SettingsSlider {
            id: slider

            tailWidth: (SettingsView.tailColumns[root.groupKey] ?? 0) - root.afterControls
            room: root.lineRoom
            onTailChanged: root.noteTail(slider.tail)
            Component.onCompleted: root.noteTail(slider.tail)
            Component.onDestruction: root.noteTail(-1)
            value: Number(root.value ?? 0)
            from: root.row.min
            to: root.row.max
            step: root.row.step ?? 1
            ends: root.row.ends ?? []
            text: Catalogue.format(root.row, Number(root.value ?? 0), SettingsState)
            enabled: !root.off
            onMoved: v => root.set(v)
        }
    }

    Component {
        id: stepControl

        SettingsStepper {
            value: Number(root.value ?? 0)
            from: root.row.min
            to: root.row.max
            step: root.row.step ?? 1
            text: Catalogue.format(root.row, Number(root.value ?? 0), SettingsState)
            enabled: !root.off
            onMoved: v => root.set(v)
        }
    }

    Component {
        id: choiceControl

        Row {
            spacing: Appearance.padding.normal

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(220, implicitWidth)
                text: String(Catalogue.optionLabel(root.row, SettingsState, root.value) ?? "")
                color: Appearance.colour.textDim
                elide: Text.ElideRight
            }

            SettingsTool {
                anchors.verticalCenter: parent.verticalCenter
                icon: "expand_more"
                turned: root.unrolled
                tip: root.unrolled ? "fold" : "choose"
                enabled: !root.off
                onClicked: root.toggleOpen()
            }
        }
    }

    Component {
        id: textControl

        SettingsField {
            text: String(root.value ?? "")
            placeholder: root.row.placeholder ?? ""
            mono: !!root.row.mono
            alarm: root.bad
            enabled: !root.off
            steps: places.count > 0
            pick: places.item?.chosen ?? ""
            onStepped: by => places.item.step(by)
            onCommitted: t => root.set(t)
        }
    }

    Component {
        id: secretControl

        SettingsSecret {
            text: String(root.value ?? "")
            alarm: root.bad
            enabled: !root.off
            onEdited: t => root.set(t)
        }
    }

    Component {
        id: pathControl

        SettingsPathEdit {
            path: String(root.value ?? "")
            readOnly: !!root.row.ro
            onCommitted: p => root.set(p)
        }
    }

    Component {
        id: buttonControl

        Button {
            size: 0
            text: String(Catalogue.val(root.row.btn, SettingsState) ?? "")
            interactive: !root.off
            onClicked: SettingsActions.run(root.row.act, root.row, root)
        }
    }
}
