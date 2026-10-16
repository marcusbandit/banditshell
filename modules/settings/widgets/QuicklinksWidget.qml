pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "../../../services/quicklinks.js" as Quicklinks

Column {
    id: root

    property var row: ({})

    property int editing: -1

    readonly property int adding: -2

    readonly property var list: Config.values.launcher.typing.quicklinks ?? []
    readonly property var blank: ({
            name: "",
            keyword: "",
            url: "https://"
        })

    width: parent ? parent.width : 0

    function drop(at: int): void {
        const link = root.list[at];
        Config.set("launcher.typing.quicklinks", root.list.filter((l, i) => i !== at));
        root.editing = -1;
        SettingsView.drop(`${link.name} removed`, "link_off", {
            label: "undo",
            run: () => {
                const back = root.list.slice();
                back.splice(Math.min(at, back.length), 0, link);
                Config.set("launcher.typing.quicklinks", back);
            }
        });
    }

    component Editor: Column {
        id: form

        property var link: root.blank
        property int at: root.adding

        readonly property var draft: ({
                name: nameField.draft.trim(),
                keyword: Quicklinks.cleanKeyword(keyword.draft),
                url: address.draft.trim()
            })
        readonly property var clash: Quicklinks.keywordHolder(root.list, form.draft.keyword, form.at)
        readonly property string problem: form.clash ? `${form.draft.keyword} is ${form.clash.name}'s keyword` : Quicklinks.problem(form.draft)

        function save(): void {
            if (form.problem)
                return;
            Config.set("launcher.typing.quicklinks", Quicklinks.withLink(root.list, form.draft, form.at));
            SettingsView.drop(`${form.draft.name} saved`, "link", null);
            root.editing = -1;
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
                text: form.link.name
                placeholder: "name"
            }

            SettingsField {
                id: keyword

                width: (form.inner - Appearance.padding.small) * 0.4
                text: form.link.keyword
                placeholder: "keyword"
                mono: true
            }
        }

        SettingsField {
            id: address

            width: form.inner
            text: form.link.url
            placeholder: "https://example.com/search?q={query}"
            mono: true
        }

        Item {
            width: form.inner
            height: actions.height

            StyledText {
                anchors.left: parent.left
                anchors.right: actions.left
                anchors.rightMargin: Appearance.padding.normal
                anchors.verticalCenter: parent.verticalCenter
                text: form.problem || Quicklinks.resolve(form.draft.url, "cats")
                color: form.problem ? Appearance.colour.alarm : Appearance.colour.textFaint
                elide: Text.ElideMiddle
            }

            Row {
                id: actions

                anchors.right: parent.right
                spacing: Appearance.padding.small

                Button {
                    text: "Cancel"
                    style: "text"
                    size: 0
                    onClicked: root.editing = -1
                }

                Button {
                    text: "Save"
                    style: "filled"
                    size: 0
                    interactive: !form.problem
                    onClicked: form.save()
                }
            }
        }
    }

    Repeater {
        model: root.list

        delegate: Column {
            id: entry

            required property var modelData
            required property int index

            readonly property bool open: root.editing === entry.index

            width: root.width

            SettingsRowFrame {
                width: root.width
                icon: Quicklinks.takes(entry.modelData) ? "travel_explore" : "link"
                label: entry.modelData.name
                detail: `${Quicklinks.cleanKeyword(entry.modelData.keyword)} · ${Quicklinks.hostOf(entry.modelData.url)}`
                selected: entry.open
                onActivated: root.editing = entry.open ? -1 : entry.index
                onPointed: SettingsView.hovered = root.row

                SettingsTool {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "edit"
                    tip: entry.open ? "close" : "edit"
                    on: entry.open
                    onClicked: root.editing = entry.open ? -1 : entry.index
                }

                SettingsTool {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "close"
                    tip: "remove"
                    onClicked: root.drop(entry.index)
                }
            }

            Loader {
                active: entry.open
                visible: active
                width: root.width

                sourceComponent: Editor {
                    link: entry.modelData
                    at: entry.index
                }
            }
        }
    }

    SettingsRowFrame {
        width: root.width
        interactive: root.editing !== root.adding
        icon: "add_link"
        label: "Add a quicklink"
        selected: root.editing === root.adding
        onActivated: root.editing = root.adding
        onPointed: SettingsView.hovered = root.row
    }

    Loader {
        active: root.editing === root.adding
        visible: active
        width: root.width

        sourceComponent: Editor {}
    }
}
