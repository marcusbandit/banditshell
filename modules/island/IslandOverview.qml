pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property var activities: []
    property bool watched: false

    property real arrivals: 0
    property var carried: []
    property real carriedOpacity: 0

    signal chosen(var activity)

    readonly property real pad: Appearance.padding.card
    readonly property real spotPad: Appearance.padding.small

    component Spot: MouseArea {
        id: spot

        property string kind: ""

        z: -1
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.chosen({
            kind: spot.kind
        })

        Follow {
            id: lit

            speed: Appearance.animation.revealSpeed * 1.5
            epsilon: 0.005
            target: spot.containsMouse ? 1 : 0
        }

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: spot.pressed ? Appearance.colour.fillStrong : Appearance.colour.fill
            opacity: lit.value
            visible: lit.value > 0.01
        }
    }
    readonly property real topInset: Appearance.padding.large
    readonly property real arrivalsTop: column.y + clockBox.height
    readonly property real rowPitch: Appearance.font.line.small + Appearance.padding.small * 2 + rows.spacing

    readonly property var live: root.activities.filter(a => a.kind !== "notifications")
    readonly property var summary: root.activities.find(a => a.kind === "notifications") ?? null

    readonly property bool mediaHovered: media.visible && media.hovered

    readonly property rect coverRect: media.visible ? Qt.rect(column.x + media.x, column.y + media.y + media.coverTop, media.artSize, media.artSize) : Qt.rect(0, 0, 0, 0)

    function mediaParts(into: Item): var {
        return media.visible ? media.parts(into) : null;
    }

    function rowTop(key: string): real {
        const i = root.live.findIndex(a => a.key === key);
        return i < 0 ? -1 : column.y + rows.y + i * root.rowPitch;
    }

    implicitHeight: root.topInset + column.implicitHeight + root.pad

    onWatchedChanged: if (root.watched)
        Weather.refresh()

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
        enabled: root.watched
    }

    Column {
        id: column

        x: root.pad
        y: root.topInset
        width: root.width - root.pad * 2
        spacing: Appearance.padding.card

        Item {
            width: parent.width
            height: clockBox.height + root.arrivals

            Item {
                id: clockBox

                readonly property real line: time.y + time.baselineOffset

                width: parent.width
                height: clockBox.line

                HoverHandler {
                    id: dateHover
                }

                Spot {
                    x: -root.spotPad
                    y: -root.spotPad
                    width: time.x + time.width + seconds.implicitWidth + root.spotPad * 2
                    height: clockBox.height + root.spotPad * 2
                    kind: "timers"
                }

                Spot {
                    readonly property real ink: dateHover.hovered ? fullDate.implicitWidth : briefInk.tightBoundingRect.width

                    x: clockBox.width - ink - root.spotPad
                    y: -root.spotPad
                    width: ink + root.spotPad * 2
                    height: -dateCap.tightBoundingRect.y + root.spotPad * 2
                    kind: "calendar"
                }

                Spot {
                    x: weather.x - root.spotPad
                    y: weather.y - root.spotPad / 2
                    width: weather.width + root.spotPad * 2
                    height: weather.height + root.spotPad
                    visible: Weather.ready
                    kind: "weather"
                }

                TextMetrics {
                    id: clockInk

                    font: time.font
                    text: time.text
                }

                TextMetrics {
                    id: dateCap

                    font.family: Appearance.font.family
                    font.pixelSize: Appearance.font.size.small
                    text: "H"
                }

                StyledText {
                    id: time

                    x: -clockInk.tightBoundingRect.x
                    y: -(time.baselineOffset + clockInk.tightBoundingRect.y)
                    text: `${TimeFormat.hourPart(clock.date)}:${TimeFormat.minutePart(clock.date)}`
                    font.pixelSize: Appearance.font.size.display
                }

                StyledText {
                    id: seconds

                    anchors.left: time.right
                    anchors.baseline: time.baseline
                    text: Qt.formatDateTime(clock.date, ":ss")
                    color: secondsTone.value

                    FollowColour {
                        id: secondsTone

                        target: dateHover.hovered ? Appearance.colour.textDim : Appearance.colour.textFaint
                        speed: Appearance.animation.revealSpeed
                    }
                }

                Follow {
                    id: longDate

                    speed: Appearance.animation.snapSpeed
                    epsilon: 0.004
                    target: dateHover.hovered ? 1 : 0
                }

                TextMetrics {
                    id: briefInk

                    font: briefDate.font
                    text: briefDate.text
                }

                TextMetrics {
                    id: weatherInk

                    font: weatherText.font
                    text: weatherText.text
                }

                StyledText {
                    id: briefDate

                    anchors.right: parent.right
                    anchors.rightMargin: -(briefInk.advanceWidth - briefInk.tightBoundingRect.x - briefInk.tightBoundingRect.width)
                    y: -(briefDate.baselineOffset + dateCap.tightBoundingRect.y)
                    text: TimeFormat.dateText(clock.date, "brief")?.toLowerCase() ?? ""
                    color: Appearance.colour.textDim
                    opacity: 1 - longDate.value
                    visible: opacity > 0.01
                }

                StyledText {
                    id: fullDate

                    anchors.right: parent.right
                    y: briefDate.y
                    text: TimeFormat.dateText(clock.date, "headline") ?? ""
                    opacity: longDate.value
                    visible: opacity > 0.01
                }

                Row {
                    id: weather

                    anchors.right: parent.right
                    anchors.rightMargin: -(weatherInk.advanceWidth - weatherInk.tightBoundingRect.x - weatherInk.tightBoundingRect.width)
                    y: clockBox.line - weatherText.baselineOffset
                    spacing: Appearance.padding.hair
                    visible: Weather.ready

                    Icon {
                        anchors.verticalCenter: weatherText.verticalCenter
                        name: Weather.icon
                        size: Appearance.font.size.small
                        color: Appearance.colour.textDim
                    }

                    StyledText {
                        id: weatherText

                        text: Weather.temperature
                        color: Appearance.colour.textDim
                    }
                }
            }
        }

        Column {
            id: rows

            width: parent.width
            spacing: Appearance.padding.small
            visible: root.live.length > 0

            Repeater {
                model: ScriptModel {
                    values: root.live
                    objectProp: "key"
                }

                ActivityRow {
                    required property var modelData

                    width: rows.width
                    activity: modelData
                    lights: true
                    live: root.watched && opacity > 0.01
                    opacity: root.carried.includes(modelData.key) ? 1 - root.carriedOpacity : 1
                    enabled: !root.carried.includes(modelData.key)

                    onChosen: root.chosen(modelData)
                    onActed: name => root.chosen(Object.assign({}, modelData, {
                            action: name
                        }))
                }
            }
        }

        IslandMedia {
            id: media

            width: parent.width
            visible: Media.hasTrack
            watched: root.watched && Media.hasTrack

            onExpand: root.chosen({
                kind: "music"
            })
        }

        ActivityRow {
            width: parent.width
            visible: !!root.summary
            activity: root.summary
            lights: true
            live: root.watched

            onChosen: root.chosen(root.summary)
        }
    }
}
