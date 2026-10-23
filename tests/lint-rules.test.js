const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const lintRules = require("../scripts/lint-rules.js");

const EM = String.fromCharCode(0x2014);
const EN = String.fromCharCode(0x2013);

function hits(file, text, rule) {
    return lintRules.lintSource(file, text, rule);
}

function lines(file, text, rule) {
    return hits(file, text, rule).map(hit => hit.line);
}

function makeRepo(files) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "banditshell-lint-"));
    for (const [name, content] of Object.entries(files)) {
        const target = path.join(dir, name);
        fs.mkdirSync(path.dirname(target), { recursive: true });
        fs.writeFileSync(target, content);
    }
    return dir;
}

function capture(argv) {
    const out = [];
    const err = [];
    const code = lintRules.run(argv, (text, error) => (error ? err : out).push(text));
    return { code, out: out.join("\n"), err: err.join("\n") };
}

test("L1 finds line and block comments and nothing that only looks like one", () => {
    const text = [
        "#!/usr/bin/env node",
        ".pragma library",
        "const a = 1; // trailing",
        "const url = \"http://example.com\";",
        "const re = /\\/\\//;",
        "const ratio = a / b / c;",
        "const t = `${a}//${b}`;",
        "/* block",
        "   comment */",
        "const s = 'it''s // inside';"
    ].join("\n");
    assert.deepStrictEqual(lines("services/a.js", text, "L1"), [3, 8]);
});

test("L1 applies to qml, not to shell scripts", () => {
    assert.deepStrictEqual(lines("modules/a.qml", "Item {\n    // note\n}\n", "L1"), [2]);
    assert.deepStrictEqual(hits("scripts/a.sh", "# note\n// not js\n", "L1"), []);
});

test("L2 flags a Rectangle that sets a radius and leaves SquircleRect alone", () => {
    const text = [
        "Item {",
        "    Rectangle {",
        "        color: \"x\"",
        "        radius: 4",
        "    }",
        "    Rectangle { color: \"x\" }",
        "    SquircleRect { radius: 4 }",
        "    Rectangle {",
        "        property real radius: 3",
        "        SquircleRect { radius: 9 }",
        "    }",
        "    Rectangle {",
        "        topLeftRadius: 2",
        "    }",
        "}"
    ].join("\n");
    assert.deepStrictEqual(lines("modules/a.qml", text, "L2"), [4, 13]);
});

test("L2 sees a radius on the same line and in nested rectangles", () => {
    const text = "Rectangle { radius: 2; Rectangle {\n    radius: 1\n} }\n";
    assert.deepStrictEqual(lines("modules/a.qml", text, "L2"), [1, 2]);
});

test("L3 flags Behavior and animation nodes", () => {
    const text = [
        "Item {",
        "    Behavior on x { NumberAnimation { duration: 100 } }",
        "    ColorAnimation on color { to: \"x\" }",
        "    SpringAnimation { spring: 2 }",
        "    SmoothedAnimation { velocity: 3 }",
        "    PropertyAnimation { }",
        "    FrameAnimation { running: true }",
        "}"
    ].join("\n");
    assert.deepStrictEqual(hits("modules/a.qml", text, "L3").map(h => h.detail), ["Behavior", "NumberAnimation", "ColorAnimation", "SpringAnimation", "SmoothedAnimation", "PropertyAnimation"]);
});

test("L3 lets a looping clock through only in a file on the allow list", () => {
    const clock = "Item {\n    NumberAnimation on phase { loops: Animation.Infinite; from: 0; to: 1 }\n}\n";
    assert.strictEqual(hits("components/ScrollingText.qml", clock, "L3").length, 0);
    assert.strictEqual(hits("modules/other/Thing.qml", clock, "L3").length, 1);
});

test("L3 lets the children of a looping sequence through and stops a one-shot in the same file", () => {
    const text = [
        "Item {",
        "    SequentialAnimation on opacity {",
        "        loops: Animation.Infinite",
        "        NumberAnimation { to: 0.3 }",
        "        NumberAnimation { to: 1 }",
        "    }",
        "    NumberAnimation on x { to: 5 }",
        "}"
    ].join("\n");
    assert.deepStrictEqual(lines("components/BatteryMeter.qml", text, "L3"), [7]);
});

