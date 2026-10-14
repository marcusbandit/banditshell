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

    StyledText {
        width: parent.width
        alignInk: true
        text: Update.headline
        color: Update.state === Update.failed ? Appearance.colour.updateFailed : Appearance.colour.text
    }

    Row {
        id: metaRow

        spacing: Appearance.padding.small

        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: Update.checking ? "Refreshing..." : "Refresh"
            interactive: !Update.checking

            onClicked: Update.check()
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            alignInk: true
            text: "|"
            color: Appearance.colour.textGhost
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            alignInk: true
            text: Update.checkedAt.getTime() === 0 ? "Never checked" : `Last checked ${Update.ago(Update.checkedAt)}`
            color: Appearance.colour.textFaint
        }
    }

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

    StyledText {
        width: parent.width
        visible: Update.diverged
        text: `It cannot just move forward. To keep this copy's commits, run in a terminal: git -C ${Update.dir} pull --rebase`
        color: Appearance.colour.updateFailed
        wrapMode: Text.WordWrap
    }

    StyledText {
        width: parent.width
        visible: Update.ahead > 0 && !Update.diverged
        text: `${Update.ahead} commit${Update.ahead === 1 ? " here is" : "s here are"} not on GitHub yet`
        color: Appearance.colour.textFaint
        wrapMode: Text.WordWrap
    }

    Button {
        visible: Update.state === Update.downloaded || (!Update.diverged && (Update.behind > 0 || Update.state === Update.failed))
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

                                y: Math.round((Appearance.font.line.small - size) / 2)
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

    Separator {
        width: parent.width
        visible: CliMigration.stale
    }

    Column {
        width: parent.width
        visible: CliMigration.stale
        spacing: Appearance.padding.small

        StyledText {
            width: parent.width
            alignInk: true
            text: "Your keybinds are deprecated"
            color: Appearance.colour.accent
            wrapMode: Text.WordWrap
        }

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
            alignInk: true
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
                if (index === 0)
                    CliMigration.migrate();
                else
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
}
