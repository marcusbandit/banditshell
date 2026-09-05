pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.settings

// SOUND: the sound menu, with room to breathe.
//
// The menu already carries the levels, the apps and the device lists, so the
// card above it is deliberately one row per direction and no more: WHICH
// device is current, said as a sentence. The menu answers that too, but with a
// glyph on the master level and a tick down a list you have to scroll to, and
// the first line of a settings page should not need decoding. The mute switch
// rides on the same row because "am I muted" is the other half of the same
// question; the menu's mute is the glyph itself, which is fine to press and
// not fine to read.
//
// WHAT THE MENU NEEDED TO BE EMBEDDED: only a width. SoundMenu has no
// `showing`, because nothing in it costs anything while it is unread: every
// value is a binding onto PipeWire that Audio already holds for the bar.
Item {
    id: root

    implicitHeight: list.implicitHeight

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.large

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

        Column {
            width: parent.width
            spacing: Appearance.padding.small

            StyledText {
                text: "Levels and apps"
                color: Appearance.colour.textFaint
                leftPadding: Appearance.padding.small
            }

            G2Rect {
                width: parent.width
                height: menu.implicitHeight + Appearance.padding.small * 2
                radius: Appearance.rounding.normal
                color: Appearance.colour.fill

                // BY FILE, the way MenuPanel loads it: modules/menu/content is a
                // folder of pages the panel picks by name, not a module.
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
