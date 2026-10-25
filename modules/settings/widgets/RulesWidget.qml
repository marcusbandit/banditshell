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
            readonly property bool muted: Notifications.mutedLabel(rule.modelData) !== ""
            readonly property double mutedEnd: Notifications.mutedEnd(rule.modelData)

            width: root.width
            interactive: false
            label: Apps.nameFor(rule.modelData)
            detail: !rule.muted ? "" : rule.mutedEnd > 0 ? `muted until ${Notifications.endsAt(rule.mutedEnd, Notifications.now)}` : "muted"
            detailColour: Appearance.colour.text
            detailLines: 2
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

                Button {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: rule.muted
                    size: 0
                    text: "Unmute"
                    onClicked: Notifications.endMute(rule.modelData)
                }

                Repeater {
                    model: root.fields

                    delegate: Item {
                        id: field

                        required property var modelData

                        readonly property bool held: rule.muted && modelData[0] !== "lock"

                        width: root.column
                        height: Appearance.sizes.toggleHeight

                        Toggle {
                            anchors.centerIn: parent
                            enabled: !field.held
                            opacity: field.held ? Appearance.opacity.disabled : 1
                            checked: !field.held && rule.switches[modelData[0]]
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
