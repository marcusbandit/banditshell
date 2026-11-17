pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.menu.content

Item {
    id: root

    property bool open: false

    property real holeX: 0
    property real holeY: 0
    property real holeWidth: 0
    property real holeHeight: 0

    readonly property Item maskItem: card

    property string restoreTo: ""

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    property var entries: []
    property int unread: 0

    readonly property real areaX: root.holeX + Appearance.sizes.gap
    readonly property real areaY: root.holeY + Appearance.sizes.gap
    readonly property real areaWidth: root.holeWidth - Appearance.sizes.gap * 2
    readonly property real areaHeight: root.holeHeight - Appearance.sizes.gap * 2

    readonly property real cardWidth: Math.min(root.areaWidth, Math.round(Appearance.sizes.menuWidth * 2.4))
    readonly property real cardHeight: Math.min(root.areaHeight, Math.round(root.areaHeight * 0.88))

    readonly property real restY: root.areaY + (root.areaHeight - root.cardHeight) / 2

    readonly property real lift: Appearance.padding.large * 2 * (1 - reveal.value)

    function show(): void {
        if (root.open)
            return;
        root.restoreTo = Hypr.focusedOn(root.screenName);
        view.positionViewAtBeginning();
        root.open = true;
        Qt.callLater(keys.forceActiveFocus);
    }

    function hide(): void {
        if (!root.open)
            return;
        root.open = false;
        keys.focus = false;
        Hypr.restoreFocus(root.restoreTo);
        root.restoreTo = "";
    }

    function leave(): void {
        root.open = false;
        keys.focus = false;
        root.restoreTo = "";
    }

    function toggle(): void {
        if (root.open)
            root.hide();
        else
            root.show();
    }

    function hue(key: string): color {
        if (key === "major")
            return Appearance.colour.accent;
        if (key === "features")
            return Appearance.colour.changeNew;
        if (key === "ui")
            return Appearance.colour.changeChanged;
        if (key === "bugs")
            return Appearance.colour.changeFixed;
        if (key === "config")
            return Appearance.colour.changeSettings;
        return Appearance.colour.textDim;
    }

    Follow {
        id: reveal

        speed: Appearance.animation.revealSpeed
        target: root.open ? 1 : 0
        epsilon: 0.005
    }

    Keys.onPressed: event => {
        if (event.key !== Qt.Key_Escape)
            return;
        Appearance.instantly();
        root.hide();
        event.accepted = true;
    }

    Item {
        id: keys
    }

    TextMetrics {
        id: tagWidth

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: "Changed"
    }

    Item {
        id: card

        x: root.areaX + (root.areaWidth - root.cardWidth) / 2
        y: root.restY + root.lift
        width: root.cardWidth
        height: root.cardHeight

        visible: reveal.value > 0.001
        enabled: root.open
        opacity: reveal.value

        SquircleRect {
            anchors.fill: parent

            radius: Appearance.rounding.large
            color: Appearance.colour.surface

            Item {
                anchors.fill: parent
                anchors.margins: Appearance.padding.large

                Item {
                    id: head

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.max(title.implicitHeight, close.implicitHeight)

                    StyledText {
                        id: title

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "What's new"
                        font.pixelSize: Appearance.font.size.normal
                    }

                    StyledText {
                        anchors.left: title.right
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.unread > 0 ? `${root.unread} unread` : ""
                        color: Appearance.colour.accent
                    }

                    Button {
                        id: close

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "close"
                        style: "ring"

                        onClicked: root.hide()
                    }
                }

                ListView {
                    id: view

                    anchors.top: head.bottom
                    anchors.topMargin: Appearance.padding.normal
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom

                    model: root.entries
                    spacing: Appearance.padding.large
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    reuseItems: false

                    WheelStep {
                        flick: view
                    }

                    delegate: Column {
                        id: entry

                        required property var modelData

                        width: view.width
                        spacing: Appearance.padding.small

                        Row {
                            spacing: Appearance.padding.small

                            SquircleRect {
                                visible: entry.modelData.unread
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(3, Appearance.font.stem * 3)
                                height: Math.round(Appearance.font.line.small * 0.6)
                                pill: "object"
                                color: Appearance.colour.accent
                            }

                            StyledText {
                                text: entry.modelData.date || entry.modelData.id
                                color: entry.modelData.unread ? Appearance.colour.text : Appearance.colour.textDim
                            }
                        }

                        Repeater {
                            model: entry.modelData.changes

                            delegate: Item {
                                id: line

                                required property var modelData

                                readonly property color tone: root.hue(line.modelData.key)
                                readonly property bool goes: line.modelData.go.length > 0

                                width: entry.width
                                height: Math.max(tag.height, words.height, goButton.visible ? goButton.height : 0)

                                StyledText {
                                    id: tag

                                    width: Math.ceil(tagWidth.advanceWidth)
                                    text: line.modelData.tag
                                    color: Appearance.blend(Appearance.colour.text, line.tone, 0.55)
                                }

                                StyledText {
                                    id: words

                                    x: tag.width + Appearance.padding.normal
                                    width: line.width - x - (line.goes ? goButton.width + Appearance.padding.normal : 0)
                                    text: line.modelData.text
                                    color: entry.modelData.unread ? Appearance.colour.text : Appearance.colour.textDim
                                    wrapMode: Text.WordWrap
                                }

                                TakeMeThere {
                                    id: goButton

                                    anchors.right: parent.right
                                    go: line.modelData.go
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
