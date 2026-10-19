pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "localisation.js" as Rules

Singleton {
    id: root

    readonly property var languages: Rules.LANGUAGES
    readonly property var formats: Rules.FORMATS

    property var zoneTable: []
    property var generated: []
    property var locale: ({})
    property var position: null

    property string geocluePath: ""
    property bool geoclueProbed: false
    readonly property bool geoclueInstalled: root.geocluePath !== ""

    property string busy: ""

    readonly property string path: `${Config.stateDir}/region.json`

    readonly property string zoneTablePath: Quickshell.env("TZDIR") || "/usr/share/zoneinfo"

    readonly property bool zoneFollowsNetwork: Config.values.region.autoZone && root.geoclueInstalled

    readonly property string language: Rules.currentChoice(root.languages, Rules.languageOf(root.locale))
    readonly property string formatsId: Rules.currentChoice(root.formats, Rules.formatsOf(root.locale))

    readonly property var languageChoices: Rules.choices(root.languages, root.generated)
    readonly property var formatChoices: Rules.choices(root.formats, root.generated)

    readonly property var zoneChoices: Rules.zoneChoices(Clock.localZone, [root.suggestedZone].concat(Clock.places), Clock.allZones)

    readonly property var sunPlace: {
        if (root.position && root.position.zone === Clock.localZone)
            return root.position;
        return Rules.placeOfZone(root.zoneTable, Clock.localZone);
    }

    property string refusedZone: ""
    property string suggestedZone: ""

    signal failed(string why)
    signal zoneMoved(string zone)

    function hasLocale(id: string): bool {
        return Rules.hasLocale(root.generated, id);
    }

    function labelOf(options: var, id: string): string {
        return Rules.labelOf(options, id);
    }

    function setZone(id: string): void {
        if (!Clock.validZone(id) || id === Clock.localZone)
            return;
        root.change("zone", ["timedatectl", "set-timezone", id]);
    }

    function setLanguage(id: string): void {
        if (Rules.sameLocale(id, Rules.languageOf(root.locale)))
            return;
        root.change("locale", ["localectl", "set-locale", ...Rules.localeArguments(root.locale, {
                language: id
            })]);
    }

    function setFormats(id: string): void {
        if (Rules.sameLocale(id, Rules.formatsOf(root.locale)))
            return;
        root.change("locale", ["localectl", "set-locale", ...Rules.localeArguments(root.locale, {
                formats: id
            })]);
    }

    function setAutomaticZone(on: bool): void {
        if (!on) {
            Config.set("region.autoZone", false);
            return;
        }
        if (!root.geoclueInstalled)
            return;
        root.refusedZone = "";
        Config.set("region.autoZone", true);
        root.locate(false);
    }

    function locate(quietly: bool): void {
        if (!root.geoclueInstalled || locator.running || root.busy)
            return;
        root.busy = "locating";
        locator.quietly = quietly;
        locator.command = [root.geocluePath, "-t", "20"];
        locator.running = true;
    }

    function placeFound(place: var, quietly: bool): void {
        const near = Rules.nearestZone(root.zoneTable, place);
        if (!near) {
            root.failed("no zone table to place you with");
            return;
        }
        root.position = {
            lat: place.lat,
            lon: place.lon,
            zone: near.zone
        };
        root.remember();
        if (quietly)
            root.suggestedZone = near.zone !== Clock.localZone ? near.zone : "";
        else if (near.zone !== root.refusedZone)
            root.setZone(near.zone);
    }

    function change(kind: string, command: var): void {
        if (changer.running)
            return;
        root.busy = kind;
        changer.kind = kind;
        changer.target = kind === "zone" ? command[command.length - 1] : "";
        changer.command = command;
        changer.running = true;
    }

    function readLocale(): void {
        if (!localeStatus.running)
            localeStatus.running = true;
    }

    function remember(): void {
        store.setText(JSON.stringify({
            position: root.position
        }, null, 4) + "\n");
    }

    Component.onCompleted: {
        zoneTableReader.running = true;
        geoclueProbe.running = true;
        localeList.running = true;
        root.readLocale();
        Clock.loadZoneList();
    }

    FileView {
        id: store

        path: root.path
        printErrors: false

        onLoaded: {
            try {
                const disk = JSON.parse(text());
                const p = disk?.position;
                if (p && Number.isFinite(p.lat) && Number.isFinite(p.lon) && typeof p.zone === "string")
                    root.position = p;
            } catch (e) {
                console.warn(`Localisation: ${root.path} is not valid JSON, so the last position is forgotten`);
            }
        }
    }

    Process {
        id: zoneTableReader

        command: ["sh", "-c", `cat "${root.zoneTablePath}/zone.tab" "${root.zoneTablePath}/zone1970.tab" 2>/dev/null`]

        stdout: StdioCollector {
            onStreamFinished: root.zoneTable = Rules.parseZoneTable(text)
        }
    }

    Process {
        id: geoclueProbe

        command: ["sh", "-c", "for p in /usr/lib/geoclue-2.0/demos/where-am-i /usr/libexec/geoclue-2.0/demos/where-am-i; do [ -x \"$p\" ] && { echo \"$p\"; exit 0; }; done; command -v where-am-i"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.geocluePath = text.trim().split("\n")[0] ?? "";
                root.geoclueProbed = true;
            }
        }
    }

    Process {
        id: localeStatus

        command: ["localectl", "status"]

        stdout: StdioCollector {
            onStreamFinished: root.locale = Rules.parseLocaleStatus(text)
        }
    }

    Process {
        id: localeList

        command: ["localectl", "list-locales"]

        stdout: StdioCollector {
            onStreamFinished: root.generated = Rules.parseLocales(text)
        }
    }

    Process {
        id: locator

        property bool quietly: false

        stdout: StdioCollector {
            id: located
        }

        onExited: {
            root.busy = "";
            const place = Rules.parseWhereAmI(located.text);
            if (place)
                root.placeFound(place, locator.quietly);
            else if (!locator.quietly)
                root.failed("geoclue could not say where you are");
        }
    }

    Process {
        id: changer

        property string kind: ""
        property string target: ""

        stderr: StdioCollector {
            id: complaint
        }

        onExited: code => {
            root.busy = "";
            if (code !== 0) {
                if (changer.kind === "zone")
                    root.refusedZone = changer.target;
                root.failed(complaint.text.trim().split("\n")[0] || "the system would not take it");
            } else if (changer.kind === "zone") {
                Date.timeZoneUpdated();
                root.zoneMoved(changer.target);
            }
            if (changer.kind === "zone")
                Clock.readLocalZone();
            else
                root.readLocale();
        }
    }

    onGeoclueProbedChanged: {
        if (root.zoneFollowsNetwork)
            root.locate(true);
    }

    Connections {
        target: Clock

        function onLocalZoneChanged(): void {
            if (Clock.localZone === root.suggestedZone)
                root.suggestedZone = "";
        }
    }

    Connections {
        target: NetworkEvents

        function onChanged(): void {
            if (root.zoneFollowsNetwork)
                relocate.restart();
        }
    }

    Timer {
        id: relocate

        interval: 60000
        onTriggered: root.locate(true)
    }
}
