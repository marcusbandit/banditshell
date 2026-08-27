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

        Flow {
            id: list

            anchors.centerIn: parent
            width: Math.min(root.width * 0.8, implicitWidth)
            spacing: Appearance.padding.large

            Repeater {
                model: root.shown

                delegate: Row {
                    id: hint

                    required property var modelData

                    spacing: Appearance.padding.small

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
        onRunningChanged: if (!running)
            settle.elapsed = false
    }
}
