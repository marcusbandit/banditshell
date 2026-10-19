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

    signal retype(string text)
    signal leave(var what)
    signal launch(var what)

    readonly property string icon: "menu_book"
    readonly property string prompt: "Look up a word"

    readonly property string word: Words.cleanWord(root.typed)

    readonly property var answer: root.word ? Dictionary.answers[root.word] : undefined
    readonly property var entry: root.answer?.entry ?? null
    readonly property var online: Dictionary.onlineEnabled && root.word ? Dictionary.online.answers[root.word] ?? null : null
    readonly property bool onlineBusy: Dictionary.onlineEnabled && !!root.word && !root.online && Dictionary.online.failures[root.word] === undefined
    readonly property bool localBusy: !!root.word && root.answer === undefined && (Dictionary.ready || Dictionary.building || Dictionary.state === "starting")
    readonly property bool busy: root.localBusy || root.onlineBusy

    readonly property string headword: root.entry?.word || root.online?.word || root.word
    readonly property string asked: root.entry?.asked && root.entry.asked.toLowerCase() !== root.entry.word.toLowerCase() ? root.entry.asked : ""

    onWordChanged: root.lookUp()
    Component.onCompleted: root.lookUp()

    function lookUp(): void {
        Dictionary.want(root.word, true);
        Dictionary.online.want(Dictionary.onlineEnabled ? root.word : "");
    }

    readonly property var items: {
        const out = [];
        const section = (key, title, list) => {
            if (!list.length)
                return;
            out.push({
                header: true,
                key: `header:${key}`,
                title: title,
                count: list.length
            });
            list.forEach(it => out.push(it));
        };
        const senses = Words.sensesOf(root.entry);
        const asSense = source => (sense, i) => Object.assign({
                key: `${source}:${i}`,
                kind: "sense",
                label: sense.text,
                source: source
            }, sense);
        section("definitions", "Definitions", senses.map(asSense("Open English WordNet")));
        const asWord = (word, i) => ({
                key: `word:${i}:${word}`,
                kind: "word",
                label: word,
                word: word
            });
        section("synonyms", "Synonyms", Words.unique(senses.reduce((all, s) => all.concat(s.synonyms), []), root.headword).map(asWord));
        section("antonyms", "Antonyms", Words.unique(senses.reduce((all, s) => all.concat(s.antonyms), []), root.headword).map(asWord));
        section("wiktionary", "Wiktionary", Words.onlineSensesOf(root.online).map(asSense("Wiktionary")));
        return out;
    }

    property int selected: -1
    property string listedWord: ""

    function firstPickable(from: int, step: int): int {
        for (let i = from; i >= 0 && i < root.items.length; i += step)
            if (!root.items[i].header)
                return i;
        return -1;
    }

    onItemsChanged: {
        const kept = root.items[root.selected];
        if (root.word !== root.listedWord || !kept || kept.header) {
            root.listedWord = root.word;
            root.selected = root.firstPickable(0, 1);
            list.positionViewAtBeginning();
        }
    }

    readonly property var current: root.items[root.selected] ?? null

    readonly property string peekWord: root.current?.kind === "word" ? root.current.word.toLowerCase() : ""
    onPeekWordChanged: if (root.peekWord)
        Dictionary.want(root.peekWord, false)
    readonly property var peekEntry: root.peekWord ? Dictionary.answers[root.peekWord]?.entry ?? null : null

    readonly property var detail: {
        const item = root.current;
        if (!item)
            return null;
        if (item.kind === "word")
            return {
                word: root.peekEntry?.word ?? item.word,
                phonetic: root.peekEntry?.phonetic ?? "",
                note: "",
                senses: Words.sensesOf(root.peekEntry).slice(0, 8),
                related: false,
                source: root.peekEntry ? "Open English WordNet" : ""
            };
        return {
            word: root.headword,
            phonetic: item.source === "Wiktionary" ? "" : root.entry?.phonetic ?? "",
            note: root.asked ? `from ${root.asked}` : "",
            senses: [item],
            related: true,
            source: item.source
        };
    }

    readonly property string actionLabel: !root.current ? (root.word && !root.busy ? "Search Wiktionary" : "") : root.current.kind === "word" ? `Look up ${root.current.word}` : "Copy definition"

    function move(step: int): void {
        const next = root.firstPickable(root.selected + step, step);
        const at = next >= 0 ? next : root.firstPickable(step > 0 ? 0 : root.items.length - 1, step);
        if (at < 0)
            return;
        root.selected = at;
        list.positionViewAtIndex(at, ListView.Contain);
        if (step < 0 && root.items[at - 1]?.header)
            list.positionViewAtIndex(at - 1, ListView.Contain);
    }

    function activate(): void {
        const item = root.current;
        if (!item) {
            if (root.word && !root.busy)
                root.launch(() => Quickshell.execDetached(["xdg-open", Words.pageUrl(root.word)]));
            return;
        }
        if (item.kind === "word") {
            root.retype(item.word);
            return;
        }
        const text = item.text;
        root.leave(() => System.copyText(text));
    }

    function scrollDetail(direction: int): void {
        const step = detailScroll.height - Appearance.font.line.normal * 2;
        detailScroll.contentY = Math.max(0, Math.min(detailScroll.contentHeight - detailScroll.height, detailScroll.contentY + direction * step));
    }

    function claimKey(event: var): bool {
        switch (event.key) {
        case Qt.Key_Down:
        case Qt.Key_Tab:
            root.move(1);
            return true;
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            root.move(-1);
            return true;
        case Qt.Key_PageDown:
            root.scrollDetail(1);
            return true;
        case Qt.Key_PageUp:
            root.scrollDetail(-1);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.activate();
            return true;
        }
        return false;
    }

    readonly property real listWidth: Math.round(root.width * 0.4)
    readonly property real footerHeight: Appearance.font.line.small + Appearance.padding.normal * 2

    implicitHeight: Appearance.sizes.rowHeight * 11

    ListView {
        id: list

        width: root.listWidth
        height: root.height - root.footerHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.items

        delegate: Item {
            id: line

            required property var modelData
            required property int index

            readonly property bool chosen: line.index === root.selected

            width: list.width - Appearance.padding.normal
            height: line.modelData.header ? Appearance.font.line.small + Appearance.padding.normal + Appearance.padding.small : Appearance.sizes.rowHeight

            Row {
                visible: !!line.modelData.header
                anchors.left: parent.left
                anchors.leftMargin: Appearance.padding.normal
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.padding.small / 2
                spacing: Appearance.padding.normal

                StyledText {
                    text: line.modelData.title ?? ""
                    color: Appearance.colour.textDim
                }

                StyledText {
                    text: line.modelData.count ?? ""
                    color: Appearance.colour.textFaint
                }
            }

            SquircleRect {
                visible: !line.modelData.header
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Appearance.colour.fill
                opacity: line.chosen ? 1 : hover.hovered ? 0.5 : 0
            }

            StyledText {
                visible: !line.modelData.header
                anchors.left: parent.left
                anchors.leftMargin: Appearance.padding.normal
                anchors.right: parent.right
                anchors.rightMargin: Appearance.padding.normal
                anchors.verticalCenter: parent.verticalCenter
                text: line.modelData.label ?? ""
                font.pixelSize: Appearance.font.size.normal
                elide: Text.ElideRight
            }

            HoverHandler {
                id: hover

                enabled: !line.modelData.header
            }

            TapHandler {
                enabled: !line.modelData.header
                onTapped: root.selected = line.index
                onDoubleTapped: {
                    root.selected = line.index;
                    root.activate();
                }
            }
        }

        StyledText {
            visible: root.items.length === 0
            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.normal
            y: Appearance.padding.normal
            width: list.width - Appearance.padding.normal * 2
            text: !root.word ? "Type a word" : root.busy ? `Looking up ${root.word}` : `No definition for “${root.word}”`
            font.pixelSize: Appearance.font.size.normal
            color: Appearance.colour.textFaint
            wrapMode: Text.Wrap
        }
    }

    Rectangle {
        x: root.listWidth
        width: 1
        height: list.height
        color: Appearance.colour.separator
    }

    Flickable {
        id: detailScroll

        x: root.listWidth + Appearance.padding.large
        width: root.width - x
        height: list.height
        contentHeight: detailPage.implicitHeight + Appearance.padding.normal
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: detailPage

            y: Appearance.padding.small
            width: detailScroll.width
            spacing: Appearance.padding.normal
            visible: root.detail !== null

            DefinitionHeading {
                width: detailPage.width
                word: root.detail?.word ?? ""
                phonetic: root.detail?.phonetic ?? ""
                note: root.detail?.note ?? ""
            }

            Repeater {
                model: root.detail?.senses ?? []

                delegate: DefinitionSense {
                    required property var modelData

                    width: detailPage.width
                    sense: modelData
                    related: root.detail?.related ?? false
                }
            }

            Separator {
                width: detailPage.width
                visible: (root.detail?.source ?? "") !== ""
            }

            StyledText {
                visible: text !== ""
                text: root.detail?.source ?? ""
                color: Appearance.colour.textFaint
            }
        }

        Connections {
            target: root

            function onCurrentChanged(): void {
                detailScroll.contentY = 0;
            }
        }
    }

    Separator {
        y: list.height
        width: root.width
    }

    Item {
        y: list.height + 1
        width: root.width
        height: root.footerHeight - 1

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.padding.normal

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "menu_book"
                size: Appearance.font.size.normal
                color: Appearance.colour.accent
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Dictionary.building ? "Dictionary · getting the offline copy" : "Dictionary"
                color: Appearance.colour.textFaint
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.small
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.padding.normal

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.actionLabel !== ""
                text: root.actionLabel
            }

            KeyCap {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.actionLabel !== ""
                text: "↵"
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: Appearance.font.line.small
                color: Appearance.colour.separator
            }

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
