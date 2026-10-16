import QtQuick
import Quickshell
import qs.services
import "../../../services/ranking.js" as Ranking
import "../../../services/colours.js" as Colours
import "../../../services/colour-picks.js" as Picks

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["colourpick", "colour"]

    readonly property string ask: Picks.colourAsk(root.search.text)

    readonly property bool intent: root.ask !== ""

    readonly property real pickScore: {
        if (root.ask === "pick" || root.ask === "history")
            return Infinity;
        const t = root.search.text;
        if (t.length < 3)
            return 0;
        return Math.max(Ranking.place("pick colour", t), Ranking.place("colour picker", t), Ranking.place("pick color", t), Ranking.place("color picker", t)) - 1;
    }

    readonly property var installWords: ({
            "": "hyprpicker is not installed",
            trying: "installing hyprpicker",
            terminal: "installing in the terminal",
            failed: "hyprpicker did not install",
            nowhere: "no hyprpicker package for this system"
        })

    function pickRow(score: real): var {
        const latest = ColourPicks.history[0];
        return {
            key: "colourpick",
            kind: "colourpick",
            label: "Pick a colour",
            detail: !ColourPicks.found && ColourPicks.probed ? root.installWords[ColourPicks.installing] ?? root.installWords[""] : latest ? `last ${latest.hex}` : "",
            icon: "colorize",
            score: score
        };
    }

    function colourRow(pick: var, score: real): var {
        const colour = Colours.parseColour(pick.hex);
        return {
            key: `colour:${pick.hex}`,
            kind: "colour",
            hex: pick.hex,
            label: pick.hex,
            detail: colour ? `${Colours.rgbOf(colour)} · ${Colours.hslOf(colour)}` : "",
            icon: "palette",
            swatch: pick.hex,
            score: score
        };
    }

    readonly property var rows: {
        const out = [];
        if (root.pickScore > 0)
            out.push(root.pickRow(root.pickScore));
        if (root.ask === "history")
            return out.concat(ColourPicks.history.map(p => root.colourRow(p, Infinity)));
        if (root.ask === "pick")
            return out.concat(ColourPicks.history.slice(0, 4).map(p => root.colourRow(p, 1)));
        return out;
    }

    readonly property var groups: [
        {
            key: "colours",
            title: "Colours",
            items: root.rows
        }
    ]

    readonly property var caps: ({
            colours: 41
        })

    function copy(text: string): void {
        root.search.leave(() => Clipboard.copy({
                text: text
            }));
    }

    function pick(): void {
        if (!ColourPicks.found) {
            ColourPicks.install();
            return;
        }
        const screen = root.search.screenName;
        root.search.leave(() => ColourPicks.pick(screen));
    }

    function activate(row: var): void {
        if (row.kind === "colourpick")
            root.pick();
        else
            root.copy(row.hex);
    }

    function actionsFor(row: var): var {
        if (row.kind === "colourpick")
            return [
                {
                    icon: ColourPicks.found ? "colorize" : "download",
                    label: ColourPicks.found ? "Pick" : "Install hyprpicker",
                    run: () => root.pick()
                }
            ];
        const colour = Colours.parseColour(row.hex);
        return [
            {
                icon: "content_copy",
                label: "Copy hex",
                run: () => root.copy(row.hex)
            },
            {
                icon: "content_copy",
                label: "Copy rgb",
                short: "rgb",
                run: () => root.copy(Colours.rgbOf(colour))
            },
            {
                icon: "content_copy",
                label: "Copy hsl",
                short: "hsl",
                run: () => root.copy(Colours.hslOf(colour))
            },
            {
                icon: "delete",
                label: "Forget this colour",
                tucked: true,
                run: () => ColourPicks.remove(row.hex)
            }
        ];
    }

    function rowById(id: string): var {
        return id === "colourpick" ? root.pickRow(1) : null;
    }
}
