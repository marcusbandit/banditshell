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
    readonly property bool atRight: SettingsState.v("widgetsSide") === "right"

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

        Flow {
            id: cards

            x: root.atRight ? mini.width - root.band - root.gap - width : root.band + root.bar + root.gap
            y: root.band + root.gap
            height: mini.height - (root.band + root.gap) * 2
            flow: Flow.TopToBottom
            layoutDirection: root.atRight ? Qt.RightToLeft : Qt.LeftToRight
            spacing: Math.max(2, root.gap * 0.6)
            opacity: shown.value

            Follow {
                id: shown

                target: root.on ? 1 : 0
                speed: Appearance.animation.revealSpeed
                epsilon: Appearance.animation.fadeEpsilon
                startsAtTarget: true
            }

            Column {
                visible: SettingsState.v("widgetClock")
                spacing: -Math.round(root.column * 0.08)

                StyledText {
                    text: "14"
                    font.family: Appearance.font.lock
                    font.pixelSize: Appearance.font.size.large
                    font.weight: Font.Bold
                    lineHeight: Math.round(root.column * 0.4)
                }

                StyledText {
                    text: "32"
                    font.family: Appearance.font.lock
                    font.pixelSize: Appearance.font.size.large
                    font.weight: Font.Bold
                    lineHeight: Math.round(root.column * 0.4)
                    color: Appearance.colour.textDim
                }
            }

            Card {
                visible: SettingsState.v("widgetCalendar")
                height: root.column * 0.82

                Grid {
                    anchors.centerIn: parent
                    columns: 7
                    spacing: Math.max(1, root.column * 0.035)

                    Repeater {
                        model: 35

                        delegate: SquircleRect {
                            required property int index

                            width: Math.max(2, root.column * 0.07)
                            height: width
                            pill: "object"
                            color: index === 13 ? Appearance.colour.accent : Appearance.colour.textGhost
                        }
                    }
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
                    color: Appearance.colour.accentFill
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

            Card {
                visible: SettingsState.v("widgetWeather")
                height: root.column * 0.3

                Icon {
                    x: root.column * 0.08
                    anchors.verticalCenter: parent.verticalCenter
                    name: "partly_cloudy_day"
                    size: parent.height * 0.6
                    fill: 1
                    color: Appearance.colour.accent
                }

                Bar {
                    x: root.column * 0.36
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.column * 0.3
                }
            }

            Card {
                visible: SettingsState.v("widgetSystem")
                height: root.column * 0.3

                Row {
                    anchors.centerIn: parent
                    spacing: root.column * 0.2

                    Repeater {
                        model: [0.35, 0.6]

                        delegate: ProgressRing {
                            required property real modelData

                            size: root.column * 0.18
                            thickness: Math.max(1.5, root.column * 0.025)
                            value: modelData
                        }
                    }
                }
            }

            Card {
                visible: SettingsState.v("widgetTimers")
                height: root.column * 0.26

                Row {
                    x: root.column * 0.08
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.column * 0.05

                    Repeater {
                        model: 3

                        delegate: SquircleRect {
                            width: root.column * 0.22
                            height: root.column * 0.08
                            pill: "object"
                            color: Appearance.colour.fillStrong
                        }
                    }
                }
            }
        }
    }

    component Card: SquircleRect {
        width: root.column
        radius: Math.max(3, Appearance.rounding.large * root.ratio * 1.6)
        color: Appearance.colour.surface
    }

    component Bar: SquircleRect {
        property bool faint: false

        height: Math.max(2, root.column * 0.05)
        pill: "place"
        color: faint ? Appearance.colour.textGhost : Appearance.colour.textFaint
    }
}
