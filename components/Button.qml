pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.config

// The button: the states of a button (enabled/disabled now; hovered, pressed and focused as
// they are specced), each holding tiers of skins - every entry a colour answer and a shape.
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

    readonly property bool hovered: root.interactive && press.containsMouse
    readonly property bool pressed: root.interactive && press.pressed

    readonly property real labelSize: Appearance.button.label(root.size)
    readonly property real padX: Appearance.button.padX(root.size)
    readonly property real markSize: Appearance.button.iconSize(root.size)
    readonly property real markGap: Appearance.button.iconGap(root.size)

    readonly property bool hasText: root.text !== ""
    readonly property bool hasIcon: root.icon !== ""
    readonly property real markSpan: root.hasIcon ? markSize + (root.hasText ? markGap : 0) : 0

    opacity: root.interactive ? 1 : 0.45

    // The skins: enabled is what a button is; disabled is the same shapes with sad colours -
    // monochrome, quiet, almost unseen - except outlined and text, which gain a fill so they
    // stay visible at all. A disabled toggle keeps the shape of its state.
    readonly property var skins: ({
            enabled: {
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
                        // Halfway between the elevated plate and the tonal plate, both as
                        // rendered over the surface.
                        bg: Appearance.blend(
                            Appearance.colour.surfaceSolid,
                            Appearance.blend(Appearance.colour.surfaceSolid, Appearance.colour.accent, Appearance.button.veilWeight),
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
                        // The outline's own colour becomes the body; the ring is gone.
                        bg: Appearance.colour.fillStrong,
                        fg: Appearance.colour.text,
                        ring: "transparent",
                        ringW: 0,
                        shape: "square"
                    }
                }
            },
            disabled: {
                "default": {
                    filled: {
                        bg: Appearance.colour.fill,
                        fg: Appearance.colour.textGhost,
                        ring: "transparent",
                        ringW: 0,
                        shape: "round"
                    },
                    elevated: {
                        bg: Appearance.colour.fill,
                        fg: Appearance.colour.textGhost,
                        ring: "transparent",
                        ringW: 0,
                        shape: "round"
                    },
                    tonal: {
                        bg: Appearance.colour.fill,
                        fg: Appearance.colour.textGhost,
                        ring: "transparent",
                        ringW: 0,
                        shape: "round"
                    },
                    outlined: {
                        bg: Appearance.colour.fill,
                        fg: Appearance.colour.textGhost,
                        ring: Appearance.colour.fillStrong,
                        ringW: Appearance.font.stem,
                        shape: "round"
                    },
                    text: {
                        bg: Appearance.colour.fill,
                        fg: Appearance.colour.textGhost,
                        ring: "transparent",
                        ringW: 0,
                        shape: "round"
                    }
                },
                unselected: {
                    filled: {
                        bg: Appearance.colour.fill,
                        fg: Appearance.colour.textGhost,
                        ring: "transparent",
                        ringW: 0,
                        shape: "round"
                    },
                    elevated: {
                        bg: Appearance.colour.fill,
                        fg: Appearance.colour.textGhost,
                        ring: "transparent",
                        ringW: 0,
                        shape: "round"
                    },
                    tonal: {
                        bg: Appearance.colour.fill,
                        fg: Appearance.colour.textGhost,
                        ring: "transparent",
                        ringW: 0,
                        shape: "round"
                    },
                    outlined: {
                        bg: Appearance.colour.fill,
                        fg: Appearance.colour.textGhost,
                        ring: Appearance.colour.fillStrong,
                        ringW: Appearance.font.stem,
                        shape: "round"
                    }
                },
                selected: {
                    filled: {
                        bg: Appearance.colour.fill,
                        fg: Appearance.colour.textGhost,
                        ring: "transparent",
                        ringW: 0,
                        shape: "square"
                    },
                    elevated: {
                        bg: Appearance.colour.fill,
                        fg: Appearance.colour.textGhost,
                        ring: "transparent",
                        ringW: 0,
                        shape: "square"
                    },
                    tonal: {
                        bg: Appearance.colour.fill,
                        fg: Appearance.colour.textGhost,
                        ring: "transparent",
                        ringW: 0,
                        shape: "square"
                    },
                    outlined: {
                        bg: Appearance.colour.fill,
                        fg: Appearance.colour.textGhost,
                        ring: Appearance.colour.fillStrong,
                        ringW: Appearance.font.stem,
                        shape: "square"
                    }
                }
            }
        })

    // The assignment: state tier by interactive, variant tier by checked, column by style.
    readonly property var stateTier: !root.interactive ? skins.disabled : skins.enabled
    readonly property var skin: {
        const tier = root.checkable ? (root.checked ? stateTier.selected : stateTier.unselected) : stateTier["default"];
        return tier[root.style] ?? stateTier["default"][root.style] ?? skins.enabled.tonal;
    }

    // The one escape hatch: a caller that paints the plate by state (the pen's readouts).
    property var paint
    readonly property color bg: root.paint ?? root.skin.bg

    readonly property color fg: root.skin.fg
    readonly property color ring: root.skin.ring
    readonly property real ringW: root.skin.ringW

    // The corners, from the skin's shape; pressed pulls one step toward the other shape.
    readonly property string skinShape: root.skin.shape ?? "round"
    readonly property real targetRadius: root.pressed ? (skinShape === "round" ? Appearance.rounding.normal : Appearance.rounding.large) : skinShape === "round" ? height / 2 : Appearance.rounding.normal

    // A fully round end is a circular arc (power 2); the square keeps the shell's G2 exponent.
    readonly property real platePower: skinShape === "round" ? 2 : Appearance.rounding.power

    implicitWidth: root.hasText ? label.implicitWidth + markSpan + padX * 2 : implicitHeight
    implicitHeight: Math.max(Appearance.sizes.minTarget, Appearance.button.height(root.size))
    width: implicitWidth
    height: implicitHeight

    // The shadow, for the elevated style alone; the cast is invisible and only sampled.
    G2Rect {
        id: cast

        visible: false
        anchors.fill: parent
        radius: root.targetRadius
        cornerPower: root.platePower
        color: "black"

        Behavior on radius {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutCubic
            }
        }

        Behavior on cornerPower {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutCubic
            }
        }
    }

    MultiEffect {
        source: cast
        anchors.fill: cast
        // Only rendered while the shadow is: the effect would draw the black cast otherwise.
        visible: root.style === "elevated"
        shadowEnabled: root.style === "elevated"
        shadowColor: Appearance.colour.scrim
        shadowBlur: 0.55
        shadowVerticalOffset: Math.max(2, Math.round(root.height / 10))
    }

    // The body: one shape, fill and/or ring.
    G2Rect {
        id: plate

        anchors.fill: parent
        radius: root.targetRadius
        cornerPower: root.platePower
        color: root.bg
        stroke: root.ring
        strokeWidth: root.ringW

        Behavior on radius {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutCubic
            }
        }

        Behavior on cornerPower {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutCubic
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    // The hover: one light over every emphasis.
    G2Rect {
        anchors.fill: parent
        radius: root.targetRadius
        cornerPower: root.platePower
        visible: root.hovered
        color: Appearance.colour.fill

        Behavior on radius {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutCubic
            }
        }

        Behavior on cornerPower {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutCubic
            }
        }
    }

    // Pressed INTO the plate: a button moves when pressed.
    scale: root.pressed ? 0.96 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Appearance.anim.fast
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
