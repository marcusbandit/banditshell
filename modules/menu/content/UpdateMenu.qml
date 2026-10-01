pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Column {
    id: root

    property bool showing: false

    property var card: []

    property bool declineConfirm: false

    // The one width the menu cannot shrink its way out of: the button row.
    // Prose wraps; a row of buttons does not. The panel grows to this hint.
    readonly property real menuWidthHint: Math.max(offerRow.implicitWidth, confirmRow.implicitWidth)

    spacing: Appearance.padding.small

    function offer(): void {
        if (!root.showing || root.card.length > 0 || WhatsNew.pending.length === 0)
            return;
        root.card = WhatsNew.pending;
        WhatsNew.markSeen(root.card[0].id);
    }

    onShowingChanged: root.offer()

    Connections {
        target: WhatsNew

        function onPendingChanged(): void {
            root.offer();
        }
    }

    StyledText {
        width: parent.width
        text: {
            if (Update.state === Update.downloaded)
                return "Downloaded - restart to apply";
            if (Update.state === Update.downloading)
                return "Downloading from GitHub...";
            if (Update.state === Update.failed)
                return "Pull failed - the checkout is unchanged";
            if (Update.behind > 0)
                return `${Update.behind} new commit${Update.behind === 1 ? "" : "s"} on ${Update.branch}`;
            if (Update.checkedAt.getTime() === 0)
                return "Not checked yet";
            return "No updates confirmed";
        }
        font.pixelSize: Appearance.font.size.small
        color: Appearance.colour.textDim
    }

    Column {
        width: parent.width
        visible: root.card.length > 0
        spacing: Appearance.padding.normal

        StyledText {
            width: parent.width
            text: "What's new"
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textDim
        }

        Repeater {
            model: root.card

            delegate: Column {
                id: entryBlock

                required property var modelData

                width: root.width
                spacing: Appearance.padding.small

                StyledText {
                    width: parent.width
                                text: entryBlock.modelData.date !== "" && entryBlock.modelData.date !== entryBlock.modelData.id ? `${entryBlock.modelData.id} · ${entryBlock.modelData.date}` : entryBlock.modelData.id
                    font.pixelSize: Appearance.font.size.small
                    color: WhatsNew.severityOf(entryBlock.modelData) === "major" ? Appearance.colour.accent : Appearance.colour.textFaint
                }

                Repeater {
                    model: entryBlock.modelData.changes

                    delegate: Item {
                        id: changeLine

                        required property var modelData

                        width: entryBlock.width
                        height: line.height

                        Row {
                            id: line

                            x: Appearance.padding.normal
                            spacing: Appearance.padding.small

                            Icon {

                                y: Math.round((Appearance.font.size.small * 4 / 3 - size) / 2)
                                size: Appearance.font.iconSize
                                name: root.glyph(changeLine.modelData.type)
                                color: Appearance.colour.textDim
                            }

                            StyledText {
                                width: changeLine.width - Appearance.padding.normal * 2 - Appearance.font.iconSize - line.spacing
                                text: changeLine.modelData.text
                                font.pixelSize: Appearance.font.size.small
                                color: changeLine.modelData.severity === "major" ? Appearance.colour.text : Appearance.colour.textDim
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }
    }

    StyledText {
        width: parent.width
        visible: Update.behind > 0 && !!Update.remoteHead
        text: `latest: ${Update.remoteHead}`
        font.pixelSize: Appearance.font.size.small
        color: Appearance.colour.textFaint
    }

    StyledText {
        width: parent.width
        visible: !!Update.error
        text: Update.error
        color: Update.state === Update.failed ? Appearance.colour.updateFailed : Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
        wrapMode: Text.WordWrap
    }

    Separator {
        width: parent.width
    }

    // THE MIGRATION CARD. The scanner found old-grammar binds in the user's
    // hyprland config; the offer is one click (the rewriter runs, a .bak
    // lands beside the file) and the decline is TWO clicks - the second asks,
    // because "no" here means "I will fix the config by hand", and that is
    // worth one moment of friction to confirm.
    Column {
        width: parent.width
        visible: CliMigration.stale
        spacing: Appearance.padding.small

        StyledText {
            width: parent.width
            text: "Your keybinds are deprecated. Migrate to make them work again"
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.accent
            wrapMode: Text.WordWrap
        }

        StyledText {
            width: parent.width
            visible: root.declineConfirm
            text: "Are you sure you want to fix the config yourself? The binds keep working, but this offer will not come back."
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.updateFailed
            wrapMode: Text.WordWrap
        }

        // (option||option): two real buttons, a hairline apart, the seam
        // corners barely rounded - one shape read as a unit, with each half's
        // own hover and press.
        Row {
            id: offerRow

            visible: !root.declineConfirm
            spacing: Appearance.font.stem

            Button {
                text: "Migrate"
                style: "filled"
                radiusRight: Appearance.rounding.small

                onClicked: CliMigration.migrate()
            }

            Button {
                text: "Manual fix"
                style: "tonal"
                radiusLeft: Appearance.rounding.small

                onClicked: root.declineConfirm = true
            }
        }

        Row {
            id: confirmRow

            visible: root.declineConfirm
            spacing: Appearance.font.stem

            Button {
                text: "Migrate"
                style: "filled"
                radiusRight: Appearance.rounding.small

                onClicked: root.declineConfirm = false
            }

            Button {
                text: "Leave it"
                style: "tonal"
                radiusLeft: Appearance.rounding.small

                onClicked: {
                    root.declineConfirm = false;
                    CliMigration.decline();
                }
            }
        }

        // The one width the menu cannot shrink its way out of: the button
        // row. Everything else wraps. The panel grows to this hint.
        readonly property real menuWidthHint: Math.max(offerRow.implicitWidth, confirmRow.implicitWidth)

        StyledText {
            width: parent.width
            visible: CliMigration.lastResult !== ""
            text: CliMigration.lastResult
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textFaint
            wrapMode: Text.WordWrap
        }
    }

    Separator {
        width: parent.width
        visible: CliMigration.stale
    }

    Button {
        text: {
            if (Update.state === Update.downloaded)
                return "Restart the shell";
            if (Update.state === Update.downloading)
                return "Downloading...";
            if (Update.state === Update.failed)
                return "Retry download";
            if (Update.behind > 0)
                return "Download Update";
            return "Search for update";
        }
        icon: {
            if (Update.state === Update.downloaded)
                return "restart_alt";
            if (Update.state === Update.downloading)
                return "cloud_download";
            if (Update.state === Update.failed)
                return "refresh";
            if (Update.behind > 0)
                return "download";
            return "sync";
        }
        style: Update.behind > 0 || Update.state === Update.downloaded || Update.state === Update.failed ? "filled" : "tonal"
        interactive: Update.state !== Update.downloading

        onClicked: {
            if (Update.state === Update.downloaded)
                Update.restart();
            else if (Update.behind > 0)
                Update.download();
            else
                Update.check();
        }
    }

    StyledText {
        visible: Update.checkedAt.getTime() > 0
        text: `checked ${root.ago(Update.checkedAt)}`
        font.pixelSize: Appearance.font.size.small
        color: Appearance.colour.textFaint
    }

    function glyph(type: string): string {
        if (type === "issues")
            return "check_circle";
        if (type === "bugs")
            return "build";
        if (type === "features")
            return "add_circle";
        if (type === "ui")
            return "border_color";
        if (type === "config")
            return "tune";
        return "chevron_right";
    }

    function ago(when: date): string {
        const mins = Math.max(0, Math.round((Date.now() - when.getTime()) / 60000));
        if (mins < 1)
            return "just now";
        if (mins < 60)
            return `${mins} min ago`;
        const hours = Math.floor(mins / 60);
        if (hours < 24)
            return `${hours}h ago`;
        return `${Math.floor(hours / 24)}d ago`;
    }
}
