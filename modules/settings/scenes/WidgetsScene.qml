pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "../../../components/squircle.js" as Squircle

Item {
    id: root

    readonly property real stageHeight: 260

    readonly property var screen: Quickshell.screens.find(s => s.name === Settings.screenName) ?? Quickshell.screens[0] ?? null
    readonly property real aspect: root.screen && root.screen.height > 0 ? root.screen.width / root.screen.height : 16 / 9
    readonly property real fit: Math.min(root.width - Appearance.padding.card * 2, (root.height - Appearance.padding.card * 2) * root.aspect)
    readonly property real ratio: root.screen && root.screen.width > 0 ? mini.width / root.screen.width : 0.2

    readonly property real band: Appearance.bare ? 0 : Math.max(2, Appearance.sizes.border * root.ratio)
    readonly property real bar: SettingsState.v("sidebar") ? Math.max(4, Appearance.sizes.sidebarWidth * root.ratio) : 0
    readonly property real corner: Math.max(3, Appearance.sizes.windowRadius * root.ratio)
    readonly property real gap: Math.max(3, Appearance.padding.large * root.ratio)
    readonly property real column: Math.max(28, Appearance.font.size.small * 26 * root.ratio)

    readonly property bool on: SettingsState.v("widgetsOn")

    Item {
        id: mini

        anchors.centerIn: parent
        width: root.fit
        height: root.fit / root.aspect
        clip: true

        SquircleImage {
            anchors.fill: parent
            visible: SettingsState.v("wallOn")
            radius: root.corner
            source: SettingsState.wallFace
            fillMode: Image.PreserveAspectCrop
        }

        Shape {
            id: frame

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            readonly property real hx: root.band + root.bar
            readonly property real hy: root.band
            readonly property real hw: Math.max(0, width - hx - root.band)
            readonly property real hh: Math.max(0, height - root.band * 2)

            ShapePath {
                fillColor: SettingsState.v("wallOn") ? Appearance.colour.surface : Appearance.colour.surfaceSolid
                strokeColor: "transparent"
                fillRule: ShapePath.OddEvenFill

                PathSvg {
                    path: `${Squircle.path(frame.width, frame.height, root.corner, root.corner, root.corner, root.corner, Appearance.rounding.power)} ${Squircle.path(frame.hw, frame.hh, root.corner, root.corner, root.corner, root.corner, Appearance.rounding.power, frame.hx, frame.hy)}`
                }
            }
        }

        Item {
            id: cards

            x: root.band + root.bar + root.gap
            y: root.band + root.gap
            width: mini.width - x - root.band - root.gap
            height: mini.height - (root.band + root.gap) * 2
            opacity: shown.value

            Follow {
                id: shown

                target: root.on ? 1 : 0
                speed: Appearance.animation.revealSpeed
                epsilon: Appearance.animation.fadeEpsilon
                startsAtTarget: true
            }

            Column {
                anchors.right: parent.right
                spacing: Math.max(2, root.gap * 0.6)

                Column {
                    anchors.right: parent.right
                    visible: SettingsState.v("widgetClock")
                    spacing: -Math.round(root.column * 0.08)

                    StyledText {
                        anchors.right: parent.right
                        text: "14"
                        font.family: Appearance.font.lock
                        font.pixelSize: Appearance.font.size.large
                        font.weight: Font.Bold
                        lineHeight: Math.round(root.column * 0.4)
                    }

                    StyledText {
                        anchors.right: parent.right
                        text: "32"
                        font.family: Appearance.font.lock
                        font.pixelSize: Appearance.font.size.large
                        font.weight: Font.Bold
                        lineHeight: Math.round(root.column * 0.4)
                        color: Appearance.colour.textDim
                    }
                }

                Card {
                    visible: SettingsState.v("widgetWeather")
                    height: root.column * 0.3

                    Icon {
                        x: root.column * 0.08
                        anchors.verticalCenter: parent.verticalCenter
                        name: "partly_cloudy_day"
                        size: parent.height * 0.6
                        fill: 1
                        color: Appearance.colour.text
                    }

                    Bar {
                        x: root.column * 0.36
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.column * 0.3
                    }
                }

                Card {
                    visible: SettingsState.v("widgetMedia")
                    height: root.column * 0.34

                    SquircleRect {
                        x: root.column * 0.08
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.height * 0.62
                        height: width
                        radius: 3
                        color: Appearance.colour.fillStronger
                    }

                    Bar {
                        x: parent.height * 0.8
                        y: parent.height * 0.32
                        width: root.column * 0.45
                    }

                    Bar {
                        x: parent.height * 0.8
                        y: parent.height * 0.56
                        width: root.column * 0.3
                        faint: true
                    }
                }
            }

            Column {
                spacing: Math.max(2, root.gap * 0.6)

                Row {
                    visible: SettingsState.v("widgetSystem")
                    width: root.column
                    height: root.column * 0.34
                    spacing: Math.max(2, root.column * 0.05)

                    Repeater {
                        model: [
                            { tone: Appearance.huedOr(Appearance.hue.processor, Appearance.colour.accent), pts: [0.8, 0.55, 0.25, 0.4, 0.2] },
                            { tone: Appearance.huedOr(Appearance.hue.graphics, Appearance.colour.accent), pts: [0.85, 0.78, 0.5, 0.58, 0.65] },
                            { tone: Appearance.huedOr(Appearance.hue.memory, Appearance.colour.accent), pts: [0.55, 0.52, 0.48, 0.46, 0.45] }
                        ]

                        delegate: SquircleRect {
                            id: miniWell

                            required property var modelData

                            width: (parent.width - parent.spacing * 2) / 3
                            height: parent.height
                            radius: Math.max(3, Appearance.rounding.large * root.ratio * 1.6)
                            color: Appearance.colour.fill
                            stroke: Appearance.colour.separator
                            strokeWidth: 1

                            Shape {
                                id: miniTrace

                                x: Math.max(2, root.column * 0.04)
                                y: miniWell.height * 0.46
                                width: miniWell.width - x * 2
                                height: miniWell.height * 0.42
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    fillColor: "transparent"
                                    strokeColor: miniWell.modelData.tone
                                    strokeWidth: Math.max(1, root.column * 0.016)
                                    capStyle: ShapePath.RoundCap
                                    joinStyle: ShapePath.RoundJoin

                                    PathSvg {
                                        path: miniWell.modelData.pts.map((p, i) => `${i === 0 ? "M" : "L"}${miniTrace.width * i / 4} ${miniTrace.height * p}`).join(" ")
                                    }
                                }
                            }
                        }
                    }
                }

                Card {
                    visible: SettingsState.v("widgetLimits")
                    height: root.column * 0.3

                    Column {
                        x: root.column * 0.08
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.column * 0.84
                        spacing: Math.max(2, root.column * 0.04)

                        SquircleRect {
                            width: parent.width * 0.55
                            height: Math.max(2, root.column * 0.055)
                            pill: "place"
                            color: Appearance.colour.providerClaude
                        }

                        SquircleRect {
                            width: parent.width * 0.78
                            height: Math.max(2, root.column * 0.055)
                            pill: "place"
                            color: Appearance.colour.providerAntigravity
                        }
                    }
                }
            }
        }
    }

    component Card: SquircleRect {
        width: root.column
        radius: Math.max(3, Appearance.rounding.large * root.ratio * 1.6)
        color: Appearance.colour.fill
        stroke: Appearance.colour.separator
        strokeWidth: 1
    }

    component Bar: SquircleRect {
        property bool faint: false

        height: Math.max(2, root.column * 0.05)
        pill: "place"
        color: faint ? Appearance.colour.textGhost : Appearance.colour.textFaint
    }
}
