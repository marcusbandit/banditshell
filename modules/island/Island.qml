pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.config
import qs.components
import qs.components.blob
import qs.modules.media
import qs.modules.notifications
import qs.services

Item {
    id: root

    property int border: Appearance.sizes.border

    property real edge: root.border

    property bool keyboardHeld: false

    signal chosen(var activity)

    readonly property var host: QsWindow.window?.screen ?? null
    readonly property string screenName: root.host?.name ?? ""

    property bool yielded: false

    readonly property bool focused: !root.screenName || !Hypr.focusedScreen || root.screenName === Hypr.focusedScreen
    readonly property bool offStage: !root.screenName || !Focus.offStageScreen || root.screenName === Focus.offStageScreen

    readonly property bool notifies: Config.values.notifications.placement === "island"

    readonly property int launchMax: 3
    readonly property int bubbleMax: 4
    readonly property int announceMs: 2500

    readonly property var high: ["dictation", "launch", "notification", "alarm", "timer", "external", "privacy"]

    readonly property var activities: {
        const out = [];
        if (root.voice)
            out.push({
                key: "dictation",
                kind: "dictation"
            });
        if (root.focused && ScreenRecorder.recording)
            out.push({
                key: "recording",
                kind: "recording"
            });
        if (root.focused)
            for (const rec of Launching.shown.slice(-root.launchMax))
                out.push({
                    key: `launch:${rec.id}`,
                    kind: "launch",
                    name: rec.name,
                    mark: rec.mark,
                    state: rec.state,
                    rec: rec
                });
        if (root.offStage && SystemUpgrade.shown && !root.lifting)
            out.push({
                key: "upgrade",
                kind: "upgrade"
            });
        if (root.offStage)
            out.push(...Notices.fresh, ...Activities.shown);
        return out;
    }

    readonly property bool voice: root.focused && (Dictation.live || Dictation.cancelled)
    readonly property var voiceActivity: ({
            key: "dictation",
            kind: "dictation"
        })
    readonly property bool voiceAside: root.voice && root.tasking
    readonly property real voiceShown: voiceOut.value
    readonly property real voiceRoom: voiceOut.value > 0.001 ? root.taskWidth + (voiceRow.implicitWidth + root.budGap + root.shadowRoom) * 2 : 0

    readonly property bool banded: root.border > 0 && root.edge >= root.border
    readonly property bool lifting: root.offStage && root.banded && SystemUpgrade.quiet
    readonly property real lifted: root.lifting && !root.upgradeOpen && !root.yielded ? SystemUpgrade.progress : -1

    readonly property bool trailing: root.voice && root.centreKey === "dictation" && root.openness === 0
    readonly property bool alone: root.trailing && root.rest === "compact" && root.stackKeys.length === 1 && root.bubbleKeys.length === 0

    property bool near: false
    readonly property bool tucked: root.alone && root.near
    readonly property bool watching: root.alone && !root.yielded && Hypr.requestSocket !== ""

    readonly property real windowOffset: {
        const box = Hypr.activeClient?.lastIpcObject;
        if (!box?.at || !box?.size)
            return 0;
        const centre = box.at[0] + box.size[0] / 2 - (root.host?.x ?? 0);
        const middle = box.at[1] + box.size[1] / 2 - (root.host?.y ?? 0);
        if (centre < 0 || centre > root.width || middle < 0 || middle > (root.host?.height ?? 0))
            return 0;
        const room = root.border + Appearance.padding.large;
        const lo = room + root.restWidth / 2;
        const hi = root.width - room - root.restWidth / 2 - root.bubbleKeys.length * root.bubblePitch;
        return hi < lo ? 0 : Math.max(lo, Math.min(hi, centre)) - root.width / 2;
    }

    readonly property var deckEntries: {
        if (!root.notifies || !root.offStage)
            return [];
        const all = Notifications.popups;
        const urgent = all.filter(e => e.urgency === NotificationUrgency.Critical);
        return urgent.length > 0 ? [...urgent, ...all.filter(e => !urgent.includes(e))] : all;
    }

    readonly property var alerts: root.deckEntries.filter(e => !e.leaving)

    readonly property int recentMax: 3
    readonly property var appGroups: root.offStage ? Notifications.byApp(Notifications.history.filter(e => !root.deckEntries.includes(e))) : []
    readonly property var recentGroups: root.appGroups.slice(0, root.recentMax)
    readonly property var recent: root.recentGroups.map(g => g.entries[0])
    readonly property int unlisted: root.appGroups.slice(root.recentMax).reduce((sum, g) => sum + g.entries.filter(e => !e.leaving).length, 0)

    readonly property var overviewRows: [...root.activities.filter(a => a.kind !== "music" && a.kind !== "level"), ...(root.lifting ? [
                {
                    key: "upgrade",
                    kind: "upgrade"
                }
            ] : []), ...(Privacy.micRow && !root.activities.some(a => a.key === Privacy.micRow.key) ? [Privacy.micRow] : []), ...(root.offStage ? Notices.settled : []), ...(Notifications.quieted ? [
                {
                    key: "quiet",
                    kind: "quiet",
                    text: Notifications.quietLine
                }
            ] : []), ...(root.unlisted > 0 ? [
                {
                    key: "notifications",
                    kind: "notifications",
                    count: root.unlisted,
                    more: root.recent.length > 0
                }
            ] : [])]

    readonly property var noticeRow: root.alerts.length > 0 ? {
        key: "notification",
        kind: "notification",
        entry: root.alerts[0],
        count: root.alerts.length
    } : null

    readonly property var groups: {
        const out = {};
        for (const a of root.activities) {
            if (!root.high.includes(a.kind))
                continue;
            if (!out[a.kind])
                out[a.kind] = {
                    key: a.kind,
                    kind: a.kind,
                    items: []
                };
            out[a.kind].items.push(a);
        }
        if (root.noticeRow)
            out.notification = {
                key: "notification",
                kind: "notification",
                items: [root.noticeRow]
            };
        return out;
    }

    readonly property var passing: root.activities.filter(a => !root.high.includes(a.kind)).reverse()

    property var order: []
    property var deferred: []
    property var sizes: ({})
    property var announcing: ({})
    property var seen: ({})
    property string summon: ""

    readonly property var liveOrder: root.order.filter(k => !!root.groups[k])
    readonly property var annKeys: root.liveOrder.filter(k => root.announcing[k] !== undefined)
    readonly property string centreKey: root.liveOrder.find(k => root.announcing[k] === undefined) ?? ""
    readonly property var annItems: {
        const out = [];
        for (const k of root.annKeys)
            for (const i of root.groups[k]?.items ?? [])
                if ((root.announcing[k]?.items ?? []).includes(i.key))
                    out.push(i);
        return out;
    }

    function viewOf(key: string): var {
        const g = root.groups[key];
        const told = root.announcing[key]?.items ?? [];
        return g && told.length > 0 ? Object.assign({}, g, {
            items: g.items.filter(i => !told.includes(i.key))
        }) : g;
    }

    property bool pinned: false
    property string task: ""
    property string heldTask: ""
    property var reading: null
    property bool backToOverview: false
    readonly property bool tasking: root.task !== ""
    readonly property bool upgradeOpen: root.task === "upgrade"
    readonly property var taskNames: ({
            upgrade: "the system update",
            update: "the shell update",
            notifications: "the notifications",
            timers: "the timers",
            weather: "the weather",
            calendar: "the calendar",
            microphone: "the microphone",
            wifi: "the failed Wi-Fi join",
            reading: "a notification"
        })
    readonly property var taskViews: ({
            upgrade: upgradeView,
            update: updateView,
            notifications: notificationsView,
            reading: readingView,
            timers: timersView,
            weather: weatherView,
            calendar: calendarView,
            microphone: microphoneView,
            wifi: wifiView
        })
    property bool pulling: false
    property real pullProgress: 0
    property real pullFrom: 0

    readonly property bool hovering: stripHover.hovered || islandHover.hovered || deck.handling
    property bool dwelt: false
    property bool spent: false
    property bool reforming: false

    readonly property bool eyeingMusic: {
        for (let i = 0; i < rows.count; i++) {
            const row = rows.itemAt(i);
            if (row?.hovered && row.item?.kind === "music")
                return true;
        }
        return root.openness > 0.5 && overview.mediaHovered;
    }
    property bool fanning: false

    readonly property bool fronting: root.centreKey === "notification" && !root.deferred.includes("notification")
    readonly property bool expanded: root.pinned || root.tasking || (root.dwelt && !root.fronting)
    readonly property bool alerting: root.fronting && !root.expanded
    readonly property real openness: root.pulling ? root.pullProgress : root.expanded ? 1 : 0

    readonly property var stackItems: {
        const out = [];
        const centre = root.groups[root.centreKey];
        if (centre && !(root.centreKey === "notification" && (root.alerting || root.expanded)))
            out.push(...centre.items);
        out.push(...root.annItems);
        out.push(...root.passing);
        return out;
    }
    readonly property var stackKeys: root.stackItems.map(i => i.key)
    readonly property var stackByKey: {
        const out = {};
        for (const i of root.stackItems)
            out[i.key] = i;
        return out;
    }
    property var shownStack: []

    readonly property string rest: {
        if (root.alerting)
            return root.alerts.length < 2 ? "alert" : root.fanning ? "spread" : "stack";
        return root.stackItems.length > 0 ? "compact" : "hidden";
    }

    readonly property bool deckRest: root.rest === "alert" || root.rest === "stack" || root.rest === "spread"

    readonly property string presentation: root.openness > 0.5 ? (root.tasking ? "task" : "overview") : root.rest

    readonly property var bubbleKeys: root.out ? root.liveOrder.filter(k => k !== root.centreKey && (root.viewOf(k)?.items.length ?? 0) > 0).slice(0, root.bubbleMax) : []
    property var shownBubbles: []

    function named(key: string, count: int): string {
        const g = root.groups[key];
        const n = count > 0 ? count : key === "notification" ? root.alerts.length : (g?.items.length ?? 0);
        switch (key) {
        case "notification":
            return n > 1 ? `${n} notifications` : "a notification";
        case "launch":
            return n > 1 ? `${n} launches` : "launch";
        case "external":
            return n > 1 ? `${n} activities` : "activity";
        case "timer":
            return n > 1 ? `${n} timers` : "timer";
        case "privacy":
            return "privacy";
        }
        return key;
    }

    readonly property string situation: {
        if (root.presentation === "task")
            return root.taskNames[root.task] ?? "a task";
        if (root.presentation === "overview")
            return root.alerts.length > 0 ? "overview, notifications arriving inside it" : "overview";
        const kinds = [...new Set(root.passing.map(p => p.kind))];
        let centre = "";
        switch (root.rest) {
        case "alert":
            centre = "one notification";
            break;
        case "stack":
            centre = `${root.alerts.length} notifications stacked`;
            break;
        case "spread":
            centre = `${root.alerts.length} notifications spread out`;
            break;
        case "compact":
            centre = !root.centreKey ? kinds.join(", ") : root.centreKey === "notification" ? "notifications waiting under the pointer" : root.named(root.centreKey, 0);
            break;
        default:
            return "hidden";
        }
        const below = [...root.annKeys.map(k => root.named(k, root.announcing[k]?.items.length ?? 0)), ...(root.centreKey ? kinds : [])];
        const beside = root.bubbleKeys.map(k => root.named(k, k === "notification" ? 0 : (root.viewOf(k)?.items.length ?? 0)));
        return [centre, below.length > 0 ? `below it: ${below.join(", ")}` : "", beside.length > 0 ? `beside it: ${beside.join(", ")}` : "", root.tucked ? "tucked away from the pointer" : ""].filter(t => t).join(", ");
    }

    readonly property bool out: root.rest !== "hidden" || root.openness > 0

    readonly property bool attending: root.hovering || root.openness > 0

    readonly property bool wantsEscape: root.pinned || root.tasking

    readonly property Item grabItem: zone

    readonly property Item passItem: pass

    readonly property Item stage: scene

    function pressable(activity: var): bool {
        const kind = activity?.kind ?? "";
        return ["music", "download", "update", "kernel", "restart", "upgrade", "held", "notification", "recording", "timer", "alarm"].includes(kind) || ((kind === "external" || kind === "privacy") && !!activity.pressable);
    }

    readonly property bool whole: root.openness > 0 || root.deckRest || root.stackItems.some(i => root.pressable(i))

    readonly property bool interactive: !root.yielded && presence.value > 0.5 && (root.whole || root.bubbleKeys.length > 0)

    readonly property real compactHeight: Appearance.font.line.small + Appearance.padding.small * 2
    readonly property real slot: Appearance.font.line.small
    readonly property real largeWidth: Config.values.island.width
    readonly property real taskSpan: taskView.item?.span ?? 1
    readonly property real taskWidth: Math.min(Math.round(root.largeWidth * root.taskSpan), (root.host?.width ?? root.largeWidth * 2) - (root.border + Appearance.padding.large) * 2)
    readonly property real taskRoom: Math.max(root.compactHeight * 6, ((root.host?.height ?? 1080) - root.islandTop) * 0.7)
    readonly property real taskHeight: taskView.item?.implicitHeight ?? 0
    readonly property real islandTop: root.edge + Appearance.padding.small
    readonly property real budGap: Appearance.padding.normal
    readonly property real bubblePitch: root.compactHeight + root.budGap
    readonly property real stackStep: Math.round(Appearance.padding.small * 0.9)
    readonly property real shadowRoom: Appearance.padding.huge * 2
    readonly property real fieldStep: Appearance.padding.huge * 4

    readonly property real rowsWidth: {
        let widest = 0;
        for (let i = 0; i < measures.count; i++)
            widest = Math.max(widest, measures.itemAt(i)?.implicitWidth ?? 0);
        return widest;
    }

    readonly property real cardHeight: root.alerting ? deck.implicitHeight : 0

    readonly property real restWidth: root.deckRest ? root.largeWidth : root.rest === "compact" ? root.rowsWidth + swell.value * 2 : root.compactHeight
    readonly property real restHeight: root.deckRest ? root.cardHeight + root.stackItems.length * root.compactHeight : root.compactHeight * Math.max(1, root.stackItems.length)

    readonly property real fieldWidth: Math.ceil(Math.max(root.largeWidth + (root.bubbleMax * root.bubblePitch + root.shadowRoom) * 2, root.taskWidth + root.shadowRoom * 2, root.voiceRoom))
    readonly property real fieldHeight: Math.ceil((root.islandTop + Math.max(root.compactHeight * (root.launchMax + 3), root.taskRoom, Math.max(overview.implicitHeight, overview.settledHeight) - overview.arrivals + deck.fullHeight, deck.fullHeight + root.compactHeight * 2, root.taskHeight) + root.shadowRoom) / root.fieldStep) * root.fieldStep
    readonly property real centreX: scene.width / 2
    readonly property real surfaceX: Math.round((root.width - root.fieldWidth) / 2 + trail.value)

    readonly property real opened: Math.max(0, Math.min(1, glide.value))
    readonly property real widening: Math.min(1, root.opened * 1.8)
    readonly property real pillWidth: wide.value + (span.value - wide.value) * root.widening
    readonly property real pillHeight: tall.value + (overviewTall.value + overview.deckHeight * deckShare.value - tall.value) * root.opened
    readonly property real pillX: root.centreX - root.pillWidth / 2
    readonly property real tuckedY: root.edge - root.pillHeight - Appearance.padding.small
    readonly property real lipY: root.edge + Appearance.padding.small - root.pillHeight
    readonly property real dropY: root.tuckedY + (root.islandTop - root.tuckedY) * presence.value
    readonly property real pillY: root.dropY - Math.max(0, root.dropY - root.lipY) * tuck.value
    readonly property real neck: Appearance.sizes.melt * (1 - settle.value)
    readonly property real squared: Math.max(0, Math.min(1, (root.pillHeight - root.compactHeight) / root.compactHeight))
    readonly property real pillRadius: root.pillHeight / 2 + (Appearance.rounding.normal - root.pillHeight / 2) * root.squared
    readonly property real pillPower: 2 + (Appearance.rounding.power - 2) * root.squared

    readonly property real chainRight: root.pillX + root.pillWidth + root.bubbleKeys.length * root.bubblePitch
    readonly property real deckY: root.pillY + overview.arrivalsTop * Math.min(1, root.opened * 1.6)
    readonly property real dealY: -(1 - deal.value) * (root.pillY + root.pillHeight - root.edge + Appearance.padding.small)

    property var ghost: null
    property real ghostHeight: 0

    property var holding: []

    readonly property var waiting: root.tasking || (!root.expanded && (!root.alerting || root.pulling)) ? root.alerts : []


    function sizeOf(key: string): int {
        return key === "notification" ? root.alerts.length : (root.groups[key]?.items.length ?? 0);
    }

    function arrange(fresh: bool): void {
        const g = root.groups;
        const before = fresh ? {} : root.sizes;
        const centre = root.centreKey;
        let next = fresh ? [] : root.order.filter(k => !!g[k]);
        let held = fresh ? [] : root.deferred.filter(k => !!g[k]);
        const told = {};
        if (!fresh)
            for (const k of Object.keys(root.announcing))
                if (g[k]) {
                    const items = root.announcing[k].items.filter(key => g[k].items.some(i => i.key === key));
                    if (items.length > 0)
                        told[k] = {
                            left: root.announcing[k].left,
                            items: items
                        };
                }
        const announce = (k, keys) => {
            if (fresh || root.expanded || keys.length === 0)
                return;
            told[k] = {
                left: root.announceMs,
                items: [...new Set([...(told[k]?.items ?? []), ...keys])]
            };
        };
        for (const k of root.high) {
            if (!g[k] || root.sizeOf(k) <= (before[k] ?? 0))
                continue;
            const known = root.seen[k] ?? [];
            const arrived = g[k].items.map(i => i.key).filter(key => !known.includes(key));
            const critical = k === "notification" && root.alerts.some(e => e.urgency === NotificationUrgency.Critical);
            if (k === centre && !held.includes(k)) {
                next = [k, ...next.filter(x => x !== k)];
                continue;
            }
            next = next.filter(x => x !== k);
            const company = next.length > 0;
            const card = next[0] === "notification" && !held.includes("notification");
            if (root.hovering && !critical) {
                if (company) {
                    next.splice(1, 0, k);
                    announce(k, k === "notification" ? ["notification"] : arrived);
                } else {
                    next.unshift(k);
                }
                if (!held.includes(k))
                    held.push(k);
                continue;
            }
            held = held.filter(x => x !== k);
            if (k === "notification") {
                next.unshift(k);
                delete told[k];
                continue;
            }
            if (k === "privacy" && company) {
                next.push(k);
                announce(k, arrived);
                continue;
            }
            if (card)
                next.splice(1, 0, k);
            else
                next.unshift(k);
            if (company)
                announce(k, arrived);
            else
                delete told[k];
        }
        if (!root.hovering && held.length > 0) {
            for (const k of root.high.filter(x => held.includes(x))) {
                next = next.filter(x => x !== k);
                next.unshift(k);
                if (k === "notification")
                    delete told[k];
            }
            held = [];
        }
        if (root.summon && g[root.summon]) {
            next = next.filter(x => x !== root.summon);
            next.unshift(root.summon);
            held = held.filter(x => x !== root.summon);
            delete told[root.summon];
        }
        root.summon = "";
        if (g.alarm) {
            next = ["alarm", ...next.filter(x => x !== "alarm")];
            held = held.filter(x => x !== "alarm");
            delete told.alarm;
        }
        const counted = {};
        const known = {};
        for (const k of Object.keys(g)) {
            counted[k] = root.sizeOf(k);
            known[k] = g[k].items.map(i => i.key);
        }
        root.sizes = counted;
        root.seen = known;
        root.deferred = held;
        if (JSON.stringify(told) !== JSON.stringify(root.announcing))
            root.announcing = told;
        if (next.join("|") !== root.order.join("|"))
            root.order = next;
        if (root.alerts.length === 0)
            root.fanning = false;
    }

    function choose(activity: var): void {
        if (activity?.kind === "dictation" && activity.action === "cancel") {
            Dictation.cancel();
            return;
        }
        if (activity?.kind === "privacy" && activity.data?.privacy === "mic") {
            root.openTask("microphone");
            return;
        }
        if (activity?.style === "wifi" && !activity.action) {
            root.openTask("wifi");
            return;
        }
        if (root.taskViews[activity?.kind ?? ""]) {
            if (activity.kind === "update" && activity.key)
                Notices.settle(activity.key);
            root.openTask(activity.kind);
            return;
        }
        if (activity?.kind === "notification") {
            root.summon = "notification";
            Qt.callLater(root.arrange);
            return;
        }
        if (activity?.kind === "music") {
            root.chosen(Object.assign({}, activity, {
                origin: root.handoff()
            }));
            return;
        }
        root.chosen(activity);
    }

    function handoff(): var {
        const parts = root.openness > 0.5 ? overview.mediaParts(scene) : root.rowOfKind("music")?.parts(scene);
        if (!parts?.cover)
            return null;
        const shift = root.surfaceX;
        const out = {
            body: Qt.rect(root.pillX + shift, root.pillY, root.pillWidth, root.pillHeight),
            radius: root.pillRadius,
            power: root.pillPower,
            glow: glow.value,
            titleSize: parts.titleSize,
            transportZoom: parts.transportZoom ?? 1
        };
        for (const key of ["cover", "title", "artist", "album", "beat", "scrub", "transport"]) {
            const r = parts[key];
            out[key] = r ? Qt.rect(r.x + shift, r.y, r.width, r.height) : null;
        }
        return out;
    }

    function handOff(): void {
        root.close();
        root.spent = true;
        root.reforming = true;
        for (const f of [glide, overviewTall, deckShare, overviewFade, wide, tall, cardRoom, swell])
            f.snap();
        presence.value = 0;
        settle.value = 0;
        Qt.callLater(root.reformed);
    }

    function reformed(): void {
        if (!root.reforming || !presence.settled)
            return;
        root.reforming = false;
        if (!root.hovering)
            root.spent = false;
    }

    property var heeded: []

    function heed(): void {
        const wanted = (root.groups.timer?.items ?? []).filter(i => i.ending).map(i => i.key);
        const fresh = wanted.some(k => !root.heeded.includes(k));
        if (wanted.join("|") !== root.heeded.join("|"))
            root.heeded = wanted;
        if (fresh)
            root.summon = "timer";
    }

    function tapBubble(key: string): void {
        if (!root.groups[key])
            return;
        root.summon = key;
        Qt.callLater(root.arrange);
    }

    function merged(shown: var, wanted: var): var {
        const next = wanted.slice();
        shown.forEach((k, i) => {
            if (!next.includes(k))
                next.splice(Math.min(i, next.length), 0, k);
        });
        return next;
    }

    function mergeBubbles(): void {
        const next = root.merged(root.shownBubbles, root.bubbleKeys);
        if (next.join("|") !== root.shownBubbles.join("|"))
            root.shownBubbles = next;
    }

    function mergeStack(): void {
        const next = root.merged(root.shownStack, root.stackKeys);
        if (next.join("|") !== root.shownStack.join("|"))
            root.shownStack = next;
    }

    function purgeBubbles(): void {
        const keep = root.shownBubbles.filter(k => root.bubbleKeys.includes(k) || (root.bubbleFor(k)?.grown ?? 0) > 0.01);
        if (keep.length !== root.shownBubbles.length)
            root.shownBubbles = keep;
    }

    function purgeStack(): void {
        const keep = root.shownStack.filter(k => root.stackKeys.includes(k) || (root.rowFor(k)?.shown ?? 0) > 0.01);
        if (keep.length !== root.shownStack.length)
            root.shownStack = keep;
    }

    function bubbleFor(key: string): Item {
        for (let i = 0; i < bubbles.count; i++) {
            const b = bubbles.itemAt(i);
            if (b?.key === key)
                return b;
        }
        return null;
    }

    function rowFor(key: string): Item {
        for (let i = 0; i < rows.count; i++) {
            const r = rows.itemAt(i);
            if (r?.key === key)
                return r;
        }
        return null;
    }

    function rowOfKind(kind: string): Item {
        for (let i = 0; i < rows.count; i++) {
            const r = rows.itemAt(i);
            if (r?.item?.kind === kind && r.here)
                return r;
        }
        return null;
    }

    function flickFront(direction: int): void {
        deck.dismissFront(direction);
    }

    function clearNotifications(only: var): void {
        deck.clearAll(only);
    }

    function close(): void {
        root.pinned = false;
        root.task = "";
        root.backToOverview = false;
        root.dwelt = false;
        root.spent = root.hovering;
    }

    function openTask(key: string): void {
        if (!root.tasking)
            root.backToOverview = root.openness > 0.5;
        root.pinned = false;
        root.task = key;
    }

    function leaveTask(): void {
        if (!root.backToOverview) {
            root.close();
            return;
        }
        root.backToOverview = false;
        root.task = "";
        root.pinned = true;
    }

    function back(): void {
        if (root.tasking)
            root.leaveTask();
        else
            root.close();
    }

    function dragTo(delta: real): void {
        if (!root.pulling)
            root.pullFrom = Math.max(0, Math.min(glide.value, 1));
        root.pulling = true;
        root.pullProgress = Math.max(0, Math.min(root.pullFrom + delta, 1));
        glide.hold(root.pullProgress);
    }

    function dragEnd(open: bool): void {
        if (!root.pulling) {
            glide.release();
            return;
        }
        root.pulling = false;
        root.pullProgress = 0;
        if (root.tasking) {
            if (!open)
                root.close();
        } else {
            root.pinned = open;
            if (!open)
                root.dwelt = false;
        }
        glide.release();
    }

    function catchGlide(down: bool): void {
        if (down && !glide.settled)
            glide.grab();
        else if (!down && !root.pulling)
            glide.release();
    }

    function claimKeys(): void {
        if (root.wantsEscape && !root.keyboardHeld)
            keys.forceActiveFocus();
    }

    function retrail(): void {
        if (root.trailing && islandHover.hovered)
            return;
        if (root.trailing)
            trail.target = root.windowOffset;
        else if (root.out)
            trail.target = 0;
        if (presence.value < 0.05)
            trail.snap();
    }

    function judge(x: real, y: real): void {
        if (!root.watching)
            return;
        const reach = Appearance.padding.large * (root.near ? 2 : 1);
        const left = (root.host?.x ?? 0) + root.surfaceX + root.pillX - reach;
        const top = root.host?.y ?? 0;
        const bottom = top + root.y + root.islandTop + root.pillHeight + reach;
        root.near = x >= left && x <= left + root.pillWidth + reach * 2 && y >= top && y <= bottom;
    }

    onTrailingChanged: root.retrail()
    onWindowOffsetChanged: root.retrail()
    onOutChanged: root.retrail()
    onSurfaceXChanged: scene.Window.window?.update()
    onWatchingChanged: if (!root.watching)
        root.near = false
    onVoiceChanged: if (root.voice)
        Hypr.resync()

    onGroupsChanged: {
        root.heed();
        Qt.callLater(root.arrange);
    }
    onStackKeysChanged: root.mergeStack()
    onBubbleKeysChanged: root.mergeBubbles()
    onAlertingChanged: if (!root.alerting && root.hovering && !root.expanded && !root.pulling)
        root.spent = true

    onExpandedChanged: {
        if (root.expanded)
            Media.sync();
        else
            Notifications.markSeen();
    }

    onUpgradeOpenChanged: SystemUpgrade.watchers += root.upgradeOpen ? 1 : -1
    onTaskChanged: if (root.task)
        root.heldTask = root.task

    Connections {
        target: Notifications

        function onReading(entry: var): void {
            if (!root.offStage)
                return;
            Notifications.markSeenOf([entry]);
            if (Notifications.popups.includes(entry))
                Notifications.expire(entry);
            root.reading = entry;
            root.openTask("reading");
        }
    }

    Connections {
        target: SystemUpgrade

        function onShownChanged(): void {
            if (!SystemUpgrade.shown && root.task === "upgrade")
                root.task = "";
        }
    }

    onHoveringChanged: {
        if (!root.hovering && !root.reforming)
            root.spent = false;
        if (root.hovering)
            Notifications.pause(root);
        else
            Notifications.resume(root);
        Qt.callLater(root.arrange);
    }

    onWaitingChanged: {
        const next = root.waiting.slice();
        for (const entry of root.holding)
            if (!next.includes(entry))
                entry.release(root);
        for (const entry of next)
            entry.hold(root);
        root.holding = next;
    }

    onAttendingChanged: {
        if (root.attending)
            Notices.hold(root);
        else
            Notices.release(root);
    }

    onWantsEscapeChanged: {
        if (root.wantsEscape)
            Qt.callLater(root.claimKeys);
        else
            keys.focus = false;
    }

    Component.onCompleted: {
        root.arrange(true);
        root.mergeStack();
        root.mergeBubbles();
        root.retrail();
    }

    Component.onDestruction: {
        if (root.upgradeOpen)
            SystemUpgrade.watchers -= 1;
        for (const entry of root.holding)
            entry.release(root);
        Notices.release(root);
        Notifications.resume(root);
    }

    Timer {
        interval: 100
        repeat: true
        running: Object.keys(root.announcing).length > 0 && !root.hovering && !root.expanded && !root.pulling

        onTriggered: {
            const next = {};
            for (const k of Object.keys(root.announcing)) {
                const left = root.announcing[k].left - interval;
                if (left > 0)
                    next[k] = {
                        left: left,
                        items: root.announcing[k].items
                    };
            }
            root.announcing = next;
        }
    }

    Timer {
        interval: Appearance.animation.dwell
        running: root.hovering && !root.dwelt && !root.spent && !root.alerting
        onTriggered: root.dwelt = true
    }

    Timer {
        interval: Appearance.animation.grace
        running: !root.hovering && root.dwelt
        onTriggered: root.dwelt = false
    }

    Timer {
        interval: Appearance.animation.dwell
        running: islandHover.hovered && root.alerting && root.alerts.length > 1 && !root.fanning && !deck.handling
        onTriggered: root.fanning = true
    }

    Timer {
        interval: Appearance.animation.grace
        running: root.fanning && !islandHover.hovered && !deck.handling
        onTriggered: root.fanning = false
    }

    Follow {
        id: presence

        speed: Appearance.animation.revealSpeed * 0.55
        target: root.out ? 1 : 0
        epsilon: 0.004

        onSettledChanged: root.reformed()
    }

    Follow {
        id: settle

        speed: settle.target > settle.value ? Appearance.animation.revealSpeed * 0.2 : Appearance.animation.revealSpeed
        target: root.out && !root.tucked ? 1 : 0
        epsilon: 0.004
    }

    Follow {
        id: trail

        speed: Appearance.animation.trackSpeed / 2
    }

    Follow {
        id: tuck

        speed: Appearance.animation.revealSpeed
        target: root.tucked ? 1 : 0
        epsilon: 0.004
    }

    Socket {
        id: pointer

        property string reply: ""

        path: Hypr.requestSocket

        onConnectedChanged: {
            if (!pointer.connected)
                return;
            pointer.reply = "";
            pointer.write("j/cursorpos");
            pointer.flush();
        }

        parser: SplitParser {
            splitMarker: ""
            onRead: data => {
                pointer.reply += data;
                let pos;
                try {
                    pos = JSON.parse(pointer.reply);
                } catch (e) {
                    return;
                }
                pointer.connected = false;
                if (typeof pos.x === "number" && typeof pos.y === "number")
                    root.judge(pos.x, pos.y);
            }
        }
    }

    Timer {
        interval: 80
        repeat: true
        running: root.watching
        onTriggered: if (!pointer.connected)
            pointer.connected = true
    }

    readonly property real morphSpeed: Appearance.animation.resizeSpeed * 0.7

    function fadeSpeed(fade: Follow): real {
        return fade.target < fade.value ? Appearance.animation.revealSpeed * 2 : Appearance.animation.revealSpeed;
    }

    Follow {
        id: wide

        speed: root.morphSpeed
        target: root.out ? root.restWidth : root.compactHeight
    }

    Follow {
        id: tall

        speed: root.deckRest && root.fanLeads || deck.raised !== 0 ? 0 : root.morphSpeed
        target: root.out ? root.restHeight : root.compactHeight
    }

    Follow {
        id: overviewTall

        speed: root.morphSpeed
        target: root.tasking ? root.taskHeight : overview.restHeight
    }

    Follow {
        id: deckShare

        speed: root.morphSpeed
        epsilon: 0.004
        target: root.tasking ? 0 : 1
        startsAtTarget: true
    }

    Follow {
        id: span

        speed: root.morphSpeed
        value: root.largeWidth
        target: root.tasking ? root.taskWidth : root.largeWidth
    }

    Follow {
        id: taskFade

        speed: root.fadeSpeed(taskFade)
        epsilon: 0.004
        target: root.tasking ? 1 : 0

        onSettledChanged: if (taskFade.settled && !root.tasking)
            root.heldTask = ""
    }

    Spring {
        id: glide

        epsilon: 0.002
        target: root.openness
    }

    Follow {
        id: swell

        speed: Appearance.animation.revealSpeed
        epsilon: 0.05
        target: root.rest === "compact" && root.hovering && root.openness === 0 ? Appearance.padding.small : 0
    }

    Follow {
        id: cardRoom

        speed: tall.speed
        epsilon: 0.1
        target: root.cardHeight
    }

    Follow {
        id: deckFade

        speed: root.fadeSpeed(deckFade)
        epsilon: 0.004
        target: root.deckEntries.length > 0 && !root.tasking && (root.alerting || root.openness > 0) ? 1 : 0
    }

    property bool fanLeads: false

    Follow {
        id: fan

        speed: root.morphSpeed
        epsilon: 0.004
        target: root.rest === "spread" || root.openness > 0 ? 1 : 0

        onTargetChanged: root.fanLeads = root.deckRest && Math.abs(tall.value - tall.target) < 1
        onSettledChanged: if (fan.settled)
            root.fanLeads = false
    }

    property bool thirdLayer: false

    Follow {
        id: deal

        speed: deck.shuffleSpeed
        epsilon: 0.002
        value: 1
        target: 1

        onSettledChanged: if (deal.settled)
            root.ghost = null
    }

    Follow {
        id: roll

        speed: deck.shuffleSpeed
        epsilon: 0.004
        value: 1
        target: 1

        onValueChanged: if (roll.target === 0 && roll.value === 0) {
            roll.value = 1;
            roll.target = 1;
        }
    }

    Follow {
        id: backs

        speed: deck.shuffleSpeed
        epsilon: 0.004
        target: Math.min(2, Math.max(0, deck.standing.length - 1))
    }

    Follow {
        id: peek

        speed: Appearance.animation.revealSpeed
        epsilon: 0.004
        target: root.rest === "stack" ? 1 : 0
    }

    Follow {
        id: overviewFade

        speed: root.fadeSpeed(overviewFade)
        epsilon: 0.004
        target: root.openness
    }

    Follow {
        id: glow

        speed: Appearance.animation.revealSpeed * 0.6
        epsilon: 0.004
        target: !Media.hasTrack || root.tasking ? 0 : root.openness > 0 ? 0.62 * root.openness : root.rest === "compact" && root.passing.some(p => p.kind === "music") ? 0.45 : 0
    }

    Pull {
        id: zone

        z: 1

        hoverEnabled: true
        height: Config.values.control.touchEdges ? Math.max(root.border, Appearance.sizes.minTarget) : root.border
        width: Math.max(root.pillWidth, root.largeWidth / 2)
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        dirX: 0
        dirY: 1
        angle: Config.values.control.pullAngleEdge
        travel: Math.max(1, overview.implicitHeight - root.compactHeight)

        onTapped: {
            if (root.tasking)
                root.close();
            else
                root.pinned = !root.pinned;
        }
        onPulled: fraction => {
            if (!root.tasking)
                root.dragTo(fraction);
        }
        onFinished: open => root.dragEnd(open)
        onPressedChanged: root.catchGlide(zone.pressed)

        HoverHandler {
            id: stripHover
        }
    }

    Item {
        id: keys

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                Appearance.instantly();
                root.back();
                event.accepted = true;
            }
        }
    }

    Item {
        id: pass

        readonly property Item over: !root.interactive ? null : root.whole ? hit : bubblesHit

        x: root.surfaceX + (pass.over?.x ?? 0)
        y: pass.over?.y ?? 0
        width: pass.over?.width ?? 0
        height: pass.over?.height ?? 0
    }

    Repeater {
        id: measures

        model: ScriptModel {
            values: root.stackItems
            objectProp: "key"
        }

        ActivityRow {
            required property var modelData

            visible: false
            activity: modelData
            live: false
        }
    }

    PanelWindow {
        id: surface

        screen: root.host

        anchors.top: true
        anchors.left: true
        margins.top: root.y
        margins.left: root.surfaceX

        implicitWidth: root.fieldWidth
        implicitHeight: root.fieldHeight
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: root.tasking ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        WlrLayershell.namespace: "banditshell-island"

        mask: Region {
            item: !root.interactive ? null : root.whole ? hit : bubblesHit
        }

        Item {
            id: scene

            focus: true
            visible: !root.yielded

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape && root.tasking) {
                    root.back();
                    event.accepted = true;
                }
            }
            width: root.fieldWidth
            height: root.fieldHeight
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: 3

                SquircleRect {
                    id: layer

                    required property int index

                    readonly property bool tucked: layer.index === 2
                    readonly property real depth: layer.tucked ? 2 - 0.6 * roll.value : layer.index + roll.value
                    readonly property real kept: layer.tucked ? (root.thirdLayer ? 1 - roll.value : 0) : Math.max(0, Math.min(1, backs.value + 1 - layer.depth))
                    readonly property real shown: peek.value * presence.value * (1 - root.opened)
                    readonly property real ghostness: layer.index === 0 && root.ghost ? (1 - roll.value) * (1 - fan.value) * presence.value : 0
                    readonly property real strip: root.pillRadius * 2 + Appearance.padding.small
                    readonly property real stand: root.ghost && layer.index === 0 ? root.ghostHeight + (root.pillHeight - root.ghostHeight) * roll.value : root.pillHeight
                    readonly property real reach: Appearance.padding.small * 1.2 * layer.depth * (layer.ghostness > 0 ? 1 : layer.shown)

                    z: layer.tucked ? -4 : -1 - layer.depth
                    width: root.pillWidth * (1 - 0.07 * layer.depth)
                    height: root.ghost && layer.index === 0 ? root.ghostHeight + (layer.strip - root.ghostHeight) * roll.value : layer.strip
                    x: root.centreX - width / 2
                    y: root.pillY + layer.stand - height + layer.reach
                    radius: root.pillRadius
                    cornerPower: root.pillPower
                    color: Appearance.blend(Appearance.colour.island, Appearance.colour.paper, layer.depth < 1 ? 0.06 * layer.depth : 0.09 - 0.03 * layer.depth)
                    stroke: Appearance.colour.seam
                    strokeWidth: Appearance.stroke.line
                    opacity: Math.max(layer.shown * layer.kept, layer.ghostness)
                    visible: layer.opacity > 0.01

                    Item {
                        id: uncovered

                        y: Math.max(0, Math.min(layer.height, root.pillY + root.dealY + root.pillHeight - layer.y))
                        width: layer.width
                        height: layer.height - uncovered.y
                        clip: true
                        visible: layer.ghostness > 0.01

                        NotificationCard {
                            y: -uncovered.y
                            width: root.largeWidth
                            entry: root.ghost
                            enabled: false
                            scale: layer.width / Math.max(1, root.largeWidth)
                            transformOrigin: Item.TopLeft
                            opacity: 1 - roll.value
                        }
                    }
                }
            }

            Repeater {
                model: ScriptModel {
                    values: root.shownBubbles
                }

                Item {
                    id: under

                    required property int index

                    readonly property Item twin: {
                        bubbles.count;
                        return bubbles.itemAt(under.index);
                    }
                    readonly property real fade: (under.twin?.grown ?? 0) * (1 - (under.twin?.travel ?? 0)) * presence.value

                    DropShadow {
                        x: under.twin?.x ?? 0
                        y: under.twin?.y ?? 0
                        width: under.twin?.width ?? 0
                        height: under.twin?.height ?? 0
                        pill: "object"
                        opacity: settle.value * Appearance.opacity.glow * under.fade
                        visible: opacity > 0.01
                    }

                    Repeater {
                        model: 2

                        SquircleRect {
                            id: behind

                            required property int index

                            readonly property int d: behind.index + 1

                            Follow {
                                id: behindShown

                                speed: Appearance.animation.revealSpeed
                                epsilon: 0.004
                                target: (under.twin?.depth ?? 0) >= behind.d ? 1 : 0
                            }

                            z: -behind.d
                            x: under.twin?.x ?? 0
                            y: (under.twin?.y ?? 0) + root.stackStep * behind.d * behindShown.value
                            width: under.twin?.width ?? 0
                            height: width
                            pill: "object"
                            color: Appearance.blend(Appearance.colour.island, Appearance.colour.paper, 0.06 * behind.d)
                            stroke: Appearance.colour.seam
                            strokeWidth: Appearance.stroke.line
                            opacity: under.fade * behindShown.value
                            visible: opacity > 0.01
                        }
                    }
                }
            }

            Item {
                id: voiceCapsule

                readonly property real shown: voiceOut.value * presence.value

                x: root.pillX + root.pillWidth - voiceCapsule.width + (voiceCapsule.width + root.budGap) * voiceOut.value
                y: root.pillY
                width: voiceRow.implicitWidth
                height: root.compactHeight
                opacity: Math.min(1, voiceCapsule.shown * 1.5)
                visible: voiceCapsule.shown > 0.01

                Follow {
                    id: voiceOut

                    speed: Appearance.animation.revealSpeed
                    epsilon: 0.004
                    target: root.voiceAside ? 1 : 0
                }

                DropShadow {
                    anchors.fill: parent
                    pill: "object"
                    opacity: settle.value * Appearance.opacity.glow * voiceCapsule.shown
                }

                SquircleRect {
                    anchors.fill: parent
                    pill: "object"
                    color: Appearance.colour.island
                    stroke: Appearance.colour.seam
                    strokeWidth: Appearance.stroke.line
                }

                ActivityRow {
                    id: voiceRow

                    width: parent.width
                    height: parent.height
                    activity: root.voiceActivity
                    live: voiceCapsule.visible
                }
            }

            DropShadow {
                x: root.pillX
                y: root.pillY + root.dealY
                width: root.pillWidth
                height: root.pillHeight
                radius: root.pillRadius
                opacity: settle.value * Appearance.opacity.glow * deal.value
            }

            IslandField {
                anchors.fill: parent

                pillRect: Qt.rect(root.pillX, root.pillY + root.dealY, root.pillWidth, root.pillHeight)
                budRects: {
                    const out = [];
                    for (let i = 0; i < Math.min(root.bubbleMax, bubbles.count); i++)
                        out.push(bubbles.itemAt(i)?.shape);
                    return out;
                }
                budReaches: {
                    const out = [];
                    for (let i = 0; i < Math.min(root.bubbleMax, bubbles.count); i++)
                        out.push(bubbles.itemAt(i)?.reach ?? 0);
                    return out;
                }
                pillRadius: root.pillRadius
                power: root.pillPower
                smoothing: root.budGap * 0.8

                edge: root.edge
                neck: root.neck

                source: inkSource
                visible: presence.value > 0.001
            }

            ShaderEffectSource {
                id: inkSource

                sourceItem: ink
                hideSource: true
                live: true
                visible: false
            }

            Item {
                id: ink

                anchors.fill: parent

                ArtGlow {
                    x: root.centreX - root.largeWidth / 2
                    y: root.pillY
                    width: root.largeWidth
                    height: Math.max(root.compactHeight, overview.implicitHeight, root.pillHeight)
                    moving: visible
                    opacity: glow.value
                    visible: glow.value > 0.005
                }

                Pull {
                    id: shut

                    x: root.pillX
                    y: root.pillY
                    width: root.pillWidth
                    height: root.pillHeight
                    enabled: root.expanded

                    dirX: 0
                    dirY: -1
                    angle: Config.values.control.pullAngleEdge
                    travel: Math.max(1, (root.tasking ? root.taskHeight : overview.implicitHeight) - root.compactHeight)

                    onPulled: fraction => root.dragTo(-fraction)
                    onFinished: open => root.dragEnd(!open)
                    onPressedChanged: root.catchGlide(shut.pressed)
                }

                IslandOverview {
                    id: overview

                    x: root.centreX - root.largeWidth / 2
                    y: root.pillY
                    width: root.largeWidth
                    activities: root.overviewRows
                    notifications: root.recentGroups
                    room: root.taskRoom
                    watched: overviewFade.value > 0.01 && taskFade.value < 0.99
                    arrivals: root.deckEntries.length > 0 ? deck.implicitHeight : 0
                    carried: root.stackKeys
                    carriedOpacity: 1
                    opacity: Math.max(0, (overviewFade.value - 0.4) / 0.6) * presence.value * (1 - taskFade.value)
                    visible: opacity > 0.005
                    enabled: root.expanded && !root.tasking

                    onChosen: activity => root.choose(activity)
                    onLifted: root.close()
                }

                Loader {
                    id: taskView

                    x: root.centreX - root.taskWidth / 2
                    y: root.pillY
                    width: root.taskWidth
                    active: root.heldTask !== ""
                    sourceComponent: root.taskViews[root.heldTask] ?? null
                    opacity: Math.max(0, (overviewFade.value - 0.4) / 0.6) * presence.value * taskFade.value
                    visible: opacity > 0.005
                    enabled: root.tasking && root.expanded

                    onLoaded: {
                        taskView.item.watched = Qt.binding(() => root.tasking && taskFade.value > 0.01);
                        taskView.item.maxHeight = Qt.binding(() => root.taskRoom);
                    }

                    Connections {
                        target: taskView.item

                        function onHide(): void {
                            root.leaveTask();
                        }

                        function onAct(notice: var): void {
                            root.close();
                            root.chosen(notice);
                        }

                        function onOpen(key: string): void {
                            root.openTask(key);
                        }
                    }
                }

                AlertDeck {
                    id: deck

                    x: root.centreX - root.largeWidth / 2
                    y: root.deckY + root.dealY
                    width: root.largeWidth
                    entries: root.deckEntries
                    fanned: fan.value
                    maxHeight: Math.max(root.compactHeight * 4, ((root.host?.height ?? 1080) - root.islandTop) * 0.55)
                    opacity: deckFade.value * presence.value
                    visible: opacity > 0.005
                    enabled: (root.deckRest || root.openness > 0) && !root.tasking

                    onDismissed: entry => Notifications.dismiss(entry)
                    onKept: entry => Notifications.expire(entry)
                    onHistory: root.openTask("notifications")
                    onLifted: {
                        for (const entry of root.alerts)
                            Notifications.expire(entry);
                        root.fanning = false;
                        if (root.expanded)
                            root.close();
                    }
                    onAdvanced: (forward, count, previous) => {
                        if (root.fanning || root.openness > 0)
                            return;
                        root.thirdLayer = forward ? count >= 4 : count >= 3;
                        if (forward) {
                            root.ghostHeight = root.pillHeight;
                            root.ghost = previous;
                            roll.value = 0;
                            roll.target = 1;
                            deal.value = 0;
                            deal.target = 1;
                        } else {
                            roll.target = 0;
                        }
                    }
                }

                Repeater {
                    id: rows

                    model: ScriptModel {
                        values: root.shownStack
                    }

                    ActivityRow {
                        id: row

                        required property string modelData
                        required property int index

                        readonly property string key: row.modelData
                        property var held: null
                        readonly property var item: root.stackByKey[row.key] ?? row.held
                        readonly property bool here: root.stackKeys.includes(row.key)
                        property int place: 0
                        readonly property real shown: appear.value

                        property real heldTop: -1
                        readonly property real liveTop: root.tasking ? -1 : overview.rowTop(row.key)
                        readonly property real toY: row.liveTop >= 0 ? row.liveTop : row.heldTop
                        readonly property bool carried: row.here && !root.tasking && row.toY >= 0
                        readonly property real t: row.carried ? root.opened : 0
                        readonly property real fromWidth: root.pillWidth - swell.value * 2
                        readonly property real toX: overview.x + overview.pad
                        readonly property real toWidth: overview.width - overview.pad * 2
                        readonly property real restY: cardRoom.value + offset.value
                        readonly property real markX: row.x + row.inset
                        readonly property real markY: row.y + (row.height - row.slot) / 2

                        onItemChanged: if (root.stackByKey[row.key])
                            row.held = root.stackByKey[row.key]
                        onLiveTopChanged: if (row.liveTop >= 0)
                            row.heldTop = row.liveTop

                        function reslot(): void {
                            const i = root.stackKeys.indexOf(row.key);
                            if (i >= 0)
                                row.place = i;
                        }

                        Follow {
                            id: appear

                            speed: root.fadeSpeed(appear)
                            epsilon: 0.004
                            target: row.here ? 1 : 0

                            onValueChanged: if (appear.value === 0 && !row.here)
                                Qt.callLater(root.purgeStack)
                        }

                        Travel {
                            id: offset

                            epsilon: 0.1
                            target: row.place * root.compactHeight
                        }

                        Connections {
                            target: root

                            function onStackKeysChanged(): void {
                                row.reslot();
                            }
                        }

                        Component.onCompleted: {
                            row.held = root.stackByKey[row.key] ?? null;
                            row.reslot();
                            offset.snap();
                        }

                        x: root.pillX + swell.value + (row.toX - root.pillX - swell.value) * row.t
                        y: root.pillY + root.dealY * (1 - row.t) + row.restY + (row.toY - row.restY) * row.t
                        width: row.fromWidth + (row.toWidth - row.fromWidth) * row.t
                        activity: row.item
                        lights: row.t > 0.5
                        live: root.focused && row.visible
                        opacity: presence.value * appear.value * (1 - tuck.value) * (row.carried ? 1 : Math.max(0, 1 - root.opened * 2.5))
                        visible: opacity > 0.005
                        enabled: row.here && (root.openness === 0 || row.carried)

                        onChosen: root.choose(row.item)
                        onActed: name => root.choose(Object.assign({}, row.item, {
                                action: name
                            }))
                    }
                }
            }

            Repeater {
                id: bubbles

                model: ScriptModel {
                    values: root.shownBubbles
                }

                Item {
                    id: bubble

                    required property string modelData
                    required property int index

                    readonly property string key: bubble.modelData
                    property var held: null
                    readonly property var group: root.viewOf(bubble.key) ?? bubble.held
                    readonly property bool here: root.bubbleKeys.includes(bubble.key)
                    readonly property real grown: grow.value
                    readonly property real reach: root.budGap * (0.8 + 1.6 * (1 - grow.value))
                    readonly property int depth: Math.min(2, Math.max(0, (bubble.group?.kind === "notification" ? (bubble.group.items[0]?.count ?? 1) : (bubble.group?.items.length ?? 1)) - 1))
                    readonly property real lean: root.stackStep * depthShown.value / 2
                    readonly property real full: root.compactHeight * (0.6 + 0.4 * grow.value) * (1 + 0.12 * hoverGlow.value)

                    readonly property real travel: Math.min(1, root.opened * 2.2)
                    readonly property real restCx: root.pillX + root.pillWidth + slide.value - bubble.full + (bubble.full + root.budGap) * grow.value + bubble.full / 2
                    readonly property real restCy: root.pillY + root.compactHeight / 2 - bubble.lean
                    readonly property real cx: bubble.restCx + (root.pillX + root.pillWidth - bubble.full / 2 - bubble.restCx) * bubble.travel
                    readonly property real cy: bubble.restCy
                    readonly property real size: bubble.full * (1 - 0.5 * bubble.travel)
                    readonly property real body: bubble.size * (1 - bubble.travel)
                    readonly property rect shape: grow.value > 0.01 && bubble.travel < 0.98 ? Qt.rect(bubble.cx - bubble.body / 2, bubble.cy - bubble.body / 2, bubble.body, bubble.body) : Qt.rect(0, 0, 0, 0)

                    onGroupChanged: if (root.groups[bubble.key])
                        bubble.held = root.viewOf(bubble.key)
                    onHereChanged: if (!bubble.here && grow.value < 0.01)
                        Qt.callLater(root.purgeBubbles)

                    Follow {
                        id: grow

                        speed: Appearance.animation.trackSpeed * 0.5
                        epsilon: 0.004
                        target: bubble.here ? 1 : 0

                        onValueChanged: if (grow.value === 0 && !bubble.here)
                            Qt.callLater(root.purgeBubbles)
                    }

                    Follow {
                        id: slide

                        speed: root.morphSpeed
                        epsilon: 0.1
                        target: bubble.index * root.bubblePitch
                    }

                    Follow {
                        id: depthShown

                        speed: Appearance.animation.revealSpeed
                        epsilon: 0.01
                        target: bubble.depth
                    }

                    Follow {
                        id: hoverGlow

                        speed: Appearance.animation.snapSpeed
                        epsilon: 0.004
                        target: tap.containsMouse && grow.value > 0.5 ? 1 : 0
                    }

                    Component.onCompleted: {
                        bubble.held = root.viewOf(bubble.key) ?? null;
                        slide.snap();
                        depthShown.snap();
                    }

                    x: bubble.cx - bubble.size / 2
                    y: bubble.cy - bubble.size / 2
                    width: bubble.size
                    height: bubble.size
                    opacity: presence.value * Math.max(0, 1 - bubble.travel * 1.6)
                    visible: grow.value > 0.01 && opacity > 0.01

                    ActivityBubble {
                        id: face

                        anchors.fill: parent
                        group: bubble.group
                        size: bubble.size
                        live: grow.value > 0.5
                        markOpacity: Math.min(1, grow.value * 1.5)
                        stateShown: Math.max(0, grow.value * 2 - 1)
                    }

                    MouseArea {
                        id: tap

                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: bubble.here && root.openness === 0
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.tapBubble(bubble.key)
                    }

                    SquircleRect {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height + Appearance.padding.small + root.stackStep * 2
                        width: label.implicitWidth + Appearance.padding.normal * 2
                        height: label.implicitHeight + Appearance.padding.small
                        pill: "object"
                        color: Appearance.colour.island
                        opacity: hoverGlow.value
                        visible: opacity > 0.01 && !!face.label

                        StyledText {
                            id: label

                            anchors.centerIn: parent
                            text: face.label
                        }
                    }
                }
            }

            ArtCrossfade {
                readonly property Item from: {
                    rows.count;
                    root.stackKeys;
                    return root.rowOfKind("music");
                }
                readonly property rect to: overview.coverRect
                readonly property real t: root.opened
                readonly property real startX: from ? from.markX : root.centreX
                readonly property real startY: from ? from.markY : root.pillY

                x: startX + (root.centreX - root.largeWidth / 2 + to.x - startX) * t
                y: startY + (root.pillY + to.y - startY) * t
                width: root.slot + (to.width - root.slot) * t
                height: width
                source: Media.hasTrack ? Media.artUrl : ""
                opacity: presence.value * (from?.shown ?? 0) * Math.min(1, t * 6) * (1 - Math.max(0, (t - 0.8) / 0.2)) * (1 - taskFade.value)
                visible: !!from && to.width > 0 && opacity > 0.01
            }

            Item {
                id: hit

                x: root.pillX
                y: root.pillY
                width: Math.max(root.pillWidth, root.chainRight - root.pillX)
                height: Math.max(root.pillHeight, root.compactHeight)

                HoverHandler {
                    id: islandHover

                    onHoveredChanged: root.retrail()
                }
            }

            Item {
                id: bubblesHit

                x: root.pillX + root.pillWidth
                y: root.pillY
                width: root.bubbleKeys.length * root.bubblePitch
                height: root.compactHeight
            }
        }
    }

    Component {
        id: upgradeView

        IslandUpgrade {}
    }

    Component {
        id: updateView

        IslandShellUpdate {}
    }

    Component {
        id: notificationsView

        IslandNotifications {}
    }

    Component {
        id: readingView

        IslandNotificationPage {
            entry: root.reading
        }
    }

    Component {
        id: timersView

        IslandTimers {}
    }

    Component {
        id: weatherView

        IslandWeather {}
    }

    Component {
        id: calendarView

        IslandCalendar {}
    }

    Component {
        id: microphoneView

        IslandMicrophone {}
    }

    Component {
        id: wifiView

        IslandWifi {}
    }
}
