pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.modules.controls
import qs.modules.settings
import qs.modules.settings.scenes
import qs.modules.workshop
import qs.services
import "../catalogue.js" as Catalogue

Column {
    id: root

    property var row: ({})

    readonly property string picked: SettingsState.v("layout")
    readonly property string refusal: SettingsState.hyprRefusal("layout")
    readonly property string refusalWhere: /\(([^)]*)\)/.exec(root.refusal)?.[1] ?? ""

    property bool customOpen: false
    readonly property int columns: Math.max(1, Math.floor((root.width + Appearance.padding.small) / (128 + Appearance.padding.small)))
    readonly property real cell: (root.width - (root.columns - 1) * Appearance.padding.small) / root.columns

    width: parent ? parent.width : 0
    topPadding: Appearance.padding.small
    bottomPadding: Appearance.padding.small

    HoverHandler {
        onHoveredChanged: {
            if (hovered)
                SettingsView.hovered = root.row;
            else
                SettingsView.layoutHover = "";
        }
    }

    Grid {
        columns: root.columns
        spacing: Appearance.padding.small

        Repeater {
            model: Catalogue.LAYOUTS

            delegate: Item {
                id: card

                required property var modelData

                readonly property bool on: root.picked === card.modelData.id
                readonly property bool ready: SettingsState.layoutAvailable(card.modelData.id)

                width: root.cell
                height: Appearance.padding.normal * 2 + mini.height + Appearance.padding.small + Appearance.font.line.small
                opacity: card.ready ? 1 : Appearance.opacity.disabled

                FollowColour {
                    id: tone

                    target: tap.pressed && !card.on ? Appearance.colour.fillStronger : hover.hovered && !card.on ? Appearance.colour.fillStrong : Appearance.colour.fill
                    speed: Appearance.animation.revealSpeed
                }

                SquircleRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.large
                    color: tone.value

                    SquircleRect {
                        anchors.fill: parent
                        radius: Appearance.rounding.large
                        color: Appearance.colour.accentFill
                        visible: card.on
                    }
                }

                LayoutMini {
                    id: mini

                    x: Appearance.padding.small
                    y: Appearance.padding.normal
                    width: parent.width - Appearance.padding.small * 2
                    height: Math.round(width * 10 / 16)
                    layout: card.modelData.id
                    lit: card.on
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: mini.y + mini.height + Appearance.padding.small
                    width: Math.min(implicitWidth, parent.width - Appearance.padding.small * 2)
                    text: card.modelData.name
                    elide: Text.ElideRight
                    color: card.on || hover.hovered ? Appearance.colour.text : Appearance.colour.textDim
                }

                HoverHandler {
                    id: hover

                    onHoveredChanged: if (hovered)
                        SettingsView.layoutHover = card.modelData.id
                }

                MouseArea {
                    id: tap

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const id = card.modelData.id;
                        if (id === "custom") {
                            root.customOpen = !root.customOpen;
                            return;
                        }
                        root.customOpen = false;
                        if (card.ready)
                            SettingsState.set("layout", id);
                        else
                            SettingsView.drop(`${card.modelData.name} is not loaded · ${SettingsState.layoutHowTo(id)}`, "extension");
                    }
                }
            }
        }
    }

    SettingsRowFrame {
        width: root.width
        visible: root.refusal !== ""
        interactive: false
        icon: "edit_off"
        label: "Your config sets this"
        detail: root.refusalWhere ? `${root.refusalWhere} · edit it there` : root.refusal
        onPointed: SettingsView.hovered = root.row
    }

    MenuLayer {
        width: root.width
        open: root.picked === "custom" || root.customOpen || LayoutDraft.editing

        SettingsRowFrame {
            width: parent.width
            interactive: false
            icon: "extension"
            label: "Custom layout"
            detail: SettingsState.customInUse || (WorkshopLayouts.layouts.length ? WorkshopLayouts.layouts.map(m => m.name).join(" · ") : "nothing drawn yet")

            Button {
                anchors.verticalCenter: parent.verticalCenter
                size: 0
                icon: "draw"
                text: "Draw one"
                visible: !LayoutDraft.editing || LayoutDraft.original !== ""
                onClicked: LayoutDraft.open("", "stage")
            }
        }

        Repeater {
            model: WorkshopLayouts.layouts

            delegate: SettingsRowFrame {
                id: saved

                required property var modelData

                readonly property string layoutName: `lua:${saved.modelData.name}`
                readonly property bool inUse: WindowLayouts.current === saved.layoutName

                width: parent.width
                interactive: false
                icon: "dashboard"
                label: saved.modelData.name
                detail: saved.inUse ? "in use" : WorkshopLayouts.isReady(saved.modelData.name) ? "loaded" : WorkshopLayouts.possible ? "not loaded" : "needs Hyprland with a Lua config"

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.padding.small

                    Button {
                        size: 0
                        icon: "play_arrow"
                        text: "Use"
                        visible: !saved.inUse
                        interactive: WorkshopLayouts.isReady(saved.modelData.name)
                        onClicked: WindowLayouts.use(saved.layoutName)
                    }

                    Button {
                        size: 0
                        icon: "edit"
                        text: "Edit"
                        onClicked: LayoutDraft.open(saved.modelData.name, "stage")
                    }

                    SettingsTool {
                        icon: "delete"
                        tip: saved.inUse ? `remove it and go back to ${WorkshopLayouts.fallbackLayout.replace(/^lua:/, "")}` : "remove it"
                        onClicked: WorkshopLayouts.remove(saved.modelData.name)
                    }
                }
            }
        }

        Loader {
            width: parent.width
            active: LayoutDraft.editing
            visible: active

            sourceComponent: LayoutWorkshop {
                withPreview: SettingsView.pin?.type !== "workshop"
            }
        }
    }

    function showWorkshop(): void {
        if (LayoutDraft.editing && !SettingsView.compact && SettingsView.pin?.type !== "workshop")
            SettingsView.openPin("workshop", LayoutDraft.model.name, "");
        else if (!LayoutDraft.editing && SettingsView.pin?.type === "workshop")
            SettingsView.unpin();
    }

    Component.onCompleted: root.showWorkshop()

    Connections {
        target: LayoutDraft

        function onEditingChanged(): void {
            root.showWorkshop();
        }
    }
}
