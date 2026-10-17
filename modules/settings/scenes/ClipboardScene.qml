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

    property bool populated: false

    ListModel {
        id: entries
    }

    Timer {
        running: true
        interval: 100
        onTriggered: root.populated = true
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
        running: root.recording && !SettingsView.reduceMotion && !Appearance.lessMotion && root.visible
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

            property bool leaving: false
            property real lastY: NaN

            width: list.width
            height: root.pitch
            opacity: fade.value

            ListView.delayRemove: entry.leaving
            ListView.onRemove: {
                entry.leaving = true;
                fade.target = 0;
            }

            onYChanged: {
                if (!isNaN(entry.lastY))
                    slide.value -= entry.y - entry.lastY;
                entry.lastY = entry.y;
            }

            Follow {
                id: fade

                target: 1
                speed: entry.leaving ? Appearance.animation.snapSpeed : Appearance.animation.settleSpeed
                epsilon: Appearance.animation.fadeEpsilon
                startsAtTarget: !root.populated
                onSettledChanged: if (settled && entry.leaving)
                    entry.leaving = false
            }

            Follow {
                id: slide

                target: 0
                speed: Appearance.animation.settleSpeed
            }

            Item {
                width: parent.width
                height: parent.height
                y: slide.value

                SquircleRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Appearance.colour.fill

                    SquircleRect {
                        anchors.fill: parent
                        radius: Appearance.rounding.normal
                        color: Appearance.colour.accentFill
                        opacity: lead.value

                        Follow {
                            id: lead

                            target: entry.index === 0 ? 1 : 0
                            speed: Appearance.animation.settleSpeed
                            epsilon: Appearance.animation.fadeEpsilon
                            startsAtTarget: true
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
        }
    }

    SceneCaption {
        visible: !root.recording
        text: "not recording"
    }
}
