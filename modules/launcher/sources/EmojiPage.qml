pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import "../../../services/emoji-grid.js" as Grid
import "../../../services/emoji-table.js" as EmojiTable

Item {
    id: root

    property string typed: ""
    property string query: ""
    property var view: null

    readonly property var source: root.view?.source ?? null

    signal leave(var what)
    signal launch(var what)
    signal back
    signal retitle(string text)
    signal asks(Item item, var actions, real x, real y)

    readonly property var groups: EmojiTable.GROUPS
    readonly property var choices: [
        {
            label: "All categories",
            icon: "apps"
        }
    ].concat(root.groups.map(g => ({
                label: g,
                icon: root.groupIcons[g] ?? "category"
            })))
    readonly property var groupIcons: ({
            "Smileys": "mood",
            "People": "front_hand",
            "Animals": "pets",
            "Food": "restaurant",
            "Travel": "flight",
            "Activities": "sports_soccer",
            "Objects": "lightbulb",
            "Symbols": "emoji_symbols",
            "Flags": "flag",
            "Arrows": "arrow_forward",
            "Maths": "function",
            "Currency": "payments",
            "Typography": "text_fields",
            "Fractions": "percent",
            "Greek": "translate",
            "Keys": "keyboard",
            "Marks": "check"
        })
    property int choice: 0
    readonly property string group: root.choice > 0 ? root.groups[root.choice - 1] ?? "" : ""

    function choose(index: int): void {
        root.choice = index;
        root.selected = 0;
        grid.reset();
    }

    readonly property int columns: 10
    readonly property real gap: Appearance.padding.small
    readonly property real tile: Math.floor((root.width - root.gap * (root.columns - 1)) / root.columns)
    readonly property real headerPitch: Appearance.font.line.small + Appearance.padding.normal + Appearance.padding.small

    readonly property string term: root.query.trim()
    readonly property var found: root.term ? Emoji.search(root.term, true, 400) : null
    readonly property var recents: Grid.recent(Emoji.used, Emoji.byChar, root.columns * 2)
    readonly property var shaped: Grid.layout(Grid.sections(Emoji.all, root.groups, root.group, root.found, root.recents), root.columns)

    property int selected: 0
    readonly property var entry: root.shaped.items[root.selected] ?? null
    readonly property var row: root.entry && root.source ? root.source.row(root.entry) : null

    onQueryChanged: {
        root.selected = 0;
        grid.reset();
    }

    function reveal(): void {
        const at = Grid.rowOf(root.shaped.rows, root.selected);
        if (at < 0)
            return;
        grid.reveal(at > 0 && root.shaped.rows[at - 1].header ? at - 1 : at);
        grid.reveal(at);
    }

    function go(dx: int, dy: int): void {
        const next = Grid.step(root.shaped.rows, root.shaped.items.length, root.selected, dx, dy);
        if (next < 0)
            return;
        root.selected = next;
        root.reveal();
    }

    function useIt(): void {
        if (root.row)
            root.source.activate(root.row);
    }

    function openActions(item: Item): void {
        if (!root.row)
            return;
        const acts = root.source.actionsFor(root.row);
        const at = item ?? footer;
        root.asks(at, acts, at.width / 2, at.height / 2);
    }

    function claimKey(event: var): bool {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const bare = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.ShiftModifier | Qt.MetaModifier));
        switch (event.key) {
        case Qt.Key_Left:
            if (!bare)
                return false;
            root.go(-1, 0);
            return true;
        case Qt.Key_Right:
            if (!bare)
                return false;
            root.go(1, 0);
            return true;
        case Qt.Key_Down:
            root.go(0, 1);
            return true;
        case Qt.Key_Up:
            root.go(0, -1);
            return true;
        case Qt.Key_PageDown:
            root.go(0, 4);
            return true;
        case Qt.Key_PageUp:
            root.go(0, -4);
            return true;
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            root.choose((root.choice + (event.key === Qt.Key_Tab ? 1 : root.choices.length - 1)) % root.choices.length);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (ctrl && root.row)
                root.source.copy(root.row, root.row.glyph);
            else
                root.useIt();
            return true;
        case Qt.Key_K:
            if (!ctrl)
                return false;
            root.openActions(null);
            return true;
        case Qt.Key_Menu:
            root.openActions(null);
            return true;
        case Qt.Key_Backspace:
            if (root.query !== "")
                return false;
            root.back();
            return true;
        }
        return false;
    }

    implicitHeight: root.headerPitch * 2 + (root.tile + root.gap) * 5 + footer.implicitHeight

    GlideList {
        id: grid

        width: root.width
        height: root.height - footer.height - Appearance.padding.small
        clip: true
        model: ScriptModel {
            values: root.shaped.rows
        }

        delegate: Item {
            id: line

            required property var modelData
            required property int index

            width: grid.width
            height: line.modelData.header ? root.headerPitch : root.tile + root.gap

            StyledText {
                visible: !!line.modelData.header
                anchors.left: parent.left
                anchors.leftMargin: Appearance.padding.small
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.padding.small / 2
                text: line.modelData.title ?? ""
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textFaint
            }

            Row {
                visible: !line.modelData.header
                spacing: root.gap

                Repeater {
                    model: line.modelData.cells ?? []

                    delegate: Item {
                        id: cell

                        required property var modelData
                        required property int index

                        readonly property int at: line.modelData.start + cell.index
                        readonly property bool chosen: cell.at === root.selected

                        width: root.tile
                        height: root.tile

                        SquircleRect {
                            anchors.fill: parent
                            radius: Appearance.rounding.normal
                            color: shade.value
                            stroke: cell.chosen ? Appearance.colour.accent : "transparent"
                            strokeWidth: Appearance.stroke.ring

                            FollowColour {
                                id: shade

                                target: cell.chosen ? Appearance.colour.fillStrong : tap.containsMouse ? Appearance.colour.fill : Appearance.colour.tile
                                speed: Appearance.animation.revealSpeed
                            }
                        }

                        Icon {
                            anchors.centerIn: parent
                            glyph: Emoji.textOf(cell.modelData)
                            size: Math.round(root.tile * 0.48)
                        }

                        MouseArea {
                            id: tap

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                root.selected = cell.at;
                                if (mouse.button === Qt.RightButton)
                                    root.openActions(cell);
                                else
                                    root.useIt();
                            }
                        }
                    }
                }
            }
        }
    }

    StyledText {
        visible: !root.shaped.items.length
        x: Appearance.padding.normal
        y: Appearance.padding.normal
        text: root.term ? `No emoji or symbol matches “${root.term}”` : "Nothing here"
        font.pixelSize: Appearance.font.size.normal
        color: Appearance.colour.textFaint
    }

    PageFooter {
        id: footer

        anchors.bottom: parent.bottom
        width: root.width
        glyph: root.row?.glyph ?? ""
        icon: root.row ? "" : "mood"
        title: root.row ? root.row.label : "Emoji and symbols"
        primary: root.row ? Typist.found ? "Type" : "Copy" : ""
        onPrimed: root.useIt()
        onAsked: root.openActions(null)
    }
}
