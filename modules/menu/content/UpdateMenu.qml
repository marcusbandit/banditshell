pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Column {
    id: root

    property bool showing: false

    readonly property var incoming: Update.behind > 0 && !Update.diverged ? Update.entries : []

    readonly property var card: root.incoming.length > 0 ? root.incoming : WhatsNew.pending

    property bool declineConfirm: false

    readonly property real menuWidthHint: Math.max(metaRow.implicitWidth, offerRow.implicitWidth, confirmRow.implicitWidth)

    spacing: Appearance.padding.small

    InkText {
        width: parent.width
        alignInk: true
        text: Update.headline
        color: Update.state === Update.failed ? Appearance.colour.updateFailed : Appearance.colour.text
    }

    InkText {
        width: parent.width
        alignInk: true
        text: Update.version === "" ? Update.channelLabel : `Version ${Update.version}, ${Update.channelLabel}`
        color: Appearance.colour.textFaint
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

        InkText {
            anchors.verticalCenter: parent.verticalCenter
            alignInk: true
            text: "|"
            color: Appearance.colour.textFaint
        }

        InkText {
            anchors.verticalCenter: parent.verticalCenter
            alignInk: true
            text: Update.checkedAt.getTime() === 0 ? "Never checked" : `Last checked ${Update.ago(Update.checkedAt)}`
            color: Appearance.colour.textFaint
        }
    }

    StyledText {
        width: parent.width
        visible: Update.behind > 0 && !Update.diverged && Update.summaryText !== ""
        text: Update.summaryText
        color: Update.restartNeeded ? Appearance.colour.accent : Appearance.colour.textDim
        wrapMode: Text.WordWrap
    }

    StyledText {
        width: parent.width
        visible: Update.behind > 0 && !!Update.remoteHead
        text: `latest: ${Update.targetVersion || Update.remoteHead}`
        color: Appearance.colour.textFaint
    }

    Repeater {
        model: Update.warnings

        delegate: StyledText {
            required property string modelData

            width: root.width
            text: modelData
            color: Appearance.colour.textFaint
            wrapMode: Text.WordWrap
        }
    }

    Column {
        width: parent.width
        visible: Update.resultPending
        spacing: Appearance.padding.small

        InkText {
            width: parent.width
            alignInk: true
            text: Update.resultText
            color: Update.result !== null && Update.result.ok ? Appearance.colour.text : Appearance.colour.updateFailed
            wrapMode: Text.WordWrap
        }

        StyledText {
            width: parent.width
            visible: Update.result !== null && (Update.result.aside ?? []).length > 0
            text: Update.result === null ? "" : `Your edits to ${(Update.result.aside ?? []).join(", ")} were in the way, so they were set aside in git stash. git stash list shows them; git stash pop brings them back.`
            color: Appearance.colour.textFaint
            wrapMode: Text.WordWrap
        }

        StyledText {
            width: parent.width
            visible: Update.result !== null && !Update.result.ok
            text: "banditshell log shows what went wrong."
            color: Appearance.colour.textFaint
            wrapMode: Text.WordWrap
        }

        Button {
            text: "Dismiss"
            onClicked: Update.dismissResult()
        }
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
        visible: Update.busy || (!Update.diverged && !Update.paused && (Update.behind > 0 || Update.state === Update.failed))
        text: {
            if (Update.busy)
                return Update.phaseText || "Updating...";
            if (Update.state === Update.failed)
                return "Try again";
            return Update.buttonText;
        }
        icon: {
            if (Update.busy)
                return "hourglass_top";
            if (Update.state === Update.failed)
                return "refresh";
            return Update.restartNeeded ? "restart_alt" : "download";
        }
        style: "filled"
        interactive: !Update.busy

        onClicked: Update.apply()
    }

    Column {
        width: parent.width
        visible: root.card.length > 0
        spacing: Appearance.padding.normal

        StyledText {
            width: parent.width
            text: root.incoming.length > 0 ? "In this update" : "What's new"
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

    Button {
        visible: root.incoming.length === 0 && root.card.length > 0
        text: "Got it"
        onClicked: WhatsNew.markSeen(root.card[0].id)
    }

    Separator {
        width: parent.width
        visible: CliMigration.stale
    }

    Column {
        width: parent.width
        visible: CliMigration.stale
        spacing: Appearance.padding.small

        InkText {
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

        InkText {
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
