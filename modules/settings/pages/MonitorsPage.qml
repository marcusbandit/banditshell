pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "../../../services/hyprgen.js" as HyprGen

Item {
    id: root

    implicitHeight: Math.max(list.implicitHeight, root.viewport)

    readonly property real viewport: {
        const p = root.pane;
        if (!p)
            return 0;
        return Math.max(0, p.height - root.parent.y - Appearance.padding.normal * 2);
    }

    readonly property real canvasMin: Appearance.sizes.rowHeight * 5
    readonly property real canvasMax: 560

    readonly property real canvasReserve: (propertyCard.visible ? propertyCard.height + list.spacing : 0) + canvas.chrome

    readonly property Item face: {
        let p = root.parent;
        while (p && p.railFoot === undefined)
            p = p.parent;
        return p;
    }

    readonly property Item pane: {
        let p = root.parent;
        while (p && p.position === undefined)
            p = p.parent;
        return p;
    }

    onPaneChanged: root.wirePane()
    Component.onCompleted: {
        root.wirePane();
        root.bandDraft = root.bandFileSpec;
    }

    property bool paneWired: false
    function wirePane(): void {
        if (!root.pane || root.paneWired)
            return;
        root.paneWired = true;
        root.pane.positionChanged.connect(() => {
            sheet.close();
            bandHelp.close();
        });
    }

    readonly property string selected: Monitors.selected
    readonly property var spec: Monitors.displaySpec(root.selected)

    readonly property int modeW: root.spec ? +root.spec.mode.split("x")[0] : 0
    readonly property int modeH: root.spec ? +((root.spec.mode.split("x")[1] ?? "").split("@")[0] || 0) : 0
    readonly property real modeHz: root.spec ? +((root.spec.mode.split("@")[1] ?? "0") || 0) : 0

    readonly property var resolutions: {
        const out = [];
        for (const s of (Monitors.selectedOutput?.availableModes ?? [])) {
            const p = Monitors.parseMode(s);
            if (p && !out.some(r => r.w === p.w && r.h === p.h))
                out.push({
                    w: p.w,
                    h: p.h
                });
        }
        return out.sort((a, b) => b.w * b.h - a.w * a.h);
    }
    readonly property int resIndex: root.resolutions.findIndex(r => root.spec && r.w === root.modeW && r.h === root.modeH)

    readonly property var hzList: {
        const out = [];
        for (const s of (Monitors.selectedOutput?.availableModes ?? [])) {
            const p = Monitors.parseMode(s);
            if (p && p.w === root.modeW && p.h === root.modeH && !out.includes(Math.round(p.hz)))
                out.push(Math.round(p.hz));
        }
        return out.sort((a, b) => b - a);
    }
    readonly property int hzIndex: root.hzList.indexOf(Math.round(root.modeHz))

    readonly property var scaleList: {
        const out = Monitors.scaleChoices.slice();
        if (root.spec && !out.some(s => Math.abs(s - root.spec.scale) < 0.001))
            out.push(root.spec.scale);
        return out.sort((a, b) => a - b);
    }
    readonly property int scaleIndex: root.scaleList.findIndex(s => root.spec && Math.abs(s - root.spec.scale) < 0.001)

    readonly property int transformIndex: root.spec ? (root.spec.transform % 4) : 0

    function options(list: var, worn: int, label, pick): var {
        return list.map((item, i) => ({
                    icon: "radio_button_unchecked",
                    label: label(item),
                    run: () => pick(i)
                }));
    }

    function below(item: Item): var {
        return item.mapToItem(root.face, 0, item.height);
    }

    function setRes(i: int): void {
        if (i < 0 || i >= root.resolutions.length)
            return;
        const r = root.resolutions[i];

        const rates = [];
        for (const s of (Monitors.selectedOutput?.availableModes ?? [])) {
            const p = Monitors.parseMode(s);
            if (p && p.w === r.w && p.h === r.h)
                rates.push(p.hz);
        }
        rates.sort((a, b) => Math.abs(Math.round(a) - Math.round(root.modeHz)) - Math.abs(Math.round(b) - Math.round(root.modeHz)));
        root.edit(root.selected, {
            mode: Monitors.modeString(r.w, r.h, rates[0] ?? root.modeHz)
        });
    }

    function setHz(i: int): void {
        if (i < 0 || i >= root.hzList.length)
            return;
        root.edit(root.selected, {
            mode: Monitors.modeString(root.modeW, root.modeH, root.hzList[i])
        });
    }

    function setScale(i: int): void {
        if (i < 0 || i >= root.scaleList.length)
            return;
        root.edit(root.selected, {
            scale: root.scaleList[i]
        });
    }

    function setTransform(i: int): void {
        if (i < 0 || i >= Monitors.transformChoices.length)
            return;
        root.edit(root.selected, {
            transform: Monitors.transformChoices[i].value
        });
    }

    property var queued: null

    function sourceEdit(fn: var): void {
        if (Config.values.sourceEdits?.acknowledged) {
            fn();
            return;
        }
        root.queued = fn;
        warn.open();
    }

    function edit(name: string, fields: var): void {
        root.sourceEdit(() => Monitors.apply(name, fields));
    }

    readonly property var band: Hypr.bands.find(b => b.monitor === root.selected) ?? null
    readonly property string bandFileSpec: root.band?.workspaces ?? ""

    property string bandDraft: ""
    onBandFileSpecChanged: root.bandDraft = root.bandFileSpec

    readonly property bool bandValid: HyprGen.parseBandSpec(root.bandDraft.trim()).ok
    readonly property bool bandDirty: root.bandDraft.trim() !== "" && root.bandDraft.trim() !== root.bandFileSpec

    function assignBand(spec: string): void {
        root.sourceEdit(() => {
            const entry = HyprConfig.bands.find(b => !b.dynamic && b.monitor === root.selected && b.path?.[1] === HyprConfig.hostName);
            if (entry)
                HyprConfig.updateBand(entry.id, {
                    workspaces: spec
                });
            else
                HyprConfig.addBand({
                    monitor: root.selected,
                    workspaces: spec
                });
        });
    }

    function takeFormat(spec: string): void {
        root.bandDraft = spec;
        input.focus = true;
    }

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.huge

        SettingsCard {
            id: arrangementCard

            title: "Arrangement"

            MonitorCanvas {
                id: canvas

                readonly property real chrome: Appearance.font.size.small * 4 / 3 + Appearance.padding.small
                readonly property real room: root.viewport - root.canvasReserve

                width: parent.width
                height: Math.max(root.canvasMin, Math.min(root.canvasMax, room))
                selected: root.selected

                onPicked: name => Monitors.selected = name
                onPlaced: (name, x, y) => root.edit(name, {
                        position: `${x}x${y}`
                    })
            }

        }

        SettingsCard {
            id: propertyCard

            visible: !!root.spec
            title: root.selected

            SettingsRow {
                icon: "workspaces"
                label: "Workspaces"
                interactive: false

                Item {
                    width: info.width + Appearance.padding.small + bandBox.width
                    height: bandBox.height

                    Item {
                        id: info

                        width: Appearance.font.iconSize + Appearance.padding.small * 2
                        height: parent.height
                        anchors.verticalCenter: parent.verticalCenter

                        Icon {
                            anchors.centerIn: parent
                            name: "info"
                            size: Appearance.font.iconSize
                            color: infoTap.containsMouse ? Appearance.colour.text : Appearance.colour.textFaint
                        }

                        MouseArea {
                            id: infoTap

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                const at = root.below(info);
                                bandHelp.popup(at.x, at.y, [{
                                            icon: "edit_note",
                                            label: "1,2,3,4,5,6,7 · a list",
                                            run: () => root.takeFormat("1,2,3,4,5,6,7")
                                        }, {
                                            icon: "edit_note",
                                            label: "1-10 · a range",
                                            run: () => root.takeFormat("1-10")
                                        }, {
                                            icon: "edit_note",
                                            label: "1-6, 8-10 · ranges, gapped",
                                            run: () => root.takeFormat("1-6, 8-10")
                                        }, {
                                            icon: "edit_note",
                                            label: "3, 2, 1 · any order",
                                            run: () => root.takeFormat("3, 2, 1")
                                        }]);
                            }
                        }
                    }

                    Item {
                        id: bandBox

                        x: info.width + Appearance.padding.small
                        anchors.verticalCenter: parent.verticalCenter

                        readonly property bool bad: root.bandDirty && !root.bandValid

                        width: 160
                        height: input.implicitHeight + Appearance.padding.small * 2

                        SquircleRect {
                            anchors.fill: parent
                            radius: Appearance.rounding.small
                            color: Appearance.colour.fillStrong
                            stroke: bandBox.bad ? Appearance.colour.alarm : "transparent"
                            strokeWidth: Appearance.font.stem
                        }

                        TextInput {
                            id: input

                            anchors.fill: parent
                            anchors.leftMargin: Appearance.padding.normal
                            anchors.rightMargin: Appearance.padding.normal
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true

                            text: root.bandDraft
                            onTextChanged: root.bandDraft = text

                            font.family: Appearance.font.family
                            font.pixelSize: Appearance.font.size.small
                            renderType: Text.NativeRendering
                            color: Appearance.colour.text
                            selectionColor: Appearance.colour.accent
                            selectedTextColor: Appearance.colour.accentText

                            onAccepted: {
                                const spec = root.bandDraft.trim();
                                if (!root.bandValid)
                                    return;
                                root.bandDraft = spec;
                                root.assignBand(spec);
                                input.focus = false;
                            }

                            Keys.onEscapePressed: {
                                root.bandDraft = root.bandFileSpec;
                                input.focus = false;
                            }

                            onActiveFocusChanged: if (!activeFocus) {
                                if (root.bandValid && root.bandDirty) {
                                    const spec = root.bandDraft.trim();
                                    root.bandDraft = spec;
                                    root.assignBand(spec);
                                } else if (!root.bandValid) {
                                    root.bandDraft = root.bandFileSpec;
                                }
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: Appearance.padding.normal
                                visible: !input.text && !input.activeFocus
                                text: "e.g. 1-5"
                                color: Appearance.colour.textFaint
                            }
                        }
                    }
                }
            }

            SettingsRow {
                icon: "aspect_ratio"
                label: "Resolution"
                interactive: false

                Button {
                    id: resBtn

                    text: root.spec ? `${root.modeW} × ${root.modeH}` : "—"
                    icon: "arrow_drop_down"
                    style: "tonal"
                    enabled: !!root.spec

                    onClicked: {
                        const at = root.below(this);
                        sheet.popup(at.x, at.y, root.options(root.resolutions, root.resIndex, r => `${r.w} × ${r.h}`, i => root.setRes(i)), root.resIndex);
                    }
                }
            }

            SettingsRow {
                icon: "speed"
                label: "Refresh rate"
                interactive: false

                Button {
                    text: root.spec ? `${Math.round(root.modeHz)} Hz` : "—"
                    icon: "arrow_drop_down"
                    style: "tonal"
                    enabled: !!root.spec

                    onClicked: {
                        const at = root.below(this);
                        sheet.popup(at.x, at.y, root.options(root.hzList, root.hzIndex, hz => `${hz} Hz`, i => root.setHz(i)), root.hzIndex);
                    }
                }
            }

            SettingsRow {
                icon: "zoom_out_map"
                label: "Scale"
                interactive: false

                Button {
                    text: root.spec ? `${Math.round(root.spec.scale * 100) / 100}` : "—"
                    icon: "arrow_drop_down"
                    style: "tonal"
                    enabled: !!root.spec

                    onClicked: {
                        const at = root.below(this);
                        sheet.popup(at.x, at.y, root.options(root.scaleList, root.scaleIndex, s => `${Math.round(s * 100) / 100}`, i => root.setScale(i)), root.scaleIndex);
                    }
                }
            }

            SettingsRow {
                icon: "screen_rotation"
                label: "Rotation"
                interactive: false

                Button {
                    text: Monitors.transformChoices[root.transformIndex]?.label ?? "—"
                    icon: "arrow_drop_down"
                    style: "tonal"
                    enabled: !!root.spec

                    onClicked: {
                        const at = root.below(this);
                        sheet.popup(at.x, at.y, root.options(Monitors.transformChoices, root.transformIndex, t => t.label, i => root.setTransform(i)), root.transformIndex);
                    }
                }
            }

            SettingsRow {
                icon: "autofps_select"
                label: "Variable refresh rate"
                onActivated: root.edit(root.selected, {
                        vrr: root.spec?.vrr ? 0 : 1
                    })

                Toggle {
                    checked: !!root.spec?.vrr
                    onToggled: root.edit(root.selected, {
                        vrr: root.spec?.vrr ? 0 : 1
                    })
                }
            }

            SettingsRow {
                icon: "view_sidebar"
                label: "Sidebar"
                onActivated: SidebarState.setOn(root.selected, !SidebarState.visibleOn(root.selected))

                Toggle {
                    checked: SidebarState.visibleOn(root.selected)
                    onToggled: SidebarState.setOn(root.selected, !SidebarState.visibleOn(root.selected))
                }
            }
        }

    }

    ActionSheet {
        id: sheet

        parent: root.face
        anchors.fill: parent
        z: 98
    }

    ActionSheet {
        id: bandHelp

        parent: root.face
        anchors.fill: parent
        z: 98
    }

    SourceEditSheet {
        id: warn

        parent: root.face
        anchors.fill: parent
        z: 99
        file: "lua/monitors.lua"

        onAccepted: {
            Config.set("sourceEdits.acknowledged", true);
            const q = root.queued;
            root.queued = null;
            if (q)
                q();
        }
    }
}
