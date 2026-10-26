import QtQuick
import qs.config
import qs.components
import qs.services
import "../../services/weather.js" as Forecast

Item {
    id: root

    property bool watched: false
    property real maxHeight: 0
    readonly property real span: 1.5

    signal hide
    signal act(var notice)
    signal open(string key)

    readonly property real pad: Appearance.padding.card
    readonly property real natural: Appearance.padding.large + column.implicitHeight + root.pad
    readonly property var days: Weather.forecast
    readonly property var range: Forecast.weekRange(root.days)
    readonly property real barWidth: Appearance.padding.small
    readonly property real barHeight: Appearance.font.line.normal * 3
    readonly property bool blank: Weather.failed && !Weather.ready
    readonly property var look: Weather.failureLook

    implicitHeight: root.maxHeight > 0 ? Math.min(root.natural, root.maxHeight) : root.natural

    onWatchedChanged: if (root.watched)
        Weather.refresh()

    Component.onCompleted: if (root.watched)
        Weather.refresh()

    Flickable {
        id: scroller

        anchors.fill: parent
        contentHeight: root.natural
        interactive: root.natural > height
        boundsBehavior: Flickable.StopAtBounds
        clip: interactive

        WheelStep {
            flick: scroller
        }

        Column {
            id: column

            x: root.pad
            y: Appearance.padding.large
            width: root.width - root.pad * 2
            spacing: Appearance.padding.card

            TaskHeader {
                id: header

                width: parent.width
                icon: root.blank ? root.look.icon : Weather.icon
                tone: !root.blank ? Appearance.colour.accent : Weather.failure === "place" ? Appearance.colour.alarm : Appearance.colour.textDim
                title: Weather.ready ? `${Weather.temperature} ${Weather.summary.trim()}` : root.blank ? root.look.title : "Weather"
                subtitle: !root.blank ? Weather.place : Weather.failure !== "place" ? root.look.detail : Weather.failedFor ? `No town called "${Weather.failedFor}"` : "The weather service does not know this place"
                onClosed: root.hide()
            }

            Item {
                width: parent.width
                height: Math.max(guess.implicitHeight, take.implicitHeight)
                visible: !!Weather.placeSuggestion

                StyledText {
                    id: guess

                    anchors.left: parent.left
                    anchors.leftMargin: header.inset
                    anchors.right: take.left
                    anchors.rightMargin: Appearance.padding.normal
                    anchors.verticalCenter: parent.verticalCenter
                    text: `Did you mean ${Weather.placeSuggestion?.text ?? ""}?`
                    wrapMode: Text.Wrap
                }

                Button {
                    id: take

                    x: parent.width - width
                    anchors.verticalCenter: parent.verticalCenter
                    style: "accent"
                    icon: "check"
                    text: `Use ${Weather.placeSuggestion?.name ?? ""}`
                    onClicked: Weather.useSuggestion()
                }
            }

            Item {
                width: parent.width
                readonly property Item beside: fix.visible ? fix : again.visible && !root.blank ? again : null

                height: Math.max(notes.implicitHeight, again.visible ? again.implicitHeight : 0, fix.visible ? fix.implicitHeight : 0)
                visible: Weather.stale || Weather.failure === "place" || root.blank && root.look.retry

                Column {
                    id: notes

                    anchors.left: parent.left
                    anchors.leftMargin: header.inset
                    anchors.right: parent.beside ? parent.beside.left : parent.right
                    anchors.rightMargin: parent.beside ? Appearance.padding.normal : 0
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        width: parent.width
                        visible: Weather.stale
                        text: `${Forecast.ago(Weather.fetchedAt, age.date.getTime())}, ${root.look.note}`
                        color: Appearance.colour.textDim
                        wrapMode: Text.Wrap
                    }

                    StyledText {
                        width: parent.width
                        visible: Weather.failure === "place"
                        text: root.look.detail
                        wrapMode: Text.Wrap
                    }

                    StyledText {
                        width: parent.width
                        visible: Weather.failure === "place"
                        text: "The weather updates as soon as it is saved"
                        color: Appearance.colour.textDim
                        wrapMode: Text.Wrap
                    }
                }

                Button {
                    id: again

                    x: root.blank ? header.inset - again.padX : parent.width - width
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.look.retry
                    style: "bare"
                    icon: "refresh"
                    text: Weather.loading ? "Trying" : "Try again"
                    interactive: !Weather.loading
                    onClicked: Weather.retry()
                }

                Button {
                    id: fix

                    x: parent.width - width
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!root.look.fix
                    icon: "edit_location_alt"
                    text: "Change place"
                    onClicked: root.act({
                        kind: "settings",
                        row: root.look.fix
                    })
                }
            }

            StyledText {
                width: parent.width
                visible: !Weather.forecastReady && !Weather.failed
                text: Weather.wanted ? "Loading the forecast" : "Weather is turned off in settings"
                color: Appearance.colour.textDim
            }

            Row {
                id: strip

                width: parent.width
                visible: Weather.forecastReady

                Repeater {
                    model: root.days

                    delegate: Item {
                        id: cell

                        required property var modelData
                        required property int index

                        readonly property var bar: Forecast.barOf(cell.modelData, root.range)
                        readonly property real fillHeight: Math.max(root.barWidth, (cell.bar.to - cell.bar.from) * root.barHeight)

                        width: strip.width / Math.max(1, root.days.length)
                        height: stack.implicitHeight

                        Column {
                            id: stack

                            width: parent.width
                            spacing: Appearance.padding.small

                            StyledText {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: cell.index === 0 ? "Today" : Qt.locale().dayName(Forecast.dateOf(cell.modelData.date).getDay(), Locale.ShortFormat)
                                color: cell.index === 0 ? Appearance.colour.text : Appearance.colour.textDim
                                elide: Text.ElideRight
                            }

                            Item {
                                width: parent.width
                                height: Appearance.font.line.large

                                Icon {
                                    anchors.centerIn: parent
                                    name: cell.modelData.icon
                                    size: Appearance.font.line.large
                                    fill: 1
                                    color: Appearance.colour.accent
                                }
                            }

                            StyledText {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: `${cell.modelData.high}°`
                                font.pixelSize: Appearance.font.size.normal
                                color: Appearance.colour.text
                            }

                            Item {
                                width: parent.width
                                height: root.barHeight

                                SquircleRect {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: root.barWidth
                                    height: parent.height
                                    pill: "place"
                                    color: Appearance.colour.fillStrong

                                    SquircleRect {
                                        width: parent.width
                                        height: cell.fillHeight
                                        y: Math.min(parent.height - height, (1 - cell.bar.to) * parent.height)
                                        pill: "place"
                                        color: Appearance.colour.accent
                                    }
                                }
                            }

                            StyledText {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: `${cell.modelData.low}°`
                                font.pixelSize: Appearance.font.size.normal
                                color: Appearance.colour.textDim
                            }

                            Item {
                                width: parent.width
                                height: Appearance.font.line.small

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Appearance.padding.hair
                                    visible: !!rain.text

                                    Icon {
                                        anchors.verticalCenter: rain.verticalCenter
                                        name: "water_drop"
                                        size: Appearance.font.size.small
                                        fill: 1
                                        color: Appearance.colour.textFaint
                                    }

                                    StyledText {
                                        id: rain

                                        text: Forecast.rainText(cell.modelData)
                                        color: Appearance.colour.textFaint
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    WallClock {
        id: age

        precision: WallClock.Minutes
        enabled: root.watched && Weather.stale
    }
}
