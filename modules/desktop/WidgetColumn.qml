import QtQuick
import qs.config
import qs.services

Flow {
    id: root

    property bool running: true
    property bool seen: true
    property bool fromRight: false
    property real room: 0
    property real availWidth: 0
    property color clockInk: Appearance.colour.text
    property bool clockBacked: false

    readonly property rect clockRect: clockCard.visible ? Qt.rect(clockCard.x, clockCard.y, clockCard.width, clockCard.height) : Qt.rect(0, 0, 0, 0)
    readonly property Item systemPopout: systemCard.visible ? systemCard.popoutItem : null

    readonly property var cfg: Config.values.widgets
    readonly property real cardWidth: Math.round(Appearance.font.size.small * 26)

    height: root.room
    flow: Flow.TopToBottom
    layoutDirection: root.fromRight ? Qt.RightToLeft : Qt.LeftToRight
    spacing: Appearance.padding.card

    ClockWidget {
        id: clockCard

        width: root.cardWidth
        visible: root.cfg.clock
        running: root.running
        ink: root.clockInk
        backed: root.clockBacked
        trailing: root.fromRight
    }

    CalendarWidget {
        width: root.cardWidth
        visible: root.cfg.calendar
        running: root.running
    }

    MediaWidget {
        width: root.cardWidth
        visible: root.cfg.media && Media.hasTrack
        running: root.running
    }

    WeatherWidget {
        width: root.cardWidth
        visible: root.cfg.weather && Weather.ready
    }

    SystemWidget {
        id: systemCard

        z: systemCard.expanded !== "" ? 10 : 0
        width: root.cardWidth
        visible: root.cfg.system
        running: root.running && root.cfg.system
        fromRight: root.fromRight
        room: root.room
        availWidth: root.availWidth
    }

    TimersWidget {
        width: root.cardWidth
        visible: root.cfg.timers
        running: root.seen
    }
}