test("L3 allows every animation in a file whose entry says all", () => {
    const text = "Item {\n    NumberAnimation on t { from: 0; to: 1 }\n}\n";
    assert.strictEqual(hits("modules/settings/scenes/UsageScene.qml", text, "L3").length, 0);
});

test("every looping clock on the allow list carries a reason", () => {
    for (const entry of lintRules.LOOPING_CLOCKS) {
        assert.ok(entry.reason.length > 0, entry.file);
        assert.ok(["infinite", "all"].includes(entry.scope), entry.file);
        assert.ok(fs.existsSync(path.join(ROOT, entry.file)), `${entry.file} exists`);
    }
});

test("L4 flags spring and bounce easing in qml and js", () => {
    const text = "Item {\n    easing.type: Easing.OutBack\n    x: Easing.InOutElastic\n    y: Easing.OutCubic\n    z: Easing.OutBounce\n}\n";
    assert.deepStrictEqual(lines("modules/a.qml", text, "L4"), [2, 3, 5]);
    assert.deepStrictEqual(lines("services/a.js", "var e = Easing.InBack;\n", "L4"), [1]);
});

test("L5 flags literal and scaled font sizes and passes tokens", () => {
    const text = [
        "Item {",
        "    StyledText { font.pixelSize: 12 }",
        "    StyledText { font.pixelSize: Appearance.font.size.small }",
        "    StyledText { font.pixelSize: Appearance.font.size.small * 0.9 }",
        "    StyledText {",
        "        font.pixelSize: Math.round(parent.height * 0.68)",
        "    }",
        "    StyledText { font.pointSize: Appearance.font.size.normal / 2 }",
        "    StyledText { font.pixelSize: root.open ? Appearance.font.size.large : Appearance.font.size.small }",
        "    StyledText { font.pixelSize: height > Appearance.font.line.large * 5 ? Appearance.font.size.large : Appearance.font.size.small }",
        "    property int pixelSize: 12",
        "    font { pixelSize: 11 }",
        "    Component.onCompleted: label.font.pixelSize = 14",
        "    readonly property real pitch: Appearance.font.size.small * 2",
        "    StyledText { font.pixelSize: Files.zoomed(Appearance.font.size.small) }",
        "}"
    ].join("\n");
    assert.deepStrictEqual(lines("modules/a.qml", text, "L5"), [2, 4, 6, 8, 12, 13]);
});

test("L6 flags hex literals and colour functions outside config", () => {
    const text = [
        "Item {",
        "    color: \"#ff00aa\"",
        "    border.color: '#abc'",
        "    fill: Qt.rgba(0, 0, 0, 0.5)",
        "    tint: Qt.lighter(base)",
        "    id: \"#12\"",
        "    text: \"Issue #1234567\"",
        "    color: Appearance.colour.text",
        "}"
    ].join("\n");
    assert.deepStrictEqual(lines("modules/a.qml", text, "L6"), [2, 3, 4, 5]);
    assert.deepStrictEqual(hits("config/Appearance.qml", text, "L6"), []);
    assert.deepStrictEqual(hits("installer/theme.js", text, "L6"), []);
    assert.deepStrictEqual(hits("tests/a.test.js", text, "L6"), []);
});

test("L6 lets a listed data file keep its hex literals but not its colour calls", () => {
    assert.deepStrictEqual(hits("components/vt.js", "var a = \"#ff0000\";\n", "L6"), []);
    assert.deepStrictEqual(lines("components/vt.js", "var a = Qt.rgba(1, 0, 0, 1);\n", "L6"), [1]);
    assert.deepStrictEqual(lines("components/other.js", "var a = \"#ff0000\";\n", "L6"), [1]);
});

test("every colour data entry names a file that exists and carries a reason", () => {
    for (const entry of lintRules.COLOUR_DATA) {
        assert.ok(entry.reason.length > 20, entry.file);
        assert.ok(fs.existsSync(path.join(ROOT, entry.file)), entry.file);
    }
});

