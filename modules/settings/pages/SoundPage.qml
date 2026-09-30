pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Item {
    id: root

    implicitHeight: list.implicitHeight

    property string opened: ""

    function toggleLayer(role: string): void {
        root.opened = root.opened === role ? "" : role;
    }

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.huge

        SettingsCard {
            title: "Output"

            SettingsRow {
                icon: Audio.muted ? "no_sound" : Audio.deviceIcon(Audio.sink)
                label: Audio.sink ? Audio.deviceLabel(Audio.sink) : "No output device"
                detail: Audio.sink ? Audio.deviceTransport(Audio.sink) : ""
                interactive: !!Audio.sink
                onActivated: Audio.toggleMute()

                Toggle {
                    checked: !Audio.muted
                    onToggled: Audio.toggleMute()
                }
            }
        }

        SettingsCard {
            title: "Input"

            SettingsRow {
                icon: Audio.sourceMuted ? "mic_off" : Audio.deviceIcon(Audio.source)
                label: Audio.source ? Audio.deviceLabel(Audio.source) : "No input device"
                detail: Audio.source ? Audio.deviceTransport(Audio.source) : ""
                interactive: !!Audio.source
                onActivated: Audio.toggleSourceMute()

                Toggle {
                    checked: !Audio.sourceMuted
                    onToggled: Audio.toggleSourceMute()
                }
            }
        }

        SettingsCard {
            title: "Speakers and headphones"

            SettingsRow {
                icon: "speaker"
                label: "Speakers"
                value: Audio.speakers ? Audio.deviceLabel(Audio.speakers) : Audio.speakersName ? "not connected" : "not set"

                detail: Audio.speakers ? Audio.deviceTransport(Audio.speakers) : Audio.speakersName ? `assigned to ${Audio.speakersName}, which is not here right now` : "nothing assigned, so the toggle has nowhere to go"
                onActivated: root.toggleLayer("speakers")

                Expander {
                    open: root.opened === "speakers"
                    tip: "choose the speakers"
                    onToggled: root.toggleLayer("speakers")
                }
            }

            MenuLayer {
                width: parent.width
                open: root.opened === "speakers"

                Repeater {
                    model: Audio.sinks

                    delegate: SettingsRow {
                        id: speakerChoice

                        required property var modelData

                        icon: Audio.deviceIcon(speakerChoice.modelData)
                        label: Audio.deviceLabel(speakerChoice.modelData)

                        detail: speakerChoice.modelData.name
                        selected: Audio.speakersName === speakerChoice.modelData.name
                        onActivated: Config.set("audio.speakers", speakerChoice.modelData.name)
                    }
                }

                SettingsRow {
                    visible: !!Audio.speakersName
                    icon: "block"
                    label: "Nothing"
                    detail: "leave the role unset; the toggle says so rather than guessing"
                    onActivated: Config.set("audio.speakers", "")
                }
            }

            SettingsRow {
                icon: "headphones"
                label: "Headphones"
                value: Audio.headphones ? Audio.deviceLabel(Audio.headphones) : Audio.headphonesName ? "not connected" : "not set"
                detail: Audio.headphones ? Audio.deviceTransport(Audio.headphones) : Audio.headphonesName ? `assigned to ${Audio.headphonesName}, which is not here right now` : "nothing assigned, so the toggle has nowhere to go"
                onActivated: root.toggleLayer("headphones")

                Expander {
                    open: root.opened === "headphones"
                    tip: "choose the headphones"
                    onToggled: root.toggleLayer("headphones")
                }
            }

            MenuLayer {
                width: parent.width
                open: root.opened === "headphones"

                Repeater {
                    model: Audio.sinks

                    delegate: SettingsRow {
                        id: headphoneChoice

                        required property var modelData

                        icon: Audio.deviceIcon(headphoneChoice.modelData)
                        label: Audio.deviceLabel(headphoneChoice.modelData)
                        detail: headphoneChoice.modelData.name
                        selected: Audio.headphonesName === headphoneChoice.modelData.name
                        onActivated: Config.set("audio.headphones", headphoneChoice.modelData.name)
                    }
                }

                SettingsRow {
                    visible: !!Audio.headphonesName
                    icon: "block"
                    label: "Nothing"
                    detail: "leave the role unset; the toggle says so rather than guessing"
                    onActivated: Config.set("audio.headphones", "")
                }
            }

            SettingsRow {
                visible: Audio.rolesCollide
                icon: "warning"
                label: "Both roles are the same device"
                detail: "the toggle has nowhere to go, so the key will look like it does nothing"
                interactive: false
            }
        }

        SettingsGroup {
            heading: "Levels and apps"

            SquircleRect {
                width: parent.width
                height: menu.implicitHeight + Appearance.padding.small * 2
                radius: Appearance.rounding.normal
                color: Appearance.colour.fill

                Loader {
                    id: menu

                    x: Appearance.padding.small
                    y: Appearance.padding.small
                    width: parent.width - Appearance.padding.small * 2

                    source: Qt.resolvedUrl("../../menu/content/SoundMenu.qml")
                }
            }
        }
    }
}
