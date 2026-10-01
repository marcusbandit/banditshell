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

    // The one width the menu cannot shrink its way out of: the widest row
    // that cannot wrap - the meta line and the button pairs. Prose wraps;
    // these do not. The panel grows to this hint.
    readonly property real menuWidthHint: Math.max(metaRow.implicitWidth, offerRow.implicitWidth, confirmRow.implicitWidth)

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

    // THE STATE LINE: what the update is doing, in the words that answer it.
    // Most of the time this is the whole menu: up to date, when, the way to
    // ask again.
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
            return "You are up to date";
        }
        color: Update.state === Update.failed ? Appearance.colour.updateFailed : Appearance.colour.text
    }

    // THE META LINE: when, and the way to ask again. The old standalone
    // button folded in here - idle, the check IS the only action.
    Row {
        id: metaRow

        spacing: Appearance.padding.small

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: Update.checkedAt.getTime() === 0 ? "Never checked" : `Last checked ${root.ago(Update.checkedAt)}`
            color: Appearance.colour.textFaint
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: "|"
            color: Appearance.colour.textGhost
        }

        Item {
            id: again

            anchors.verticalCenter: parent.verticalCenter
            width: againLabel.implicitWidth
            height: againLabel.implicitHeight

            StyledText {
                id: againLabel

                text: Update.checking ? "Checking..." : "(Check again)"
                color: againPress.containsMouse ? Appearance.colour.text : Appearance.colour.accent
            }

            MouseArea {
                id: againPress

                anchors.fill: parent
                anchors.margins: -Appearance.padding.small
                enabled: !Update.checking
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Update.check()
            }
        }
    }

    // THE ORDINARY UPDATE, when there is one: what came down, what went
    // wrong, and the one button the update itself needs. None of it shows
    // when the answer is already "up to date".
    StyledText {
        width: parent.width
        visible: Update.behind > 0 && !!Update.remoteHead
        text: `latest: ${Update.remoteHead}`
        color: Appearance.colour.textFaint
    }

    StyledText {
        width: parent.width
        visible: !!Update.error
        text: Update.error
        color: Update.state === Update.failed ? Appearance.colour.updateFailed : Appearance.colour.textFaint
        wrapMode: Text.WordWrap
    }

    Button {
        visible: Update.behind > 0 || Update.state === Update.downloaded || Update.state === Update.failed
        text: {
            if (Update.state === Update.downloaded)
                return "Restart the shell";
            if (Update.state === Update.failed)
                return "Retry download";
            return "Download Update";
        }
        icon: {
            if (Update.state === Update.downloaded)
                return "restart_alt";
            if (Update.state === Update.failed)
                return "refresh";
            return "download";
        }
        style: "filled"

        onClicked: {
            if (Update.state === Update.downloaded)
                Update.restart();
            else
                Update.download();
        }
    }

    // THE CHANGELOG, when there is something new said about the update.
    Column {
        width: parent.width
        visible: root.card.length > 0
        spacing: Appearance.padding.normal

        StyledText {
            width: parent.width
            text: "What's new"
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

                            spacing: Appearance.padding.small

                            Icon {

                                y: Math.round((Appearance.font.size.small * 4 / 3 - size) / 2)
                                size: Appearance.font.iconSize
                                name: root.glyph(changeLine.modelData.type)
                                color: Appearance.colour.textDim
                            }

                            StyledText {
                                width: changeLine.width - Appearance.font.iconSize - line.spacing
                                text: changeLine.modelData.text
                                color: changeLine.modelData.severity === "major" ? Appearance.colour.text : Appearance.colour.textDim
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }
    }

    // EVERYTHING BELOW the rule is a SPECIAL update - one that needs more of
    // the user than pressing the update button. Most of the time there is
    // none, and most of the time the rule and the sections under it do not
    // exist.
    Separator {
        width: parent.width
        visible: CliMigration.stale
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
            text: "Your keybinds are deprecated"
            color: Appearance.colour.accent
            wrapMode: Text.WordWrap
        }

        StyledText {
            width: parent.width
            visible: !root.declineConfirm
            text: "Migrate to fix"
            color: Appearance.colour.textDim
            wrapMode: Text.WordWrap
        }

        // (option||option): the component, not hand-made rows - the seam gap
        // and the seam rounding are tokens, `primary` decides who is loud.
        ButtonPair {
            id: offerRow

            visible: !root.declineConfirm
            actions: [{ text: "Migrate" }, { text: "Manual fix" }]

            onTriggered: index => {
                if (index === 0)
                    CliMigration.migrate();
                else
                    root.declineConfirm = true;
            }
        }

        StyledText {
            width: parent.width
            visible: root.declineConfirm
            text: "Are you sure you want to fix the config yourself? The binds keep working, but this offer will not come back."
            color: Appearance.colour.updateFailed
            wrapMode: Text.WordWrap
        }

        ButtonPair {
            id: confirmRow

            visible: root.declineConfirm
            actions: [{ text: "Migrate" }, { text: "Leave it" }]

            onTriggered: index => {
                root.declineConfirm = false;
                if (index === 1)
                    CliMigration.decline();
            }
        }

        StyledText {
            width: parent.width
            visible: CliMigration.lastResult !== ""
            text: CliMigration.lastResult
            color: Appearance.colour.textFaint
            wrapMode: Text.WordWrap
        }
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
