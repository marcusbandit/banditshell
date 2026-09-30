pragma Singleton

import QtQuick
import Quickshell

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
}
