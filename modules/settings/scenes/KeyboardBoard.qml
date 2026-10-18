pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.modules.controls
import "../boards.js" as Boards

Item {
    id: root

    property var keys: []
    property var hot: ({})
    property bool flat: false
    property bool tips: true

    readonly property var size: Boards.extent(root.keys)
    readonly property real unit: Math.min(root.width / Math.max(1, root.size.cols), root.height / Math.max(1, root.size.rows))
    readonly property real drawnWidth: root.size.cols * root.unit
    readonly property real drawnHeight: root.size.rows * root.unit
    readonly property real inset: root.flat ? 1 : 1.5

    readonly property color plain: Appearance.colour.pane
    readonly property color lit: Appearance.blend(Appearance.colour.surfaceSolid, Appearance.colour.accent, 0.45)
    readonly property color pointed: Appearance.blend(Appearance.colour.surfaceSolid, Appearance.colour.paper, 0.3)

    Item {
        x: (root.width - root.drawnWidth) / 2
        y: (root.height - root.drawnHeight) / 2
        width: root.drawnWidth
        height: root.drawnHeight

        Repeater {
            model: Boards.rects(root.keys)

            delegate: SquircleRect {
                id: key

                required property var modelData

                readonly property bool on: Boards.struck(key.modelData, root.hot)

                x: key.modelData.x * root.unit + root.inset
                y: key.modelData.y * root.unit + root.inset
                width: key.modelData.w * root.unit - root.inset * 2
                height: key.modelData.h * root.unit - root.inset * 2
                radius: root.flat ? 3 : 5
                color: hover.hovered && root.tips && key.modelData.label ? root.pointed : key.on ? root.lit : root.plain

                HoverHandler {
                    id: hover

                    enabled: root.tips
                }

                HoverTip {
                    host: key
                    text: root.tips && !key.modelData.second ? key.modelData.label.toLowerCase() : ""
                }
            }
        }
    }
}
