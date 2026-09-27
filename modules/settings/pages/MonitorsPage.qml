pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "../../../services/hyprgen.js" as HyprGen

// MONITORS: the layout, the modes, and who owns which workspaces.
//
// The page is Windows display settings, said in this shell's accent: an
// ARRANGEMENT canvas at the top (modules/settings/MonitorCanvas.qml), where
// every output is a rectangle at its layout position at one to-scale fit --
// clicked to be edited, dragged to be moved -- and a property card under it
// whose choices are the shell's own dropdown (components/ActionSheet.qml, the
// power menu's sliding marker, not a full-width list pretending). Position,
// resolution, refresh, scale, rotation and VRR are the whole of what a
// monitor offers short of HDR, and each control applies as it is pressed:
// the press is a splice into the user's own Hyprland config
// (services/HyprConfig.qml's chain), verified before the compositor reloads
// it, and the poll brings the page the truth that survived. There is no
// apply step to forget; the canvas, the rows, the file and the desktop are
// four views of the same answer.
//
// THE FIRST EDIT IS STOPPED AND TOLD ITS NATURE (SourceEditSheet.qml, below):
// writing the user's hand-commented config is a deed said once, out loud,
// before it is ever done -- and never asked again once it has been.
//
// THE WORKSPACES A MONITOR OWNS ARE ONE OF ITS PROPERTIES NOW, said in the
// same card as its resolution: click the monitor in the canvas and the
// Workspaces row shows the band the config's managed section gives it, with
// the free runs to move it to one press away. The assignment lives in the
// user's lua, host-keyed, inside the markers that name it the shell's to
// write -- data only, the rules it becomes still emitted by the file's own
// code -- and a band edited by hand in the file is what this page shows on
// the next scan, because there is no second representation anywhere.
//
// THE DRAG IS THE SHELL'S FIRST, and it took the page apart to earn: the old
// band list's header argued there was no DropArea anywhere and no reason for
// one, and it was right about a LIST -- reordering three rows by drag is a
// gesture looking for a job. A canvas of monitors is the other thing
// entirely: dragging a rectangle to where the desk says it belongs is the
// primary gesture in every display settings UI there ever was, it is
// reversible until the release, and DESIGN.md section 15's rule (drag before
// click, nothing moving until the 6px commit) is the one it follows.
Item {
    id: root

    // THE FLEX. The page is as tall as its content wants, and never shorter
    // than the pane it was put in: a page that fills the view does not
    // scroll, and what it has to spare goes to the canvas (below), so the
    // property card borders the bottom the way a display settings page
    // should -- the picture first, the fine print at its foot. On a pane
    // too small to hold the natural heights, the natural heights win and
    // the pane scrolls, which is what it is for.
    implicitHeight: Math.max(list.implicitHeight, root.viewport)

    // The view the page fills: the pane's height minus the gutter the pane
    // keeps at its foot, the gutter the face keeps at its head, and the
    // header the column put above this page (the loader's own y is exactly
    // that: header plus the spacing that came before it).
    readonly property real viewport: {
        const p = root.pane;
        if (!p)
            return 0;
        return Math.max(0, p.height - root.parent.y - Appearance.padding.normal * 2);
    }

    // THE CANVAS'S OWN DIALS: the smallest picture a two-monitor desk can
    // still drag in, and the tallest the picture may get before a tall
    // window stops making it sillier.
    readonly property real canvasMin: Appearance.sizes.rowHeight * 5
    readonly property real canvasMax: 560

    // WHAT THE PAGE SPENDS that is not the canvas: the property card (when
    // there is one to show) and the air between the cards, plus the
    // arrangement card's own title row. The canvas is what flexes around
    // it.
    readonly property real canvasReserve: (propertyCard.visible ? propertyCard.height + list.spacing : 0) + canvas.chrome

    // THE FACE THIS PAGE IS DRAWN IN, found by walking up until a property
    // only the face has. The sheet floats over everything the page is in --
    // the property card, the pane's clip, the rail's separator -- so it is
    // drawn at the face's level and clamped in the face's coordinates.
    readonly property Item face: {
        let p = root.parent;
        while (p && p.windowed === undefined)
            p = p.parent;
        return p;
    }

    // THE SCROLLING PANE the page lives in, found the same way, for one
    // reason: the sheet is anchored to a row and the page can scroll the row
    // out from under it, which is the clipboard panel's "a menu pointing at
    // nothing" -- closed the moment the pane moves.
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

    // Connected ONCE per pane, guarded, because Component.onCompleted and the
    // onPaneChanged notification race for which arrives first.
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

    // THE SELECTED OUTPUT, and the spec the page displays for it: what we
    // have ASKED the compositor for, until the poll confirms it (see
    // Monitors.displaySpec), so two fast changes in a row stack instead of
    // the second building on a stale answer.
    readonly property string selected: Monitors.selected
    readonly property var spec: Monitors.displaySpec(root.selected)

    readonly property int modeW: root.spec ? +root.spec.mode.split("x")[0] : 0
    readonly property int modeH: root.spec ? +((root.spec.mode.split("x")[1] ?? "").split("@")[0] || 0) : 0
    readonly property real modeHz: root.spec ? +((root.spec.mode.split("@")[1] ?? "0") || 0) : 0

    // THE RESOLUTION LIST: every WxH the panel can be driven at, once each,
    // widest first. The mode carries its refresh and the resolution does
    // not: they are two dropdowns because they are two decisions, and the
    // resolution picks the shape while the refresh picks the rate in it.
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

    // THE REFRESH LIST: every rate the CURRENT resolution is offered at,
    // rounded to whole hertz, fastest first -- "59.94" is a number no panel
    // ever printed on its box.
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

    // THE SCALE LIST: the deliberate choices plus wherever the output
    // currently is, sorted, so the sheet can mark a value some earlier hand
    // set in a file.
    readonly property var scaleList: {
        const out = Monitors.scaleChoices.slice();
        if (root.spec && !out.some(s => Math.abs(s - root.spec.scale) < 0.001))
            out.push(root.spec.scale);
        return out.sort((a, b) => a - b);
    }
    readonly property int scaleIndex: root.scaleList.findIndex(s => root.spec && Math.abs(s - root.spec.scale) < 0.001)

    readonly property int transformIndex: root.spec ? (root.spec.transform % 4) : 0

    // THE ACTIONS a sheet opens with: the shell's own { icon, label, run }
    // shape, with the marker seeded on the worn option -- the sheet opens
    // with the marker already where the answer is. Every row carries the
    // same hollow circle, and the sheet fills the WORN one's in on the
    // symbol set's own axis, so "which answer is live" is one look.
    function options(list: var, worn: int, label, pick): var {
        return list.map((item, i) => ({
                    icon: "radio_button_unchecked",
                    label: label(item),
                    run: () => pick(i)
                }));
    }

    // Below the button, in the face's coordinates: the sheet's own flip and
    // clamp handles the edges from there.
    function below(item: Item): var {
        return item.mapToItem(root.face, 0, item.height);
    }

    function setRes(i: int): void {
        if (i < 0 || i >= root.resolutions.length)
            return;
        const r = root.resolutions[i];
        // Changing shape keeps the rate nearest the one being worn; a panel
        // offered 144 only at its native mode drops to its best at the new
        // shape rather than to a default nobody chose.
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

    // THE DOOR EVERY SOURCE EDIT WALKS THROUGH, and the only one the warning
    // watches -- monitor specs and band assignments alike, both of which are
    // splices into the user's config. Once the workflow has been
    // acknowledged the edit runs as it is; before that, it is held and the
    // sheet asks -- accept, and the held edit proceeds as the
    // acknowledgement's first deed, so the press that asked is the press
    // that lands.
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

    // ------------------------------------------------------------- bands

    // THE SELECTED MONITOR'S BAND, as the file says it: the field shows the
    // spec text VERBATIM -- the list, the ranges, the user's own punctuation
    // -- and the write stores what was typed, because the file is the only
    // representation. The grammar's verdict is live in the field; the
    // expansion is the file's own business, said by the managed section's
    // bs_expand, which reads the same formats this field accepts.
    readonly property var band: Hypr.bands.find(b => b.monitor === root.selected) ?? null
    readonly property string bandFileSpec: root.band?.workspaces ?? ""

    // THE DRAFT the field edits, kept apart from the file's answer and reset
    // to it whenever the answer moves -- a rescan, a hand edit in the file,
    // a selection change -- because the field is a view of the source, not
    // the source.
    property string bandDraft: ""
    onBandFileSpecChanged: root.bandDraft = root.bandFileSpec

    // THE GRAMMAR'S VERDICT on the draft, live, and whether the draft is
    // saying anything the file does not already say. Both asked of the
    // TRIMMED draft, because the write trims too: what is judged is what
    // would land.
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

    // A FORMAT ROW'S GIFT: the example becomes the draft, and the cursor
    // lands in the field to edit it. Nothing is written here -- it is the
    // field's text now, and Enter or a walk-away is what files it.
    function takeFormat(spec: string): void {
        root.bandDraft = spec;
        input.focus = true;
    }

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.huge

        // ------------------------------------------------------ arrangement

        // THE SPRING, in the flexbox sense: the canvas wants to fill
        // everything the page has and is content to be capped -- the space
        // it gets is the view minus what the property card spends, between
        // a floor a two-monitor desk can still drag in and a ceiling so a
        // tall window stops making the picture silly. Everything below
        // borders the bottom because this card ate all the slack above it.
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

        // ------------------------------------------------------- properties

        // THE SELECTED OUTPUT'S CARD, titled with its name -- the same name
        // the canvas labels it with, so selection is one fact said twice and
        // never a lookup between them. An output that is unplugged shows a
        // card of nothing: the properties are all facts about hardware that
        // is present, and a band it is not here to wear keeps itself in the
        // file, ready for the cable.
        //
        // THE ROWS ARE INERT AND THE BUTTONS ARE THE CONTROLS, the Expander's
        // two-hover-states rule: the button says what is worn, the arrow says
        // more is one press away, and the row's own fill stays out of it.
        SettingsCard {
            id: propertyCard

            visible: !!root.spec
            title: root.selected

            // THE MONITOR'S WORKSPACES, assigned right here, in text: the
            // field wears the managed section's own spec for this output,
            // and Enter writes it -- a splice like any other. An invalid
            // spec is refused in place (the field's border says so) and
            // never written, so the file cannot learn a spec its own
            // bs_expand would refuse.
            SettingsRow {
                icon: "workspaces"
                label: "Workspaces"
                interactive: false

                // THE (i) AND THE FIELD, one trailing item of explicit
                // size: the slot reads its height off its children's rect,
                // and a child anchored into that height is a binding loop.
                Item {
                    width: info.width + Appearance.padding.small + bandBox.width
                    height: bandBox.height

                    // THE (i), LEFT OF THE FIELD, because the one thing a
                    // text format owes its typist is the grammar -- said on
                    // PRESS, in the page's own sheet, and not as a hover
                    // pill: a tooltip that big is an overlay over the very
                    // field it describes. Each format is a row that fills
                    // the field with itself, so the note is also a way in.
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

                    // THE FIELD: the managed section's spec for this output,
                    // editable as text, red while the grammar refuses the
                    // draft. Enter writes it -- a splice like any other --
                    // and an invalid spec is never written, so the file
                    // cannot learn a spec its own bs_expand would refuse.
                    Item {
                        id: bandBox

                        x: info.width + Appearance.padding.small
                        anchors.verticalCenter: parent.verticalCenter

                        readonly property bool bad: root.bandDirty && !root.bandValid

                        width: 160
                        height: input.implicitHeight + Appearance.padding.small * 2

                        G2Rect {
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

                            // ENTER WRITES, and only a spec the grammar
                            // accepts gets as far as the file. The draft is
                            // trimmed at the edges -- the user's own spaces
                            // after commas are kept, the ones they typed by
                            // accident at the ends are not.
                            onAccepted: {
                                const spec = root.bandDraft.trim();
                                if (!root.bandValid)
                                    return;
                                root.bandDraft = spec;
                                root.assignBand(spec);
                                input.focus = false;
                            }

                            // ESCAPE PUTS THE FILE BACK in the field: the
                            // draft was a thought, the file is the answer.
                            Keys.onEscapePressed: {
                                root.bandDraft = root.bandFileSpec;
                                input.focus = false;
                            }

                            // AND SO IS A FIELD WALKED AWAY FROM: committed
                            // when the grammar took the draft, reverted when
                            // it did not -- an invalid spec never becomes the
                            // file's truth by the door's being opened.
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
        }

    }

    // THE SHEET, at the face's level: outside the pane's clip, over the
    // cards, clamped in the face's own coordinates -- the clipboard panel's
    // arrangement ("outside the viewport, so it is not clipped") with the
    // face for a viewport. It closes on the pane moving, on a press anywhere
    // else, and on Escape; the pressed option commits through its own `run`.
    ActionSheet {
        id: sheet

        parent: root.face
        anchors.fill: parent
        z: 98
    }

    // THE FORMAT SHEET, the (i)'s answer: the same sheet, the same clamping,
    // each row a format the field takes -- pressed, the example becomes the
    // draft. It is the grammar said as choices instead of as a paragraph,
    // which is the only way a row this narrow was ever going to say it.
    ActionSheet {
        id: bandHelp

        parent: root.face
        anchors.fill: parent
        z: 98
    }

    // THE QUESTION, at the face's level beside the sheet and one plate above
    // it (98): nothing the page floats may draw over the thing asking
    // whether the page may write the file. Acceptance is remembered in the
    // shell's own config -- a fact about the workflow, not about a monitor
    // -- and the edit that asked is the edit that lands.
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
