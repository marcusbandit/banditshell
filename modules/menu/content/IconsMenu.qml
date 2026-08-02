pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// SETTINGS: what each application looks like.
//
// A DRAFT, and the first page of a settings menu that will have others. What it
// does is the part that has to be right: the shell's automatic answer for an
// application is a SUGGESTION, and this is where it can be overruled.
//
// Two views in one panel, because the panel is 300px wide and a list plus a
// picker side by side is neither. The list is every application this machine has
// seen (AppIcons keeps that record); picking one swaps to its alternatives and
// swaps back when it is chosen or dismissed.
//
// The alternatives are FOUND, not invented: every icon file in every installed
// theme whose name mentions the application, which is where "Telegram has a
// plane in a circle and also a bare plane and also a monochrome panel version"
// comes from. Nobody wrote that list; the machine already had it.
Item {
    id: root

    // Which application's alternatives are showing, or "" for the list.
    property string picking: ""
    // The alternative under the cursor, for the label under the row of them.
    property string hint: ""

    implicitHeight: picking ? picker.implicitHeight : list.implicitHeight

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Appearance.anim.fast
            easing.type: Easing.OutCubic
        }
    }

    // ------------------------------------------------------------------ list

    Column {
        id: list

        width: parent.width
        visible: !root.picking
        spacing: Appearance.padding.small / 2

        StyledText {
            text: `${AppIcons.classes.length} applications seen`
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            bottomPadding: Appearance.padding.small
        }

        Repeater {
            model: AppIcons.classes

            delegate: MenuRow {
                id: appRow

                required property string modelData

                width: list.width
                label: AppIcons.titleOf(modelData) || modelData
                detail: modelData
                // The mark it currently gets, whatever decided that.
                mark: markComponent

                readonly property Component markComponent: Component {
                    AppMark {
                        spec: AppIcons.markFor(appRow.modelData)
                        fallback: Apps.iconFor(appRow.modelData)
                        color: Appearance.colour.text
                        // A picked one is louder than an automatic one: this is
                        // a list of decisions, and which ones you have made is
                        // the only thing worth showing twice.
                        opacity: AppIcons.specFor(appRow.modelData) ? 1 : 0.6
                    }
                }

                onActivated: {
                    root.picking = appRow.modelData;
                    AppIcons.suggest(appRow.modelData);
                }
            }
        }

        StyledText {
            visible: !AppIcons.classes.length
            text: "nothing yet: open something"
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
        }
    }

    // ---------------------------------------------------------------- picker

    Column {
        id: picker

        width: parent.width
        visible: root.picking !== ""
        spacing: Appearance.padding.normal

        // Header: what is being changed, and the way back.
        MenuRow {
            width: picker.width
            icon: "arrow_back"
            label: AppIcons.titleOf(root.picking) || root.picking
            detail: root.picking
            onActivated: root.picking = ""
        }

        // THE ALTERNATIVES. The one in use first, then everything the machine
        // has, then the two automatic answers, so the list reads as "this, or
        // any of these instead".
        Flow {
            width: picker.width
            spacing: Appearance.padding.small

            Repeater {
                model: root.picking ? root.options(root.picking) : []

                delegate: Item {
                    id: option

                    required property var modelData

                    // The SAME FILE counts as current whichever colour it is
                    // being drawn in, or switching to original colours would
                    // look like losing the choice.
                    readonly property bool current: AppIcons.sameMark(AppIcons.specFor(root.picking), modelData.spec)

                    width: Appearance.sizes.rowHeight
                    height: width

                    G2Rect {
                        anchors.fill: parent
                        radius: Appearance.rounding.small
                        color: option.current ? Appearance.colour.accentFill : mouse.containsMouse ? Appearance.colour.fillStrong : Appearance.colour.fill

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }

                    AppMark {
                        anchors.centerIn: parent
                        size: Appearance.font.iconSize
                        // Shown the way it will actually be drawn, including
                        // whether it keeps its own colours: a picker that lies
                        // about the result is worse than no picker.
                        spec: option.current ? AppIcons.specFor(root.picking) : option.modelData.spec
                        fallback: Apps.iconFor(root.picking)
                        color: Appearance.colour.text
                    }

                    // The chosen one says so. Without this the only feedback for
                    // a click is a tint behind a mark you are already looking
                    // at, and picking the icon you already had looks like
                    // nothing happening at all.
                    Icon {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 2
                        visible: option.current
                        size: Appearance.font.size.small
                        name: "check_circle"
                        color: Appearance.colour.accent
                    }

                    MouseArea {
                        id: mouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // Picking the one already picked clears it, which is how
                        // you get back to the automatic answer without a second
                        // control that only ever does that.
                        onClicked: AppIcons.assign(root.picking, option.current ? "" : option.modelData.spec)
                        onEntered: root.hint = option.modelData.spec
                        onExited: if (root.hint === option.modelData.spec)
                            root.hint = ""
                    }
                }
            }
        }

        // The one thing the alternatives cannot show at once: whether a file
        // keeps its own colours. Everything is offered tinted, because that is
        // what makes a row of them comparable and a bar of them coherent, and
        // this is how you say "not this one".
        MenuRow {
            width: picker.width
            visible: AppIcons.isFile(AppIcons.specFor(root.picking))
            icon: AppIcons.specFor(root.picking).startsWith("mono:") ? "palette" : "invert_colors"
            label: AppIcons.specFor(root.picking).startsWith("mono:") ? "Use its own colours" : "Use the shell's colour"
            detail: root.picking
            onActivated: AppIcons.recolour(root.picking)
        }

        Separator {
            width: picker.width
        }

        MenuRow {
            width: picker.width
            icon: "folder_open"
            label: "Choose a file"
            detail: "svg or png"
            onActivated: {
                browse.cls = root.picking;
                browse.running = true;
            }
        }

        MenuRow {
            width: picker.width
            icon: AppIcons.asking === root.picking ? "hourglass_top" : "auto_awesome"
            label: AppIcons.asking === root.picking ? "Asking Claude" : "Ask Claude"
            detail: AppIcons.asking === root.picking ? "looking for a logo" : "find and download one"
            enabled: !AppIcons.asking
            onActivated: AppIcons.ask(root.picking)
        }
    }

    // Every alternative for an application, most specific first.
    function options(cls: string): var {
        const out = [];
        const add = spec => {
            if (spec && !out.some(o => o.spec === spec))
                out.push({
                    spec
                });
        };

        add(AppIcons.specFor(cls));

        // The per-application line glyph, when the brand set has one: monochrome
        // by construction, so it is the one alternative guaranteed to fit.
        const glyph = Apps.brandFor(cls);
        if (glyph)
            add(`glyph:${glyph.codePointAt(0).toString(16)}`);

        for (const spec of AppIcons.found[cls] ?? [])
            add(spec);

        // The category symbol last: it is the fallback anyway, so it is here to
        // be chosen deliberately rather than to be the only thing on offer.
        add(`symbol:${Apps.iconFor(cls)}`);
        return out;
    }

    // The system's own file chooser rather than one built here. A file dialog is
    // a filesystem browser with previews, bookmarks and typing, and every shell
    // that has written its own has written a worse one.
    Process {
        id: browse

        property string cls: ""

        command: ["zenity", "--file-selection", "--title=Pick an icon", "--file-filter=Icons | *.svg *.png *.xpm"]

        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (!path)
                    return;
                // A file chosen by hand is drawn as it is: if it needed
                // recolouring it would be in the theme's symbolic set already.
                AppIcons.assign(browse.cls, `image:${path}`);
            }
        }
    }
}
