pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import "../../../services/dictionary.js" as Words

Item {
    id: root

    property var entry: null

    readonly property var local: root.entry?.local ?? null
    readonly property var online: root.entry?.online ?? null
    readonly property string word: root.local?.word || root.entry?.word || ""
    readonly property string asked: root.local?.asked ?? ""
    readonly property int mostSenses: 8

    readonly property var senses: Words.sensesOf(root.local)
    readonly property var shownSenses: root.senses.slice(0, root.mostSenses)
    readonly property var onlineSenses: Words.onlineSensesOf(root.online).slice(0, root.mostSenses)

    readonly property string onlineNote: root.entry?.onlineBusy ? "Wiktionary · looking it up" : ""

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
            spacing: Appearance.padding.normal

            DefinitionHeading {
                width: page.width
                word: root.word
                phonetic: root.local?.phonetic ?? ""
                note: root.asked && root.asked.toLowerCase() !== root.word.toLowerCase() ? `from ${root.asked}` : ""
            }

            Repeater {
                model: root.shownSenses

                delegate: DefinitionSense {
                    required property var modelData

                    width: page.width
                    sense: modelData
                }
            }

            StyledText {
                visible: root.senses.length > root.mostSenses
                text: `${root.senses.length - root.mostSenses} more, press Enter for all`
                color: Appearance.colour.textFaint
            }

            Separator {
                width: page.width
                visible: root.local !== null
            }

            StyledText {
                visible: root.local !== null
                text: "Open English WordNet"
                color: Appearance.colour.textFaint
            }

            Separator {
                width: page.width
                visible: root.onlineSenses.length > 0 || root.onlineNote !== ""
            }

            StyledText {
                visible: root.onlineSenses.length > 0 || root.onlineNote !== ""
                text: root.onlineNote || "Wiktionary"
                color: Appearance.colour.textFaint
            }

            Repeater {
                model: root.onlineSenses

                delegate: DefinitionSense {
                    required property var modelData

                    width: page.width
                    sense: modelData
                }
            }
        }
    }
}
