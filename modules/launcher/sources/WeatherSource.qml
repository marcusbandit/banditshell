import QtQuick
import Quickshell
import qs.config
import qs.services
import "../../../services/weather.js" as Forecast

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["weather"]

    readonly property bool enabled: Config.values.launcher.online.weather !== false
    readonly property var asked: root.enabled ? Forecast.weatherAsk(root.search.text) : null
    readonly property string place: root.asked ? root.asked.place || Weather.location : ""
    readonly property bool shared: !!root.asked && root.place === Weather.location && Weather.ready && Weather.fetchedFor === Weather.location
    readonly property string wanted: root.asked && !root.shared ? root.place || "here" : ""

    onWantedChanged: lookup.want(root.wanted)

    readonly property bool intent: !!root.asked && !root.asked.loose

    readonly property var now: root.shared ? Forecast.nowOf(Weather.wttrData) : root.wanted ? lookup.answers[root.wanted] : null
    readonly property bool pending: !!root.wanted && lookup.answers[root.wanted] === undefined && lookup.failures[root.wanted] === undefined
    readonly property bool failed: !!root.wanted && lookup.failures[root.wanted] !== undefined

    readonly property string title: root.place || "your location"
    readonly property string where: root.place ? ` in ${root.place}` : ""

    readonly property var prefixes: !root.enabled ? [] : [
            {
                section: "Ask and look up",
                word: "weather",
                example: "weather paris",
                about: "Weather now in a place",
                icon: "partly_cloudy_day",
                also: ["forecast"]
            }
        ]

    readonly property var groups: [
        {
            key: "weather",
            title: "Weather",
            items: root.rows
        }
    ]

    readonly property var rows: {
        if (!root.asked)
            return [];
        const key = `weather:${root.title}`;
        if (root.now) {
            const text = Forecast.nowText(root.now, Weather.imperial);
            const dark = root.now.daytime === null ? Weather.night : !root.now.daytime;
            return [
                {
                    key: key,
                    kind: "weather",
                    label: text.label,
                    detail: text.detail,
                    icon: Weather.iconFor(root.now.code, dark),
                    place: root.place || root.now.place,
                    summary: `${text.label}${[root.now.place, root.now.country].filter(Boolean).join(", ") ? ` in ${[root.now.place, root.now.country].filter(Boolean).join(", ")}` : root.where}`,
                    score: root.asked.loose ? 0.3 : Infinity
                }
            ];
        }
        if (root.asked.loose)
            return [];
        if (root.pending)
            return [
                {
                    key: key,
                    kind: "weather",
                    label: `Looking up the weather${root.where}`,
                    detail: "",
                    icon: "partly_cloudy_day",
                    waiting: true,
                    score: Infinity
                }
            ];
        if (root.failed)
            return [
                {
                    key: key,
                    kind: "weather",
                    label: root.place ? `No weather found for ${root.place}` : "No weather found",
                    detail: "Check the spelling or the connection",
                    icon: "cloud_off",
                    waiting: true,
                    score: Infinity
                }
            ];
        return [];
    }

    property Lookup lookup: Lookup {
        delay: 450
        keep: 40
        freshFor: 15 * 60 * 1000
        commandFor: key => ["curl", "-sS", "--max-time", "10", "-w", "\n%{http_code} %{exitcode}", `https://wttr.in/${key === "here" ? "" : encodeURIComponent(key)}?format=j1`]
        read: text => {
            const got = Forecast.readWttr(text);
            return got.data ? Forecast.nowOf(got.data) : null;
        }
    }

    function pageUrl(row: var): string {
        return `https://wttr.in/${encodeURIComponent(row.place)}`;
    }

    function activate(row: var): void {
        if (row.waiting)
            return;
        const text = row.summary;
        root.search.leave(() => System.copyText(text));
    }

    function actionsFor(row: var): var {
        if (row.waiting)
            return [];
        return [
            {
                icon: "content_copy",
                label: "Copy",
                run: () => root.activate(row)
            },
            {
                icon: "open_in_new",
                label: "Open the forecast",
                short: "Open",
                run: () => {
                    const url = root.pageUrl(row);
                    root.search.launch(() => Quickshell.execDetached(["xdg-open", url]));
                }
            }
        ];
    }
}
