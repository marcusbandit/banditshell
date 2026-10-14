pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.modules.settings

Item {
    id: root

    readonly property real stageHeight: 220
    readonly property bool oneDark: SettingsState.v("termColours") === "one dark"
    readonly property var c: root.oneDark ? {
        bg: "#282c34",
        fg: "#abb2bf",
        b: "#61afef",
        g: "#98c379",
        y: "#e5c07b",
        r: "#e06c75"
    } : {
        bg: Appearance.colour.surfaceSolid,
        fg: Appearance.colour.text,
        b: Appearance.colour.accent,
        g: Appearance.colour.accent,
        y: Appearance.colour.textDim,
        r: Appearance.colour.alarm
    }
    readonly property string command: "git status -s"

    SceneClock {
        id: clock

        duration: 5000
        still: 0.5
    }

    readonly property real secs: clock.value * 5
    readonly property int typed: SettingsView.reduceMotion ? root.command.length : root.command.split("").filter((ch, i) => root.secs >= i * 0.08 && root.secs < i * 0.08 + 4.5).length
    readonly property bool answered: SettingsView.reduceMotion || (root.secs >= 1.5 && root.secs < 4.5)

    property bool blink: true

    Timer {
        interval: 500
        running: !SettingsView.reduceMotion
        repeat: true
        onTriggered: root.blink = !root.blink
    }

    function span(colour: color, text: string): string {
        return `<font color="${colour}">${text.replace(/&/g, "&amp;").replace(/</g, "&lt;")}</font>`;
    }

    SquircleRect {
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: root.c.bg
    }

    Text {
        x: Appearance.padding.card
        y: Appearance.padding.card
        width: parent.width - Appearance.padding.card * 2
        textFormat: Text.StyledText
        font.family: SettingsState.v("termFont")
        font.pixelSize: 13
        lineHeight: 18
        lineHeightMode: Text.FixedHeight
        renderType: Text.NativeRendering
        color: root.c.fg
        clip: true
        text: [`${root.span(root.c.b, "~/projects")} ls`, `${root.span(root.c.b, "banditshell/")}&nbsp;&nbsp;${root.span(root.c.g, "install.sh")}&nbsp;&nbsp;notes.md`, `${root.span(root.c.b, "~/projects")} ${root.command.slice(0, root.typed).replace(/ /g, "&nbsp;")}${root.blink ? "█" : "&nbsp;"}`, root.answered ? `${root.span(root.c.g, "A")}&nbsp;&nbsp;modules/settings/SettingsRail.qml` : "&nbsp;", root.answered ? `${root.span(root.c.r, "M")}&nbsp;&nbsp;config/Config.qml` : "&nbsp;", root.span(root.c.y, `${SettingsState.v("termRows")} rows · ${SettingsState.v("termScroll")} back`)].join("<br>")
    }
}
