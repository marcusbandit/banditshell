pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "calculation.js" as Calculation

Singleton {
    id: root

    readonly property int precision: 12

    readonly property var operators: ({
            "+": "+",
            "-": "−",
            "−": "−",
            "–": "−",
            "*": "×",
            "x": "×",
            "×": "×",
            "/": "÷",
            "÷": "÷"
        })

    readonly property var binding: ({
            "+": 1,
            "−": 1,
            "×": 2,
            "÷": 2
        })

    function format(n: real): string {
        if (isNaN(n))
            return "?";
        if (!isFinite(n))
            return n > 0 ? "∞" : "-∞";
        return parseFloat(n.toPrecision(root.precision)).toString();
    }

    function apply(a: real, o: string, b: real): real {
        switch (o) {
        case "+":
            return a + b;
        case "−":
            return a - b;
        case "×":
            return a * b;
        case "÷":
            return a / b;
        }
        return b;
    }

    function scan(text: string): var {
        const out = [];
        let i = 0;

        while (i < text.length) {
            const c = text[i];

            if (c === " " || c === "\t") {
                i++;
                continue;
            }

            if (c === "(" || c === ")") {
                out.push({
                    kind: c
                });
                i++;
                continue;
            }

            if ((c >= "0" && c <= "9") || c === ".") {
                let j = i;
                let dot = false;
                while (j < text.length) {
                    const d = text[j];
                    if (d >= "0" && d <= "9") {
                        j++;
                        continue;
                    }
                    if (d === "." && !dot) {
                        dot = true;
                        j++;
                        continue;
                    }
                    break;
                }
                const n = parseFloat(text.slice(i, j));
                if (isNaN(n))
                    return null;
                out.push({
                    kind: "n",
                    value: n
                });
                i = j;
                continue;
            }

            const o = root.operators[c] ?? root.operators[c.toLowerCase()];
            if (o !== undefined) {
                out.push({
                    kind: "o",
                    value: o
                });
                i++;
                continue;
            }

            return null;
        }

        return out;
    }

    function evaluate(text: string): var {
        const tokens = root.scan(text ?? "");
        if (!tokens || tokens.length === 0)
            return null;

        const values = [];
        const ops = [];

        let wantValue = true;

        let work = 0;

        function fold() {
            const o = ops.pop();
            const b = values.pop();
            const a = values.pop();
            if (a === undefined || b === undefined)
                return false;
            values.push(root.apply(a, o, b));
            work++;
            return true;
        }

        for (const t of tokens) {
            if (t.kind === "n") {
                if (!wantValue)
                    return null;
                values.push(t.value);
                wantValue = false;
                continue;
            }

            if (t.kind === "(") {
                if (!wantValue)
                    return null;
                ops.push("(");
                continue;
            }

            if (t.kind === ")") {
                if (wantValue)
                    return null;
                while (ops.length > 0 && ops[ops.length - 1] !== "(")
                    if (!fold())
                        return null;
                if (ops.pop() !== "(")
                    return null;
                continue;
            }

            if (wantValue) {
                if (t.value === "+")
                    continue;
                if (t.value === "−") {
                    values.push(0);
                    ops.push("−");
                    continue;
                }
                return null;
            }

            while (ops.length > 0 && ops[ops.length - 1] !== "(" && root.binding[ops[ops.length - 1]] >= root.binding[t.value])
                if (!fold())
                    return null;
            ops.push(t.value);
            wantValue = true;
        }

        if (wantValue)
            return null;

        while (ops.length > 0) {
            if (ops[ops.length - 1] === "(")
                return null;
            if (!fold())
                return null;
        }

        if (values.length !== 1)
            return null;

        return {
            value: values[0],
            text: root.format(values[0]),
            work: work
        };
    }

    function answer(text: string): var {
        const result = root.evaluate(text);
        return result && result.work > 0 ? result : null;
    }

    property bool qalcFound: false
    property bool qalcProbed: false
    property string installing: ""

    readonly property var qalcPackages: ["pacman:libqalculate", "apt:qalc", "dnf:qalculate", "zypper:qalculate", "xbps:libqalculate", "apk:libqalculate"]
    readonly property string installer: `${Quickshell.shellDir}/scripts/install-package.sh`

    readonly property var installWords: ({
            "": "The calculator needs qalc",
            trying: "Installing qalc…",
            terminal: "Finish in the terminal",
            failed: "qalc did not install",
            nowhere: "No package manager for qalc",
            noterminal: "No terminal to install qalc in"
        })

    function probeQalc(): void {
        if (!prober.running)
            prober.running = true;
    }

    function installQalc(): void {
        if (root.installing === "trying" || root.qalcFound)
            return;
        root.installing = "trying";
        quietInstall.running = true;
    }

    function missing(text: string): var {
        if (!root.qalcProbed || root.qalcFound)
            return null;
        const ask = Calculation.looksLikeCalculation(text);
        if (!ask && !Calculation.mathOnly(text) && !(/[=;]/.test(text) && /\d/.test(text)))
            return null;
        return {
            text: root.installWords[root.installing] ?? root.installWords[""],
            missing: true,
            firm: !/^[\d\s.,]+$/.test(text) && (ask || Calculation.firm(text))
        };
    }
    property string asked: ""
    property var worked: null
    property int generation: 0
    property var latestRun: null

    function leniently(text: string): var {
        if (!Calculation.mathOnly(text))
            return null;
        const got = Calculation.lenient(text, t => root.evaluate(t));
        return got ? Object.assign({}, got, {
            firm: Calculation.firm(text)
        }) : null;
    }

    function amountOf(text: string): var {
        return root.leniently(text)?.value ?? null;
    }

    function programmed(text: string): var {
        const got = Calculation.program(text, t => root.evaluate(t), n => root.format(n));
        return got ? Object.assign({}, got, {
            work: 1,
            firm: true
        }) : null;
    }

    function answerFor(text: string): var {
        return Currency.answer(text, root.amountOf) ?? root.missing(text) ?? root.leniently(text) ?? root.programmed(text) ?? (root.worked?.query === text ? root.worked : null);
    }

    function ask(text: string): void {
        root.asked = text;
        if (!root.qalcFound || root.worked?.query === text || Currency.answer(text, root.amountOf) || root.leniently(text) || root.programmed(text) || !Calculation.looksLikeCalculation(text)) {
            settle.stop();
            return;
        }
        settle.restart();
    }

    function take(generation: int, query: string, output: string): void {
        if (generation !== root.generation)
            return;
        const text = Calculation.readQalc(output, query);
        root.worked = text ? {
            query: query,
            text: text,
            work: 1,
            firm: true
        } : null;
    }

    Timer {
        id: settle

        interval: 60

        onTriggered: {
            root.generation += 1;
            if (root.latestRun)
                root.latestRun.running = false;
            root.latestRun = runner.createObject(root, {
                command: ["qalc", "-t", Calculation.qalcExpression(root.asked)],
                generation: root.generation,
                query: root.asked,
                running: true
            });
        }
    }

    Component {
        id: runner

        Process {
            id: run

            property int generation: 0
            property string query: ""

            environment: ({
                    LC_ALL: "C.UTF-8"
                })

            stdout: StdioCollector {
                onStreamFinished: root.take(run.generation, run.query, text)
            }

            onRunningChanged: if (!run.running)
                run.destroy()
        }
    }

    Process {
        id: prober

        command: ["sh", "-c", "command -v qalc"]
        running: true
        onExited: code => {
            root.qalcFound = code === 0;
            root.qalcProbed = true;
            if (root.qalcFound) {
                watch.stop();
                root.installing = "";
            }
        }
    }

    Process {
        id: quietInstall

        command: [root.installer, "--quiet", ...root.qalcPackages]
        onExited: code => {
            if (code === 0) {
                root.probeQalc();
                return;
            }
            if (code === 3) {
                root.installing = "nowhere";
                return;
            }
            root.installing = "terminal";
            terminal.running = true;
            watch.restart();
        }
    }

    Process {
        id: terminal

        command: [`${Quickshell.shellDir}/scripts/in-terminal.sh`, `'${root.installer}' --ask ${root.qalcPackages.join(" ")}`]
        onExited: code => {
            if (code === 127)
                root.installing = "noterminal";
            root.probeQalc();
        }
    }

    Timer {
        id: watch

        property int tries: 0

        interval: 2000
        repeat: true
        onRunningChanged: if (watch.running)
            watch.tries = 0
        onTriggered: {
            root.probeQalc();
            if (++watch.tries > 300) {
                watch.stop();
                if (root.installing === "terminal")
                    root.installing = "failed";
            }
        }
    }
}