test("L7 flags textGhost as the colour of text and not of shapes", () => {
    const text = [
        "Item {",
        "    StyledText {",
        "        text: \"x\"",
        "        color: Appearance.colour.textGhost",
        "    }",
        "    Text { color: root.dim ? Appearance.colour.textGhost : \"white\" }",
        "    SquircleRect { color: Appearance.colour.textGhost }",
        "    StyledText {",
        "        color: Appearance.colour.text",
        "        SquircleRect { color: Appearance.colour.textGhost }",
        "    }",
        "}"
    ].join("\n");
    assert.deepStrictEqual(lines("modules/a.qml", text, "L7"), [4, 6]);
});

test("L8 finds em and en dashes in any text file", () => {
    const text = `plain\na ${EM} b\nc ${EN} d\n`;
    assert.deepStrictEqual(hits("docs/a.md", text, "L8").map(h => [h.line, h.detail]), [[2, "em dash"], [3, "en dash"]]);
    assert.deepStrictEqual(lines("modules/a.qml", `Item { text: "x ${EM} y" }\n`, "L8"), [1]);
    assert.deepStrictEqual(hits("docs/a.md", "a - b\n", "L8"), []);
});

test("L9 flags the JavaScript the engine lacks", () => {
    const text = [
        "var a = s.matchAll(re);",
        "var b = list.flat();",
        "var c = list.flatMap(f);",
        "var d = Object.fromEntries(pairs);",
        "var e = s.replaceAll(\"a\", \"b\");",
        "var f = list.at(-1);",
        "var g = structuredClone(o);",
        "var h = /(?<=a)b/;",
        "var i = new RegExp(\"(?<!a)b\");",
        "var j = \"matchAll in a string\";"
    ].join("\n");
    assert.deepStrictEqual(lines("services/a.js", text, "L9"), [1, 2, 3, 4, 5, 6, 7, 8, 9]);
});

test("L9 passes the repo's own at functions and node-only files", () => {
    const own = "var a = Frames.at(x, 1, e);\nvar b = layout.at(i);\nvar c = root.rounding.at(2);\n";
    assert.deepStrictEqual(hits("modules/a.qml", own, "L9"), []);
    assert.strictEqual(hits("modules/a.qml", "var a = list.at(0);\n", "L9").length, 1);
    assert.deepStrictEqual(hits("tests/a.test.js", "x.flat();\n", "L9"), []);
    assert.deepStrictEqual(hits("scripts/a.js", "x.flat();\n", "L9"), []);
    assert.deepStrictEqual(hits("services/cli-migration.js", "x.matchAll(y);\n", "L9"), []);
});

test("L10 wants a qmldir that matches what qmldirs.sh would write", () => {
    const repo = makeRepo({
        "components/Zed.qml": "Item {}\n",
        "components/Alpha.qml": "Item {}\n",
        "components/Store.qml": "pragma Singleton\nItem {}\n",
        "components/qmldir": "module qs.components\nAlpha 1.0 Alpha.qml\nsingleton Store 1.0 Store.qml\nZed 1.0 Zed.qml\n",
        "services/Bus.qml": "Item {}\n",
        "modules/sidebar/Rail.qml": "Item {}\n",
        "modules/sidebar/scenes/Scene.qml": "Item {}\n"
    });
    const found = lintRules.lint(repo, "L10").findings.map(f => `${f.file}:${f.detail}`);
    assert.deepStrictEqual(found, [
        "modules/sidebar/qmldir:qmldir is missing",
        "modules/sidebar/scenes/qmldir:qmldir is missing",
        "services/qmldir:qmldir is missing"
    ]);
    fs.writeFileSync(path.join(repo, "components/qmldir"), "module qs.components\nZed 1.0 Zed.qml\n");
    const mismatched = lintRules.lint(repo, "L10").findings.find(f => f.file === "components/qmldir");
    assert.strictEqual(mismatched.line, 2);
    fs.rmSync(repo, { recursive: true, force: true });
});

