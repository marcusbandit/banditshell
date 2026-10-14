pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.config

Item {
    id: root

    property string text: ""
    property string icon: ""
    property real iconFill: 0
    property string style: "tonal"
    property int size: 1
    property bool checkable: false
    property bool checked: false
    signal toggled

    signal clicked

    property bool interactive: true

    property bool alarm: false

    readonly property bool hovered: root.interactive && press.containsMouse
    readonly property bool pressed: root.interactive && press.pressed

    readonly property real labelSize: root.size < 2 ? Appearance.font.size.small : root.size < 3 ? Appearance.font.size.normal : Appearance.font.size.large
    readonly property real padX: Appearance.button.padX(root.size)
    readonly property real markSize: Appearance.button.iconSize(root.size)
    readonly property real markGap: Appearance.button.iconGap(root.size)

    readonly property bool hasText: root.text !== ""
    readonly property bool hasIcon: root.icon !== ""
    readonly property real markSpan: root.hasIcon ? markSize + (root.hasText ? markGap : 0) : 0

    opacity: root.interactive ? 1 : 0.45

    readonly property var skins: ({
            "default": {
                filled: {
                    bg: Appearance.colour.accent,
                    fg: Appearance.colour.accentText,
                    ring: "transparent",
                    ringW: 0,
                    shape: "round"
                },
                elevated: {
                    bg: Appearance.colour.surfaceSolid,
                    fg: Appearance.colour.text,
                    ring: "transparent",
                    ringW: 0,
                    shape: "round"
                },
                tonal: {
                    bg: Appearance.colour.accentFill,
                    fg: Appearance.colour.text,
                    ring: "transparent",
                    ringW: 0,
                    shape: "round"
                },
                outlined: {
                    bg: "transparent",
                    fg: Appearance.colour.text,
                    ring: Appearance.colour.fillStrong,
                    ringW: Appearance.font.stem,
                    shape: "round"
                },
                text: {
                    bg: "transparent",
                    fg: Appearance.colour.text,
                    ring: "transparent",
                    ringW: 0,
                    shape: "round"
                }
            },
            unselected: {
                filled: {
                    bg: Appearance.blend(
                        Appearance.colour.surfaceSolid,
                        Appearance.blend(Appearance.colour.surfaceSolid, Appearance.colour.accent, Appearance.colour.veilWeight),
                        0.5),
                    fg: Appearance.colour.text,
                    ring: "transparent",
                    ringW: 0,
                    shape: "round"
                },
                elevated: {
                    bg: Appearance.colour.surfaceSolid,
                    fg: Appearance.colour.text,
                    ring: "transparent",
                    ringW: 0,
                    shape: "round"
                },
                tonal: {
                    bg: Appearance.colour.accentFillDull,
                    fg: Appearance.colour.text,
                    ring: "transparent",
                    ringW: 0,
                    shape: "round"
                },
                outlined: {
                    bg: "transparent",
                    fg: Appearance.colour.text,
                    ring: Appearance.colour.fillStrong,
                    ringW: Appearance.font.stem,
                    shape: "round"
                }
            },
            selected: {
                filled: {
                    bg: Appearance.colour.accent,
                    fg: Appearance.colour.accentText,
                    ring: "transparent",
                    ringW: 0,
                    shape: "square"
                },
                elevated: {
                    bg: Appearance.colour.accent,
                    fg: Appearance.colour.accentText,
                    ring: "transparent",
                    ringW: 0,
                    shape: "square"
                },
                tonal: {
                    bg: Appearance.colour.accentFill,
                    fg: Appearance.colour.text,
                    ring: "transparent",
                    ringW: 0,
                    shape: "square"
                },
                outlined: {
                    bg: Appearance.colour.fillStrong,
                    fg: Appearance.colour.text,
                    ring: "transparent",
                    ringW: 0,
                    shape: "square"
                }
            }
        })

    readonly property var skin: {
        const tier = root.checkable ? (root.checked ? root.skins.selected : root.skins.unselected) : root.skins["default"];
        return tier[root.style] ?? root.skins["default"][root.style] ?? root.skins["default"].tonal;
    }

    property var paint
    readonly property color bg: {
        const base = root.paint ?? root.skin.bg;

        if (!root.interactive)
            return base;
        if (root.pressed)
            return Appearance.blend(base, root.fg, 0.18);
        if (root.hovered)
            return Appearance.blend(base, root.fg, 0.09);
        return base;
    }

    property real radiusLeft: -1
    property real radiusRight: -1

    readonly property color fg: root.alarm ? Appearance.colour.alarm : root.skin.fg
    readonly property color ring: root.skin.ring
    readonly property real ringW: root.skin.ringW

    readonly property string skinShape: root.skin.shape ?? "round"
    readonly property real targetRadius: root.pressed ? (skinShape === "round" ? Appearance.rounding.normal : Appearance.rounding.large) : skinShape === "round" ? height / 2 : Appearance.rounding.normal

    readonly property real platePower: skinShape === "round" ? 2 : Appearance.rounding.power

    implicitWidth: root.hasText ? label.implicitWidth + markSpan + padX * 2 : implicitHeight
    implicitHeight: Math.max(Appearance.sizes.minTarget, Appearance.button.height(root.size))
    width: implicitWidth
    height: implicitHeight

    Loader {
        anchors.fill: parent

        active: root.style === "elevated"

        sourceComponent: Item {
            SquircleRect {
                id: cast

                visible: false
                anchors.fill: parent
                radius: root.targetRadius
                topLeftRadius: root.radiusLeft >= 0 ? root.radiusLeft : root.targetRadius
                bottomLeftRadius: root.radiusLeft >= 0 ? root.radiusLeft : root.targetRadius
                topRightRadius: root.radiusRight >= 0 ? root.radiusRight : root.targetRadius
                bottomRightRadius: root.radiusRight >= 0 ? root.radiusRight : root.targetRadius
                cornerPower: root.platePower
                color: "black"

                Behavior on radius {
                    NumberAnimation {
                        duration: Appearance.animation.fast
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on cornerPower {
                    NumberAnimation {
                        duration: Appearance.animation.fast
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MultiEffect {
                source: cast
                anchors.fill: cast

                shadowEnabled: true
                shadowColor: Appearance.colour.scrim
                shadowBlur: 0.55
                shadowVerticalOffset: Math.max(2, Math.round(root.height / 10))
            }
        }
    }

    SquircleRect {
        id: plate

        anchors.fill: parent
        radius: root.targetRadius
        topLeftRadius: root.radiusLeft >= 0 ? root.radiusLeft : root.targetRadius
        bottomLeftRadius: root.radiusLeft >= 0 ? root.radiusLeft : root.targetRadius
        topRightRadius: root.radiusRight >= 0 ? root.radiusRight : root.targetRadius
        bottomRightRadius: root.radiusRight >= 0 ? root.radiusRight : root.targetRadius
        cornerPower: root.platePower
        color: root.bg
        stroke: root.ring
        strokeWidth: root.ringW

        Behavior on radius {
            NumberAnimation {
                duration: Appearance.animation.fast
                easing.type: Easing.OutCubic
            }
        }

        Behavior on cornerPower {
            NumberAnimation {
                duration: Appearance.animation.fast
                easing.type: Easing.OutCubic
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.fast
            }
        }
    }

    scale: root.pressed ? Appearance.press.plate : 1

    Behavior on scale {
        NumberAnimation {
            duration: Appearance.animation.fast
            easing.type: Easing.OutCubic
        }
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.hasText && root.hasIcon ? root.markGap : 0

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasIcon
            name: root.icon
            fill: root.iconFill
            size: root.markSize
            color: root.fg
        }

        StyledText {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasText
            width: visible ? Math.min(implicitWidth, root.width - root.padX * 2 - root.markSpan) : 0
            text: root.text
            font.pixelSize: root.labelSize
            color: root.fg
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: press

        anchors.fill: parent
        anchors.margins: -Appearance.padding.small
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.checkable ? root.toggled() : root.clicked()
    }
}
