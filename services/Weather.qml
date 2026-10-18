pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "weather.js" as Forecast

Singleton {
    id: root

    readonly property var cfg: Config.values.weather
    readonly property bool wanted: root.cfg.show
    readonly property bool imperial: root.cfg.units === "imperial"

    property var current: null
    property double fetchedAt: 0
    property string fetchedFor: ""
    property string place: ""
    property var coordinates: null
    property var wttrData: null
    property var outlook: []
    property bool outlookImperial: false

    readonly property bool ready: root.wanted && !!root.current
    readonly property string temperature: root.current ? `${root.imperial ? root.current.temp_F : root.current.temp_C}°${root.imperial ? "F" : "C"}` : ""
    readonly property string summary: root.current?.weatherDesc?.[0]?.value ?? ""
    readonly property var forecast: root.outlook.length > 0 && root.outlookImperial === root.imperial ? root.outlook : Forecast.wttrDays(root.wttrData, root.imperial)
    readonly property bool forecastReady: root.forecast.length > 0
    readonly property string forecastSource: root.outlook.length > 0 && root.outlookImperial === root.imperial ? "open-meteo" : "wttr"
    readonly property bool night: clock.hours < 6 || clock.hours >= 20
    readonly property string icon: root.iconFor(Number(root.current?.weatherCode ?? 0), root.night)

    function iconFor(code: int, dark: bool): string {
        return Forecast.wttrIcon(code, dark);
    }

    function loadOutlook(): void {
        if (!root.wanted || !root.coordinates || outlookReader.running)
            return;
        outlookReader.imperial = root.imperial;
        outlookReader.command = ["curl", "-fsS", "--max-time", "10", Forecast.outlookUrl(root.coordinates, root.imperial)];
        outlookReader.running = true;
    }

    onImperialChanged: root.loadOutlook()

    function refresh(): void {
        if (!root.wanted || reader.running)
            return;
        const place = root.cfg.location ?? "";
        const fresh = Date.now() - root.fetchedAt < Math.max(5, root.cfg.minutes) * 60000;
        if (fresh && place === root.fetchedFor)
            return;
        reader.place = place;
        reader.command = ["curl", "-fsS", "--max-time", "10", `https://wttr.in/${encodeURIComponent(place)}?format=j1`];
        reader.running = true;
    }

    Process {
        id: reader

        property string place: ""

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const now = data?.current_condition?.[0];
                    if (!now)
                        return;
                    root.current = now;
                    root.wttrData = data;
                    root.place = Forecast.placeOf(data);
                    root.coordinates = Forecast.coordsOf(data);
                    root.fetchedAt = Date.now();
                    root.fetchedFor = reader.place;
                    root.loadOutlook();
                } catch (e) {}
            }
        }
    }

    Process {
        id: outlookReader

        property bool imperial: false

        stdout: StdioCollector {
            onStreamFinished: {
                let days = [];
                try {
                    days = Forecast.outlookDays(JSON.parse(text));
                } catch (e) {}
                root.outlook = days;
                root.outlookImperial = outlookReader.imperial;
                if (outlookReader.imperial !== root.imperial)
                    Qt.callLater(root.loadOutlook);
            }
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Hours
        enabled: root.wanted
    }
}
