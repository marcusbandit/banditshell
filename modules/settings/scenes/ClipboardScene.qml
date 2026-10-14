pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.modules.settings
import "../catalogue.js" as Catalogue

Item {
    id: root

    readonly property bool recording: SettingsState.v("clip")
    readonly property real pitch: Appearance.font.line.small + Appearance.padding.small * 2
    readonly property real stageHeight: Appearance.padding.card * 2 + 5 * root.pitch + 4 * Appearance.padding.small

    ListModel {
        id: entries
    }

    Component.onCompleted: {
        for (const text of Catalogue.CLIP_POOL.slice(0, 5))
            entries.append({
                text
            });
    }

    Timer {
        id: tick

        interval: 900
        running: root.recording && !SettingsView.reduceMotion && root.visible
        repeat: true
        onTriggered: {
            const showing = [];
            for (let i = 0; i < entries.count; i++)
                showing.push(entries.get(i).text);
            const pool = Catalogue.CLIP_POOL.filter(x => showing.indexOf(x) < 0);
            entries.insert(0, {
                text: pool[Math.floor(Math.random() * pool.length)]
            });
            if (entries.count > 5)
                entries.remove(entries.count - 1);
            tick.interval = 1100 + Math.random() * 700;
        }
    }

    ListView {
        id: list

        x: Appearance.padding.card
        y: Appearance.padding.card
        width: parent.width - Appearance.padding.card * 2
        height: parent.height - Appearance.padding.card * 2
        interactive: false
        spacing: Appearance.padding.small
        model: entries

        delegate: Item {
            id: entry

            required property string text
            required property int index

            width: list.width
            height: root.pitch

            SquircleRect {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Appearance.colour.fill

                SquircleRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Appearance.colour.accentFill
                    opacity: entry.index === 0 ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animation.slow
                        }
                    }
                }
            }

            StyledText {
                x: Appearance.padding.normal
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Appearance.padding.normal * 2
                text: entry.text
                elide: Text.ElideRight
                color: entry.index === 0 ? Appearance.colour.text : Appearance.colour.textDim
            }
        }

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 300
            }
        }

        displaced: Transition {
            NumberAnimation {
                property: "y"
                duration: 420
                easing.type: Easing.OutCubic
            }
        }

        remove: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: 120
            }
        }
    }

    SceneCaption {
        visible: !root.recording
        text: "not recording"
    }
}