test("L10 agrees with scripts/qmldirs.sh in C order, whatever the caller's locale", () => {
    const repo = makeRepo({
        "components/b.qml": "Item {}\n",
        "components/B.qml": "Item {}\n",
        "components/a2.qml": "Item {}\n",
        "components/a.qml": "Item {}\n",
        "components/Store.qml": "pragma Singleton\nItem {}\n",
        "modules/files/Pane.qml": "Item {}\n",
        "modules/files/parts/Cell.qml": "Item {}\n",
        "previews/Gallery.qml": "Item {}\n",
        "config/Theme.qml": "pragma Singleton\nItem {}\n"
    });
    execFileSync("bash", [path.join(ROOT, "scripts/qmldirs.sh")], { env: { PATH: process.env.PATH, BANDITSHELL_DIR: repo, LC_ALL: "en_US.UTF-8" }, stdio: "pipe" });
    assert.deepStrictEqual(lintRules.lint(repo, "L10").findings, []);
    fs.rmSync(repo, { recursive: true, force: true });
});

const FOCUS_SOURCE = [
    "pragma Singleton",
    "import QtQuick",
    "import Quickshell",
    "Singleton {",
    "    id: root",
    "    property string mode",
    "    readonly property var screens: ({ inner: 1 })",
    "    required property int need",
    "    default property list<QtObject> kids",
    "    property alias tint: box.color",
    "    property list<string> names",
    "    property var offStage: null",
    "    signal pressed(int key)",
    "    function reset(): void {",
    "        const hidden = 1;",
    "    }",
    "    enum Kind { Idle, Busy }",
    "    Rectangle {",
    "        id: box",
    "        property real nested",
    "    }",
    "    QtObject {",
    "        function buried() {}",
    "    }",
    "}"
].join("\n");

function sourceMap(files) {
    return new Map(Object.entries(files));
}

function memberHits(files) {
    return lintRules.checkMembers(sourceMap({
        "services/qmldir": "module qs.services\nsingleton Focus 1.0 Focus.qml\n",
        "services/Focus.qml": FOCUS_SOURCE,
        ...files
    })).map(hit => `${hit.file}:${hit.line}`);
}

test("L13 flags a Button that asks for a Material 3 emphasis", () => {
    const text = [
        "Item {",
        "    Button { style: \"filled\" }",
        "    Button {",
        "        style: root.on ? \"tonal\" : \"accent\"",
        "    }",
        "    Button { style: \"plate\" }",
        "    Button { text: \"text\"; style: \"bare\" }",
        "    Repeater { delegate: Button { style: \"outlined\" } }",
        "}"
    ].join("\n");
    assert.deepStrictEqual(lines("modules/a.qml", text, "L13"), [2, 4, 8]);
});

test("L14 flags a variable font axis that follows an unsnapped value, on the axis's own line", () => {
    const text = [
        "Text {",
        "    font.variableAxes: ({ \"wght\": 300 + 160 * presence.value })",
        "    font.variableAxes: ({ \"wght\": 600, \"opsz\": 32 })",
        "    font.variableAxes: ({",
        "            \"wght\": FontAxes.between(150, 600, turn.value),",
        "            \"opsz\": Math.max(20, root.size)",
        "        })",
        "    font.variableAxes: root.axes",
        "    onActiveChanged: label.font.variableAxes = { wght: root.weight }",
        "}"
    ].join("\n");
    assert.deepStrictEqual(lines("modules/a.qml", text, "L14"), [2, 6, 8, 9]);
});

test("L14 wants the whole value to be one FontAxes call", () => {
    const text = [
        "Text {",
        "    font.variableAxes: ({ \"wght\": FontAxes.between(300, 460, p) + 160 * presence.value })",
        "    font.variableAxes: ({ wght: FontAxes.between(0, 1, p) * turn.value })",
        "    font.variableAxes: ({ FILL: FontAxes.between(0, 1, Math.min(1, root.fill)) })",
        "}"
    ].join("\n");
    assert.deepStrictEqual(lines("modules/a.qml", text, "L14"), [2, 3]);
});

test("L14 reads axes that start on the next line and properties the file snaps", () => {
    const text = [
        "Item {",
        "    property real presence: 1",
        "    readonly property real weight: FontAxes.between(220, 620, root.presence)",
        "    property real loose: 220 + 400 * root.presence",
        "    Text {",
        "        font.variableAxes:",
        "            ({ \"wght\": 600 })",
        "    }",
        "    Text { font.variableAxes: ({ \"wght\": root.weight }) }",
        "    Text { font.variableAxes: ({ \"wght\": root.loose }) }",
        "    Text { font.variableAxes: ({ \"wght\": root.presence }) }",
        "}"
    ].join("\n");
    assert.deepStrictEqual(lines("modules/a.qml", text, "L14"), [10, 11]);
});

