pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import "layout-model.js" as LayoutModel

Item {
    id: root

    property var model: null
    property int arrangement: 0
    property int count: 3
    property var shape: ({
            width: 5120,
            height: 1440
        })
    property string selected: ""

    signal picked(string id)

    readonly property var placed: root.model ? LayoutModel.arrangeWith(root.model, Math.min(root.arrangement, root.model.arrangements.length - 1), {
        x: 0,
        y: 0,
        w: root.shape.width,
        h: root.shape.height
    }, root.count, {}) : ({
            regions: [],
            windows: []
        })

    readonly property real scale: Math.min(root.width / root.shape.width, root.height / root.shape.height)
    readonly property real gap: Math.max(2, Appearance.padding.hair)

    function regionAt(x: real, y: real): var {
        let hit = null;
        for (const region of root.placed.regions)
            if (region.kind !== "split" && x >= region.x && x < region.x + region.w && y >= region.y && y < region.y + region.h)
                hit = region;
        return hit;
    }

    function chainOf(id: string): var {
        const chain = [];
        let walk = root.placed.regions.find(r => r.id === id);
        while (walk) {
            chain.push(walk.id);
            walk = walk.parent ? root.placed.regions.find(r => r.id === walk.parent) : null;
        }
        return chain;
    }

    Item {
        id: screen

        width: Math.round(root.shape.width * root.scale)
        height: Math.round(root.shape.height * root.scale)
        anchors.centerIn: parent

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colour.fill
        }

        Repeater {
            model: root.placed.regions

            delegate: Item {
                id: area

                required property var modelData

                readonly property bool leaf: area.modelData.kind !== "split"
                readonly property bool chosen: root.selected === area.modelData.id
                readonly property bool empty: area.leaf && area.modelData.windows.length === 0

                x: area.modelData.x * root.scale
                y: area.modelData.y * root.scale
                width: area.modelData.w * root.scale
                height: area.modelData.h * root.scale
                visible: area.width > 0 && area.height > 0 && (area.leaf || area.chosen)
                z: area.chosen ? 2 : 0

                SquircleRect {
                    anchors.fill: parent
                    anchors.margins: root.gap / 2
                    radius: Appearance.rounding.small
                    color: !area.leaf || area.modelData.kind === "space" ? "transparent" : Appearance.colour.fillStrong
                    stroke: area.chosen ? Appearance.colour.accent : area.modelData.kind === "space" ? Appearance.colour.textGhost : "transparent"
                    strokeWidth: area.chosen ? Appearance.stroke.ring : Appearance.stroke.line
                }

                StyledText {
                    x: Appearance.padding.small
                    y: Appearance.padding.hair
                    width: parent.width - Appearance.padding.small * 2
                    visible: area.empty && area.height > Appearance.font.line.small * 2
                    text: area.modelData.id
                    elide: Text.ElideRight
                    color: area.chosen ? Appearance.colour.accent : Appearance.colour.textFaint
                }
            }
        }

        Repeater {
            model: root.placed.windows.length

            delegate: Item {
                id: window

                required property int index

                readonly property var box: root.placed.windows[window.index] ?? ({
                        x: 0,
                        y: 0,
                        w: 0,
                        h: 0
                    })
                readonly property bool inChosen: root.placed.assigned[window.index] === root.selected

                Follow {
                    id: left
                    target: window.box.x * root.scale
                }
                Follow {
                    id: top
                    target: window.box.y * root.scale
                }
                Follow {
                    id: wide
                    target: window.box.w * root.scale
                }
                Follow {
                    id: tall
                    target: window.box.h * root.scale
                }

                Component.onCompleted: {
                    left.snap();
                    top.snap();
                    wide.snap();
                    tall.snap();
                }

                x: left.value + root.gap
                y: top.value + root.gap
                width: Math.max(0, wide.value - root.gap * 2)
                height: Math.max(0, tall.value - root.gap * 2)
                z: 1

                SquircleRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.small
                    color: window.index === 0 ? Appearance.colour.accentFill : Appearance.colour.fillStronger
                    stroke: window.inChosen ? Appearance.colour.accent : "transparent"
                    strokeWidth: Appearance.stroke.line
                }

                Column {
                    anchors.centerIn: parent
                    visible: parent.width > number.implicitWidth && parent.height > number.implicitHeight

                    StyledText {
                        id: number

                        anchors.horizontalCenter: parent.horizontalCenter
                        text: window.index + 1
                        font.pixelSize: window.height > Appearance.font.line.large * 3 ? Appearance.font.size.large : Appearance.font.size.small
                        color: window.index === 0 ? Appearance.colour.text : Appearance.colour.textDim
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: window.height > number.implicitHeight + implicitHeight * 1.5 && window.width > implicitWidth + Appearance.padding.small
                        text: root.placed.assigned[window.index] ?? ""
                        color: window.inChosen ? Appearance.colour.accent : Appearance.colour.textFaint
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                const hit = root.regionAt(mouse.x / root.scale, mouse.y / root.scale);
                if (!hit)
                    return;
                const chain = root.chainOf(hit.id);
                const at = chain.indexOf(root.selected);
                root.picked(at < 0 || at === chain.length - 1 ? hit.id : chain[at + 1]);
            }
        }
    }
}
