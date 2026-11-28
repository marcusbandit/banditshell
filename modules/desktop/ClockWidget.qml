pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

DeskWidget {
    id: root

    property bool running: true
    property color ink: Appearance.colour.text

    readonly property real pad: Appearance.padding.card
    readonly property real tighten: Math.round(Appearance.font.size.hero * 0.84 - heroMetrics.height)
    readonly property bool trailing: root.place.side === "right"
    readonly property var nextAlarm: {
        const at = clock.date.getTime();
        let best = null;
        for (const alarm of Clock.alarms) {
            if (!alarm.armed)
                continue;
            const when = Clock.nextFor(alarm, at);
            if (when > 0 && (!best || when < best.when))
                best = {
                    when,
                    label: alarm.label
                };
        }
        return best;
    }

    readonly property string alarmText: {
        if (!root.nextAlarm)
            return "";
        const at = new Date(root.nextAlarm.when);
        const time = TimeFormat.clock(at.getHours(), at.getMinutes());
        return at.toDateString() === clock.date.toDateString() ? time : `${Qt.locale().dayName(at.getDay(), Locale.ShortFormat)} ${time}`;
    }

    key: "clock"
    fallbackSize: "medium"
    clearByDefault: true

    TextMetrics {
        id: heroMetrics

        font.family: Appearance.font.lock
        font.pixelSize: Appearance.font.size.hero
        font.weight: Font.Bold
        text: "0"
    }

    WallClock {
        id: clock

        precision: WallClock.Minutes
        enabled: root.running
    }

    FollowColour {
        id: tone

        target: root.backed || root.lifted ? Appearance.colour.text : root.ink
        speed: Appearance.animation.settleSpeed
    }

    small: Item {
        implicitWidth: smallLine.implicitWidth + root.pad * 2
        implicitHeight: smallLine.implicitHeight + root.pad * 2

        Row {
            id: smallLine

            x: root.pad
            y: root.pad
            spacing: Appearance.padding.normal

            StyledText {
                anchors.baseline: smallDate.baseline
                text: `${TimeFormat.hourPart(clock.date)}:${TimeFormat.minutePart(clock.date)}`
                font.family: Appearance.font.lock
                font.pixelSize: Appearance.font.size.display
                font.weight: Font.Bold
                color: tone.value
            }

            StyledText {
                id: smallDate

                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(Appearance.font.size.display * 0.12)
                text: TimeFormat.dateText(clock.date, "brief") ?? ""
                color: Qt.alpha(tone.value, 0.72)
            }
        }
    }

    medium: Item {
        implicitWidth: Math.max(digits.implicitWidth, headline.implicitWidth) + root.pad * 2
        implicitHeight: stack.implicitHeight + root.pad * 2

        Stack {
            id: stack

            x: root.pad
            y: root.pad
            width: parent.width - root.pad * 2

            Digits {
                id: digits
            }

            Headline {
                id: headline
            }
        }
    }

    large: Item {
        implicitWidth: Math.max(Math.round(Appearance.font.size.small * 20), bigDigits.implicitWidth, bigHeadline.implicitWidth) + root.pad * 2
        implicitHeight: body.implicitHeight + root.pad * 2

        Column {
            id: body

            x: root.pad
            y: root.pad
            width: parent.width - root.pad * 2
            spacing: Appearance.padding.large

            Stack {
                width: parent.width

                Digits {
                    id: bigDigits
                }

                Headline {
                    id: bigHeadline
                }
            }

            MonthGrid {
                span: parent.width
                today: clock.date
            }

            Column {
                width: parent.width
                visible: Clock.zones.length > 0 || !!root.nextAlarm
                spacing: Appearance.padding.small

                Repeater {
                    model: Clock.zones

                    delegate: Fact {
                        required property var modelData

                        readonly property var there: Clock.zoneTime(modelData.offsetMinutes, clock.date.getTime())

                        width: parent.width
                        icon: "public"
                        label: modelData.city
                        value: there.text
                        aside: Clock.offsetLabel(modelData.deltaMinutes)
                    }
                }

                Fact {
                    width: parent.width
                    visible: !!root.nextAlarm
                    icon: "alarm"
                    label: root.nextAlarm?.label || "Alarm"
                    value: root.alarmText
                    aside: ""
                }
            }
        }
    }

    component Stack: Column {
        spacing: Math.round(root.tighten * 0.45)
    }

    component Digits: Column {
        id: digitsColumn

        readonly property real size: Appearance.font.size.hero

        x: root.trailing ? parent.width - width : 0
        spacing: root.tighten

        StyledText {
            id: hours

            x: root.trailing ? parent.width - width : 0
            text: TimeFormat.hourPart(clock.date)
            font.family: Appearance.font.lock
            font.pixelSize: digitsColumn.size
            font.weight: Font.Bold
            color: tone.value
        }

        StyledText {
            x: root.trailing ? parent.width - width : 0
            text: TimeFormat.minutePart(clock.date)
            font.family: Appearance.font.lock
            font.pixelSize: digitsColumn.size
            font.weight: Font.Bold
            color: Qt.alpha(tone.value, 0.72)
        }
    }

    component Headline: StyledText {
        x: root.trailing ? parent.width - width : 0
        leftPadding: root.trailing ? 0 : Math.round(Appearance.font.size.hero * 0.05)
        rightPadding: root.trailing ? Math.round(Appearance.font.size.hero * 0.05) : 0
        text: TimeFormat.dateText(clock.date, "headline") ?? ""
        font.pixelSize: Appearance.font.size.large
        color: Qt.alpha(tone.value, 0.72)
    }

    component Fact: Item {
        id: fact

        property string icon: ""
        property string label: ""
        property string value: ""
        property string aside: ""

        implicitHeight: Math.max(factLabel.implicitHeight, factIcon.height)

        Icon {
            id: factIcon

            anchors.verticalCenter: parent.verticalCenter
            name: fact.icon
            size: Appearance.icon.small
            color: Appearance.colour.textFaint
        }

        StyledText {
            id: factLabel

            x: factIcon.width + Appearance.padding.small
            width: factValue.x - x - Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            text: fact.label
            color: Appearance.colour.textDim
            elide: Text.ElideRight
        }

        StyledText {
            id: factAside

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: fact.aside
            color: Appearance.colour.textFaint
        }

        StyledText {
            id: factValue

            anchors.right: factAside.left
            anchors.rightMargin: fact.aside ? Appearance.padding.normal : 0
            anchors.verticalCenter: parent.verticalCenter
            text: fact.value
            font.weight: Font.DemiBold
        }
    }
}
