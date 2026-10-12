pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.controls

Column {
    id: root

    spacing: Appearance.padding.normal

    readonly property var timerPresets: [1, 5, 10, 25]

    readonly property int dawnHour: 6
    readonly property int duskHour: 18

    readonly property int zoneListMax: 8

    readonly property int scrubDetent: 5

    readonly property int hoursInDay: 24
    readonly property int daysInWeek: 7
    readonly property int oneMinute: 60000

    readonly property int mark: Appearance.font.stem

    SystemClock {
        id: clock

        precision: SystemClock.Minutes

        enabled: root.visible
    }

    readonly property double now: clock.date.getTime()

    readonly property real localHour: clock.date.getHours() + clock.date.getMinutes() / 60

    property double timersSeen: Date.now()

    Connections {
        target: Clock

        function onTimersChanged(): void {
            root.timersSeen = Date.now();
        }
    }

    readonly property double beat: Math.max(Clock.tick, root.timersSeen)

    property bool picking: false

    readonly property string query: filter.value

    property string editing: ""

    property int setHours: 0
    property int setMinutes: 0
    property int setSeconds: 0

    readonly property int composedSeconds: root.setHours * 3600 + root.setMinutes * 60 + root.setSeconds

    readonly property var alarmRows: Clock.alarms.slice().sort((a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute))

    readonly property var matches: {
        if (!root.picking)
            return [];
        const q = root.query.toLowerCase();
        return Clock.allZones.filter(z => z !== Clock.localZone && !Clock.places.includes(z) && z.toLowerCase().includes(q)).slice(0, root.zoneListMax);
    }

    function clockText(ms: double): string {
        const total = Math.max(0, Math.ceil(ms / 1000));
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = total % 60;
        return h > 0 ? `${h}:${Clock.twoDigits(m)}:${Clock.twoDigits(s)}` : `${m}:${Clock.twoDigits(s)}`;
    }

    function zoneDetail(delta: int, dayDelta: int): string {
        const offset = Clock.offsetLabel(delta);
        if (dayDelta === 0)
            return offset;
        return `${offset} · ${dayDelta > 0 ? "tomorrow" : "yesterday"}`;
    }

    function alarmDetail(alarm: var): string {
        if (alarm.missed)
            return "missed";
        if (alarm.days.length > 0)
            return alarm.days.map(d => Qt.locale().dayName(d + 1, Locale.ShortFormat)).join(" ");
        if (!alarm.armed)
            return "once";
        const next = Clock.nextFor(alarm, root.now);
        return next > 0 ? `in ${Clock.spanLabel(next - root.now)}` : "once";
    }

    function addPlace(id: string): void {
        Clock.addZone(id);
        root.picking = false;
    }

    component Eyebrow: StyledText {
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    component DayBar: Item {
        id: bar

        required property real hourOfDay

        implicitHeight: root.mark * 3
        height: implicitHeight

        Rectangle {
            y: (bar.height - height) / 2
            width: bar.width
            height: root.mark
            color: Appearance.colour.textGhost
        }

        Rectangle {
            x: root.dawnHour / root.hoursInDay * bar.width
            y: (bar.height - height) / 2
            width: (root.duskHour - root.dawnHour) / root.hoursInDay * bar.width
            height: root.mark
            color: Appearance.colour.fillStrong
        }

        Rectangle {
            x: bar.hourOfDay / root.hoursInDay * (bar.width - width)
            width: root.mark * 2
            height: bar.height
            color: Appearance.colour.text
        }
    }

    SquircleRect {
        id: ringing

        readonly property var alarm: Clock.ringing

        readonly property double due: Clock.ringingSince - Clock.ringingLate

        visible: !!ringing.alarm
        width: parent.width
        height: visible ? answers.y + answers.height + Appearance.padding.normal : 0
        radius: Appearance.rounding.normal

        color: Appearance.colour.accentFill

        StyledText {
            id: ringTime

            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.normal
            anchors.top: parent.top
            anchors.topMargin: Appearance.padding.normal

            text: ringing.visible ? Qt.formatDateTime(new Date(ringing.due), "HH:mm") : ""
            font.pixelSize: Appearance.font.size.large
            color: Appearance.colour.accent
        }

        StyledText {
            id: ringLabel

            anchors.left: ringTime.left
            anchors.top: ringTime.bottom
            anchors.right: ringLate.left
            anchors.rightMargin: Appearance.padding.normal

            visible: !!text
            text: ringing.alarm?.label ?? ""
            color: Appearance.colour.textDim
            font.pixelSize: Appearance.font.size.small
            elide: Text.ElideRight
        }

        StyledText {
            id: ringLate

            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.normal
            anchors.baseline: ringLabel.baseline

            visible: Clock.ringingLate >= root.oneMinute
            text: visible ? `late by ${Clock.spanLabel(Clock.ringingLate)}` : ""
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
        }

        Item {
            id: answers

            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.normal
            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.normal
            anchors.top: ringLabel.visible || ringLate.visible ? ringLabel.bottom : ringTime.bottom
            anchors.topMargin: Appearance.padding.normal

            height: stop.height

            Button {
                anchors.left: parent.left

                width: parent.width - stop.width - Appearance.padding.large
                text: "Snooze"
                onClicked: Clock.snooze()
            }

            Button {
                id: stop

                anchors.right: parent.right

                text: "Stop"
                onClicked: Clock.stop()
            }
        }
    }

    Item {
        id: here

        width: parent.width
        height: hereTime.implicitHeight + Appearance.padding.small + hereBar.height

        StyledText {
            id: hereTime

            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.pixelSize: Appearance.font.size.large
        }

        StyledText {
            anchors.right: parent.right
            anchors.baseline: hereTime.baseline

            text: Qt.formatDateTime(clock.date, "ddd d MMM")
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
        }

        DayBar {
            id: hereBar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            hourOfDay: root.localHour
        }
    }

    Eyebrow {
        visible: Clock.zones.length > 0
        text: "ELSEWHERE"
    }

    Item {
        id: elsewhere

        visible: Clock.zones.length > 0
        width: parent.width
        height: zoneRows.implicitHeight

        Rectangle {
            x: root.localHour / root.hoursInDay * (elsewhere.width - root.mark * 2) + root.mark / 2
            width: root.mark
            height: elsewhere.height
            color: Appearance.colour.textGhost
        }

        Column {
            id: zoneRows

            width: parent.width
            spacing: 0

            Repeater {
                model: Clock.zones

                delegate: ClockCard {
                    id: zoneCard

                    required property var modelData

                    readonly property var at: Clock.zoneTime(zoneCard.modelData.offsetMinutes, root.now)

                    width: zoneRows.width
                    rowHeight: Math.max(Appearance.sizes.rowHeight, names.implicitHeight + Appearance.padding.small * 2 + zoneBar.height + Appearance.padding.small)

                    onDismissed: Clock.removeZone(zoneCard.modelData.id)

                    Column {
                        id: names

                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.right: timeThere.left
                        anchors.rightMargin: Appearance.padding.normal
                        anchors.top: parent.top
                        anchors.topMargin: Appearance.padding.small

                        spacing: 0

                        StyledText {
                            width: parent.width
                            text: zoneCard.modelData.city
                            color: Appearance.colour.textDim
                            elide: Text.ElideRight
                        }

                        StyledText {
                            width: parent.width
                            text: root.zoneDetail(zoneCard.modelData.deltaMinutes, zoneCard.at.dayDelta)
                            color: Appearance.colour.textFaint
                            font.pixelSize: Appearance.font.size.small
                            elide: Text.ElideRight
                        }
                    }

                    StyledText {
                        id: timeThere

                        anchors.right: parent.right
                        anchors.rightMargin: zoneCard.discSpace
                        anchors.top: parent.top
                        anchors.topMargin: Appearance.padding.small

                        text: zoneCard.at.text
                        font.pixelSize: Appearance.font.size.normal
                    }

                    DayBar {
                        id: zoneBar

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Appearance.padding.small

                        hourOfDay: zoneCard.at.hourOfDay
                    }
                }
            }
        }
    }

    Button {
        width: parent.width
        text: root.picking ? "Never mind" : "Add a place"
        onClicked: {
            root.picking = !root.picking;
            if (root.picking)
                Clock.loadZoneList();
        }
    }

    Item {
        id: picker

        visible: root.picking
        width: parent.width
        height: visible ? filter.height + zoneList.implicitHeight : 0

        ClockTextField {
            id: filter

            width: parent.width

            placeholder: "filter cities"
            onAccepted: if (root.matches.length > 0)
                root.addPlace(root.matches[0])

            onCancelled: root.picking = false
        }

        Column {
            id: zoneList

            anchors.top: filter.bottom
            width: parent.width

            Repeater {
                model: root.matches

                delegate: MenuRow {
                    required property var modelData

                    width: zoneList.width
                    label: Clock.cityOf(modelData)

                    detail: modelData.slice(0, Math.max(0, modelData.lastIndexOf("/"))).replace(/_/g, " ")
                    onActivated: root.addPlace(modelData)
                }
            }
        }
    }

    Separator {
        width: parent.width
    }

    Eyebrow {
        text: "TIMER"
    }

    Repeater {
        model: Clock.timers

        delegate: ClockCard {
            id: timerCard

            required property var modelData

            readonly property double remainingMs: Clock.remainingOf(timerCard.modelData, root.beat)
            readonly property real fraction: timerCard.modelData.total > 0 ? Math.max(0, Math.min(1, timerCard.remainingMs / timerCard.modelData.total)) : 0

            width: root.width
            rowHeight: Math.max(Appearance.sizes.rowHeight, remaining.implicitHeight + Appearance.padding.small * 2 + track.height + Appearance.padding.small)
            tappable: true

            onTapped: Clock.toggleTimer(timerCard.modelData.id)
            onDismissed: Clock.removeTimer(timerCard.modelData.id)

            StyledText {
                id: remaining

                anchors.left: parent.left
                anchors.leftMargin: Appearance.padding.normal
                anchors.top: parent.top
                anchors.topMargin: Appearance.padding.small

                text: root.clockText(timerCard.remainingMs)
                font.pixelSize: Appearance.font.size.large

                color: timerCard.modelData.finished ? Appearance.colour.accent : timerCard.modelData.paused ? Appearance.colour.textFaint : Appearance.colour.text
            }

            StyledText {
                anchors.right: parent.right
                anchors.rightMargin: timerCard.discSpace
                anchors.baseline: remaining.baseline

                text: `of ${root.clockText(timerCard.modelData.total)}`
                color: Appearance.colour.textFaint
                font.pixelSize: Appearance.font.size.small
            }

            SquircleRect {
                id: track

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.padding.small

                height: Appearance.sizes.sliderHeight
                radius: height / 2
                color: Appearance.colour.fill

                SquircleRect {
                    width: drain.value
                    height: parent.height
                    radius: height / 2
                    color: Appearance.colour.text
                    opacity: 0.55
                }
            }

            Follow {
                id: drain

                target: timerCard.fraction * track.width
                speed: Appearance.animation.trackSpeed
            }
        }
    }

    Item {
        id: setter

        width: parent.width
        height: fields.height

        Row {
            id: fields

            anchors.left: parent.left

            spacing: Appearance.padding.small

            ClockScrubField {
                value: root.setHours
                to: 23
                detent: 1
                onMoved: v => root.setHours = v
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: ":"
                font.pixelSize: Appearance.font.size.large
                color: Appearance.colour.textFaint
            }

            ClockScrubField {
                value: root.setMinutes
                detent: root.scrubDetent
                onMoved: v => root.setMinutes = v
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: ":"
                font.pixelSize: Appearance.font.size.large
                color: Appearance.colour.textFaint
            }

            ClockScrubField {
                value: root.setSeconds
                detent: root.scrubDetent
                onMoved: v => root.setSeconds = v
            }
        }

        Button {
            anchors.right: parent.right
            anchors.verticalCenter: fields.verticalCenter

            visible: root.composedSeconds > 0
            text: "Start"
            onClicked: Clock.startTimer(root.composedSeconds, "")
        }
    }

    Item {
        id: presets

        width: parent.width
        height: childrenRect.height

        Repeater {
            model: root.timerPresets

            delegate: Button {
                required property int index
                required property var modelData

                readonly property int count: root.timerPresets.length

                x: count > 1 ? index * (presets.width - width) / (count - 1) : (presets.width - width) / 2
                width: (presets.width - Appearance.padding.small * (count - 1)) / count

                text: `${modelData}m`
                onClicked: Clock.startTimer(modelData * 60, "")
            }
        }
    }

    Separator {
        width: parent.width
    }

    Eyebrow {
        text: "ALARM"
    }

    Repeater {
        model: root.alarmRows

        delegate: ClockCard {
            id: alarmCard

            required property var modelData

            readonly property bool open: root.editing === alarmCard.modelData.id

            width: root.width
            rowHeight: head.height + (alarmCard.open ? editor.implicitHeight + Appearance.padding.normal : 0)
            tappable: true

            onTapped: root.editing = alarmCard.open ? "" : alarmCard.modelData.id
            onDismissed: Clock.removeAlarm(alarmCard.modelData.id)

            Item {
                id: head

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top

                height: Math.max(Appearance.sizes.rowHeight, times.implicitHeight + Appearance.padding.small * 2)

                Column {
                    id: times

                    anchors.left: parent.left
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.right: armed.left
                    anchors.rightMargin: Appearance.padding.normal
                    anchors.verticalCenter: parent.verticalCenter

                    spacing: 0

                    StyledText {
                        width: parent.width
                        text: `${Clock.twoDigits(alarmCard.modelData.hour)}:${Clock.twoDigits(alarmCard.modelData.minute)}`
                        font.pixelSize: Appearance.font.size.normal
                    }

                    StyledText {
                        width: parent.width
                        text: root.alarmDetail(alarmCard.modelData)
                        color: Appearance.colour.textFaint
                        font.pixelSize: Appearance.font.size.small
                        elide: Text.ElideRight
                    }
                }

                Toggle {
                    id: armed

                    anchors.right: parent.right
                    anchors.rightMargin: alarmCard.discSpace
                    anchors.verticalCenter: parent.verticalCenter

                    checked: alarmCard.modelData.armed
                    onToggled: Clock.setAlarmArmed(alarmCard.modelData.id, !alarmCard.modelData.armed)
                }
            }

            Column {
                id: editor

                anchors.left: parent.left
                anchors.leftMargin: Appearance.padding.normal
                anchors.right: parent.right
                anchors.rightMargin: Appearance.padding.normal
                anchors.top: head.bottom
                anchors.topMargin: Appearance.padding.normal

                visible: alarmCard.open
                spacing: Appearance.padding.small

                Row {
                    spacing: Appearance.padding.small

                    ClockScrubField {
                        value: alarmCard.modelData.hour
                        to: 23
                        detent: 1

                        zeroIsEmpty: false
                        onCommitted: v => Clock.setAlarm(alarmCard.modelData.id, {
                                hour: v
                            })
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ":"
                        font.pixelSize: Appearance.font.size.large
                        color: Appearance.colour.textFaint
                    }

                    ClockScrubField {
                        value: alarmCard.modelData.minute
                        detent: root.scrubDetent
                        zeroIsEmpty: false
                        onCommitted: v => Clock.setAlarm(alarmCard.modelData.id, {
                                minute: v
                            })
                    }
                }

                Row {
                    id: days

                    width: parent.width
                    spacing: Appearance.padding.small

                    Repeater {
                        model: root.daysInWeek

                        delegate: Button {
                            required property int index

                            width: (days.width - days.spacing * (root.daysInWeek - 1)) / root.daysInWeek

                            text: Qt.locale().dayName(index + 1, Locale.NarrowFormat).toUpperCase()
                            checkable: true
                            checked: alarmCard.modelData.days.includes(index)
                            onToggled: {
                                const was = alarmCard.modelData.days;
                                Clock.setAlarm(alarmCard.modelData.id, {
                                    days: was.includes(index) ? was.filter(d => d !== index) : [...was, index]
                                });
                            }
                        }
                    }
                }

                Segments {
                    id: modeChoice

                    readonly property var modes: ["none", "command", "cloud"]

                    width: parent.width

                    options: ["Nothing", "Command", "Cloud"]
                    current: Math.max(0, modeChoice.modes.indexOf(alarmCard.modelData.mode))
                    onPicked: index => Clock.setAlarm(alarmCard.modelData.id, {
                            mode: modeChoice.modes[index]
                        })
                }

                ClockTextField {
                    width: parent.width

                    visible: alarmCard.modelData.mode !== "none"

                    autoFocus: false
                    seed: alarmCard.modelData.payload
                    placeholder: alarmCard.modelData.mode === "cloud" ? "what to ask" : "what to run"
                    onCommitted: text => Clock.setAlarm(alarmCard.modelData.id, {
                            payload: text
                        })
                }
            }
        }
    }

    Button {
        width: parent.width
        text: "Add an alarm"
        onClicked: {
            const id = Clock.addAlarm();
            if (id)
                root.editing = id;
        }
    }
}
