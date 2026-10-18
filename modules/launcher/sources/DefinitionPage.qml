pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property var entry: null

    readonly property var local: root.entry?.local ?? null
    readonly property var online: root.entry?.online ?? null
    readonly property string word: root.local?.word || root.entry?.word || ""
    readonly property string asked: root.local?.asked ?? ""
    readonly property int mostSenses: 8
    readonly property int mostOnline: 6

    readonly property var groups: (root.local?.groups ?? []).map(group => ({
                part: group.part,
                senses: group.senses.slice(0, root.mostSenses),
                hidden: Math.max(0, group.senses.length - root.mostSenses)
            }))

    readonly property var onlineSenses: (root.online?.senses ?? []).slice(0, root.mostOnline)

    readonly property string subtitle: {
        const bits = [];
        if (root.local?.phonetic)
            bits.push(root.local.phonetic);
        if (root.asked && root.asked.toLowerCase() !== root.word.toLowerCase())
            bits.push(`from ${root.asked}`);
        else if (root.local?.forms?.length)
            bits.push(root.local.forms.join(", "));
        return bits.join(" · ");
    }

    readonly property string onlineNote: root.entry?.onlineBusy ? "Looking it up" : root.entry?.onlineFailed ? "No entry" : ""

    readonly property real limit: Appearance.sizes.launcherWidth * 0.8 - Appearance.padding.small * 2

    function scrollPage(direction: int): bool {
        if (scroller.contentHeight <= scroller.height)
            return false;
        const step = scroller.height - Appearance.font.line.normal * 2;
        const to = Math.max(0, Math.min(scroller.contentHeight - scroller.height, scroller.contentY + direction * step));
        if (to === scroller.contentY)
            return false;
        scroller.contentY = to;
        return true;
    }

    onEntryChanged: if ((root.entry?.word ?? "") !== scroller.shownWord) {
        scroller.shownWord = root.entry?.word ?? "";
        scroller.contentY = 0;
    }

    width: Math.round(Appearance.sizes.launcherWidth * 0.55)
    implicitHeight: Math.min(root.limit, page.implicitHeight + Appearance.padding.card * 2)
    height: implicitHeight

    Flickable {
        id: scroller

        property string shownWord: ""

        anchors.fill: parent
        anchors.margins: Appearance.padding.card
        contentHeight: page.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        clip: true

        readonly property real fade: Appearance.font.line.normal * 1.5

        layer.enabled: scroller.interactive
        layer.effect: ShaderEffect {
            readonly property vector4d fades: Qt.vector4d(scroller.atYBeginning ? 0 : scroller.fade, scroller.atYEnd ? 0 : scroller.fade, height, 1)

            fragmentShader: Qt.resolvedUrl("../../../components/edgefade.frag.qsb")
        }

        Column {
            id: page

            width: scroller.width
            spacing: Appearance.padding.card

            Column {
                width: parent.width
                spacing: Appearance.padding.hair

                StyledText {
                    width: parent.width
                    text: root.word
                    font.pixelSize: Appearance.font.size.display
                    wrapMode: Text.Wrap
                }

                StyledText {
                    width: parent.width
                    visible: text !== ""
                    text: root.subtitle
                    color: Appearance.colour.textDim
                    wrapMode: Text.Wrap
                }
            }

            Repeater {
                model: root.groups

                delegate: Column {
                    id: group

                    required property var modelData

                    width: page.width
                    spacing: Appearance.padding.small

                    StyledText {
                        text: group.modelData.part
                        color: Appearance.colour.accent
                    }

                    Repeater {
                        model: group.modelData.senses

                        delegate: DefinitionSense {
                            required property var modelData
                            required property int index

                            width: group.width
                            number: index + 1
                            sense: modelData
                        }
                    }

                    StyledText {
                        visible: group.modelData.hidden > 0
                        text: group.modelData.hidden === 1 ? "1 more sense" : `${group.modelData.hidden} more senses`
                        color: Appearance.colour.textFaint
                    }
                }
            }

            Column {
                width: page.width
                spacing: Appearance.padding.small
                visible: root.onlineSenses.length > 0 || root.onlineNote !== ""

                Item {
                    width: parent.width
                    height: wiktionary.height

                    StyledText {
                        id: wiktionary

                        text: "Wiktionary"
                        color: Appearance.colour.accent
                    }

                    StyledText {
                        anchors.right: parent.right
                        text: root.onlineNote
                        color: Appearance.colour.textFaint
                    }
                }

                Repeater {
                    model: root.onlineSenses

                    delegate: DefinitionSense {
                        required property var modelData
                        required property int index

                        width: page.width
                        number: index + 1
                        sense: ({
                                text: modelData.text,
                                part: modelData.part,
                                examples: modelData.example ? [modelData.example] : []
                            })
                    }
                }
            }
        }
    }
}
