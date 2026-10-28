pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.config
import qs.components
import qs.services
import "catalogue.js" as Catalogue

Item {
    id: root

    property bool compact: false
    property bool showing: true
    property bool covered: false
    property bool lingering: false

    Binding {
        target: SettingsView
        property: "sceneSeen"
        when: root.showing
        value: !root.covered && stage.visible && stage.y + stage.height > scroll.contentY && stage.y < scroll.contentY + scroll.height
        restoreMode: Binding.RestoreNone
    }

    onShowingChanged: {
        if (root.showing)
            root.lingering = true;
        else
            linger.restart();
    }

    Timer {
        id: linger

        interval: 900
        onTriggered: root.lingering = root.showing
    }

    Component.onCompleted: root.lingering = root.showing

    readonly property var s: SettingsState
    readonly property var pin: SettingsView.pin
    readonly property var row: SettingsView.hovered

    readonly property string sceneName: SettingsView.fold && SettingsView.preview === "arrange" ? "" : SettingsView.preview
    readonly property string pinName: root.pin ? root.pin.type : ""

    function esc(t: var): string {
        return String(t ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    function tone(c: color, t: string): string {
        return `<font color="${c}">${root.esc(t)}</font>`;
    }

    function defaultText(r: var): string {
        if (!r?.k || !r.cfg)
            return "";
        const d = SettingsState.defaultOf(r.k);
        if (d === undefined)
            return "";
        if (r.kind === "toggle")
            return d ? "on" : "off";
        if (r.o) {
            const hit = Catalogue.options(r, root.s).find(o => Catalogue.same(o[0], d));
            if (hit)
                return String(hit[1]);
        }
        return Catalogue.format(r, d, root.s);
    }

    Column {
        id: top

        width: parent.width
        spacing: 0

        Item {
            width: parent.width
            height: 36

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - close.width - Appearance.padding.normal
                text: (root.pin ? SettingsView.pinTitle(root.pin) : SettingsView.paneTitle).toUpperCase()
                color: Appearance.colour.textDim
                elide: Text.ElideRight
            }

            SettingsTool {
                id: close

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "close"
                tip: root.pin ? "put it away" : root.compact ? "put it away" : "close settings"
                onClicked: {
                    if (root.pin)
                        SettingsView.unpin();
                    else if (root.compact)
                        SettingsView.paneOut = false;
                    else
                        Settings.hide();
                }
            }
        }

        Item {
            width: parent.width
            height: Appearance.padding.card * 2 + 1

            Rectangle {
                y: Appearance.padding.card
                width: parent.width
                height: 1
                color: Appearance.colour.separator
            }
        }
    }

    Flickable {
        id: scroll

        y: top.height
        width: parent.width
        height: parent.height - y
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        WheelStep {
            flick: scroll
        }

        Column {
            id: body

            width: scroll.width
            spacing: Appearance.padding.card

            Loader {
                width: parent.width
                active: !!root.pin
                visible: active
                source: root.pin?.type ? Qt.resolvedUrl(`pins/${root.pin.type.charAt(0).toUpperCase()}${root.pin.type.slice(1)}Pin.qml`) : ""

                onLoaded: item.width = Qt.binding(() => width)
            }

            Item {
                id: stage

                readonly property real wanted: scene.item?.stageHeight ?? 220
                readonly property bool fills: scene.item?.fills ?? false
                readonly property bool rounded: GraphicsInfo.api !== GraphicsInfo.Software && !!scene.item

                visible: !root.pin && root.sceneName !== ""
                width: parent.width
                height: stage.fills ? Math.max(stage.wanted, scroll.height - info.implicitHeight - body.spacing) : Math.max(220, stage.wanted)

                HoverHandler {
                    onHoveredChanged: if (hovered)
                        SettingsView.replays++
                }

                SquircleRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.large
                    color: Appearance.colour.fill
                }

                Item {
                    id: stageMask

                    anchors.fill: parent
                    visible: false
                    layer.enabled: stage.rounded

                    SquircleRect {
                        anchors.fill: parent
                        radius: Appearance.rounding.large
                        color: "black"
                    }
                }

                Item {
                    anchors.fill: parent
                    clip: true
                    layer.enabled: stage.rounded
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: stageMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }

                    Loader {
                        id: scene

                        anchors.fill: parent
                        active: root.lingering && !root.pin && root.sceneName !== "" && (!root.compact || SettingsView.paneOut)
                        source: root.sceneName ? Qt.resolvedUrl(`scenes/${root.sceneName.charAt(0).toUpperCase()}${root.sceneName.slice(1)}Scene.qml`) : ""
                    }
                }
            }

            Column {
                id: info

                visible: !root.pin
                width: parent.width
                spacing: Appearance.padding.small

                readonly property var r: root.row && root.row.page === SettingsView.current ? root.row : null
                readonly property string title: info.r ? Catalogue.labelOf(info.r) : ""
                readonly property string why: info.r ? Catalogue.whyOf(info.r, root.s) : ""
                readonly property string fallback: {
                    if (SettingsView.hub)
                        return "Tiles flip the things you reach for most. Rows open the rest.";
                    return "Point at a row to see what it does and where it lives in config.json.";
                }

                StyledText {
                    width: parent.width
                    visible: info.title !== ""
                    text: info.title
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    width: parent.width
                    visible: info.r ? info.why !== "" : true
                    text: info.r ? info.why : info.fallback
                    color: Appearance.colour.textDim
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    width: parent.width
                    visible: text !== ""
                    textFormat: Text.StyledText
                    wrapMode: Text.WordWrap
                    color: Appearance.colour.textFaint
                    text: {
                        const r = info.r;
                        if (r) {
                            if (r.cfg)
                                return `config ${root.tone(Appearance.colour.textDim, r.cfg)}`;
                            if (r.k && r.k.startsWith("scr:"))
                                return `hyprland ${root.tone(Appearance.colour.textDim, `monitor = ${SettingsState.selMon}, ${SettingsState.describeMonitor(SettingsState.selMon)}`)}`;
                            return "";
                        }
                        if (SettingsView.hub) {
                            const c = SettingsView.cat;
                            return `${c.pages.length} pages ${root.tone(Appearance.colour.textDim, `${Catalogue.rowCount(c)} rows`)}`;
                        }
                        const cover = Catalogue.pagesCovered(SettingsView.page);
                        return `covers ${root.tone(Appearance.colour.textDim, `${cover.settings} ${cover.settings === 1 ? "setting" : "settings"}`)}`;
                    }
                }

                StyledText {
                    readonly property string d: root.defaultText(info.r)
                    readonly property bool back: !!info.r?.k && !(info.r.dis && info.r.dis(SettingsState)) && SettingsState.offersReset(info.r.k)

                    width: parent.width
                    visible: d !== ""
                    textFormat: Text.StyledText
                    text: `${back ? "reset to default," : "default"} ${root.tone(Appearance.colour.textDim, d)}`
                    color: Appearance.colour.textFaint
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    width: parent.width
                    textFormat: Text.StyledText
                    wrapMode: Text.WordWrap
                    color: Appearance.colour.textFaint
                    readonly property var w: SettingsState.wrote
                    readonly property var last: SettingsState.changes[0] ?? null
                    visible: text !== ""
                    text: {
                        const r = info.r;
                        if (r)
                            return w && r.cfg === w.key ? `wrote ${root.tone(Appearance.colour.accent, `${w.key} = ${w.value}`)}` : "";
                        if (SettingsView.hub)
                            return last ? `last changed ${root.tone(Appearance.colour.accent, `${last.label} · ${last.to}`)}` : "";
                        return w ? `last wrote ${root.tone(Appearance.colour.accent, `${w.key} = ${w.value}`)}` : "";
                    }
                }
            }
        }
    }
}
