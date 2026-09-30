import QtQuick
import qs.config
import qs.components

Item {
    id: root

    function rootOf(item: Item): Item {
        let top = item;
        while (top?.parent)
            top = top.parent;
        return top;
    }

    readonly property bool mine: !!Tooltips.anchor && root.rootOf(Tooltips.anchor) === root.rootOf(root)

    readonly property Item anchor: root.mine ? Tooltips.anchor : null
    readonly property bool shown: Tooltips.shown && root.mine

    property rect box: Qt.rect(0, 0, 0, 0)

    onAnchorChanged: if (root.anchor)
        root.box = root.mapFromItem(root.anchor, 0, 0, root.anchor.width, root.anchor.height)

    readonly property real gap: Appearance.padding.normal
    readonly property real inset: Appearance.sizes.border

    readonly property real fullWidth: label.implicitWidth + Appearance.padding.normal * 2
    readonly property real fullHeight: label.implicitHeight + Appearance.padding.small * 2

    readonly property real wantX: box.x + box.width + gap + fullWidth > root.width - inset ? box.x - gap - fullWidth : box.x + box.width + gap
    readonly property real wantY: Math.max(inset, Math.min(box.y + (box.height - fullHeight) / 2, root.height - inset - fullHeight))

    Follow {
        id: glideX

        target: root.wantX
        speed: Appearance.anim.trackSpeed
    }

    Follow {
        id: glideY

        target: root.wantY
        speed: Appearance.anim.trackSpeed
    }

    Follow {
        id: grow

        target: root.shown ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.001
    }

    onShownChanged: if (root.shown) {
        glideX.snap();
        glideY.snap();
    }

    readonly property var blobs: pill.width < 1 ? [] : [
        {
            x: pill.x,
            y: pill.y,
            w: pill.width,
            h: pill.height,
            radius: Math.min(Appearance.rounding.normal, pill.height / 2),

            smooth: Appearance.sizes.melt / 3
        }
    ]

    Item {
        id: pill

        width: root.fullWidth * grow.value
        height: root.fullHeight * grow.value

        x: glideX.value + (root.fullWidth - width) / 2
        y: glideY.value + (root.fullHeight - height) / 2

        StyledText {
            id: label

            anchors.centerIn: parent

            text: Tooltips.text || label.text
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.text

            opacity: Math.max(0, grow.value * 2 - 1)
        }
    }
}
