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
    readonly property string detailText: String(Catalogue.val(root.row.detail, SettingsState) ?? "")
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
    readonly property bool flashing: !!SettingsView.flash && !!root.row.uid && SettingsView.flash.uid === root.row.uid

    width: parent ? parent.width : 0

    function set(next: var): void {
        SettingsState.set(root.key, next);
    }

    function toggleOpen(): void {
        SettingsView.setOpen(root.row.uid, !root.unrolled);
    }

    function activate(): void {
        if (root.off)
            return;
        if (root.kind === "toggle")
            root.set(!root.value);
        else if (root.kind === "choice" || root.hasLayer)
            root.toggleOpen();
        else if (root.kind === "text" || root.kind === "secret")
            controls.item?.take?.();
    }

    SettingsRowFrame {
        id: frame

        width: root.width
        icon: root.row.icon ?? ""
        label: Catalogue.labelOf(root.row)
        detail: root.detailText
        off: root.off
        flashing: root.flashing
        interactive: root.kind === "toggle" || root.kind === "choice" || root.hasLayer
        onActivated: root.activate()
        onPointed: SettingsView.hovered = root.row

        Loader {
            id: controls

            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: ({
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
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasLayer
            icon: "expand_more"
            turned: root.unrolled
            tip: root.unrolled ? "fold" : "more"
            onClicked: root.toggleOpen()
        }
    }

    MenuLayer {
        width: root.width
        open: root.hasLayer && root.unrolled
        visible: root.hasLayer && implicitHeight > 0.5

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
        width: root.width
        open: root.kind === "choice" && root.unrolled
        visible: root.kind === "choice" && implicitHeight > 0.5

        Repeater {
            model: root.kind === "choice" ? root.choices : []

            delegate: SettingsRowFrame {
                id: option

                required property var modelData

                readonly property bool chosen: Catalogue.same(option.modelData[0], root.value)

                icon: option.chosen ? "check" : "radio_button_unchecked"
                label: String(option.modelData[1])
                selected: option.chosen
                onActivated: {
                    SettingsView.setOpen(root.row.uid, false);
                    root.set(option.modelData[0]);
                }
            }
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

        Segments {
            options: root.choices.map(o => String(o[1]))
            current: Math.max(0, root.choices.findIndex(o => Catalogue.same(o[0], root.value)))
            enabled: !root.off
            onPicked: i => root.set(root.choices[i][0])
        }
    }

    Component {
        id: sliderControl

        SettingsSlider {
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
            enabled: !root.off
            onCommitted: t => root.set(t)
        }
    }

    Component {
        id: secretControl

        SettingsSecret {
            text: String(root.value ?? "")
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
