pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.config
import qs.components
import "catalogue.js" as Catalogue

Item {
    id: root

    property real trailRoom: 0
    property bool covered: false
    property bool showing: true
    property bool lingering: false

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

    Binding {
        target: SettingsView
        property: "sceneSeen"
        when: root.showing
        value: !root.covered && stage.visible && stage.y + stage.height > view.contentY && stage.y < view.contentY + view.height
        restoreMode: Binding.RestoreNone
    }

    readonly property string sceneName: SettingsView.home || SettingsView.fold && SettingsView.preview === "arrange" ? "" : SettingsView.preview

    readonly property var s: SettingsState
    property string pendingReveal: ""
    property double revealUntil: 0
    property var recent: []
    readonly property real fade: SettingsView.reduceMotion ? 1 : 1 - arrive.value
    readonly property real slide: SettingsView.reduceMotion ? 0 : arrive.value * 8

    function tone(c: color, t: string): string {
        return `<font color="${c}">${String(t ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")}</font>`;
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

    Flickable {
        id: view

        width: parent.width
        height: parent.height - status.height
        contentHeight: body.implicitHeight + Appearance.padding.large
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        readonly property real fade: Appearance.font.line.normal * 1.5

        layer.enabled: view.contentHeight > view.height
        layer.effect: ShaderEffect {
            readonly property vector4d fades: Qt.vector4d(view.atYBeginning ? 0 : view.fade, view.atYEnd ? 0 : view.fade, height, 1)

            fragmentShader: Qt.resolvedUrl("../../components/edgefade.frag.qsb")
        }

        onContentYChanged: SettingsView.scroll = view.contentY
        onMovementStarted: {
            SettingsView.resumeScroll = 0;
            root.pendingReveal = "";
        }
        onContentHeightChanged: {
            root.resume();
            if (root.pendingReveal && Date.now() < root.revealUntil)
                root.reveal(root.pendingReveal, true);
        }
        onHeightChanged: root.resume()

        WheelStep {
            id: wheel

            flick: view

            onBegan: {
                SettingsView.resumeScroll = 0;
                root.pendingReveal = "";
            }
        }

        Column {
            id: body

            width: view.width

            Connections {
                target: SettingsView

                function onTurnChanged(): void {
                    wheel.stop();
                    view.contentY = 0;
                    arrive.value = 1;
                }

                function onCurrentChanged(): void {
                    root.keep(SettingsView.current);
                }

                function onFlashChanged(): void {
                    root.takeFlash();
                }
            }

            Follow {
                id: arrive

                target: 0
                speed: Appearance.animation.revealSpeed
                epsilon: 0.005
            }

            Item {
                id: head

                width: parent.width
                height: SettingsView.home ? 0 : Math.max(back.visible ? back.height + 4 : 0, words.implicitHeight) + 2 + Appearance.padding.large
                visible: !SettingsView.home
                opacity: root.fade
                transform: Translate {
                    y: root.slide
                }

                SettingsTool {
                    id: back

                    x: 0
                    y: 2
                    visible: !SettingsView.hub && !SettingsView.home
                    icon: "arrow_back"
                    tip: SettingsView.cat?.name.toLowerCase() ?? ""
                    onClicked: SettingsView.go(SettingsView.cat.id)
                }

                SettingsTool {
                    id: pageReset

                    readonly property var changed: SettingsView.hub || SettingsView.home ? [] : Catalogue.pageChanges(SettingsView.current, root.s)

                    x: parent.width - root.trailRoom - width
                    y: 2
                    visible: pageReset.changed.length > 0
                    icon: "restart_alt"
                    tip: pageReset.changed.length === 1 ? "reset the 1 changed setting on this page" : `reset the ${pageReset.changed.length} changed settings on this page`
                    onClicked: {
                        const was = SettingsState.resetPage(SettingsView.current);
                        if (was.length > 0)
                            SettingsView.drop(was.length === 1 ? "1 setting reset" : `${was.length} settings reset`, "restart_alt", {
                                label: "undo",
                                run: () => SettingsState.putBack(was)
                            });
                    }
                }

                Column {
                    id: words

                    x: back.visible ? back.x + back.width + Appearance.padding.normal : Appearance.padding.small
                    y: 0
                    width: parent.width - x - root.trailRoom - (pageReset.visible ? pageReset.width + Appearance.padding.small : 0)

                    StyledText {
                        width: parent.width
                        text: SettingsView.title
                        font.pixelSize: Appearance.font.size.large
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    StyledText {
                        width: parent.width
                        visible: text !== ""
                        text: SettingsView.home ? "" : SettingsView.hub ? String(SettingsView.cat.blurb(root.s) ?? "") : String(SettingsView.page?.status(root.s) ?? "")
                        color: Appearance.colour.textFaint
                        elide: Text.ElideRight
                    }
                }
            }

            Item {
                id: stage

                readonly property real wanted: scene.item?.stageHeight ?? 220
                readonly property bool rounded: GraphicsInfo.api !== GraphicsInfo.Software && !!scene.item

                visible: root.sceneName !== ""
                width: parent.width
                height: stage.visible ? Math.max(200, stage.wanted) + Appearance.padding.card : 0
                opacity: root.fade
                transform: Translate {
                    y: root.slide
                }

                HoverHandler {
                    onHoveredChanged: if (hovered)
                        SettingsView.replays++
                }

                Item {
                    id: plate

                    width: parent.width
                    height: parent.height - Appearance.padding.card

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
                            active: root.lingering && root.sceneName !== ""
                            source: root.sceneName ? Qt.resolvedUrl(`scenes/${root.sceneName.charAt(0).toUpperCase()}${root.sceneName.slice(1)}Scene.qml`) : ""
                        }
                    }
                }
            }

            Item {
                id: folded

                readonly property bool wanted: SettingsView.fold && !SettingsView.hub && SettingsView.current === "screens"
                readonly property real full: SettingsView.foldHeight + Appearance.padding.card

                width: parent.width
                height: Math.round(folded.full * drop.value)
                visible: height > 0.5
                clip: true
                opacity: root.fade
                transform: Translate {
                    y: root.slide
                }

                Follow {
                    id: drop

                    target: folded.wanted ? 1 : 0
                    speed: Appearance.animation.revealSpeed
                    epsilon: 0.002
                }

                Item {
                    y: Appearance.padding.card + folded.height - folded.full
                    width: parent.width
                    height: SettingsView.foldHeight

                    SquircleRect {
                        anchors.fill: parent
                        radius: Appearance.rounding.large
                        color: Appearance.colour.fill
                    }

                    Loader {
                        anchors.fill: parent
                        active: folded.wanted || drop.value > 0.002
                        sourceComponent: ScreenCanvas {
                            editable: true
                        }
                    }
                }
            }

            Repeater {
                model: shelves

                delegate: Column {
                    id: shelf

                    required property string pageId

                    readonly property var cat: Catalogue.CAT_BY_ID[shelf.pageId] ?? null
                    readonly property var page: shelf.cat ? null : Catalogue.PAGE_BY_ID[shelf.pageId] ?? null
                    readonly property double born: Date.now()
                    readonly property int budget: Math.ceil(view.height / Appearance.sizes.rowHeight) + 1

                    visible: shelf.pageId === SettingsView.current
                    opacity: shelf.visible ? root.fade : 1
                    transform: Translate {
                        y: shelf.visible ? root.slide : 0
                    }

                    Binding on width {
                        value: body.width
                        when: shelf.visible
                        restoreMode: Binding.RestoreNone
                    }

                    Loader {
                        width: parent.width
                        active: shelf.pageId === "home"
                        visible: active
                        sourceComponent: SettingsHome {}
                    }

                    Loader {
                        width: parent.width
                        active: !!shelf.cat
                        visible: active
                        sourceComponent: SettingsHub {
                            cat: shelf.cat
                        }
                    }

                    Repeater {
                        model: (shelf.page?.groups ?? []).filter(g => Catalogue.present(g, root.s))

                        delegate: Column {
                            id: group

                            required property var modelData
                            required property int index

                            readonly property string heading: String(Catalogue.val(group.modelData.t, root.s) ?? "")
                            readonly property int before: shelf.page.groups.slice(0, shelf.page.groups.indexOf(group.modelData)).reduce((n, g) => n + g.rows.length, 0)

                            width: shelf.width
                            z: SettingsView.lifted !== "" && group.modelData.rows.some(r => r.uid === SettingsView.lifted) ? 1 : 0
                            topPadding: group.index > 0 || group.heading !== "" ? Appearance.padding.large : 0
                            spacing: Appearance.padding.small

                            StyledText {
                                x: Appearance.padding.small
                                visible: group.heading !== ""
                                bottomPadding: Appearance.padding.small
                                text: group.heading
                                font.pixelSize: Appearance.font.size.normal
                                font.weight: Font.DemiBold
                            }

                            Repeater {
                                model: group.modelData.rows

                                delegate: SettingsCell {
                                    required property var modelData
                                    required property int index

                                    width: shelf.width
                                    row: modelData
                                    asynchronous: Date.now() - shelf.born < 1000 && group.before + index >= shelf.budget
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    StyledText {
        id: status

        readonly property var r: SettingsView.hovered && SettingsView.hovered.page === SettingsView.current ? SettingsView.hovered : null
        readonly property var w: SettingsState.wrote
        readonly property string fallback: root.defaultText(status.r)

        x: Appearance.padding.small
        y: parent.height - height
        width: parent.width - Appearance.padding.small * 2
        height: Appearance.font.line.small + Appearance.padding.small
        verticalAlignment: Text.AlignBottom
        textFormat: Text.StyledText
        elide: Text.ElideRight
        color: Appearance.colour.textFaint
        text: {
            const r = status.r;
            const w = status.w;
            if (!r)
                return w ? `last wrote ${root.tone(Appearance.colour.accent, `${w.key} = ${w.value}`)}` : "";
            const parts = [];
            if (r.cfg)
                parts.push(`config ${root.tone(Appearance.colour.textDim, r.cfg)}`);
            if (status.fallback)
                parts.push(`default ${root.tone(Appearance.colour.textDim, status.fallback)}`);
            if (w && r.cfg === w.key)
                parts.push(`wrote ${root.tone(Appearance.colour.accent, `${w.key} = ${w.value}`)}`);
            return parts.join("&nbsp;&nbsp;&nbsp;");
        }
    }

    ListModel {
        id: shelves
    }

    function keep(id: string): void {
        if (!id)
            return;
        root.recent = [id].concat(root.recent.filter(seen => seen !== id));
        let found = false;
        for (let i = 0; i < shelves.count; i++)
            found = found || shelves.get(i).pageId === id;
        if (!found)
            shelves.append({
                pageId: id
            });
        const dropped = root.recent.slice(8);
        root.recent = root.recent.slice(0, 8);
        for (let i = shelves.count - 1; i >= 0; i--)
            if (dropped.includes(shelves.get(i).pageId))
                shelves.remove(i);
    }

    function resume(): void {
        const want = SettingsView.resumeScroll;
        if (want <= 0)
            return;
        const reach = Math.max(0, view.contentHeight - view.height);
        view.contentY = Math.min(want, reach);
        if (reach >= want)
            SettingsView.resumeScroll = 0;
    }

    Component.onCompleted: {
        root.lingering = root.showing;
        root.keep(SettingsView.current);
        Qt.callLater(root.resume);
        if (SettingsView.flash && Date.now() - SettingsView.flash.at < 1500)
            root.takeFlash();
    }

    function takeFlash(): void {
        if (!SettingsView.flash)
            return;
        root.pendingReveal = SettingsView.flash.uid;
        root.revealUntil = Date.now() + 1500;
        Qt.callLater(root.reveal, SettingsView.flash.uid, false);
    }

    function reveal(uid: string, snap: bool): void {
        const target = root.findRow(body, uid);
        if (!target)
            return;
        const at = target.mapToItem(body, 0, 0).y;
        let want = at - view.height / 3;
        const group = root.groupOf(target);
        if (group) {
            const inset = view.layer.enabled ? view.fade : 0;
            const top = group.mapToItem(body, 0, 0).y - inset;
            const bottom = top + group.height + Appearance.padding.normal + inset * 2;
            if (bottom - top <= view.height)
                want = Math.min(top, Math.max(want, bottom - view.height));
        }
        want = Math.max(0, Math.min(view.contentHeight - view.height, want));
        if (snap || SettingsView.reduceMotion || arrive.value > 0.01) {
            wheel.stop();
            view.contentY = want;
        }
        else
            wheel.scrollTo(want);
    }

    function groupOf(item: Item): Item {
        for (let at = item; at && at !== body; at = at.parent)
            if (typeof at.heading === "string")
                return at;
        return null;
    }

    function findRow(item: Item, uid: string): Item {
        if (!item)
            return null;
        if (item.row && item.row.uid === uid)
            return item;
        for (let i = 0; i < item.children.length; i++) {
            const hit = root.findRow(item.children[i], uid);
            if (hit)
                return hit;
        }
        return null;
    }
}
