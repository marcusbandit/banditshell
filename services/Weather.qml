pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property var cfg: Config.values.weather
    readonly property bool wanted: root.cfg.show
    readonly property bool imperial: root.cfg.units === "imperial"

    property var current: null
    property double fetchedAt: 0
    property string fetchedFor: ""

    readonly property bool ready: root.wanted && !!root.current
    readonly property string temperature: root.current ? `${root.imperial ? root.current.temp_F : root.current.temp_C}°${root.imperial ? "F" : "C"}` : ""
    readonly property string summary: root.current?.weatherDesc?.[0]?.value ?? ""
    readonly property bool night: {
        const hour = new Date().getHours();
        return hour < 6 || hour >= 20;
    }
    readonly property string icon: root.iconFor(Number(root.current?.weatherCode ?? 0), root.night)

    function iconFor(code: int, dark: bool): string {
        if (code === 113)
            return dark ? "clear_night" : "sunny";
        if (code === 116)
            return dark ? "partly_cloudy_night" : "partly_cloudy_day";
        if ([119, 122].includes(code))
            return "cloud";
        if ([143, 248, 260].includes(code))
            return "foggy";
        if ([200, 386, 389, 392, 395].includes(code))
            return "thunderstorm";
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371].includes(code))
            return "weather_snowy";
        if ([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].includes(code))
            return "weather_mix";
        if ([299, 302, 305, 308, 356, 359].includes(code))
            return "rainy_heavy";
        if ([176, 263, 266, 293, 296, 353].includes(code))
            return "rainy";
        return "cloud";
    }

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
                    const now = JSON.parse(text)?.current_condition?.[0];
                    if (!now)
                        return;
                    root.current = now;
                    root.fetchedAt = Date.now();
                    root.fetchedFor = reader.place;
                } catch (e) {}
            }
        }
    }
}
