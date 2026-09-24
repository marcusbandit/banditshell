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
// THE CARD BETWEEN THEM AND THE MENU asks the other question, which is not
// what is playing but what a KEY should reach for. Speakers or headphones is a
// switch worth a bind and the shell cannot work out on its own which sink is
// which, so the pair is a setting and this page is where it is made. Its own
// comment, further down, has the argument.
//
// WHAT THE MENU NEEDED TO BE EMBEDDED: only a width. SoundMenu has no
// `showing`, because nothing in it costs anything while it is unread: every
// value is a binding onto PipeWire that Audio already holds for the bar.
Item {
    id: root

    implicitHeight: list.implicitHeight

    // WHICH DEVICE LIST IS UNROLLED, at most one of them. Two open at once is
    // the same list of sinks printed twice on one page, with the row that says
    // which is which scrolled off the top.
    property string opened: ""

    function toggleLayer(role: string): void {
        root.opened = root.opened === role ? "" : role;
    }

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

        // THE TWO DEVICES A KEY SWITCHES BETWEEN.
        //
        // `banditshell output toggle` is one bind and it has to be told which
        // sink is which, because nothing on a sink knows: the onboard chip
        // calls its speaker output a headphone jack and the interface calls its
        // headphone amp a line output, so the two devices wear each other's
        // names. The rows above say what is playing NOW; these two say what the
        // key will reach for.
        //
        // UNROLLED IN PLACE rather than led to on a page of its own, which is
        // FontPage's question asked of a much shorter list. A machine has three
        // or four sinks. A sub-page for four rows is a slide, a back arrow and
        // a title to say what a chevron and a fold say here without taking away
        // the row you are choosing for.
        SettingsCard {
            title: "Speakers and headphones"

            // THE ROLE'S OWN GLYPH, not the device's. A row that names the
            // speakers is about the role whether or not anything is assigned to
            // it, and Audio.deviceIcon answers a different question honestly
            // enough to put "headphones" on the speakers row, which is exactly
            // the confusion this pair exists to settle.
            SettingsRow {
                icon: "speaker"
                label: "Speakers"
                value: Audio.speakers ? Audio.deviceLabel(Audio.speakers) : Audio.speakersName ? "not connected" : "not set"

                // ASSIGNED-BUT-ABSENT IS NOT UNASSIGNED, and the two must not
                // read alike: one is a device in a drawer and the other is a
                // setting nobody has made. The name is printed for the first,
                // because seeing what it is waiting for is how you find out
                // that it is waiting for a typo.
                detail: Audio.speakers ? Audio.deviceTransport(Audio.speakers) : Audio.speakersName ? `assigned to ${Audio.speakersName}, which is not here right now` : "nothing assigned, so the toggle has nowhere to go"
                onActivated: root.toggleLayer("speakers")

                // The chevron is not a second control here, it is the same one
                // drawn where the eye looks for it: both it and the row open
                // the list. Its hover swap means nothing on this row and the
                // affordance is worth more than the purity.
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
                        // The node name under every one, because it is the
                        // string the CLI wants and this is the only place in
                        // the shell it is written down.
                        detail: speakerChoice.modelData.name
                        selected: Audio.speakersName === speakerChoice.modelData.name
                        onActivated: Config.set("audio.speakers", speakerChoice.modelData.name)
                    }
                }

                // The only way back out from inside the shell. The CLI can
                // write an empty name and a settings page that could not would
                // be a page where every assignment is permanent.
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

            // THE ONE WAY TO SET THIS UP WRONG AND SEE NOTHING WRONG. Both
            // names on one device leaves a toggle that succeeds every time and
            // never moves the sound, so the key reads as dead. Said here rather
            // than left for the CLI, because this page is where it happens.
            SettingsRow {
                visible: Audio.rolesCollide
                icon: "warning"
                label: "Both roles are the same device"
                detail: "the toggle has nowhere to go, so the key will look like it does nothing"
                interactive: false
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