test("L12 flags a half-size radius on a SquircleRect or a shadow that names no pill role", () => {
    const text = [
        "Item {",
        "    SquircleRect {",
        "        height: 8",
        "        radius: height / 2",
        "    }",
        "    SquircleRect { radius: width / 2 }",
        "    SquircleRect { radius: root.dot / 2; cornerPower: 2 }",
        "    DropShadow {",
        "        radius: Math.min(width, height) / 2",
        "    }",
        "    RectangularShadow { radius: height * 0.5 }",
        "}"
    ].join("\n");
    assert.deepStrictEqual(lines("modules/a.qml", text, "L12"), [4, 6, 7, 9, 11]);
});

test("L12 sees a half-size literal radius and the four corners set one by one", () => {
    const text = [
        "Item {",
        "    SquircleRect {",
        "        width: 6",
        "        height: 20",
        "        radius: 3",
        "    }",
        "    SquircleRect {",
        "        topLeftRadius: height / 2",
        "        bottomLeftRadius: height / 2",
        "    }",
        "}"
    ].join("\n");
    assert.deepStrictEqual(lines("modules/a.qml", text, "L12"), [5, 8]);
});

test("L12 leaves token radii, clamped radii, other fractions and Rectangles alone", () => {
    const text = [
        "Item {",
        "    SquircleRect { radius: Appearance.rounding.normal }",
        "    SquircleRect { radius: Appearance.rounding.small / 2 }",
        "    SquircleRect { radius: Math.min(Appearance.rounding.normal, height / 2) }",
        "    SquircleRect { radius: height / 3 }",
        "    SquircleRect { width: 10; height: 4; radius: 3 }",
        "    SquircleRect { radius: root.pillRadius; cornerPower: root.pillPower }",
        "    Rectangle { radius: height / 2 }",
        "}"
    ].join("\n");
    assert.deepStrictEqual(lines("modules/a.qml", text, "L12"), []);
});

test("L12 accepts object and place, and a conditional between them or the plain shape", () => {
    const text = [
        "Item {",
        "    SquircleRect { pill: \"object\" }",
        "    SquircleRect { pill: \"place\"; topLeftRadius: 0 }",
        "    DropShadow { pill: \"place\" }",
        "    SquircleRect { pill: marker.square ? \"\" : \"object\" }",
        "    SquircleRect { pill: root.flat ? \"place\" : \"object\" }",
        "}"
    ].join("\n");
    assert.deepStrictEqual(lines("modules/a.qml", text, "L12"), []);
});

test("L12 rejects any other pill value and an explicit radius or corner power beside a role", () => {
    const text = [
        "Item {",
        "    SquircleRect { pill: \"round\" }",
        "    SquircleRect { pill: \"\" }",
        "    SquircleRect { pill: root.kind }",
        "    SquircleRect { pill: \"object\"; radius: height / 2 }",
        "    SquircleRect { pill: \"place\"; cornerPower: 2 }",
        "    SquircleRect { pill: root.on ? \"object\" : \"pebble\" }",
        "}"
    ].join("\n");
    assert.deepStrictEqual(lines("modules/a.qml", text, "L12"), [2, 3, 4, 5, 6, 7]);
});

test("L12 names the problem and only applies to qml", () => {
    const [bare] = hits("modules/a.qml", "SquircleRect { radius: height / 2 }", "L12");
    assert.match(bare.detail, /half-size radius without a pill role/);
    const [bad] = hits("modules/a.qml", "SquircleRect { pill: \"blob\" }", "L12");
    assert.match(bad.detail, /pill must be "object" or "place"/);
    assert.deepStrictEqual(hits("scripts/a.js", "SquircleRect { radius: height / 2 }", "L12"), []);
});

test("L11 flags a member the singleton does not declare and names the file and line", () => {
    const found = lintRules.checkMembers(sourceMap({
        "services/qmldir": "module qs.services\nsingleton Focus 1.0 Focus.qml\n",
        "services/Focus.qml": FOCUS_SOURCE,
        "modules/a/A.qml": "import qs.services\nItem {\n    x: Focus.mode\n    y: Focus.offStageScreen\n}\n"
    }));
    assert.deepStrictEqual(found.map(f => [f.rule, f.file, f.line]), [["L11", "modules/a/A.qml", 4]]);
    assert.match(found[0].detail, /Focus\.offStageScreen is not a member of the Focus singleton \(services\/Focus\.qml\)/);
});

