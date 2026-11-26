pragma ComponentBehavior: Bound

import QtQuick
import qs.config

Item {
    id: root

    property string label: ""
    property int remaining: 0
    property real remainingFraction: 0
    property real elapsedFraction: -1
    property string resetText: ""
    property color accentColor: Appearance.colour.accent
    property bool compact: false

    readonly property real barHeight: root.compact ? 20 : 24
    readonly property real pad: root.compact ? Appearance.padding.small : Appearance.padding.normal

    implicitHeight: root.compact ? compactLayout.implicitHeight + root.pad * 2 : wideLayout.implicitHeight + root.pad * 2

    Follow {
        id: fillLevel

        target: Math.max(0, Math.min(1, root.remainingFraction))
        speed: Appearance.animation.trackSpeed
        epsilon: 0.002
        startsAtTarget: true
    }

    SquircleRect {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colour.fill
    }

    Column {
        id: compactLayout

        visible: root.compact
        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        spacing: Appearance.padding.small

        Item {
            width: parent.width
            height: Math.max(compactLabel.implicitHeight, compactPct.implicitHeight)

            StyledText {
                id: compactLabel

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - compactPct.implicitWidth - Appearance.padding.small
                text: root.label
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textDim
                elide: Text.ElideRight
            }

            Row {
                id: compactPct

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                StyledText {
                    text: root.remaining + "%"
                    font.pixelSize: Appearance.font.size.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colour.text
                }

                StyledText {
                    anchors.baseline: parent.children[0].baseline
                    text: "left"
                    font.pixelSize: Appearance.font.size.small
                    color: Appearance.colour.textDim
                }
            }
        }

        BarTrack {
            width: parent.width
            height: root.barHeight
        }
    }

    Row {
        id: wideLayout

        visible: !root.compact
        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        spacing: Appearance.padding.normal

        Column {
            id: metaCol

            width: Math.min(108, Math.round(wideLayout.width * 0.34))
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                width: parent.width
                text: root.label
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textDim
                elide: Text.ElideRight
            }

            Row {
                spacing: 4

                StyledText {
                    text: root.remaining + "%"
                    font.pixelSize: Appearance.font.size.large
                    font.weight: Font.DemiBold
                    color: Appearance.colour.text
                }

                StyledText {
                    anchors.baseline: parent.children[0].baseline
                    text: "left"
                    font.pixelSize: Appearance.font.size.small
                    color: Appearance.colour.textDim
                }
            }
        }

        BarTrack {
            width: wideLayout.width - metaCol.width - wideLayout.spacing
            height: root.barHeight
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    component BarTrack: Item {
        id: track

        clip: true

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: Appearance.withAlpha(Appearance.colour.surfaceSolid, 0.55)
        }

        Canvas {
            id: hatch

            anchors.fill: parent
            opacity: 0.14
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.strokeStyle = Appearance.colour.text;
                ctx.lineWidth = 1;
                const step = 7;
                ctx.beginPath();
                for (let x = -height; x < width + height; x += step) {
                    ctx.moveTo(x, height);
                    ctx.lineTo(x + height, 0);
                }
                ctx.stroke();
            }
        }

        SquircleRect {
            x: 0
            y: 0
            width: Math.round(track.width * fillLevel.value)
            height: track.height
            radius: Appearance.rounding.small
            visible: width > 0
            color: Appearance.withAlpha(root.accentColor, 0.65)
        }

        Rectangle {
            visible: root.elapsedFraction >= 0 && root.elapsedFraction <= 1
            x: Math.max(1, Math.min(track.width - 3, Math.round(track.width * root.elapsedFraction) - 1))
            y: 0
            width: 2
            height: track.height
            radius: 1
            color: Appearance.colour.text
        }

        SquircleRect {
            id: resetPill

            visible: root.resetText !== "" && track.width > resetRow.implicitWidth + 16
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: resetRow.implicitWidth + 10
            height: Math.max(14, track.height - 6)
            radius: Appearance.rounding.small
            color: Appearance.withAlpha(Appearance.colour.surfaceSolid, 0.78)

            Row {
                id: resetRow

                anchors.centerIn: parent
                spacing: 3

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "refresh"
                    size: Math.max(10, Appearance.font.size.small - 1)
                    color: Appearance.colour.textDim
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.resetText
                    font.pixelSize: Math.max(10, Appearance.font.size.small - 1)
                    color: Appearance.colour.text
                }
            }
        }
    }
}
