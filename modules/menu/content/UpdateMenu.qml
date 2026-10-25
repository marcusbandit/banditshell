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
    property bool goBackConfirm: false
    property bool reinstallConfirm: false
    property bool reportOpen: false
    property bool reportHanded: false

    readonly property bool reinstallAsking: root.reinstallConfirm && Update.canReinstall
    readonly property bool reportAsking: root.reportOpen && Update.wentBackByHand && Update.resultPending
    readonly property bool asking: root.goBackConfirm || root.reinstallAsking || root.reportAsking

    readonly property real menuWidthHint: Math.max(metaRow.implicitWidth, offerRow.implicitWidth, confirmRow.implicitWidth, actionRow.implicitWidth, goBackRow.implicitWidth, afterRow.implicitWidth, reinstallRow.implicitWidth, reportRow.implicitWidth)

    onShowingChanged: if (!root.showing) {
        root.goBackConfirm = false;
        root.reinstallConfirm = false;
        root.reportOpen = false;
        root.reportHanded = false;
    }

    function sendReport(): void {
        Update.report(reportField.value);
        root.reportOpen = false;
        root.reportHanded = true;
    }

    spacing: Appearance.padding.small

    InkText {
        width: parent.width
        alignInk: true
        wrapMode: Text.Wrap
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
            color: Update.result !== null && (Update.result.ok || Update.wentBackByHand) ? Appearance.colour.text : Appearance.colour.updateFailed
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
            visible: Update.result !== null && !Update.result.ok && !Update.wentBackByHand
            text: "banditshell log shows what went wrong."
            color: Appearance.colour.textFaint
            wrapMode: Text.WordWrap
        }

        Row {
            id: afterRow

            visible: !root.asking && Update.canReinstall
            spacing: Appearance.padding.small

            Button {
                text: `Reinstall ${Update.skippedVersion}`
                icon: "restart_alt"

                onClicked: root.reinstallConfirm = true
            }
        }

        StyledText {
            width: parent.width
            visible: root.reportHanded && !root.asking
            text: "The report opens in a terminal. Nothing is sent until you answer y there."
            color: Appearance.colour.textFaint
            wrapMode: Text.WordWrap
        }
    }

    Column {
        width: parent.width
        visible: root.reportAsking
        spacing: Appearance.padding.small

        InkText {
            width: parent.width
            alignInk: true
            text: "What broke?"
        }

        ClockTextField {
            id: reportField

            width: parent.width
            placeholder: "what stopped working, in a few words"

            onAccepted: root.sendReport()
            onCancelled: root.reportOpen = false
        }

        StyledText {
            width: parent.width
            text: "The report starts with"
            color: Appearance.colour.textDim
        }

        SquircleRect {
            width: parent.width
            height: reportPreview.implicitHeight + Appearance.padding.normal * 2
            radius: Appearance.rounding.small
            color: Appearance.colour.fillStrong

            StyledText {
                id: reportPreview

                x: Appearance.padding.normal
                y: Appearance.padding.normal
                width: parent.width - Appearance.padding.normal * 2
                text: Update.reportText(reportField.value)
                color: Appearance.colour.text
                wrapMode: Text.WordWrap
            }
        }

        StyledText {
            width: parent.width
            text: "A terminal then shows the whole report, with your config and the last log lines, secrets left out. Nothing is sent until you answer y there."
            color: Appearance.colour.textFaint
            wrapMode: Text.WordWrap
        }

        ButtonPair {
            id: reportRow

            actions: [{ text: "Review and send", icon: "bug_report" }, { text: "Cancel" }]

            onTriggered: index => {
                if (index === 0)
                    root.sendReport();
                else
                    root.reportOpen = false;
            }
        }
    }

    Column {
        width: parent.width
        visible: root.reinstallAsking
        spacing: Appearance.padding.small

        InkText {
            width: parent.width
            alignInk: true
            text: `Reinstall ${Update.skippedVersion}? The shell restarts on it, and it is no longer skipped.`
            wrapMode: Text.Wrap
        }

        ButtonPair {
            id: reinstallRow

            actions: [{ text: "Reinstall", icon: "restart_alt" }, { text: `Stay on ${Update.version}` }]

            onTriggered: index => {
                root.reinstallConfirm = false;
                if (index === 0)
                    Update.reinstall();
            }
        }
    }

    Row {
        id: actionRow

        visible: !root.asking && (Update.canGoBack || Update.resultPending)
        spacing: Appearance.padding.small

        Button {
            visible: Update.canGoBack
            text: `Go back to ${Update.previousVersion}`
            icon: "history"

            onClicked: root.goBackConfirm = true
        }

        Button {
            visible: Update.wentBackByHand && Update.resultPending
            text: "Report what broke"
            icon: "bug_report"

            onClicked: {
                root.reportHanded = false;
                root.reportOpen = true;
            }
        }

        Button {
            visible: Update.resultPending
            text: "Hide message"
            onClicked: Update.dismissResult()
        }
    }

    Column {
        width: parent.width
        visible: Update.canGoBack && root.goBackConfirm
        spacing: Appearance.padding.small

        InkText {
            width: parent.width
            alignInk: true
            text: `Go back to ${Update.previousVersion}? The shell restarts on it, and ${Update.version} is skipped until a newer version arrives.`
            wrapMode: Text.Wrap
        }

        InkText {
            width: parent.width
            alignInk: true
            text: "Only the shell's own files go back. Your settings and anything else this update changed stay changed."
            wrapMode: Text.Wrap
        }

        ButtonPair {
            id: goBackRow

            actions: [{ text: "Go back", icon: "history" }, { text: `Stay on ${Update.version}` }]

            onTriggered: index => {
                root.goBackConfirm = false;
                if (index === 0)
                    Update.goBack();
            }
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
        visible: Update.busy || (!root.asking && !Update.diverged && !Update.paused && (Update.behind > 0 || Update.state === Update.failed))
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
        style: "accent"
        interactive: !Update.busy

        onClicked: Update.state === Update.failed ? Update.retry() : Update.apply()
    }

    Column {
        width: parent.width
        visible: root.card.length > 0
        spacing: Appearance.padding.small

        StyledText {
            width: parent.width
            text: root.incoming.length > 0 ? "In this update" : "What's new"
            color: Appearance.colour.textDim
        }

        Repeater {
            model: WhatsNew.sections(root.card)

            delegate: SquircleRect {
                id: section

                required property var modelData

                readonly property color hue: root.hue(section.modelData.key)
                readonly property bool major: section.modelData.key === "major"

                width: root.width
                height: sectionBody.implicitHeight + Appearance.padding.normal * 2
                radius: Appearance.rounding.small
                color: Appearance.withAlpha(section.hue, 0.07)

                Column {
                    id: sectionBody

                    x: Appearance.padding.normal
                    y: Appearance.padding.normal
                    width: parent.width - Appearance.padding.normal * 2
                    spacing: Appearance.padding.hair

                    Row {
                        spacing: Appearance.padding.small

                        Icon {
                            y: Math.round((Appearance.font.line.small - size) / 2)
                            size: Appearance.font.iconSize
                            name: section.modelData.glyph
                            color: Appearance.blend(Appearance.colour.textDim, section.hue, 0.7)
                        }

                        StyledText {
                            text: section.modelData.title
                            color: Appearance.blend(Appearance.colour.text, section.hue, 0.55)
                        }

                        StyledText {
                            text: section.modelData.changes.length
                            color: Appearance.colour.textFaint
                        }
                    }

                    Repeater {
                        model: section.modelData.changes

                        delegate: Item {
                            id: changeLine

                            required property var modelData

                            width: sectionBody.width
                            height: changeText.height

                            SquircleRect {
                                x: Math.round((Appearance.font.iconSize - width) / 2)
                                y: Math.round((Appearance.font.line.small - height) / 2)
                                width: Math.max(4, Math.round(Appearance.font.size.small / 4))
                                height: width
                                pill: "object"
                                color: Appearance.blend(Appearance.colour.textFaint, section.hue, 0.5)
                            }

                            StyledText {
                                id: changeText

                                x: Appearance.font.iconSize + Appearance.padding.small
                                width: changeLine.width - x
                                text: changeLine.modelData.text
                                color: section.major ? Appearance.colour.text : Appearance.colour.textDim
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }
    }

    Button {
        visible: !root.asking && root.incoming.length === 0 && root.card.length > 0
        text: "Mark as read"
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

    function hue(key: string): color {
        if (key === "major")
            return Appearance.colour.accent;
        if (key === "features")
            return Appearance.colour.changeNew;
        if (key === "ui")
            return Appearance.colour.changeChanged;
        if (key === "bugs")
            return Appearance.colour.changeFixed;
        if (key === "config")
            return Appearance.colour.changeSettings;
        return Appearance.colour.textDim;
    }
}
