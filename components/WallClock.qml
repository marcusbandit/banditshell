import QtQuick
import "wall-clock.js" as Ticks

QtObject {
    id: root

    enum Precision {
        Hours,
        Minutes,
        Seconds
    }

    property int precision: WallClock.Seconds
    property bool enabled: true

    property date date: new Date(Ticks.floorTo(Date.now(), root.span))
    readonly property int hours: root.date.getHours()
    readonly property int minutes: root.date.getMinutes()
    readonly property int seconds: root.date.getSeconds()

    readonly property real span: root.precision === WallClock.Hours ? 3600000 : root.precision === WallClock.Seconds ? 1000 : 60000

    function tick(): void {
        if (!root.enabled) {
            root.ticker.stop();
            return;
        }
        const now = Date.now();
        const start = Ticks.floorTo(now, root.span);
        if (start !== root.date.getTime())
            root.date = new Date(start);
        root.ticker.interval = Math.min(Ticks.after(now, root.span) - now, 1000);
        root.ticker.restart();
    }

    onEnabledChanged: root.tick()
    onSpanChanged: root.tick()
    Component.onCompleted: root.tick()

    readonly property Timer ticker: Timer {
        onTriggered: root.tick()
    }
}
