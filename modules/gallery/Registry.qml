pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property string current: "buttons"

    readonly property var entries: [

        {
            key: "buttons",
            title: "Buttons",
            icon: "smart_button",
            section: "Buttons",
            blurb: "what a press looks like, at every size it is asked for",
            checklist: "Buttons (common, filled, elevated, outlined, text)",
            ref: "components/Button.qml",
            status: "draft"
        },
        {
            key: "icon-buttons",
            title: "Icon buttons",
            icon: "touch_app",
            section: "Buttons",
            blurb: "the same press, holding one mark and no words",
            checklist: "Icon buttons",
            status: "planned"
        },
        {
            key: "fab",
            title: "FAB",
            icon: "add",
            section: "Buttons",
            blurb: "the one action of a place, floating over it",
            checklist: "FAB (floating action button)",
            status: "planned"
        },
        {
            key: "extended-fab",
            title: "Extended FAB",
            icon: "add_circle",
            section: "Buttons",
            blurb: "that, with words on it",
            checklist: "Extended FAB",
            status: "planned"
        },
        {
            key: "fab-menu",
            title: "FAB menu",
            icon: "menu",
            section: "Buttons",
            blurb: "the fab opened: its actions fanned out",
            checklist: "FAB menu",
            status: "planned"
        },
        {
            key: "split-button",
            title: "Split button",
            icon: "call_split",
            section: "Buttons",
            blurb: "a press and its alternatives on one stem",
            checklist: "Split button",
            status: "planned"
        },
        {
            key: "button-groups",
            title: "Button groups",
            icon: "apps",
            section: "Buttons",
            blurb: "related presses held together",
            checklist: "Button groups",
            ref: "components/ButtonGroup.qml",
            status: "draft"
        },
        {
            key: "segmented-buttons",
            title: "Segmented buttons",
            icon: "view_week",
            section: "Buttons",
            blurb: "one row, one choice taken",
            checklist: "Segmented buttons",
            ref: "components/Segments.qml",
            status: "draft"
        },

        {
            key: "checkbox",
            title: "Checkbox",
            icon: "check_box",
            section: "Selection",
            blurb: "a list of independent yeses",
            checklist: "Checkbox",
            status: "planned"
        },
        {
            key: "radio",
            title: "Radio button",
            icon: "radio_button_checked",
            section: "Selection",
            blurb: "one yes among many",
            checklist: "Radio button",
            status: "planned"
        },
        {
            key: "switch",
            title: "Switch",
            icon: "toggle_on",
            section: "Selection",
            blurb: "one thing, on or off",
            checklist: "Switch",
            ref: "components/Toggle.qml",
            status: "draft"
        },
        {
            key: "chips",
            title: "Chips",
            icon: "label",
            section: "Selection",
            blurb: "a small state you can tap",
            checklist: "Chips",
            status: "planned"
        },

        {
            key: "cards",
            title: "Cards",
            icon: "crop_portrait",
            section: "Containers",
            blurb: "a rounded plate things sit on",
            checklist: "Cards",
            status: "planned"
        },
        {
            key: "carousel",
            title: "Carousel",
            icon: "view_carousel",
            section: "Containers",
            blurb: "a row that scrolls by card",
            checklist: "Carousel",
            status: "planned"
        },
        {
            key: "dialogs",
            title: "Dialogs",
            icon: "message",
            section: "Containers",
            blurb: "a question the whole screen stops for",
            checklist: "Dialogs",
            ref: "components/Prompts.qml",
            status: "planned"
        },
        {
            key: "divider",
            title: "Divider",
            icon: "safety_divider",
            section: "Containers",
            blurb: "a hairline between groups",
            checklist: "Divider",
            ref: "components/Separator.qml",
            status: "planned"
        },
        {
            key: "lists",
            title: "Lists",
            icon: "format_list_bulleted",
            section: "Containers",
            blurb: "icon, label, detail, and the row that folds out",
            checklist: "Lists",
            ref: "components/MenuRow.qml",
            status: "planned"
        },
        {
            key: "bottom-sheets",
            title: "Bottom sheets",
            icon: "call_to_action",
            section: "Containers",
            blurb: "a panel out of the bottom edge",
            checklist: "Bottom sheets",
            ref: "components/ActionSheet.qml",
            status: "planned"
        },
        {
            key: "side-sheets",
            title: "Side sheets",
            icon: "view_sidebar",
            section: "Containers",
            blurb: "the same, out of a side",
            checklist: "Side sheets",
            status: "planned"
        },

        {
            key: "navigation-bar",
            title: "Navigation bar",
            icon: "menu_open",
            section: "Navigation",
            blurb: "where you are, along an edge",
            checklist: "Navigation bar",
            status: "planned"
        },
        {
            key: "navigation-drawer",
            title: "Navigation drawer",
            icon: "view_headline",
            section: "Navigation",
            blurb: "the places, folded out of the chassis",
            checklist: "Navigation drawer",
            status: "planned"
        },
        {
            key: "navigation-rail",
            title: "Navigation rail",
            icon: "swap_horiz",
            section: "Navigation",
            blurb: "the places, down a flank",
            checklist: "Navigation rail",
            status: "planned"
        },
        {
            key: "app-bars",
            title: "App bars",
            icon: "web_asset",
            section: "Navigation",
            blurb: "what a window's own top edge says",
            checklist: "App bars",
            status: "planned"
        },
        {
            key: "toolbars",
            title: "Toolbars",
            icon: "handyman",
            section: "Navigation",
            blurb: "the tools of the thing in front of you",
            checklist: "Toolbars",
            status: "planned"
        },
        {
            key: "tabs",
            title: "Tabs",
            icon: "tab",
            section: "Navigation",
            blurb: "one place, several views",
            checklist: "Tabs",
            ref: "components/Segments.qml",
            status: "planned"
        },

        {
            key: "text-fields",
            title: "Text fields",
            icon: "edit_note",
            section: "Input",
            blurb: "a line to type into",
            checklist: "Text fields",
            ref: "components/PasswordField.qml",
            status: "planned"
        },
        {
            key: "sliders",
            title: "Sliders",
            icon: "tune",
            section: "Input",
            blurb: "a bead on a rail",
            checklist: "Sliders",
            ref: "components/Slider.qml",
            status: "draft"
        },
        {
            key: "date-pickers",
            title: "Date pickers",
            icon: "calendar_month",
            section: "Input",
            blurb: "a month, and a day on it",
            checklist: "Date pickers",
            status: "planned"
        },
        {
            key: "time-pickers",
            title: "Time pickers",
            icon: "schedule",
            section: "Input",
            blurb: "an hour, a minute",
            checklist: "Time pickers",
            status: "planned"
        },
        {
            key: "search",
            title: "Search",
            icon: "search",
            section: "Input",
            blurb: "type to narrow",
            checklist: "Search",
            status: "planned"
        },

        {
            key: "badges",
            title: "Badges",
            icon: "badge",
            section: "Feedback",
            blurb: "a count riding a mark",
            checklist: "Badges",
            status: "planned"
        },
        {
            key: "progress",
            title: "Progress indicators",
            icon: "progress_activity",
            section: "Feedback",
            blurb: "how far along, as a bar or a ring",
            checklist: "Progress indicators",
            ref: "components/Gauge.qml",
            status: "planned"
        },
        {
            key: "loading-indicator",
            title: "Loading indicator",
            icon: "hourglass_top",
            section: "Feedback",
            blurb: "alive, going nowhere yet",
            checklist: "Loading indicator",
            status: "planned"
        },
        {
            key: "snackbar",
            title: "Snackbar",
            icon: "notifications",
            section: "Feedback",
            blurb: "one line of aftermath, briefly",
            checklist: "Snackbar",
            ref: "services/NotifBrief.qml",
            status: "planned"
        },
        {
            key: "menus",
            title: "Menus",
            icon: "menu_book",
            section: "Feedback",
            blurb: "a panel of actions",
            checklist: "Menus",
            ref: "modules/menu/MenuPanel.qml",
            status: "planned"
        },
        {
            key: "tooltips",
            title: "Tooltips",
            icon: "info",
            section: "Feedback",
            blurb: "what a hover is for",
            checklist: "Tooltips",
            ref: "components/Tooltips.qml",
            status: "planned"
        }
    ]

    readonly property var sections: {
        const out = [];
        for (const e of root.entries) {
            let s = out.find(o => o.name === e.section);
            if (!s) {
                s = {
                    name: e.section,
                    entries: []
                };
                out.push(s);
            }
            s.entries.push(e);
        }
        return out;
    }

    readonly property int drawn: root.entries.filter(e => e.status !== "planned").length
    readonly property int total: root.entries.length

    function entryFor(key: string): var {
        return root.entries.find(e => e.key === key) ?? null;
    }

    function pageUrl(key: string): url {
        const name = key.split("-").map(p => p[0].toUpperCase() + p.slice(1)).join("") + "Page.qml";
        return Qt.resolvedUrl(`pages/${name}`);
    }
}
