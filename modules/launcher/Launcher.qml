pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// The launcher.
//
// It grows out of the sidebar like everything else, rather than appearing in the
// middle of the screen. A centred panel would be the conventional choice and
// would be the only thing in this shell that is not part of the chassis; the
// whole point of the field is that nothing floats.
//
// It is the ONE thing here that takes the keyboard, which is why it needs a
// focus grab: a layer surface does not get key events unless it asks, and the
// asking has to stop the moment it closes or the desktop stays deaf.
Item {
    id: root

    required property real originX
    required property real inset

    readonly property bool open: shown
    property bool shown: false

    readonly property real panelWidth: Appearance.sizes.launcherWidth
    readonly property Item maskItem: panel

    readonly property var results: Apps.search(query.text)
    property int selected: 0

    // The blob the chassis melts in.
    readonly property var blobs: reveal.value <= 0 ? [] : [
        {
            x: panel.x,
            y: panel.y,
            w: panel.width,
            h: panel.height,
            radius: Appearance.rounding.large
        }
    ]

    function show(): void {
        root.shown = true;
        query.text = "";
        root.selected = 0;
        reveal.target = 1;
        query.forceActiveFocus();
    }

    function hide(): void {
        root.shown = false;
        reveal.target = 0;
        query.focus = false;
    }

    function toggle(): void {
        if (root.shown)
            root.hide();
        else
            root.show();
    }

    function accept(): void {
        const entry = root.results[root.selected];
        if (entry)
            Apps.launch(entry);
        root.hide();
    }

    // Wrapping, because a launcher list is short and getting stuck at the end of
    // it is a small papercut you feel every time.
    function move(delta: int): void {
        const n = root.results.length;
        if (n > 0)
            root.selected = (root.selected + delta + n) % n;
    }

    onResultsChanged: root.selected = 0

    Follow {
        id: reveal

        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    Item {
        id: panel

        x: root.originX
        y: (root.height - height) / 2
        width: root.panelWidth * reveal.value
        height: Math.min(root.height - root.inset * 2, Appearance.padding.large * 2 + field.height + list.implicitHeight + Appearance.padding.normal)

        visible: reveal.value > 0

        Item {
            anchors.fill: parent
            clip: true

            Column {
                x: Appearance.padding.large
                y: Appearance.padding.large
                width: root.panelWidth - Appearance.padding.large * 2
                spacing: Appearance.padding.normal

                Item {
                    id: field

                    width: parent.width
                    implicitHeight: Math.max(searchGlyph.implicitHeight, query.implicitHeight)
                    height: implicitHeight

                    Icon {
                        id: searchGlyph

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        name: "search"
                        color: Appearance.colour.textFaint
                    }

                    TextInput {
                        id: query

                        anchors.left: searchGlyph.right
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        font.family: Appearance.font.family
                        font.pixelSize: Appearance.font.size.normal
                        renderType: Text.NativeRendering
                        color: Appearance.colour.text
                        selectionColor: Appearance.colour.accent
                        selectedTextColor: Appearance.colour.accentText
                        clip: true

                        Keys.onEscapePressed: root.hide()
                        Keys.onReturnPressed: root.accept()
                        Keys.onEnterPressed: root.accept()
                        Keys.onDownPressed: root.move(1)
                        Keys.onUpPressed: root.move(-1)
                        // Tab moves too, because half the world reaches for it.
                        Keys.onTabPressed: root.move(1)
                        Keys.onBacktabPressed: root.move(-1)

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !query.text
                            text: "type to find an application"
                            color: Appearance.colour.textFaint
                        }
                    }
                }

                Separator {
                    width: parent.width
                }

                Column {
                    id: list

                    width: parent.width
                    spacing: 0

                    Repeater {
                        model: root.results

                        delegate: MenuRow {
                            required property var modelData
                            required property int index

                            width: parent.width
                            // The entry's own icon, resolved out of the icon
                            // theme, with the generic mark only as a fallback
                            // for the entries that do not name one.
                            iconSource: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                            icon: "apps"
                            label: modelData.name ?? ""
                            detail: modelData.genericName || modelData.comment || ""
                            selected: index === root.selected

                            onActivated: {
                                root.selected = index;
                                root.accept();
                            }
                        }
                    }

                    StyledText {
                        visible: !root.results.length
                        text: query.text ? "nothing matches" : "no applications found"
                        color: Appearance.colour.textFaint
                        font.pixelSize: Appearance.font.size.small
                    }
                }
            }
        }
    }
}
