pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    property string editing: ""

    readonly property var list: Snippets.list
    readonly property var blank: ({
            id: "",
            name: "",
            keyword: "",
            text: ""
        })

    readonly property var placeholders: ["date", "time", "clipboard", "cursor"]

    width: parent ? parent.width : 0

    function drop(snippet: var): void {
        const at = root.list.findIndex(s => s?.id === snippet.id);
        Snippets.remove(snippet.id);
        if (root.editing === snippet.id)
            root.editing = "";
        SettingsView.drop(`${snippet.name || "snippet"} removed`, "short_text", {
            label: "undo",
            run: () => Snippets.restore(snippet, at)
        });
    }

    component Editor: Column {
        id: form

        property var snippet: root.blank

        readonly property var clash: Snippets.keywordHolder(keyword.draft, form.snippet.id)
        readonly property bool ready: nameField.draft.trim() !== "" && body.text !== "" && !form.clash

        function save(): void {
            if (!form.ready)
                return;
            Snippets.save({
                id: form.snippet.id,
                name: nameField.draft,
                keyword: keyword.draft,
                text: body.text
            });
            SettingsView.drop(`${nameField.draft.trim()} saved`, "short_text", null);
            root.editing = "";
        }

        width: root.width
        spacing: Appearance.padding.small
        topPadding: Appearance.padding.small
        bottomPadding: Appearance.padding.normal
        leftPadding: Appearance.padding.normal
        rightPadding: Appearance.padding.normal

        readonly property real inner: form.width - form.leftPadding - form.rightPadding

        Row {
            spacing: Appearance.padding.small

            SettingsField {
                id: nameField

                width: (form.inner - Appearance.padding.small) * 0.6
                text: form.snippet.name
                placeholder: "name"
            }

            SettingsField {
                id: keyword

                width: (form.inner - Appearance.padding.small) * 0.4
                text: form.snippet.keyword
                placeholder: "keyword"
                mono: true
            }
        }

        Item {
            id: box

            width: form.inner
            height: Math.max(Appearance.sizes.rowHeight * 2, body.contentHeight + Appearance.padding.normal * 2)

            SquircleRect {
                anchors.fill: parent
                radius: Appearance.rounding.small
                color: Appearance.colour.fillStrong
                stroke: body.activeFocus ? Appearance.colour.accent : "transparent"
                strokeWidth: body.activeFocus ? Appearance.stroke.ring : 0
            }

            TextEdit {
                id: body

                anchors.fill: parent
                anchors.margins: Appearance.padding.normal
                text: form.snippet.text
                wrapMode: TextEdit.Wrap
                font.family: Appearance.font.family
                font.pixelSize: Appearance.font.size.small
                renderType: Text.NativeRendering
                color: Appearance.colour.text
                selectionColor: Appearance.colour.accent
                selectedTextColor: Appearance.colour.accentText
                selectByMouse: true

                onActiveFocusChanged: {
                    if (activeFocus)
                        Prompts.request(box);
                    else
                        Prompts.release(box);
                }

                Keys.onEscapePressed: event => {
                    body.focus = false;
                    event.accepted = true;
                }

                StyledText {
                    visible: !body.text
                    text: "text to type"
                    color: Appearance.colour.textFaint
                }
            }

            Component.onDestruction: Prompts.release(box)
        }

        Flow {
            width: form.inner
            spacing: Appearance.padding.small

            Repeater {
                model: root.placeholders

                delegate: Button {
                    required property string modelData

                    text: modelData
                    style: "tonal"
                    size: 0
                    onClicked: {
                        body.insert(body.cursorPosition, `{${modelData}}`);
                        body.forceActiveFocus();
                    }
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
                visible: !!form.clash
                text: form.clash ? `${keyword.draft.trim()} is ${form.clash.name}'s keyword` : ""
                color: Appearance.colour.alarm
                elide: Text.ElideRight
            }

            Row {
                id: actions

                anchors.right: parent.right
                spacing: Appearance.padding.small

                Button {
                    text: "Cancel"
                    style: "text"
                    size: 0
                    onClicked: root.editing = ""
                }

                Button {
                    text: "Save"
                    style: "filled"
                    size: 0
                    interactive: form.ready
                    onClicked: form.save()
                }
            }
        }
    }

    SettingsRowFrame {
        width: root.width
        visible: root.list.length === 0 && root.editing !== "new"
        interactive: false
        icon: "short_text"
        label: "No snippets yet"
        onPointed: SettingsView.hovered = root.row
    }

    Repeater {
        model: ScriptModel {
            values: root.list.filter(s => !!s?.id)
            objectProp: "id"
        }

        delegate: Column {
            id: entry

            required property var modelData

            readonly property bool open: root.editing === entry.modelData.id
            readonly property string preview: Snippets.preview(entry.modelData)

            width: root.width

            SettingsRowFrame {
                width: root.width
                icon: "short_text"
                label: entry.modelData.name || entry.preview
                detail: entry.modelData.keyword ? `${entry.modelData.keyword} · ${entry.preview}` : entry.preview
                selected: entry.open
                onActivated: root.editing = entry.open ? "" : entry.modelData.id
                onPointed: SettingsView.hovered = root.row

                SettingsTool {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "edit"
                    tip: entry.open ? "close" : "edit"
                    on: entry.open
                    onClicked: root.editing = entry.open ? "" : entry.modelData.id
                }

                SettingsTool {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "close"
                    tip: "remove"
                    onClicked: root.drop(entry.modelData)
                }
            }

            Loader {
                active: entry.open
                visible: active
                width: root.width

                sourceComponent: Editor {
                    snippet: entry.modelData
                }
            }
        }
    }

    SettingsRowFrame {
        width: root.width
        interactive: root.editing !== "new"
        icon: "add"
        label: "Add a snippet"
        selected: root.editing === "new"
        onActivated: root.editing = "new"
        onPointed: SettingsView.hovered = root.row
    }

    Loader {
        active: root.editing === "new"
        visible: active
        width: root.width

        sourceComponent: Editor {}
    }
}
