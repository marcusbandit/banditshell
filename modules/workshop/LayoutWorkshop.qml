pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "../../services/layout-model.js" as LayoutModel
import "../../services/layout-lua.js" as LayoutLua

Column {
    id: root

    property bool withPreview: true

    readonly property var region: LayoutDraft.region
    readonly property var current: LayoutDraft.current

    readonly property var kindNames: [["slot", "one window"], ["stack", "many"], ["space", "nothing"]]
    readonly property var ruleNames: [["share", "share"], ["aspect", "aspect"], ["fraction", "fraction"], ["pixels", "pixels"]]
    readonly property var aspects: {
        const out = [[16, 9], [21, 9], [4, 3], [1, 1], [9, 16]];
        const size = root.region.size;
        if (size.rule === "aspect" && !out.some(a => a[0] === size.width && a[1] === size.height))
            out.push([size.width, size.height]);
        return out;
    }
    readonly property var conditions: [["minWindows", "Fewest windows", "group", 1, 9, 1, " windows"], ["maxWindows", "Most windows", "group", 1, 9, 1, " windows"], ["minWidth", "Narrowest screen", "width", 800, 7680, 160, " px"], ["maxWidth", "Widest screen", "width", 800, 7680, 160, " px"]]

    width: parent ? parent.width : 0
    spacing: Appearance.padding.small

    Item {
        width: root.width
        height: Math.max(nameField.height, closeTool.height)

        SettingsField {
            id: nameField

            anchors.left: parent.left
            anchors.right: closeTool.left
            anchors.rightMargin: Appearance.padding.small
            anchors.verticalCenter: parent.verticalCenter
            text: LayoutDraft.model.name
            placeholder: "layout name"
            onCommitted: text => LayoutDraft.change(LayoutModel.rename(LayoutDraft.model, text))
        }

        SettingsTool {
            id: closeTool

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon: "close"
            tip: "close the workshop"
            onClicked: LayoutDraft.close()
        }
    }

    Flow {
        width: root.width
        visible: LayoutDraft.original === ""
        spacing: Appearance.padding.small
        leftPadding: Appearance.padding.normal

        StyledText {
            height: Appearance.sizes.minTarget
            verticalAlignment: Text.AlignVCenter
            text: "Start from"
            color: Appearance.colour.textDim
        }

        Repeater {
            model: LayoutModel.STARTERS

            delegate: Button {
                required property var modelData

                size: 0
                style: "ring"
                icon: "auto_awesome_mosaic"
                text: modelData.label
                onClicked: LayoutDraft.open("", modelData.id)
            }
        }
    }

    WorkshopPreview {
        width: root.width
        visible: root.withPreview
    }

    WorkshopHeading {
        text: "Arrangements"
    }

    Flow {
        width: root.width
        spacing: Appearance.padding.small
        leftPadding: Appearance.padding.normal

        Segments {
            options: LayoutDraft.model.arrangements.map((a, i) => LayoutDraft.arrangementName(i))
            current: LayoutDraft.arrangement
            onPicked: index => LayoutDraft.pickArrangement(index)
        }

        Button {
            size: 0
            icon: "add"
            text: "Add fallback"
            onClicked: LayoutDraft.addFallback()
        }

        Button {
            size: 0
            icon: "delete"
            text: "Remove"
            visible: LayoutDraft.model.arrangements.length > 1
            onClicked: LayoutDraft.removeArrangement()
        }
    }

    SettingsRowFrame {
        width: root.width
        interactive: false
        icon: "rule"
        label: LayoutDraft.arrangement === LayoutDraft.last ? (LayoutDraft.last === 0 ? "Always used" : "Used when nothing above fits") : "Smallest slot or stack"
        detail: LayoutDraft.arrangement === LayoutDraft.last ? "" : LayoutModel.whenText(root.current, LayoutDraft.arrangement, LayoutDraft.model.arrangements.length)

        SettingsStepper {
            anchors.verticalCenter: parent.verticalCenter
            visible: LayoutDraft.arrangement < LayoutDraft.last
            from: 0
            to: 2000
            step: 100
            value: root.current.fit > 1 ? root.current.fit : 0
            text: root.current.fit > 1 ? `${root.current.fit} px` : "any size"
            onMoved: value => LayoutDraft.change(LayoutModel.setWhen(LayoutDraft.model, LayoutDraft.arrangement, "fit", Math.max(1, value)))
        }
    }

    Repeater {
        model: LayoutDraft.arrangement < LayoutDraft.last ? root.conditions : []

        delegate: SettingsRowFrame {
            id: condition

            required property var modelData

            readonly property int value: root.current.when[condition.modelData[0]]

            width: root.width
            interactive: false
            icon: condition.modelData[2]
            label: condition.modelData[1]

            SettingsStepper {
                anchors.verticalCenter: parent.verticalCenter
                from: condition.modelData[3] - condition.modelData[5]
                to: condition.modelData[4]
                step: condition.modelData[5]
                value: condition.value || from
                text: condition.value ? `${condition.value}${condition.modelData[6]}` : "any"
                onMoved: value => LayoutDraft.change(LayoutModel.setWhen(LayoutDraft.model, LayoutDraft.arrangement, condition.modelData[0], value < condition.modelData[3] ? 0 : value))
            }
        }
    }

    WorkshopHeading {
        text: `Region · ${root.region.id}`
    }

    Flow {
        width: root.width
        spacing: Appearance.padding.small
        leftPadding: Appearance.padding.normal

        Button {
            size: 0
            icon: "view_column"
            text: "Split across"
            onClicked: LayoutDraft.split("row")
        }

        Button {
            size: 0
            icon: "view_agenda"
            text: "Split down"
            onClicked: LayoutDraft.split("column")
        }

        Button {
            size: 0
            icon: "arrow_back"
            text: "Earlier"
            visible: LayoutDraft.parentRegion !== null
            interactive: LayoutDraft.siblingIndex > 0
            onClicked: LayoutDraft.change(LayoutModel.moveRegion(LayoutDraft.model, LayoutDraft.arrangement, root.region.id, -1))
        }

        Button {
            size: 0
            icon: "arrow_forward"
            text: "Later"
            visible: LayoutDraft.parentRegion !== null
            interactive: LayoutDraft.parentRegion !== null && LayoutDraft.siblingIndex < LayoutDraft.parentRegion.children.length - 1
            onClicked: LayoutDraft.change(LayoutModel.moveRegion(LayoutDraft.model, LayoutDraft.arrangement, root.region.id, 1))
        }

        Button {
            size: 0
            icon: "north_west"
            text: "Select parent"
            visible: LayoutDraft.parentRegion !== null
            onClicked: LayoutDraft.selected = LayoutDraft.parentRegion.id
        }

        Button {
            size: 0
            icon: "delete"
            text: "Remove"
            visible: LayoutDraft.parentRegion !== null
            onClicked: LayoutDraft.removeRegion()
        }
    }

    SettingsRowFrame {
        width: root.width
        interactive: false
        icon: LayoutDraft.leaf ? "inventory_2" : "splitscreen"
        label: LayoutDraft.leaf ? "Holds" : "Splits"

        Segments {
            anchors.verticalCenter: parent.verticalCenter
            options: LayoutDraft.leaf ? root.kindNames.map(k => k[1]) : ["across", "down"]
            current: LayoutDraft.leaf ? root.kindNames.findIndex(k => k[0] === root.region.kind) : (root.region.axis === "row" ? 0 : 1)
            onPicked: index => LayoutDraft.setRegion(LayoutDraft.leaf ? {
                kind: root.kindNames[index][0]
            } : {
                axis: index === 0 ? "row" : "column"
            })
        }
    }

    SettingsRowFrame {
        width: root.width
        visible: root.region.kind === "stack"
        interactive: false
        icon: "stacks"
        label: "Windows sit"

        Segments {
            anchors.verticalCenter: parent.verticalCenter
            options: ["side by side", "top to bottom"]
            current: root.region.axis === "row" ? 0 : 1
            onPicked: index => LayoutDraft.setRegion({
                axis: index === 0 ? "row" : "column"
            })
        }
    }

    SettingsRowFrame {
        width: root.width
        visible: LayoutDraft.parentRegion !== null
        interactive: false
        icon: "straighten"
        label: "Size"
        detail: LayoutModel.describeSize(root.region.size)

        Segments {
            anchors.verticalCenter: parent.verticalCenter
            options: root.ruleNames.map(r => r[1])
            current: root.ruleNames.findIndex(r => r[0] === root.region.size.rule)
            onPicked: index => LayoutDraft.setRegion({
                size: {
                    rule: root.ruleNames[index][0]
                }
            })
        }
    }

    SettingsRowFrame {
        width: root.width
        visible: LayoutDraft.parentRegion !== null
        interactive: false
        icon: "tune"
        label: root.region.size.rule === "share" ? "Share of what is left" : root.region.size.rule === "aspect" ? "Width to height" : root.region.size.rule === "fraction" ? "Part of the split" : "Pixels along the split"

        SettingsStepper {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.region.size.rule === "share"
            from: 0.5
            to: 8
            step: 0.5
            value: root.region.size.value ?? 1
            text: `× ${root.region.size.value}`
            onMoved: value => LayoutDraft.setRegion({
                size: {
                    rule: "share",
                    value: value
                }
            })
        }

        Segments {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.region.size.rule === "aspect"
            options: root.aspects.map(a => `${a[0]}:${a[1]}`)
            current: root.aspects.findIndex(a => a[0] === root.region.size.width && a[1] === root.region.size.height)
            onPicked: index => LayoutDraft.setRegion({
                size: {
                    rule: "aspect",
                    width: root.aspects[index][0],
                    height: root.aspects[index][1]
                }
            })
        }

        SettingsSlider {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.region.size.rule === "fraction"
            trackWidth: 140
            from: 5
            to: 95
            step: 5
            value: Math.round((root.region.size.value ?? 0.5) * 100)
            text: `${Math.round((root.region.size.value ?? 0.5) * 100)}%`
            onMoved: value => LayoutDraft.setRegion({
                size: {
                    rule: "fraction",
                    value: value / 100
                }
            })
        }

        SettingsStepper {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.region.size.rule === "pixels"
            from: 100
            to: 4000
            step: 50
            value: root.region.size.value ?? 400
            text: `${root.region.size.value} px`
            onMoved: value => LayoutDraft.setRegion({
                size: {
                    rule: "pixels",
                    value: value
                }
            })
        }
    }

    SettingsRowFrame {
        width: root.width
        visible: LayoutDraft.parentRegion !== null
        interactive: false
        icon: "compress"
        label: "Gives its space away when empty"

        Toggle {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.region.collapse
            onToggled: LayoutDraft.setRegion({
                collapse: !root.region.collapse
            })
        }
    }

    WorkshopHeading {
        text: "Fill order"
    }

    Repeater {
        model: [["first", "First windows go to", "looks_one"], ["repeat", "Then, over and over", "repeat"]]

        delegate: Column {
            id: orderRow

            required property var modelData

            readonly property string list: orderRow.modelData[0]
            readonly property var entries: orderRow.list === "first" ? root.current.order.first : root.current.order.repeat

            width: root.width
            spacing: Appearance.padding.small
            bottomPadding: Appearance.padding.small

            SettingsRowFrame {
                width: root.width
                interactive: false
                icon: orderRow.modelData[2]
                label: orderRow.modelData[1]
                detail: orderRow.entries.length ? "" : "nothing"
            }

            Flow {
                width: root.width
                leftPadding: Appearance.padding.normal
                spacing: Appearance.padding.small

                Repeater {
                    model: orderRow.entries

                    delegate: Button {
                        required property string modelData
                        required property int index

                        size: 0
                        style: "accent"
                        icon: "close"
                        text: modelData
                        onClicked: LayoutDraft.orderDrop(orderRow.list, index)
                    }
                }

                Repeater {
                    model: LayoutDraft.holders

                    delegate: Button {
                        required property string modelData

                        size: 0
                        style: "ring"
                        icon: "add"
                        text: modelData
                        onClicked: LayoutDraft.orderAdd(orderRow.list, modelData)
                    }
                }
            }
        }
    }

    Repeater {
        model: LayoutDraft.warnings

        delegate: SettingsRowFrame {
            required property string modelData

            width: root.width
            interactive: false
            icon: "warning"
            iconColour: Appearance.colour.alarm
            label: modelData
        }
    }

    WorkshopHeading {
        text: "Keys"
    }

    SettingsRowFrame {
        width: root.width
        interactive: false
        icon: "open_in_full"
        label: "Each press grows or shrinks by"

        SettingsStepper {
            anchors.verticalCenter: parent.verticalCenter
            from: 1.05
            to: 2
            step: 0.05
            value: LayoutDraft.model.messages.step
            text: `× ${LayoutDraft.model.messages.step}`
            onMoved: value => LayoutDraft.change(LayoutModel.setMessages(LayoutDraft.model, {
                step: value
            }))
        }
    }

    SettingsRowFrame {
        width: root.width
        interactive: false
        icon: "keyboard"
        label: "Binds for this layout"
        detail: LayoutModel.MESSAGES.map(m => m.label).join(" · ")

        Button {
            anchors.verticalCenter: parent.verticalCenter
            size: 0
            icon: "content_copy"
            text: "Copy binds"
            onClicked: {
                Quickshell.execDetached(["wl-copy", LayoutLua.bindLines(LayoutDraft.model, LayoutModel.MESSAGES).join("\n")]);
                LayoutDraft.problem = "binds copied";
            }
        }
    }

    Item {
        width: root.width
        height: Appearance.padding.normal
    }

    Item {
        width: root.width
        height: Math.max(footerText.implicitHeight, footerButtons.height)

        StyledText {
            id: footerText

            readonly property bool trouble: (LayoutDraft.problem !== "" && LayoutDraft.problem !== "binds copied") || (LayoutDraft.problem === "" && LayoutDraft.nameProblem !== "") || (LayoutDraft.problem === "" && LayoutDraft.nameProblem === "" && WorkshopLayouts.failed)

            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.normal
            anchors.right: footerButtons.left
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            text: LayoutDraft.problem || LayoutDraft.nameProblem || (WorkshopLayouts.working ? "loading" : WorkshopLayouts.said) || `lua:${LayoutDraft.model.name}`
            color: footerText.trouble ? Appearance.colour.alarm : Appearance.colour.textDim
        }

        Row {
            id: footerButtons

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.padding.small

            Button {
                icon: "save"
                text: "Save"
                interactive: !WorkshopLayouts.working
                onClicked: LayoutDraft.save(false)
            }

            Button {
                style: "accent"
                icon: "play_arrow"
                text: WindowLayouts.current === `lua:${LayoutDraft.model.name}` ? "Use again" : "Use now"
                interactive: WorkshopLayouts.possible && !WorkshopLayouts.working
                onClicked: LayoutDraft.save(true)
            }
        }
    }
}
