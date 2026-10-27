pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import "../../../services/dictionary.js" as Words

Item {
    id: root

    property string typed: ""

    signal leave(var what)
    signal launch(var what)

    readonly property string word: String(root.typed ?? "").trim().toLowerCase().replace(/\s+/g, " ")

    readonly property var answer: root.word ? Dictionary.answers[root.word] : undefined
    readonly property var onlineAnswer: Dictionary.onlineEnabled && root.word ? Dictionary.online.answers[root.word] ?? null : null

    property var entry: null
    property var online: null

    onAnswerChanged: if ((root.answer?.entry ?? null) !== root.entry)
        root.entry = root.answer?.entry ?? null
    onOnlineAnswerChanged: if (root.onlineAnswer !== root.online)
        root.online = root.onlineAnswer

    readonly property bool onlineBusy: Dictionary.onlineEnabled && !!root.word && !root.online && Dictionary.online.failures[root.word] === undefined
    readonly property bool localBusy: Dictionary.pending(root.word, true)
    readonly property bool busy: root.localBusy || root.onlineBusy

    readonly property string title: root.entry?.word || root.word
    readonly property string note: {
        const asked = root.entry?.asked ?? "";
        if (asked && asked.toLowerCase() !== root.title.toLowerCase())
            return `from ${asked}`;
        return (root.entry?.forms ?? []).join(", ");
    }

    readonly property var groups: root.entry?.groups ?? []

    readonly property var onlineGroups: {
        const out = [];
        Words.onlineSensesOf(root.online).forEach(sense => {
            let group = out.find(g => g.part === sense.part);
            if (!group) {
                group = {
                    part: sense.part,
                    senses: []
                };
                out.push(group);
            }
            group.senses.push(sense);
        });
        return out;
    }

    readonly property string firstMeaning: root.groups[0]?.senses[0]?.text ?? root.onlineGroups[0]?.senses[0]?.text ?? ""

    readonly property string status: {
        if (!root.word || root.groups.length || root.onlineGroups.length)
            return "";
        if (root.busy)
            return `Looking up ${root.word}`;
        if (Dictionary.missing && Dictionary.state === "failed")
            return "The offline dictionary could not be downloaded. It tries again in a minute.";
        return `No definition for “${root.word}”`;
    }

    onWordChanged: {
        wheel.stop();
        scroller.contentY = 0;
        root.lookUp();
    }
    Component.onCompleted: {
        root.entry = root.answer?.entry ?? null;
        root.online = root.onlineAnswer;
        root.lookUp();
    }

    function lookUp(): void {
        if (!root.word)
            return;
        Dictionary.want(root.word, true);
        Dictionary.online.want(Dictionary.onlineEnabled ? root.word : "");
    }

    function copy(): void {
        const text = root.firstMeaning;
        root.leave(() => System.copyText(text));
    }

    function openWiktionary(): void {
        const url = Words.pageUrl(root.word);
        root.launch(() => Quickshell.execDetached(["xdg-open", url]));
    }

    function scrollBy(pixels: real): void {
        wheel.scrollTo(wheel.goal + pixels);
    }

    function claimKey(event: var): bool {
        const page = scroller.height - Appearance.font.line.normal * 2;
        switch (event.key) {
        case Qt.Key_Down:
            root.scrollBy(Appearance.font.line.normal * 3);
            return true;
        case Qt.Key_Up:
            root.scrollBy(-Appearance.font.line.normal * 3);
            return true;
        case Qt.Key_PageDown:
        case Qt.Key_Space:
            root.scrollBy(page);
            return true;
        case Qt.Key_PageUp:
            root.scrollBy(-page);
            return true;
        case Qt.Key_Home:
            wheel.scrollTo(0);
            return true;
        case Qt.Key_End:
            root.scrollBy(scroller.contentHeight);
            return true;
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (event.modifiers & Qt.ControlModifier || !root.firstMeaning && !root.busy)
                root.openWiktionary();
            else if (root.firstMeaning)
                root.copy();
            return true;
        }
        return false;
    }

    readonly property real footerHeight: Appearance.font.line.small + Appearance.padding.normal * 2

    implicitHeight: Math.max(Appearance.sizes.rowHeight * 6, scroller.contentHeight + root.footerHeight)

    Flickable {
        id: scroller

        width: root.width
        height: root.height - root.footerHeight
        contentHeight: page.implicitHeight + Appearance.padding.large
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        readonly property real fade: Appearance.font.line.normal * 1.5

        layer.enabled: scroller.contentHeight > scroller.height
        layer.effect: ShaderEffect {
            readonly property vector4d fades: Qt.vector4d(scroller.atYBeginning ? 0 : scroller.fade, scroller.atYEnd ? 0 : scroller.fade, height, 1)

            fragmentShader: Qt.resolvedUrl("../../../components/edgefade.frag.qsb")
        }

        WheelStep {
            id: wheel

            flick: scroller
        }

        Column {
            id: page

            x: Appearance.padding.normal
            y: Appearance.padding.small
            width: scroller.width - Appearance.padding.normal * 2
            spacing: Appearance.padding.large

            DefinitionHeading {
                width: page.width
                word: root.title
                phonetic: root.entry?.phonetic ?? ""
                note: root.note
            }

            StyledText {
                visible: text !== ""
                width: page.width
                text: root.status
                font.pixelSize: Appearance.font.size.normal
                color: Appearance.colour.textFaint
                wrapMode: Text.Wrap
            }

            Repeater {
                model: root.groups

                delegate: PartGroup {}
            }

            Column {
                width: page.width
                spacing: Appearance.padding.large
                visible: root.onlineGroups.length > 0

                Separator {
                    width: page.width
                }

                StyledText {
                    text: "Wiktionary"
                    font.pixelSize: Appearance.font.size.normal
                    font.bold: true
                    color: Appearance.colour.textDim
                }

                Repeater {
                    model: root.onlineGroups

                    delegate: PartGroup {}
                }
            }

            Separator {
                width: page.width
                visible: source.text !== ""
            }

            StyledText {
                id: source

                visible: text !== ""
                text: [root.entry ? "Open English WordNet" : "", root.online ? "Wiktionary" : "", root.onlineBusy && root.entry ? "looking on Wiktionary" : ""].filter(Boolean).join(" · ")
                color: Appearance.colour.textFaint
            }
        }
    }

    Separator {
        y: scroller.height
        width: root.width
    }

    Item {
        y: scroller.height + 1
        width: root.width
        height: root.footerHeight - 1

        Icon {
            id: book

            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            name: "menu_book"
            size: Appearance.font.size.normal
            color: Appearance.colour.accent
        }

        StyledText {
            anchors.left: book.right
            anchors.leftMargin: Appearance.padding.normal
            anchors.right: actions.left
            anchors.rightMargin: Appearance.padding.large
            anchors.verticalCenter: parent.verticalCenter
            text: Dictionary.building ? "Dictionary · getting the offline copy" : "Dictionary"
            elide: Text.ElideRight
            color: Appearance.colour.textFaint
        }

        Row {
            id: actions

            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.small
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.padding.normal

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.firstMeaning !== ""
                text: "Copy definition"
            }

            KeyCap {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.firstMeaning !== ""
                text: "↵"
            }

            Rule {
                visible: root.firstMeaning !== ""
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Wiktionary"
                color: Appearance.colour.textDim
            }

            KeyCap {
                anchors.verticalCenter: parent.verticalCenter
                text: root.firstMeaning || root.busy ? "Ctrl ↵" : "↵"
            }

            Rule {}

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Back"
                color: Appearance.colour.textDim
            }

            KeyCap {
                anchors.verticalCenter: parent.verticalCenter
                text: "Esc"
            }
        }
    }

    component PartGroup: Column {
        id: group

        required property var modelData

        width: page.width
        spacing: Appearance.padding.normal

        StyledText {
            visible: text !== ""
            text: group.modelData.part
            font.pixelSize: Appearance.font.size.normal
            font.italic: true
            color: Appearance.colour.accent
        }

        Repeater {
            model: group.modelData.senses

            delegate: Item {
                id: numbered

                required property var modelData
                required property int index

                readonly property real gutter: Appearance.font.size.normal * 2

                width: group.width
                height: sense.implicitHeight

                StyledText {
                    text: numbered.index + 1
                    font.pixelSize: Appearance.font.size.normal
                    color: Appearance.colour.textFaint
                }

                DefinitionSense {
                    id: sense

                    x: numbered.gutter
                    width: numbered.width - numbered.gutter
                    sense: Object.assign({}, numbered.modelData, {
                        part: ""
                    })
                    related: true
                }
            }
        }
    }

    component Rule: Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: Appearance.font.line.small
        color: Appearance.colour.separator
    }

    component KeyCap: Item {
        id: cap

        property string text: ""

        width: Math.max(height, capText.implicitWidth + Appearance.padding.normal * 2)
        height: capText.implicitHeight + Appearance.padding.hair * 2

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: Appearance.colour.fill
        }

        StyledText {
            id: capText

            anchors.centerIn: parent
            text: cap.text
            color: Appearance.colour.textDim
        }
    }
}
