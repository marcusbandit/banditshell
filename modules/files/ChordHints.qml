pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// HOLD A MODIFIER, SEE WHAT IT DOES.
//
// A keymap that lives in a config file is a keymap nobody reads, and a window
// with four panels and a terminal in it has more chords than anybody will
// remember from having been told once. So the modifier itself is the way in:
// hold Ctrl for a moment and the chords it starts fade up, over the window they
// act on.
//
// A MOMENT, not immediately. Ctrl is held in passing constantly - it is the
// start of every shell binding and every copy - and a panel that flashed up on
// each of those would be a strobe. The delay is the shell's own `settle`, which
// is the same number that decides when a menu has been on screen long enough to
// be believed (see Appearance.anim).
//
// It reads the SAME MAP the router does, so it cannot describe a binding that
// does not exist: rebinding a chord in config.json rewrites this panel with it.
Item {
    id: root

    // Which modifier is being held, as the prefix its chords start with.
    property string held: ""

    // THE DELAY IS RESET HERE, on the thing that actually changed, and not in
    // the Timer's own onRunningChanged - which is where it was, and which does
    // not work. A non-repeating Timer takes its own `running` down when it
    // fires, so a handler on that runs immediately after the trigger and undoes
    // exactly what the trigger just set. The panel was correct for less than one
    // frame and then never appeared.
    onHeldChanged: settle.elapsed = false

    readonly property var shown: {
        if (root.held === "")
            return [];
        const prefix = `${root.held}+`;
        const out = [];
        for (const chord in Files.chords)
            if (chord.startsWith(prefix))
                out.push({chord: chord, action: Files.chords[chord]});
        return out;
    }

    // WHAT AN ACTION IS CALLED, for a person. The map is written in verbs the
    // code dispatches on; this is the one place they are turned into English,
    // and an action with no entry falls back to its own name rather than to
    // nothing, so a chord bound to something new is still listed.
    readonly property var labels: ({
            "terminal": "terminal",
            "preview": "preview panel",
            "hidden": "hidden files",
            "back": "back",
            "forward": "forward",
            "parent": "parent folder",
            "home": "home",
            "focus:grid": "focus files",
            "focus:preview": "focus preview",
            "focus:terminal": "focus terminal"
        })

    visible: opacity > 0
    opacity: root.held !== "" && settle.elapsed ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.OutQuad
        }
    }

    // Not a MouseArea and not a catcher: the hints are a legend, and the window
    // underneath must go on working exactly as it did while they are up.
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Appearance.padding.huge

        implicitWidth: list.implicitWidth + Appearance.padding.large * 2
        implicitHeight: list.implicitHeight + Appearance.padding.normal * 2

        G2Rect {
            anchors.fill: parent

            radius: Appearance.rounding.large
            color: Appearance.colour.surface
            stroke: Appearance.colour.separator
            strokeWidth: Appearance.font.stem
        }

        // A GRID, not a Flow, and the column count is arithmetic on how many
        // there are.
        //
        // The Flow that was here bound its own width to its own implicitWidth,
        // which is a loop: constrained, a Flow reports the width of its widest
        // child, so it settled at one item per line and the legend became a
        // column ten tall. A Grid sizes itself from its content and needs no
        // width at all.
        //
        // Five rows a column, and as many columns as that takes
        // (~/.claude/rules/math-over-hardcoding.md): one chord makes one column
        // of one, and a keymap somebody has filled out grows sideways instead of
        // off the top of the window.
        Grid {
            id: list

            anchors.centerIn: parent

            readonly property int perColumn: 5

            // Columns from the ceiling on height, then rows from the columns,
            // which is what BALANCES them: taking the rows straight from the
            // ceiling instead puts five in the first column and one in the
            // second, and the panel looks like it ran out rather than like it
            // was laid out.
            columns: Math.max(1, Math.ceil(root.shown.length / list.perColumn))
            rows: Math.ceil(root.shown.length / list.columns)
            flow: Grid.TopToBottom

            columnSpacing: Appearance.padding.huge
            rowSpacing: Appearance.padding.small

            Repeater {
                model: root.shown

                delegate: Row {
                    id: hint

                    required property var modelData

                    spacing: Appearance.padding.normal

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter

                        // Only the part after the modifier: the whole panel is
                        // already "what Ctrl does", and repeating the prefix on
                        // every row is ten copies of the thing being held down.
                        text: hint.modelData.chord.split("+").pop()
                        color: Appearance.colour.accent
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter

                        text: root.labels[hint.modelData.action] ?? hint.modelData.action
                        color: Appearance.colour.textDim
                    }
                }
            }
        }
    }

    Timer {
        id: settle

        // NOT called `triggered`. Timer already has a triggered() SIGNAL, and a
        // property of that name shadows it.
        property bool elapsed: false

        interval: Appearance.anim.settle
        running: root.held !== ""

        onTriggered: settle.elapsed = true
    }
}
