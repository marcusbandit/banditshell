pragma Singleton

import QtQuick
import Quickshell

// Arithmetic, in one place, because two things in this shell now do it.
//
// The keypad panel and the launcher's answer row are two INPUT METHODS onto the
// same question, and the thing they must not do is disagree about the answer.
// Everything either of them would have had its own copy of lives here: how much
// of a float to believe, how a number is written out, and what a typed
// expression means.
//
// WHAT IS NOT HERE is the keypad's state. Which operator is pending and whether
// the line holds something somebody typed are facts about a panel being
// operated, not about arithmetic, and they die with the panel that owns them
// (see modules/menu/content/CalculatorMenu.qml). A singleton holding them would
// be one calculator shared between every surface that ever draws one, which is
// exactly the shape a second monitor turns into a bug.
//
// THE TWO INPUTS DISAGREE ABOUT PRECEDENCE, on purpose, and this is the one
// thing in this file worth arguing rather than stating.
//
//   A KEYPAD IS LEFT TO RIGHT. It has to be: an operator key commits the sum so
//   far the moment it is pressed, because the line has room for one number and
//   the panel has to show you something. 2 + 3 × 4 is 20 there, and it says so
//   as you go: the line reads 5 the instant × is pressed, so nothing is hidden.
//
//   TYPED TEXT IS NOT. You can see the whole expression, you did not commit to
//   any of it, and "2+3*4" is 14 everywhere else a person has ever typed it.
//   Reading it left to right would be this shell quietly meaning something
//   different by an expression the rest of the world agrees on.
//
// So the difference is not an inconsistency to be tidied away: it follows from
// whether the input can show you an expression or only a number.
Singleton {
    id: root

    // HOW MUCH OF A FLOAT TO BELIEVE. Binary floating point cannot hold 0.1, so
    // 0.1 + 0.2 is 0.30000000000000004 and a calculator that prints it is a
    // calculator nobody trusts. Twelve significant figures throws that tail away
    // and keeps every digit anybody typed, since a double carries between
    // fifteen and seventeen and no hand enters twelve.
    readonly property int precision: 12

    // Every character that means an operation, in both the spellings the shell
    // has to accept: the real glyphs the keypad draws, and the ASCII a keyboard
    // actually produces. Kept as a map rather than as two switch statements,
    // because the panel and the parser both need to normalise and there is only
    // one right answer to what `*` means.
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

    // Which operations bind tighter. Data rather than two levels of parser
    // function, so adding one is a line here (~/.claude/rules/math-over-
    // hardcoding.md). Only used by the TYPED parser; see the header for why the
    // keypad has no use for it.
    readonly property var binding: ({
            "+": 1,
            "−": 1,
            "×": 2,
            "÷": 2
        })

    // A NUMBER, WRITTEN THE WAY A PERSON WOULD. Trailing zeros go, because
    // toPrecision keeps them and "4.00000000000" is not an answer; the round trip
    // through parseFloat is what drops them without a regular expression that
    // would also eat the zeros in 4000.
    //
    // The two non-numbers get a glyph each rather than the engine's own words:
    // "Infinity" is eight characters wide on a line that holds fourteen, and
    // "NaN" tells you which language the shell is written in rather than what
    // went wrong.
    function format(n: real): string {
        if (isNaN(n))
            return "?";
        if (!isFinite(n))
            return n > 0 ? "∞" : "-∞";
        return parseFloat(n.toPrecision(root.precision)).toString();
    }

    // One operation. The whole of what this calculator does, and the panel
    // switches through here rather than keeping its own copy so that the glyph a
    // key draws IS the operation performed.
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

    // ------------------------------------------------------------------
    // A TYPED EXPRESSION.
    //
    // A hand-written scanner and a shunting-yard, rather than handing the string
    // to Qt's JavaScript engine, which is the tempting one-liner and is a hole
    // straight through the shell: `Function(query)` in a launcher means every
    // character anybody types into the search field is executed, and the search
    // field is the one thing in this shell that a stray paste lands in. The
    // grammar below is four operators, brackets and a number, and nothing it
    // cannot parse can do anything at all.

    // WHAT A LEXER PRODUCES: `{kind, value}`, where kind is "n", "o", "(" or ")".
    // Null the moment anything is not one of those, so a query that is merely a
    // word is rejected at the first character rather than half consumed.
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

            // A NUMBER, greedily, including its decimal part. A second point is
            // where the number stops rather than an error, so "1.2.3" fails at
            // the parser as two numbers with nothing between them, which is what
            // it is.
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

            // AN OPERATOR, in either spelling. `x` is here because it is what a
            // hand types for times and what half the world writes on paper; it
            // costs nothing, because a bare letter cannot appear anywhere else in
            // this grammar, so no expression this accepts is ambiguous.
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

    // THE EXPRESSION, EVALUATED, or null if it is not one.
    //
    // Shunting-yard: operators wait on a stack until something binds less
    // tightly than they do, which is what makes 2+3×4 fourteen rather than
    // twenty. Values are folded as the operators come off, so there is no tree
    // to walk afterwards; the expressions this accepts are short enough that a
    // tree would be scaffolding around one multiplication.
    //
    // A LEADING OR REPEATED MINUS IS A SIGN, not a missing operand: -5, 3 × -2
    // and 2 - -3 all mean what they look like. It is the one place the grammar
    // is ambiguous and the one place a person would be surprised by an error.
    function evaluate(text: string): var {
        const tokens = root.scan(text ?? "");
        if (!tokens || tokens.length === 0)
            return null;

        const values = [];
        const ops = [];
        // Where an OPERAND is expected, which is at the start, after an operator
        // and after an opening bracket. It is what tells a sign from a
        // subtraction, and what catches "2 3" and "2 +" without a second pass.
        let wantValue = true;
        // How many operations were actually performed. A query of "5" is a
        // perfectly good expression and a terrible answer to show under a search
        // field, so the caller is told this and can decline (see `answer`).
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

            // An operator where a value was expected is a SIGN. Plus is a no-op
            // and minus is a zero to subtract from, which costs one addition and
            // no special case anywhere below.
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

    // WHAT A SEARCH FIELD SHOULD SHOW, which is a narrower question than "is
    // this an expression".
    //
    // A query has to have asked for a CALCULATION, not merely be parseable as
    // one. Every bare number is a valid expression and none of them is an
    // answer worth a row, and more to the point a launcher whose search field
    // answers "7" with "7" is a launcher that stopped being about applications.
    // One operation performed is the whole test, and brackets alone do not
    // count: "(7)" is still just seven.
    function answer(text: string): var {
        const result = root.evaluate(text);
        return result && result.work > 0 ? result : null;
    }
}
