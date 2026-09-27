pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.settings

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
// the compositor is told in the dialect it speaks (services/Monitors.qml),
// the change is written to the shell's `monitors` overrides, and the poll
// brings the page the truth the compositor actually settled on. There is no
// apply step to forget; the canvas, the rows and the desktop are three views
// of the same answer.
//
// THE WORKSPACE BANDS ARE STILL HERE, below, because they are a different
// axis of the same hardware: the canvas says WHERE an output is, the bands
// say WHICH WORKSPACES it owns. The band list is also the one place the
// page names outputs that are NOT connected -- the canvas draws what is
// plugged in, and a name reserved in the order for a monitor in a cupboard
// keeps its row here.
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

    implicitHeight: list.implicitHeight

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
    Component.onCompleted: root.wirePane()

    // Connected ONCE per pane, guarded, because Component.onCompleted and the
    // onPaneChanged notification race for which arrives first.
    property bool paneWired: false
    function wirePane(): void {
        if (!root.pane || root.paneWired)
            return;
        root.paneWired = true;
        root.pane.positionChanged.connect(() => sheet.close());
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
        Monitors.apply(root.selected, {
            mode: Monitors.modeString(r.w, r.h, rates[0] ?? root.modeHz)
        });
    }

    function setHz(i: int): void {
        if (i < 0 || i >= root.hzList.length)
            return;
        Monitors.apply(root.selected, {
            mode: Monitors.modeString(root.modeW, root.modeH, root.hzList[i])
        });
    }

    function setScale(i: int): void {
        if (i < 0 || i >= root.scaleList.length)
            return;
        Monitors.apply(root.selected, {
            scale: root.scaleList[i]
        });
    }

    function setTransform(i: int): void {
        if (i < 0 || i >= Monitors.transformChoices.length)
            return;
        Monitors.apply(root.selected, {
            transform: Monitors.transformChoices[i].value
        });
    }

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.huge

        // ------------------------------------------------------ arrangement

        SettingsCard {
            title: "Arrangement"

            MonitorCanvas {
                width: parent.width
                selected: root.selected

                onPicked: name => Monitors.selected = name
                onPlaced: (name, x, y) => Monitors.apply(name, {
                        position: `${x}x${y}`
                    })
            }

        }

        // ------------------------------------------------------- properties

        // THE SELECTED OUTPUT'S CARD, titled with its name -- the same name
        // the canvas labels it with, so selection is one fact said twice and
        // never a lookup between them. An output that is unplugged shows a
        // card of nothing: the properties are all facts about hardware that
        // is present, and an absent monitor's row lives in the bands below.
        //
        // THE ROWS ARE INERT AND THE BUTTONS ARE THE CONTROLS, the Expander's
        // two-hover-states rule: the button says what is worn, the arrow says
        // more is one press away, and the row's own fill stays out of it.
        SettingsCard {
            visible: !!root.spec
            title: root.selected

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
                onActivated: Monitors.apply(root.selected, {
                        vrr: root.spec?.vrr ? 0 : 1
                    })

                Toggle {
                    checked: !!root.spec?.vrr
                    onToggled: Monitors.apply(root.selected, {
                        vrr: root.spec?.vrr ? 0 : 1
                    })
                }
            }
        }

        // ------------------------------------------------------------ bands

        // ONE CARD, and its title carries the count. What the title cannot
        // say, and what a list of monitors cannot show, is that there is no
        // apply step: the bands have already moved by the time the row has
        // finished sliding.
        SettingsCard {
            title: `${Hypr.order.length} ${Hypr.order.length === 1 ? "monitor" : "monitors"}, ${Hypr.count} workspaces each`

            Repeater {
                model: root.screens

                delegate: SettingsRow {
                    id: monitor

                    required property int index
                    required property string modelData

                    // The output itself, when there is one. Null IS the answer
                    // to "is it plugged in", so the lookup does both jobs and
                    // there is no second test that can disagree with this one.
                    readonly property var output: Quickshell.screens.find(s => s.name === monitor.modelData) ?? null

                    // Whether the order has actually heard of this name, which
                    // is not the same question as whether it has a row here:
                    // the rows are the order plus whatever is connected, and
                    // the plus is the interesting case.
                    readonly property bool filed: Hypr.order.indexOf(monitor.modelData) >= 0

                    // ASKED OF THE MODEL, never worked out again from this
                    // row's index. The two agree for every name the order
                    // knows, and the disagreement is the whole reason to ask:
                    // a monitor the order has not filed yet DRAWS the first
                    // band, because that is what `bandFor` falls back to when
                    // it cannot find a name, and a row that showed it the band
                    // it is going to get would be describing the future while
                    // its sidebar drew the present.
                    readonly property int band: Hypr.bandFor(monitor.modelData)

                    // A screen that is not there gets the struck-through
                    // monitor rather than the same glyph as everything else.
                    icon: monitor.output ? "monitor" : "desktop_access_disabled"
                    label: monitor.modelData

                    // In the order you would ask it: which workspaces, then
                    // whether the screen is there at all, then the one thing
                    // that is only true in the moment before the order catches
                    // up with a cable. The far end of the band is the near end
                    // plus the count, so a column lengthened in config.json
                    // relabels every row here with nothing to keep in step.
                    detail: {
                        const bits = [];
                        // A SCREEN THAT IS NOT THERE CLAIMS NOTHING. Bands are
                        // counted off the connected screens, so an absent one
                        // has no run to name, and printing `bandFor`'s
                        // fallback would have every unplugged row claiming 1-5
                        // alongside the screen that actually has them.
                        if (!monitor.output)
                            bits.push("no workspaces while unplugged");
                        else if (Hypr.count > 1)
                            bits.push(`workspaces ${monitor.band}-${monitor.band + Hypr.count - 1}`);
                        else
                            bits.push(`workspace ${monitor.band}`);

                        // WHAT IT IS WEARING, and ONLY WHEN THAT IS A CHOICE.
                        // A wallpaper is per screen and the shape of that is a
                        // default plus the screens that disagree with it; the
                        // row says nothing while a screen follows the default
                        // and names the file the moment it stops. Shown for an
                        // unplugged screen too: a wallpaper is a RESERVATION
                        // that survives the cable.
                        if (Wallpaper.hasOwn(monitor.modelData))
                            bits.push(Wallpaper.nameOf(Wallpaper.currentOn(monitor.modelData)));

                        // The mode, not the layout size: through the device
                        // pixel ratio it is the resolution written on the box.
                        if (monitor.output)
                            bits.push(`${Math.round(monitor.output.width * monitor.output.devicePixelRatio)} × ${Math.round(monitor.output.height * monitor.output.devicePixelRatio)}`);
                        else
                            bits.push("not connected");

                        if (!monitor.filed)
                            bits.push("not in the order yet");

                        return bits.join(" · ");
                    }

                    // THE ROW IS A FACT AND THE BUTTONS ARE THE CONTROL. There
                    // is nothing sensible for a press on the body to do here:
                    // a monitor is not a setting to flip. Inert also means the
                    // fill below can only ever mean one thing.
                    interactive: false

                    // WHICH ONE YOU ARE LOOKING AT: the fill is the shell
                    // answering "which of these is under my eyes" by lighting
                    // the row as you look at it.
                    selected: Hypr.focusedScreen === monitor.modelData

                    Row {
                        spacing: Appearance.padding.small

                        // HAND THIS SCREEN BACK TO THE DEFAULT wallpaper. Dead
                        // rather than absent on a screen that already follows
                        // the default, which is Nudge's own contract at the
                        // ends of the list.
                        Nudge {
                            enabled: Wallpaper.hasOwn(monitor.modelData)
                            glyph: "settings_backup_restore"
                            tip: `${monitor.modelData} back to the default wallpaper`
                            onNudged: Wallpaper.clearOn(monitor.modelData)
                        }

                        Nudge {
                            enabled: monitor.index > 0
                            glyph: "keyboard_arrow_up"
                            tip: `move ${monitor.modelData} to the band above`
                            onNudged: root.move(monitor.index, -1)
                        }

                        Nudge {
                            enabled: monitor.index < root.screens.length - 1
                            glyph: "keyboard_arrow_down"
                            tip: `move ${monitor.modelData} to the band below`
                            onNudged: root.move(monitor.index, 1)
                        }
                    }
                }
            }
        }
    }

    // THE ROWS COME FROM THE ORDER, not from the outputs that happen to be
    // plugged in, and the difference is the whole argument of the band model.
    // `Hypr.order` is the thing being edited AND the thing `bandFor` indexes.
    // PLUS ANYTHING CONNECTED THE ORDER HAS NOT HEARD OF, appended, which is
    // the honest half: a screen you are looking at is a screen this page
    // would otherwise pretend does not exist until adopt catches up. AND A
    // NAME WHOSE MONITOR IS GONE KEEPS ITS ROW: the name is a reservation,
    // and putting the cable back has to give that screen the workspaces it
    // had.
    readonly property var screens: {
        const out = Hypr.order.slice();
        for (const s of Quickshell.screens)
            if (out.indexOf(s.name) < 0)
                out.push(s.name);
        return out;
    }

    // A MOVE IS A WHOLE NEW ARRAY, never an edit to the one that is there. QML
    // notices assignment and nothing else, so splicing `Hypr.order` in place
    // would move a band and tell nobody at all; see services/Apps.qml for the
    // same copy-then-assign on a map.
    function move(from: int, step: int): void {
        const to = from + step;
        if (to < 0 || to >= root.screens.length)
            return;

        const next = root.screens.slice();
        next.splice(to, 0, next.splice(from, 1)[0]);
        Config.set("sidebar.workspaces.order", next);
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
}
