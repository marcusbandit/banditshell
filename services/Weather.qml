pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.config
import qs.components
import "weather.js" as Forecast

Singleton {
    id: root

    readonly property var cfg: Config.values.weather
    readonly property bool wanted: root.cfg.show
    readonly property bool imperial: root.cfg.units === "imperial"
    readonly property string location: root.cfg.location ?? ""
    readonly property bool online: Networking.connectivity === NetworkConnectivity.Full

    property var current: null
    property double fetchedAt: 0
    property string fetchedFor: ""
    property string place: ""
    property var coordinates: null
    property var wttrData: null
    property var outlook: []
    property bool outlookImperial: false
    property string failure: ""
    property string failedFor: ""

    readonly property bool failed: root.wanted && root.failure !== ""
    readonly property bool ready: root.wanted && !!root.current && (root.failure === "" || root.failure !== "place" && root.failedFor === root.fetchedFor)
    readonly property bool stale: root.ready && root.failed
    readonly property bool loading: reader.running
    readonly property var failureLook: Forecast.failureLook(root.failure)
    readonly property string temperature: root.current ? `${root.imperial ? root.current.temp_F : root.current.temp_C}°${root.imperial ? "F" : "C"}` : ""
    readonly property string summary: root.current?.weatherDesc?.[0]?.value ?? ""
    readonly property var forecast: root.outlook.length > 0 && root.outlookImperial === root.imperial ? root.outlook : Forecast.wttrDays(root.wttrData, root.imperial)
    readonly property bool forecastReady: root.forecast.length > 0 && (root.failure === "" || root.ready)
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
    onLocationChanged: root.refresh()
    onOnlineChanged: if (root.online && root.failure === "offline")
        root.retry()

    function refresh(): void {
        const place = root.location;
        const fresh = Date.now() - root.fetchedAt < Math.max(5, root.cfg.minutes) * 60000;
        if (!fresh || place !== root.fetchedFor || root.failure !== "")
            root.retry();
    }

    function retry(): void {
        if (!root.wanted || reader.running)
            return;
        const place = root.location;
        reader.place = place;
        reader.command = ["curl", "-sS", "--max-time", "10", "-w", "\n%{http_code} %{exitcode}", `https://wttr.in/${encodeURIComponent(place)}?format=j1`];
        reader.running = true;
    }

    function take(place: string, output: string): void {
        const answer = Forecast.readWttr(output);
        if (answer.failure) {
            root.failure = answer.failure;
            root.failedFor = place;
            return;
        }
        root.failure = "";
        root.failedFor = "";
        root.current = answer.data.current_condition[0];
        root.wttrData = answer.data;
        root.place = Forecast.placeOf(answer.data);
        root.coordinates = Forecast.coordsOf(answer.data);
        root.fetchedAt = Date.now();
        root.fetchedFor = place;
        root.loadOutlook();
    }

    Process {
        id: reader

        property string place: ""

        stdout: StdioCollector {
            onStreamFinished: root.take(reader.place, text)
        }

        onRunningChanged: if (!reader.running && reader.place !== root.location)
            Qt.callLater(root.retry)
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

    WallClock {
        id: clock

        precision: WallClock.Hours
        enabled: root.wanted
    }
}
