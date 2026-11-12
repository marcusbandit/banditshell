pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    property bool editing: false

    readonly property var shades: [["dim", "Soft"], ["mid", "Normal"], ["bright", "Strong"], ["alarm", "Alarm"]]

    width: parent ? parent.width : 0

    function close(): void {
        root.editing = false;
        ThemeEditor.cancel();
    }

    component Editor: Column {
        id: form

        readonly property real inner: form.width - form.leftPadding - form.rightPadding
        property var colours: ThemeEditor.current

        readonly property string problem: ThemeEditor.problem(nameField.draft, form.colours)

        function setShade(key: string, value: string): void {
            if (form.colours[key] === value)
                return;
            const next = Object.assign({}, form.colours);
            next[key] = value;
            form.colours = next;
        }

        onColoursChanged: ThemeEditor.preview(form.colours)

        width: root.width
        spacing: Appearance.padding.small
        topPadding: Appearance.padding.small
        bottomPadding: Appearance.padding.normal
        leftPadding: Appearance.padding.normal
        rightPadding: Appearance.padding.normal

        SettingsField {
            id: nameField

            width: form.inner
            placeholder: `name, a copy of ${Themes.activeName}`
        }

        Repeater {
            model: root.shades

            delegate: Row {
                id: shade

                required property var modelData

                spacing: Appearance.padding.small

                SquircleRect {
                    width: Appearance.sizes.rowHeight * 0.6
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    radius: Appearance.rounding.small
                    color: /^#[0-9a-fA-F]{6}$/.test(field.draft.trim()) ? field.draft.trim() : Appearance.colour.fillStrong
                }

                StyledText {
                    width: form.inner * 0.3
                    anchors.verticalCenter: parent.verticalCenter
                    text: shade.modelData[1]
                    color: Appearance.colour.textDim
                    elide: Text.ElideRight
                }

                SettingsField {
                    id: field

                    width: form.inner - Appearance.sizes.rowHeight * 0.6 - form.inner * 0.3 - Appearance.padding.small * 2
                    text: ThemeEditor.current[shade.modelData[0]]
                    mono: true
                    onDraftChanged: form.setShade(shade.modelData[0], field.draft.trim())
                }
            }
        }

        Item {
            width: form.inner
            height: actions.height

            StyledText {
                anchors.left: parent.left
                anchors.right: actions.left
                anchors.rightMargin: Appearance.padding.normal
                anchors.verticalCenter: parent.verticalCenter
                text: ThemeEditor.failure || (nameField.draft !== "" ? form.problem : "")
                color: Appearance.colour.alarm
                elide: Text.ElideRight
            }

            Row {
                id: actions

                anchors.right: parent.right
                spacing: Appearance.padding.small

                Button {
                    text: "Cancel"
                    style: "bare"
                    size: 0
                    onClicked: root.close()
                }

                Button {
                    text: ThemeEditor.saving ? "Saving" : "Save"
                    style: "accent"
                    size: 0
                    interactive: form.problem === "" && !ThemeEditor.saving
                    onClicked: {
                        ThemeEditor.save(nameField.draft, form.colours);
                        SettingsView.drop(`${nameField.draft.trim()} saved`, "palette", null);
                        root.editing = false;
                    }
                }
            }
        }

        Component.onDestruction: ThemeEditor.cancel()
    }

    SettingsRowFrame {
        width: root.width
        icon: "palette"
        label: "Make your own theme"
        detail: root.editing ? "changes show live" : `copies ${Themes.activeName}`
        selected: root.editing
        onActivated: root.editing ? root.close() : root.editing = true
        onPointed: SettingsView.hovered = root.row
    }

    Loader {
        active: root.editing
        visible: active
        width: root.width

        sourceComponent: Editor {}
    }
}