test("L11 knows every kind of declaration, its Changed signal, enums and the QObject basics", () => {
    const reads = ["mode", "modeChanged", "screens", "need", "kids", "tint", "tintChanged", "names", "offStage", "pressed", "reset", "Kind", "Idle", "Busy", "objectName", "destroyed", "toString", "data"];
    const imports = "import qs.services\n";
    const body = reads.map(name => `    p${name}: Focus.${name}`).join("\n");
    assert.deepStrictEqual(memberHits({ "modules/a/A.qml": `${imports}Item {\n${body}\n}\n` }), []);
});

test("L11 does not count what is nested inside the singleton", () => {
    const found = memberHits({ "modules/a/A.qml": "import qs.services\nItem {\n    a: Focus.nested\n    b: Focus.buried\n    c: Focus.box\n    d: Focus.root\n    e: Focus.hidden\n    f: Focus.inner\n}\n" });
    assert.deepStrictEqual(found, [3, 4, 5, 6, 7, 8].map(line => `modules/a/A.qml:${line}`));
});

test("L11 only checks singletons the file imports or sits beside", () => {
    assert.deepStrictEqual(memberHits({ "modules/a/A.qml": "Item { x: Focus.missing }\n" }), []);
    assert.deepStrictEqual(memberHits({ "services/Neighbour.qml": "Item { x: Focus.missing }\n" }), ["services/Neighbour.qml:1"]);
    assert.deepStrictEqual(memberHits({ "modules/a/A.qml": "import \"../../services\"\nItem { x: Focus.missing }\n" }), ["modules/a/A.qml:2"]);
    assert.deepStrictEqual(memberHits({ "modules/a/A.qml": "import qs.services\nItem { x: other.Focus.missing }\n" }), []);
});

test("L11 reads a qualified import as Alias.Name.member and not as Name.member", () => {
    const text = "import qs.services as Services\nItem {\n    a: Services.Focus.mode\n    b: Services.Focus.missing\n    c: Focus.missing\n}\n";
    assert.deepStrictEqual(memberHits({ "modules/a/A.qml": text }), ["modules/a/A.qml:4"]);
    const both = "import qs.services\nimport qs.services as Services\nItem {\n    a: Services.Focus.missing\n    b: Focus.missing\n}\n";
    assert.deepStrictEqual(memberHits({ "modules/a/A.qml": both }), ["modules/a/A.qml:4", "modules/a/A.qml:5"]);
});

test("L11 lets a local id, a script alias or a local variable shadow the singleton", () => {
    const id = "import qs.services\nItem {\n    Item { id: Focus }\n    x: Focus.missing\n}\n";
    const alias = "import qs.services\nimport \"focus.js\" as Focus\nItem { x: Focus.missing }\n";
    const local = "import qs.services\nItem {\n    function f(Focus) { return Focus.missing; }\n}\n";
    const constant = "import qs.services\nItem {\n    function f() { const Focus = {}; return Focus.missing; }\n}\n";
    for (const text of [id, alias, local, constant])
        assert.deepStrictEqual(memberHits({ "modules/a/A.qml": text }), [], text);
});

test("L11 ignores strings and comments", () => {
    const text = "import qs.services\nItem {\n    a: \"Focus.missing\"\n    // Focus.missing\n    b: `${Focus.mode}.missing`\n}\n";
    assert.deepStrictEqual(memberHits({ "modules/a/A.qml": text }), []);
});

test("L11 follows a script the QML imports into the importer's scope and skips library scripts", () => {
    const qml = "import qs.services\nimport \"logic.js\" as Logic\nItem {}\n";
    assert.deepStrictEqual(memberHits({ "modules/a/A.qml": qml, "modules/a/logic.js": "function f() { return Focus.missing; }\n" }), ["modules/a/logic.js:1"]);
    assert.deepStrictEqual(memberHits({ "modules/a/A.qml": qml, "modules/a/logic.js": ".pragma library\nfunction f() { return Focus.missing; }\n" }), []);
    assert.deepStrictEqual(memberHits({ "modules/a/logic.js": "function f() { return Focus.missing; }\n" }), []);
});

