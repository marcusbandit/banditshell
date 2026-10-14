pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    readonly property var list: SettingsState.planned.rules ?? []
    readonly property var fields: [["pop", "popups"], ["snd", "sound"], ["lock", "lock screen"]]
    readonly property real column: 64
    property bool adding: false

    width: parent ? parent.width : 0

    function save(next: var): void {
        SettingsState.plan("rules", next);
    }

    Item {
        width: root.width
        height: Appearance.font.line.small + Appearance.padding.small

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.normal

            Repeater {
                model: ["pop", "sound", "lock"]

                delegate: StyledText {
                    required property string modelData

                    width: root.column
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Appearance.colour.textFaint
                }
            }
        }
    }

    Repeater {
        model: root.list

        delegate: SettingsRowFrame {
            id: rule

            required property var modelData
            required property int index

            width: root.width
            interactive: false
            label: rule.modelData.name
            onPointed: SettingsView.hovered = root.row
            lead: Component {
                AppMark {
                    spec: AppIcons.markFor(rule.modelData.id, "colour")
                    color: Appearance.colour.textDim
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Repeater {
                    model: root.fields

                    delegate: Item {
                        required property var modelData

                        width: root.column
                        height: Appearance.sizes.toggleHeight

                        Toggle {
                            anchors.centerIn: parent
                            checked: !!rule.modelData[modelData[0]]
                            onToggled: {
                                const next = root.list.slice();
                                const changed = Object.assign({}, rule.modelData);
                                changed[modelData[0]] = !changed[modelData[0]];
                                next[rule.index] = changed;
                                root.save(next);
                            }
                        }
                    }
                }
            }
        }
    }

    SettingsRowFrame {
        width: root.width
        interactive: false
        icon: "add"
        label: "Add an app"
        onPointed: SettingsView.hovered = root.row

        Button {
            anchors.verticalCenter: parent.verticalCenter
            size: 0
            text: "Add"
            onClicked: {
                root.adding = !root.adding;
                if (root.adding)
                    Qt.callLater(picker.take);
            }
        }
    }

    MenuLayer {
        width: root.width
        open: root.adding

        AppPicker {
            id: picker

            exclude: root.list.map(a => a.id)
            onPicked: entry => {
                root.save(root.list.concat([{
                        id: entry.id,
                        name: entry.name,
                        pop: true,
                        snd: false,
                        lock: false
                    }]));
                root.adding = false;
            }
        }
    }
}
