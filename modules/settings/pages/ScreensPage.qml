pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// SCREENS: which monitor owns which workspaces.
//
// A monitor's whole claim on the desktop is its POSITION in one list of names,
// counting only the screens that are plugged in. The k-th CONNECTED name in
// `sidebar.workspaces.order` owns the run [k*count + 1 .. k*count + count], so
// with a five-slot column the first screen owns 1 to 5 and the second owns 6 to
// 10 (services/Hypr.qml). Move a name up this page and that screen takes the
// band above it, plates, windows and all. Unplug one and the screens below it
// close the gap, so a laptop on its own is always on 1 to 5.
//
// THIS IS THE ONLY WAY IN, which is the unusual thing about it. Every other
// setting in this shell has a terminal in front of it as well as a row;
// config/Config.qml records that Quickshell's IPC reads a bracketed argument as
// an argument LIST and splats it, so `banditshell set sidebar.workspaces.order
// [DP-1,DP-2]` can never mean what it plainly looks like it means. An array is
// the one shape the CLI cannot carry, which turns this page from a convenience
// into the control.
//
// AND WRITING THE LIST IS THE WHOLE OF THE DEED. Hypr listens to the key and
// tells the compositor where every band went, so nothing in here runs a
// process, pushes a keyword, or knows what hyprctl is. A page that also applied
// its own change would be a second implementation of the band model, and two
// implementations disagree on the day one of them is edited. This one renders
// `bandFor`'s answers and assigns an array of strings; that is deliberately all
// of it.
//
// NOT DRAG TO REORDER. There is no DropArea and no Drag attached property
// anywhere in this shell, and DESIGN.md spends twenty lines on why hand-rolling
// a drag here is harder than it looks. It would also be the wrong gesture: this
// list is as long as you have monitors, and on a list of two or three a nudge
// is over before a drag has finished deciding it started.
//
// WIDTH COMES FROM THE FACE, the same contract every page here has: fill what
// the pager hands you and ask only for height.
Item {
    id: root

    implicitHeight: list.implicitHeight

    // THE ROWS COME FROM THE ORDER, not from the outputs that happen to be
    // plugged in, and the difference is the whole argument of the band model.
    //
    // Three lists could have been asked. `Quickshell.screens` is what is
    // connected right now, in the order the compositor enumerated it, which is
    // PLUG order: sorting the page by it would arrange the rows by the one fact
    // bands refuse to depend on, and the page would reshuffle itself when a
    // cable moved. `Shell.screenNames()` is a step further out again, a list of
    // shell WINDOWS rather than of monitors, and it is a function rather than a
    // property, so a binding on it would never be told to run a second time.
    // `Hypr.order` is the thing being edited AND the thing `bandFor` indexes,
    // so rendering it is the page showing the bands the sidebars are actually
    // drawing, in the order that decides them.
    //
    // PLUS ANYTHING CONNECTED THE ORDER HAS NOT HEARD OF, appended, which is
    // the honest half. `Hypr.adopt()` appends a new monitor to the key itself
    // and normally beats you to it by a frame, but it can only do that once the
    // compositor's rules have arrived AND config.json has been read, and until
    // both are true a screen you are looking at is a screen this page would
    // otherwise pretend does not exist. The append costs one lookup per output
    // when adopt has already run and is the difference between an honest page
    // and a blank one when it has not.
    //
    // AND A NAME WHOSE MONITOR IS GONE KEEPS ITS ROW. Dropping it would silently
    // renumber every band below an unplugged screen, which is precisely what an
    // ordered list of names exists to prevent: the name is a reservation, and
    // putting the cable back has to give that screen the workspaces it had. The
    // row says it is not connected instead, which is a fact worth showing
    // anyway: it is how you find out that DP-3 in this list is the monitor
    // currently sitting in a cupboard.
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
    //
    // BUILT FROM `screens` rather than from the order, so a monitor adopt has
    // not filed yet gets filed by the first button you press on it. That is the
    // same list adopt was about to write, only sooner and with your ordering in
    // it.
    //
    // The step is a direction, not a slot: it is added to the row's own index,
    // so the two buttons are one function called twice and nothing here knows
    // how long the list is except to refuse to walk off either end.
    function move(from: int, step: int): void {
        const to = from + step;
        if (to < 0 || to >= root.screens.length)
            return;

        const next = root.screens.slice();
        next.splice(to, 0, next.splice(from, 1)[0]);
        Config.set("sidebar.workspaces.order", next);
    }

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.small / 2

        // The quiet eyebrow the other pages open with, saying the one thing a
        // list of monitors cannot show: there is no apply step, and the bands
        // have already moved by the time the row has finished sliding.
        StyledText {
            text: `${root.screens.length} ${root.screens.length === 1 ? "screen" : "screens"}, ${Hypr.count} workspaces each, moved immediately`
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            bottomPadding: Appearance.padding.small
        }

        Repeater {
            model: root.screens

            delegate: MenuRow {
                id: monitor

                required property int index
                required property string modelData

                // The output itself, when there is one. Null IS the answer to
                // "is it plugged in", so the lookup does both jobs and there is
                // no second test that can disagree with this one.
                readonly property var output: Quickshell.screens.find(s => s.name === monitor.modelData) ?? null

                // Whether the order has actually heard of this name, which is
                // not the same question as whether it has a row here: the rows
                // are the order plus whatever is connected, and the plus is the
                // interesting case.
                readonly property bool filed: Hypr.order.indexOf(monitor.modelData) >= 0

                // ASKED OF THE MODEL, never worked out again from this row's
                // index. The two agree for every name the order knows, and the
                // disagreement is the whole reason to ask: a monitor the order
                // has not filed yet DRAWS the first band, because that is what
                // `bandFor` falls back to when it cannot find a name, and a row
                // that showed it the band it is going to get would be
                // describing the future while its sidebar drew the present.
                readonly property int band: Hypr.bandFor(monitor.modelData)

                width: list.width

                // A screen that is not there gets the struck-through monitor
                // rather than the same glyph as everything else. The detail
                // line says it too, but a list is scanned before it is read.
                icon: monitor.output ? "monitor" : "desktop_access_disabled"
                label: monitor.modelData

                // In the order you would ask it: which workspaces, then whether
                // the screen is there at all, then the one thing that is only
                // true in the moment before the order catches up with a cable.
                //
                // The far end of the band is the near end plus the count, so a
                // column lengthened in config.json relabels every row here with
                // nothing to keep in step. A one-workspace band is a workspace
                // and says so, because "workspaces 3-3" is a sentence no
                // interface should make somebody parse.
                detail: {
                    const bits = [];
                    // A SCREEN THAT IS NOT THERE CLAIMS NOTHING. Bands are
                    // counted off the connected screens, so an absent one has
                    // no run to name, and printing `bandFor`'s fallback would
                    // have every unplugged row claiming 1-5 alongside the
                    // screen that actually has them.
                    if (!monitor.output)
                        bits.push("no workspaces while unplugged");
                    else if (Hypr.count > 1)
                        bits.push(`workspaces ${monitor.band}-${monitor.band + Hypr.count - 1}`);
                    else
                        bits.push(`workspace ${monitor.band}`);

                    // The mode, not the layout size. A screen's `width` is in
                    // logical pixels, so a 2560 panel at scale 1.5 reports 1706
                    // and nobody recognises their own monitor in that number;
                    // through the device pixel ratio it is the resolution
                    // written on the box. See PickerState for the other end of
                    // the same conversion.
                    if (monitor.output)
                        bits.push(`${Math.round(monitor.output.width * monitor.output.devicePixelRatio)} × ${Math.round(monitor.output.height * monitor.output.devicePixelRatio)}`);
                    else
                        bits.push("not connected");

                    if (!monitor.filed)
                        bits.push("not in the order yet");

                    return bits.join(" · ");
                }

                // THE ROW IS A FACT AND THE BUTTONS ARE THE CONTROL. There is
                // nothing sensible for a press on the body to do here: a
                // monitor is not a setting to flip, and a row that lit up on
                // hover and then swallowed the press would be the same lie the
                // dead buttons above refuse to tell. Inert also means the fill
                // below can only ever mean one thing.
                interactive: false

                // WHICH ONE YOU ARE LOOKING AT. This is the mark the page most
                // needs and the one a list of names cannot carry on its own:
                // "DP-1" and "HDMI-A-1" are not how anybody identifies the
                // screen in front of them, and the fill is the shell answering
                // that by lighting the row as you look at it. It cannot be
                // misread as a selection the way a tint in a list of choices
                // would be, because no row on this page ever lights for any
                // other reason.
                selected: Hypr.focusedScreen === monitor.modelData

                Row {
                    spacing: Appearance.padding.small / 2

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