test("L11 runs over a repo through lint and honours the rule filter", () => {
    const repo = makeRepo({
        "services/qmldir": "module qs.services\nsingleton Focus 1.0 Focus.qml\n",
        "services/Focus.qml": FOCUS_SOURCE,
        "modules/a/A.qml": "import qs.services\nItem { x: Focus.gone }\n"
    });
    const found = lintRules.lint(repo, "L11").findings;
    assert.deepStrictEqual(found.map(f => `${f.rule} ${f.file}:${f.line}`), ["L11 modules/a/A.qml:2"]);
    assert.deepStrictEqual(lintRules.lint(repo, "L2").findings, []);
    fs.rmSync(repo, { recursive: true, force: true });
});

function optionalHits(files) {
    return lintRules.checkOptionalModules(sourceMap(files)).map(f => `${f.rule} ${f.file}:${f.line}`);
}

test("L15 flags a type another file names when it imports an optional Qt module", () => {
    assert.deepStrictEqual(optionalHits({
        "modules/a/Player.qml": "import QtQuick\nimport QtMultimedia\n\nMediaPlayer {}\n",
        "modules/a/Pane.qml": "import QtQuick\n\nItem {\n    Player {\n    }\n    component Slot: Player {}\n}\n"
    }), ["L15 modules/a/Pane.qml:4", "L15 modules/a/Pane.qml:6"]);
});

test("L15 flags a singleton that imports an optional Qt module", () => {
    assert.deepStrictEqual(optionalHits({
        "services/Obs.qml": "pragma Singleton\n\nimport QtQuick\nimport QtWebSockets\n\nSingleton {}\n"
    }), ["L15 services/Obs.qml:4"]);
});

test("L15 lets a file loaded by URL import an optional Qt module", () => {
    assert.deepStrictEqual(optionalHits({
        "modules/a/Player.qml": "import QtQuick\nimport QtMultimedia\n\nMediaPlayer {}\n",
        "modules/a/Pane.qml": "import QtQuick\n\nLoader {\n    source: Qt.resolvedUrl(\"Player.qml\")\n}\n",
        "modules/a/Other.qml": "import QtQuick\n\nItem {\n    property var Player: null\n    readonly property bool p: Player !== null\n}\n"
    }), []);
});

test("L15 flags a property type and a name reached through an aliased import", () => {
    assert.deepStrictEqual(optionalHits({
        "components/Camera2.qml": "import QtQuick\nimport QtMultimedia\n\nItem {}\n",
        "modules/a/Pane.qml": "import QtQuick\nimport qs.components as Parts\n\nItem {\n    property Camera2 lens: null\n    Parts.Camera2 {}\n}\n"
    }), ["L15 modules/a/Pane.qml:5", "L15 modules/a/Pane.qml:6"]);
});

test("L15 only counts a name the file can reach, not a namesake in another folder", () => {
    assert.deepStrictEqual(optionalHits({
        "modules/b/Player.qml": "import QtQuick\nimport QtMultimedia\n\nMediaPlayer {}\n",
        "modules/a/Player.qml": "import QtQuick\n\nItem {}\n",
        "modules/a/Pane.qml": "import QtQuick\n\nItem {\n    Player {}\n}\n",
        "modules/c/Pane.qml": "import QtQuick\nimport \"../b\"\n\nItem {\n    Player {}\n}\n"
    }), ["L15 modules/c/Pane.qml:5"]);
});

test("the optional Qt modules are the same in lint, the compile check and install.sh", () => {
    const check = fs.readFileSync(path.join(ROOT, "scripts/qml-compile-check.sh"), "utf8");
    const install = fs.readFileSync(path.join(ROOT, "install.sh"), "utf8");
    const named = /module "Qt\(([\w|]+)\)"/.exec(check)[1].split("|").map(m => `Qt${m}`).sort();
    assert.deepStrictEqual(named, [...lintRules.OPTIONAL_QT_MODULES].sort());
    for (const module of lintRules.OPTIONAL_QT_MODULES)
        assert.match(install, new RegExp(`qt_present module ${module}"`), module);
});

