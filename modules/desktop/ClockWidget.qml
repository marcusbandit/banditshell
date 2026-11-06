import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property bool running: true
    property color ink: Appearance.colour.text
    property bool backed: false
    property bool trailing: false

    readonly property real digits: Appearance.font.size.hero
    readonly property real tighten: Math.round(root.digits * 0.84 - hours.implicitHeight)
    readonly property real pad: Appearance.padding.card

    implicitHeight: stack.implicitHeight + root.pad * 2

    WallClock {
        id: clock

        precision: WallClock.Minutes
        enabled: root.running
    }

    FollowColour {
        id: tone

        target: root.backed ? Appearance.colour.text : root.ink
        speed: Appearance.animation.settleSpeed
    }

    SquircleRect {
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Appearance.colour.surface
        opacity: card.value

        Follow {
            id: card

            target: root.backed ? 1 : 0
            speed: Appearance.animation.settleSpeed
            epsilon: Appearance.animation.fadeEpsilon
            startsAtTarget: true
        }
    }

    Column {
        id: stack

        x: root.trailing ? root.width - root.pad - width : root.pad
        y: root.pad
        spacing: Math.round(root.tighten * 0.45)

        Column {
            x: root.trailing ? stack.width - width : 0
            spacing: root.tighten

            StyledText {
                id: hours

                x: root.trailing ? parent.width - width : 0
                text: TimeFormat.hourPart(clock.date)
                font.family: Appearance.font.lock
                font.pixelSize: root.digits
                font.weight: Font.Bold
                color: tone.value
            }

            StyledText {
                x: root.trailing ? parent.width - width : 0
                text: TimeFormat.minutePart(clock.date)
                font.family: Appearance.font.lock
                font.pixelSize: root.digits
                font.weight: Font.Bold
                color: Qt.alpha(tone.value, 0.72)
            }
        }

        StyledText {
            width: root.width - root.pad * 2
            horizontalAlignment: root.trailing ? Text.AlignRight : Text.AlignLeft
            leftPadding: root.trailing ? 0 : Math.round(root.digits * 0.05)
            rightPadding: root.trailing ? Math.round(root.digits * 0.05) : 0
            text: TimeFormat.dateText(clock.date, "headline") ?? ""
            font.pixelSize: Appearance.font.size.large
            fontSizeMode: Text.HorizontalFit
            elide: Text.ElideRight
            minimumPixelSize: Appearance.font.size.normal
            color: Qt.alpha(tone.value, 0.72)
        }
    }
}
