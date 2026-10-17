pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property real holeX
    required property real holeY
    required property real holeWidth
    required property real holeHeight

    required property real aspect

    property string screen: Hypr.focusedScreen

    readonly property int band: Hypr.bandFor(root.screen)

    readonly property int activeId: Hypr.activeOn(root.screen)

    property real pointX: 0
    property real pointY: 0
    property bool active: false

    readonly property var slots: {
        const out = [];
        for (let i = 0; i < Hypr.count; i++)
            out.push({
                target: root.band + i,
                label: `${root.band + i}`,
                glyph: ""
            });
        out.push({
            target: "empty",
            label: "",
            glyph: "add"
        });
        return out;
    }

    readonly property int count: root.slots.length

    readonly property real gap: Appearance.padding.normal
    readonly property real span: root.holeWidth * 0.8

    readonly property real plateW: Math.min(root.holeWidth * Appearance.sizes.windowPlate, (root.span - (root.count - 1) * root.gap) / root.count)
    readonly property real plateH: root.plateW * root.aspect

    readonly property real pitch: root.plateW + root.gap
    readonly property real rowW: root.count * root.pitch - root.gap
    readonly property real rowX: root.holeX + (root.holeWidth - root.rowW) / 2
    readonly property real rowY: root.holeY + root.gap

    readonly property real dockedHeight: root.gap * 2 + root.plateH * root.docked

    readonly property real docked: 0.72
    readonly property real rowScale: root.docked + (1 - root.docked) * arm.value

    readonly property int marksFit: Math.max(1, Math.floor((root.scaledW - root.markGap) / (Appearance.sizes.workspaceIcon + root.markGap)))
    readonly property real markGap: Appearance.padding.hair

    readonly property real scaledPitch: root.pitch * root.rowScale
    readonly property real scaledW: root.plateW * root.rowScale
    readonly property real scaledH: root.plateH * root.rowScale
    readonly property real scaledRowW: root.rowW * root.rowScale
    readonly property real scaledRowX: root.rowX + (root.rowW - root.scaledRowW) / 2

    function plateCentre(i: int): point {
        return Qt.point(root.scaledRowX + i * root.scaledPitch + root.scaledW / 2, root.rowY + root.scaledH / 2);
    }

    readonly property bool armed: root.active && root.pointY < root.rowY + root.scaledH * 2

    readonly property int over: {
        if (!root.armed)
            return -1;

        if (root.pointX < root.scaledRowX - root.scaledW / 2 || root.pointX > root.scaledRowX + root.scaledRowW + root.scaledW / 2)
            return -1;

        return Math.max(0, Math.min(root.count - 1, Math.floor((root.pointX - root.scaledRowX) / root.scaledPitch)));
    }

    Follow {
        id: reveal

        target: root.active ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.005
    }

    Follow {
        id: arm

        target: root.armed ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.005
    }

    visible: reveal.value > 0.01

    opacity: reveal.value * (Appearance.opacity.trail + (1 - Appearance.opacity.trail) * arm.value)

    Repeater {
        model: root.slots

        delegate: Item {
            id: plate

            required property int index
            required property var modelData

            readonly property bool here: plate.modelData.target === root.activeId
            readonly property bool aimed: root.over === plate.index

            readonly property var windows: typeof plate.modelData.target === "number" ? Hypr.clientsIn(plate.modelData.target).slice(0, root.marksFit) : []

            readonly property point centre: root.plateCentre(plate.index)

            x: plate.centre.x - width / 2

            y: plate.centre.y - height / 2 - (1 - reveal.value) * root.plateH * 0.3
            width: root.scaledW
            height: root.scaledH

            scale: lift.value

            Follow {
                id: lift

                target: plate.aimed ? 1.08 : 1
                speed: Appearance.animation.revealSpeed
                epsilon: Appearance.animation.fadeEpsilon
                startsAtTarget: true
            }

            SquircleRect {
                anchors.fill: parent

                radius: Appearance.rounding.normal
                color: tone.value

                stroke: plate.here ? Appearance.colour.accent : "transparent"
                strokeWidth: Appearance.stroke.ring

                FollowColour {
                    id: tone

                    target: plate.aimed ? Appearance.colour.fillStrong : Appearance.colour.fill
                    speed: Appearance.animation.revealSpeed
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: Appearance.padding.small

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !!plate.modelData.label

                    text: plate.modelData.label
                    font.pixelSize: Appearance.font.size.normal
                    color: plate.here ? Appearance.colour.accent : plate.aimed ? Appearance.colour.text : Appearance.colour.textDim
                }

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !!plate.modelData.glyph

                    name: plate.modelData.glyph
                    size: Appearance.font.iconSize
                    color: plate.aimed ? Appearance.colour.text : Appearance.colour.textDim
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: root.markGap

                    Repeater {
                        model: plate.windows

                        delegate: AppMark {
                            required property var modelData

                            spec: AppIcons.markFor(Hypr.classOf(modelData))
                            fits: AppIcons.fits
                            onMeasured: (path, box) => AppIcons.recordFit(path, box)
                            size: Appearance.sizes.workspaceIcon
                            color: Appearance.colour.textDim
                        }
                    }
                }
            }
        }
    }
}