test("L15 ignores an optional module named in a comment or a string", () => {
    assert.deepStrictEqual(optionalHits({
        "modules/a/Note.qml": "import QtQuick\n\nText {\n    text: \"import QtMultimedia\"\n}\n",
        "modules/a/Pane.qml": "import QtQuick\n\nItem {\n    Note {}\n}\n"
    }), []);
});

test("a new violation fails, with its file and line, and a fixed one only prints a notice", () => {
    const repo = makeRepo({
        "modules/a.qml": "Item {\n    Rectangle { radius: 3 }\n}\n",
        "modules/qmldir": "module qs.modules\nitem 1.0 a.qml\n"
    });
    fs.writeFileSync(path.join(repo, "modules/qmldir"), lintRules.expectedQmldir(repo, "modules"));
    assert.strictEqual(capture(["--root", repo, "--write-baseline"]).code, 0);
    const baseline = JSON.parse(fs.readFileSync(path.join(repo, "rules.baseline.json"), "utf8"));
    assert.deepStrictEqual(baseline, { violations: { L2: { "modules/a.qml": 1 } } });
    assert.strictEqual(capture(["--root", repo]).code, 0);

    fs.writeFileSync(path.join(repo, "modules/a.qml"), "Item {\n    Rectangle { radius: 3 }\n    Rectangle {\n        radius: 5\n    }\n}\n");
    const failed = capture(["--root", repo]);
    assert.strictEqual(failed.code, 1);
    assert.match(failed.err, /modules\/a\.qml:2: L2/);
    assert.match(failed.err, /modules\/a\.qml:4: L2/);
    assert.match(failed.err, /SquircleRect/);

    fs.writeFileSync(path.join(repo, "modules/a.qml"), "Item {\n}\n");
    const fixed = capture(["--root", repo]);
    assert.strictEqual(fixed.code, 0);
    assert.match(fixed.out, /1 baseline entries are fixed/);
    fs.rmSync(repo, { recursive: true, force: true });
});

test("--rule narrows the check and the baseline write", () => {
    const repo = makeRepo({
        "docs/a.md": `x ${EM} y\n`,
        "modules/a.qml": "Item { Rectangle { radius: 1 } }\n"
    });
    assert.strictEqual(capture(["--root", repo, "--write-baseline", "--rule", "L8"]).code, 0);
    assert.deepStrictEqual(JSON.parse(fs.readFileSync(path.join(repo, "rules.baseline.json"), "utf8")), { violations: { L8: { "docs/a.md": 1 } } });
    assert.strictEqual(capture(["--root", repo, "--rule", "l8"]).code, 0);
    assert.strictEqual(capture(["--root", repo, "--rule", "L2"]).code, 1);
    assert.strictEqual(capture(["--root", repo, "--write-baseline", "--rule", "L2"]).code, 0);
    assert.deepStrictEqual(JSON.parse(fs.readFileSync(path.join(repo, "rules.baseline.json"), "utf8")).violations, { L2: { "modules/a.qml": 1 }, L8: { "docs/a.md": 1 } });
    fs.rmSync(repo, { recursive: true, force: true });
});

test("--all lists every violation and the options are checked", () => {
    const repo = makeRepo({ "docs/a.md": `x ${EM} y\n` });
    const all = capture(["--root", repo, "--all"]);
    assert.strictEqual(all.code, 0);
    assert.match(all.out, /docs\/a\.md:1: L8 em dash/);
    assert.strictEqual(capture(["--bogus"]).code, 2);
    assert.strictEqual(capture(["--rule", "L99"]).code, 2);
    assert.strictEqual(capture(["--list"]).out.split("\n").length, lintRules.RULES.length);
    fs.rmSync(repo, { recursive: true, force: true });
});

test("every rule has an id in order and a reason", () => {
    assert.deepStrictEqual(lintRules.RULES.map(r => r.id), Array.from({ length: 15 }, (_, i) => `L${i + 1}`));
    for (const rule of lintRules.RULES)
        assert.ok(rule.reason.length > 20, rule.id);
});

test("the repo holds no more violations than its baseline", () => {
    const result = capture([]);
    assert.strictEqual(result.code, 0, result.err);
});
