pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property var rules: [
        {
            apps: ["qbittorrent"],

            brief: body => body.replace(/\s+has finished downloading\.?\s*$/, "").replace(/\[[^\]]*\]\s*/g, "").replace(/\s+/g, " ").replace(/\s+([.,;:!?)])/g, "$1").replace(/^\s+|\s+$/g, "").replace(/^'(.*)'$/, "$1")
        }
    ]

    function ruleFor(entry: var): var {
        const names = [entry?.desktopEntry, entry?.appName].filter(n => n).map(n => n.toLowerCase());
        if (names.length === 0)
            return null;
        return root.rules.find(rule => rule.apps.some(app => names.some(name => name.includes(app)))) ?? null;
    }

    function briefFor(entry: var): string {
        const body = entry?.body ?? "";
        if (!body)
            return "";

        const rule = root.ruleFor(entry);
        if (!rule)
            return "";

        const short = rule.brief(body);
        return short && short !== body ? short : "";
    }
}
