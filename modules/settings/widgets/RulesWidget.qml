pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    readonly property var keys: Object.keys(Notifications.rules)
    readonly property var fields: [["pop", "popups"], ["snd", "sound"], ["lock", "lock screen"]]
    readonly property real column: 64
    property bool adding: false

    width: parent ? parent.width : 0

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
        model: root.keys

        delegate: SettingsRowFrame {
            id: rule

            required property string modelData

            readonly property var switches: Notifications.ruleAt(rule.modelData)

            width: root.width
            interactive: false
            label: Apps.nameFor(rule.modelData)
            onPointed: SettingsView.hovered = root.row
            lead: Component {
                AppMark {
                    spec: AppIcons.markFor(rule.modelData, "colour")
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
                            checked: rule.switches[modelData[0]]
                            onToggled: Notifications.setRule(rule.modelData, {
                                [modelData[0]]: !rule.switches[modelData[0]]
                            })
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
            onClicked: root.adding = !root.adding
        }
    }

    MenuLayer {
        width: root.width
        open: root.adding

        Column {
            id: candidates

            width: parent ? parent.width : 0

            Repeater {
                model: Notifications.candidates

                delegate: SettingsRowFrame {
                    id: pick

                    required property string modelData

                    width: candidates.width
                    label: Apps.nameFor(pick.modelData)
                    detail: "sent a notification"
                    onActivated: {
                        Notifications.setRule(pick.modelData, {});
                        root.adding = false;
                    }
                    lead: Component {
                        AppMark {
                            spec: AppIcons.markFor(pick.modelData, "colour")
                            color: Appearance.colour.textDim
                        }
                    }
                }
            }

            SettingsRowFrame {
                width: candidates.width
                visible: Notifications.candidates.length === 0
                interactive: false
                label: "No app has sent a notification yet"
            }
        }
    }
}
