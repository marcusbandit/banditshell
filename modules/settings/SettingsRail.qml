pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import "catalogue.js" as Catalogue

Item {
    id: root

    property bool tiny: false
    property bool foldable: false
    property bool folded: false

    readonly property real rowHeight: Appearance.sizes.settingsRailRow
    readonly property var hits: Catalogue.search(SettingsView.query).filter(h => Catalogue.present(h.page, SettingsState) && Catalogue.present(h.group, SettingsState))
    readonly property bool listingRecent: SettingsView.searchFocused && SettingsView.query.trim() === ""
    readonly property var recent: SettingsState.changes.slice(0, 6)
    property int hitIndex: 0
    property string pointedUid: ""
    readonly property bool hitOpen: Catalogue.hitIsOpen(root.hits, root.hitIndex, SettingsView.flash?.uid ?? "", SettingsView.current)

    onHitsChanged: root.point(Catalogue.hitIndexOf(root.hits, root.pointedUid))

    Component.onDestruction: Prompts.release(root)

    function focusSearch(): void {
        query.forceActiveFocus();
    }

    function point(i: int): void {
        root.hitIndex = i;
        root.pointedUid = root.listingRecent ? "" : root.hits[i]?.row.uid ?? "";
    }

    function openHit(i: int): void {
        if (root.listingRecent) {
            const c = root.recent[i];
            const found = c ? Catalogue.resolve(c.k) : null;
            if (found?.row)
                SettingsView.openHit({
                    page: Catalogue.PAGE_BY_ID[found.page],
                    row: found.row
                });
        } else if (root.hits[i]) {
            root.point(i);
            SettingsView.openHit(root.hits[i]);
        }
    }

    function pick(i: int): void {
        root.openHit(i);
        if (root.tiny)
            SettingsView.query = "";
        query.focus = false;
    }

    Item {
        id: field

        width: root.tiny && !query.activeFocus ? 40 : root.width
        height: 40
        z: 5

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: Appearance.colour.fillStrong
            stroke: query.activeFocus ? Appearance.colour.accent : "transparent"
            strokeWidth: query.activeFocus ? Appearance.stroke.ring : 0
        }

        Icon {
            id: glass

            x: root.tiny && !query.activeFocus ? (parent.width - width) / 2 : Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            color: Appearance.colour.textFaint
        }

        TextInput {
            id: query

            x: glass.x + glass.width + Appearance.padding.small
            width: (count.visible ? count.x - Appearance.padding.small : clear.visible ? clear.x : parent.width - Appearance.padding.normal) - x
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.tiny || activeFocus
            clip: true

            font.family: Appearance.font.family
            font.pixelSize: Appearance.font.size.small
            renderType: Text.NativeRendering
            color: Appearance.colour.text
            selectionColor: Appearance.colour.accent
            selectedTextColor: Appearance.colour.accentText

            text: SettingsView.query
            onTextEdited: {
                root.pointedUid = "";
                SettingsView.query = text;
            }
            onActiveFocusChanged: {
                SettingsView.searchFocused = activeFocus;
                if (activeFocus)
                    Prompts.request(root);
                else
                    Prompts.release(root);
            }

            Keys.onPressed: event => {
                const n = root.listingRecent ? root.recent.length : root.hits.length;
                if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                    root.point(Math.max(0, Math.min(n - 1, root.hitIndex + (event.key === Qt.Key_Down ? 1 : -1))));
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.listingRecent)
                        root.pick(root.hitIndex);
                    else
                        root.openHit(Catalogue.hitToOpen(root.hits, root.hitIndex, SettingsView.flash?.uid ?? "", SettingsView.current, !!(event.modifiers & Qt.ShiftModifier)));
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    if (query.text)
                        SettingsView.query = "";
                    else
                        query.focus = false;
                    event.accepted = true;
                }
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: !query.text
                text: "search"
                color: Appearance.colour.textFaint
            }
        }

        MouseArea {
            anchors.fill: parent
            visible: !query.activeFocus
            cursorShape: Qt.IBeamCursor
            onClicked: query.forceActiveFocus()
        }

        StyledText {
            id: count

            x: (clear.visible ? clear.x : parent.width - Appearance.padding.normal) - width - Appearance.padding.small
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.tiny && !root.listingRecent && root.hits.length > 0
            text: `${root.hitIndex + 1} of ${root.hits.length}`
            color: Appearance.colour.textFaint
        }

        SettingsTool {
            id: clear

            x: parent.width - width - (parent.height - height) / 2
            anchors.verticalCenter: parent.verticalCenter
            visible: !!SettingsView.query && (!root.tiny || query.activeFocus)
            size: 28
            icon: "close"
            tip: "clear the search"
            onClicked: SettingsView.query = ""
        }
    }

    Flickable {
        id: list

        x: -Appearance.padding.small
        y: field.height + Appearance.padding.normal
        width: root.width + Appearance.padding.small * 2
        height: root.height - y - (fold.visible ? fold.height + Appearance.padding.small : 0)
        contentHeight: SettingsView.searching ? found.implicitHeight : tree.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        WheelStep {
            flick: list
        }

        SquircleRect {
            id: plate

            x: Appearance.padding.small
            y: glide.value
            width: root.width
            height: root.rowHeight
            radius: Appearance.rounding.normal
            color: Appearance.colour.fillStrong
            visible: !SettingsView.searching && glide.ready

            SquircleRect {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Appearance.colour.accentFill
            }
        }

        Follow {
            id: glide

            property bool ready: false

            target: tree.markY
            speed: Appearance.animation.trackSpeed
            onTargetChanged: if (!ready) {
                snap();
                ready = true;
            }
        }

        Column {
            id: tree

            x: Appearance.padding.small
            width: root.width
            visible: !SettingsView.searching

            property real markY: 0

            Repeater {
                model: Catalogue.CATS

                delegate: Column {
                    id: cat

                    required property var modelData
                    required property int index

                    readonly property bool open: SettingsView.cat?.id === cat.modelData.id

                    width: tree.width

                    RailRow {
                        id: catRow

                        width: parent.width
                        icon: cat.modelData.icon
                        label: cat.modelData.name
                        on: SettingsView.current === cat.modelData.id
                        lit: cat.open
                        onClicked: SettingsView.go(cat.modelData.id)
                    }

                    Item {
                        id: subs

                        width: parent.width
                        height: Math.round(column.implicitHeight * unroll.value)
                        clip: true
                        visible: height > 0.5

                        Follow {
                            id: unroll

                            target: cat.open ? 1 : 0
                            speed: Appearance.animation.revealSpeed
                            epsilon: 0.001
                        }

                        SquircleRect {
                            x: root.tiny ? 0 : Appearance.padding.normal + Appearance.font.iconSize / 2 - 1
                            y: 4
                            width: 2
                            height: Math.max(0, column.implicitHeight - 8)
                            pill: "place"
                            color: Appearance.colour.fillStronger
                            visible: !root.tiny
                            opacity: stem.value

                            Follow {
                                id: stem

                                target: cat.open ? 1 : 0
                                speed: Appearance.animation.revealSpeed
                                epsilon: Appearance.animation.fadeEpsilon
                                startsAtTarget: true
                            }
                        }

                        Column {
                            id: column

                            x: root.tiny ? 0 : Appearance.padding.large + 4
                            width: parent.width - x

                            Repeater {
                                model: cat.modelData.pages.filter(p => Catalogue.present(p, SettingsState))

                                delegate: RailRow {
                                    id: sub

                                    required property var modelData

                                    width: column.width
                                    icon: sub.modelData.icon
                                    iconScale: 0.9
                                    inset: Appearance.padding.small
                                    label: Catalogue.nameOf(sub.modelData, SettingsState)
                                    on: SettingsView.current === sub.modelData.id
                                    dimmed: !!sub.modelData.off && sub.modelData.off(SettingsState)
                                    onClicked: SettingsView.go(sub.modelData.id)
                                }
                            }
                        }
                    }
                }
            }

            function locate(): void {
                const target = SettingsView.current;
                let y = 0;
                for (let i = 0; i < children.length; i++) {
                    const c = children[i];
                    if (!c.modelData)
                        continue;
                    if (c.modelData.id === target) {
                        tree.markY = c.y;
                        return;
                    }
                    const pages = c.modelData.pages.filter(p => Catalogue.present(p, SettingsState));
                    const at = pages.findIndex(p => p.id === target);
                    if (at >= 0) {
                        tree.markY = c.y + root.rowHeight + Math.min(at * root.rowHeight, c.children[1].height - root.rowHeight);
                        return;
                    }
                }
            }

            onImplicitHeightChanged: locate()
            Component.onCompleted: locate()

            Connections {
                target: SettingsView

                function onCurrentChanged(): void {
                    tree.locate();
                }
            }
        }

        Column {
            id: found

            x: Appearance.padding.small
            width: root.width
            visible: SettingsView.searching

            StyledText {
                x: Appearance.padding.normal
                width: parent.width - Appearance.padding.normal * 2
                topPadding: Appearance.padding.normal
                bottomPadding: Appearance.padding.normal
                visible: root.listingRecent || root.hits.length === 0
                text: root.listingRecent ? (root.recent.length ? "changed lately" : "type a setting, or a number from the list") : `nothing called “${SettingsView.query.trim()}”. try fewer letters, or a number from the list.`
                color: Appearance.colour.textFaint
                wrapMode: Text.WordWrap
            }

            StyledText {
                x: Appearance.padding.normal
                width: parent.width - Appearance.padding.normal * 2
                topPadding: Appearance.padding.small
                bottomPadding: Appearance.padding.normal
                visible: query.activeFocus && !root.tiny && !root.listingRecent && root.hits.length > 0 && !(root.hitOpen && root.hits.length < 2)
                text: root.hitOpen ? "enter next\nshift+enter back" : "enter opens it"
                color: Appearance.colour.textFaint
            }

            Repeater {
                model: root.listingRecent ? root.recent : root.hits

                delegate: HitRow {
                    id: hit

                    required property var modelData
                    required property int index

                    width: found.width
                    icon: root.listingRecent ? "history" : hit.modelData.page.icon
                    label: root.listingRecent ? hit.modelData.label : hit.modelData.label
                    detail: root.listingRecent ? `${hit.modelData.from} → ${hit.modelData.to}` : `${Catalogue.CAT_BY_ID[hit.modelData.page.cat].name.toLowerCase()} · ${Catalogue.nameOf(hit.modelData.page, SettingsState).toLowerCase()}`
                    active: hit.index === root.hitIndex
                    onPicked: root.pick(hit.index)
                }
            }
        }
    }

    RailRow {
        id: fold

        y: root.height - height
        width: root.width
        visible: root.foldable
        icon: root.folded ? "left_panel_open" : "left_panel_close"
        label: "Fold this list"
        onClicked: SettingsState.foldRail(!root.folded)
    }

    component RailRow: Item {
        id: rr

        property string icon: ""
        property string label: ""
        property bool on: false
        property bool lit: false
        property bool dimmed: false
        property real iconScale: 1
        property real inset: Appearance.padding.normal

        signal clicked

        height: root.rowHeight

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colour.fill
            opacity: hover.hovered && !rr.on ? 1 : 0
        }

        Icon {
            id: mark

            x: root.tiny ? (parent.width - width) / 2 : rr.inset
            anchors.verticalCenter: parent.verticalCenter
            name: rr.icon
            size: Math.round(Appearance.font.iconSize * rr.iconScale)
            fill: rr.on ? 1 : 0
            color: markTone.value
            opacity: rr.dimmed ? Appearance.opacity.disabled : 1

            FollowColour {
                id: markTone

                target: rr.on || rr.lit || hover.hovered ? Appearance.colour.text : Appearance.colour.textDim
                speed: Appearance.animation.revealSpeed
            }
        }

        StyledText {
            x: mark.x + mark.width + Appearance.padding.normal
            width: parent.width - x - Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.tiny
            text: rr.label
            elide: Text.ElideRight
            color: mark.color
            opacity: rr.dimmed ? Appearance.opacity.disabled : 1
        }

        HoverHandler {
            id: hover
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                SettingsView.query = "";
                rr.clicked();
            }
        }
    }

    component HitRow: Item {
        id: hr

        property string icon: ""
        property string label: ""
        property string detail: ""
        property bool active: false

        signal picked

        implicitHeight: Math.max(root.rowHeight, words.implicitHeight + 12)

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: hr.active ? Appearance.colour.fillStrong : Appearance.colour.fill
            opacity: hr.active || hitHover.hovered ? 1 : 0
        }

        Icon {
            id: hitMark

            x: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            name: hr.icon
            color: Appearance.colour.textDim
        }

        Column {
            id: words

            x: hitMark.x + hitMark.width + Appearance.padding.normal
            width: parent.width - x - Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                width: parent.width
                text: hr.label
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                text: hr.detail
                elide: Text.ElideRight
                color: Appearance.colour.textFaint
            }
        }

        HoverHandler {
            id: hitHover
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: hr.picked()
        }
    }
}
