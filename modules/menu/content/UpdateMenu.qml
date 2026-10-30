pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Column {
    id: root

    property bool showing: false
    property bool settled: false

    readonly property var incoming: Update.behind > 0 && !Update.diverged ? Update.entries : []

    readonly property string cardKind: root.incoming.length > 0 ? "incoming" : Update.notes.length > 0 ? "running" : "pending"

    readonly property var card: root.cardKind === "incoming" ? root.incoming : root.cardKind === "running" ? Update.notes : WhatsNew.pending

    property bool declineConfirm: false
    property bool goBackConfirm: false
    property bool reinstallConfirm: false
    property bool reportOpen: false
    property bool reportHanded: false

    readonly property bool reinstallAsking: root.reinstallConfirm && Update.canReinstall
    readonly property bool reportAsking: root.reportOpen && Update.wentBackByHand && Update.resultPending
    readonly property bool asking: root.goBackConfirm || root.reinstallAsking || root.reportAsking
    readonly property bool leaving: root.goBackConfirm && Update.canGoBack

    readonly property var listed: root.leaving ? Update.notes : root.card
    readonly property var unread: root.leaving || root.cardKind === "incoming" ? [] : WhatsNew.pending
    readonly property var shortList: WhatsNew.shortList(root.listed, root.unread)
    readonly property string listTitle: {
        if (root.leaving)
            return "What you leave behind";
        if (root.cardKind === "pending")
            return "What's new";
        return "What changed";
    }

    readonly property var sections: root.shortList.length > 0 ? [] : WhatsNew.sections(root.listed, root.unread)
    readonly property int unreadCount: WhatsNew.unreadCount(root.shortList, root.sections)
    readonly property real unreadBar: Math.max(3, Appearance.font.stem * 3)
    readonly property var linesBefore: {
        const out = [];
        let seen = 0;
        for (const section of root.sections) {
            out.push(seen);
            seen += section.changes.length;
        }
        return out;
    }
    readonly property int eagerLines: {
        let tallest = 0;
        for (const screen of Quickshell.screens)
            tallest = Math.max(tallest, screen.height);
        return Math.ceil(tallest / Appearance.font.line.small);
    }

    readonly property bool wentBack: Update.wentBackByHand && Update.resultPending

    readonly property real menuWidthHint: Math.max(refreshRow.implicitWidth, updateRow.implicitWidth, offerRow.implicitWidth, confirmRow.implicitWidth, actionRow.implicitWidth, reportLink.implicitWidth, root.listed.length > 0 && root.unreadCount > 0 ? titleRow.implicitWidth + Appearance.padding.normal + markRead.implicitWidth : 0, goBackOffer.implicitWidth, goBackRow.implicitWidth, Update.diverged ? pullRow.fullWidth : 0, reinstallRow.implicitWidth, reportRow.implicitWidth)

    onShowingChanged: if (root.showing) {
        root.settled = true;
    } else {
        root.goBackConfirm = false;
        root.reinstallConfirm = false;
        root.reportOpen = false;
        root.reportHanded = false;
    }

    onReportAskingChanged: if (root.reportAsking) {
        reportBody.text = "";
        reportBody.forceActiveFocus();
    }

    function sendReport(): void {
        Update.report(reportBody.text);
        root.reportOpen = false;
        root.reportHanded = true;
    }

    spacing: Appearance.padding.small

    InkText {
        width: parent.width
        alignInk: true
        wrapMode: Text.Wrap
        text: root.leaving ? `Go back to ${Update.previousVersion}?` : Update.headline
        color: Update.state === Update.failed ? Appearance.colour.updateFailed : Appearance.colour.text
    }

    InkText {
        width: parent.width
        visible: !root.leaving && !root.wentBack
        alignInk: true
        wrapMode: Text.Wrap
        text: Update.haveLabel
        color: Appearance.colour.textFaint
    }

    StyledText {
        width: parent.width
        visible: root.leaving
        text: `Restarts on ${Update.previousVersion}. Updates skip ${Update.version} until a newer version arrives.`
        color: Appearance.colour.textDim
        wrapMode: Text.WordWrap
    }

    StyledText {
        width: parent.width
        visible: root.leaving
        text: "Only the shell's own files go back. Your settings and anything else this update changed stay changed."
        color: Appearance.colour.textDim
        wrapMode: Text.WordWrap
    }

    StyledText {
        width: parent.width
        visible: !root.leaving && Update.behind > 0 && !Update.diverged && Update.detailsText !== ""
        text: Update.detailsText
        color: Appearance.colour.textDim
        wrapMode: Text.WordWrap
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
        visible: Update.resultPending && !root.leaving && !root.reinstallAsking
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
            text: "Report what broke"
        }

        Item {
            id: reportBox

            width: parent.width
            height: Math.max(Appearance.font.line.small * 4, reportBody.contentHeight) + Appearance.padding.normal * 2

            SquircleRect {
                anchors.fill: parent
                radius: Appearance.rounding.small
                color: Appearance.colour.fillStrong
                stroke: reportBody.activeFocus ? Appearance.colour.accent : "transparent"
                strokeWidth: reportBody.activeFocus ? Appearance.stroke.ring : 0
            }

            TextEdit {
                id: reportBody

                readonly property bool typable: true

                anchors.fill: parent
                anchors.margins: Appearance.padding.normal
                wrapMode: TextEdit.Wrap
                font.family: Appearance.font.family
                font.pixelSize: Appearance.font.size.small
                renderType: Text.NativeRendering
                color: Appearance.colour.text
                selectionColor: Appearance.colour.accent
                selectedTextColor: Appearance.colour.accentText
                selectByMouse: true

                onActiveFocusChanged: {
                    if (activeFocus)
                        Prompts.request(reportBox);
                    else
                        Prompts.release(reportBox);
                }

                Keys.onEscapePressed: event => {
                    root.reportOpen = false;
                    event.accepted = true;
                }

                StyledText {
                    width: parent.width
                    visible: !reportBody.text
                    text: "What broke, and what did you expect?"
                    color: Appearance.colour.textFaint
                    wrapMode: Text.WordWrap
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                acceptedButtons: Qt.NoButton
            }

            Component.onDestruction: Prompts.release(reportBox)
        }

        StyledText {
            width: parent.width
            text: "Added after your words"
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
                text: Update.reportContext
                color: Appearance.colour.text
                wrapMode: Text.WordWrap
            }
        }

        StyledText {
            width: parent.width
            text: "Review in a terminal shows the whole report, your config and the last log lines included, secrets left out. It files an issue on banditshell's GitHub only after you answer y."
            color: Appearance.colour.textDim
            wrapMode: Text.WordWrap
        }

        ButtonPair {
            id: reportRow

            rest: "ring"
            actions: [{ text: "Review in a terminal", icon: "terminal" }, { text: "Don't send" }]

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
            text: `Restarts on ${Update.skippedVersion}, and updates stop skipping it.`
            wrapMode: Text.Wrap
        }

        ButtonPair {
            id: reinstallRow

            rest: "ring"
            actions: [{ text: `Update to ${Update.skippedVersion} again`, icon: "download" }, { text: `Stay on ${Update.version}` }]

            onTriggered: index => {
                root.reinstallConfirm = false;
                if (index === 0)
                    Update.reinstall();
            }
        }
    }

    Row {
        id: actionRow

        visible: !root.asking && Update.resultPending
        spacing: Appearance.padding.small

        Button {
            visible: Update.canReinstall
            text: `Update to ${Update.skippedVersion} again`
            icon: "download"
            style: "accent"

            onClicked: root.reinstallConfirm = true
        }

        Button {
            visible: Update.resultPending
            text: "Hide message"
            style: "ring"
            onClicked: Update.dismissResult()
        }
    }

    Button {
        id: reportLink

        visible: !root.asking && Update.wentBackByHand && Update.resultPending
        text: "Tell us why you went back"
        style: "ring"

        onClicked: {
            root.reportHanded = false;
            root.reportOpen = true;
        }
    }

    Column {
        width: parent.width
        visible: root.listed.length > 0 && (root.leaving || !root.asking || root.reinstallAsking)
        spacing: Appearance.padding.small

        Item {
            width: parent.width
            height: Math.max(listTitle.implicitHeight, markRead.visible ? markRead.implicitHeight : 0)

            Row {
                id: titleRow

                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.padding.small

                StyledText {
                    id: listTitle

                    anchors.verticalCenter: parent.verticalCenter
                    text: root.listTitle
                    color: Appearance.colour.textDim
                }

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.unreadCount > 0
                    width: newCount.x + newCount.implicitWidth
                    height: Appearance.font.line.small

                    SquircleRect {
                        id: newMark

                        anchors.verticalCenter: parent.verticalCenter
                        width: root.unreadBar
                        height: Math.round(parent.height * 0.6)
                        pill: "object"
                        color: Appearance.colour.accent
                    }

                    StyledText {
                        id: newCount

                        x: newMark.x + newMark.width + Appearance.padding.small
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${root.unreadCount} unread`
                        color: Appearance.blend(Appearance.colour.text, Appearance.colour.accent, 0.55)
                    }
                }
            }

            Button {
                id: markRead

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.asking && root.unreadCount > 0
                text: "Mark all read"
                icon: "done_all"
                style: "ring"

                onClicked: WhatsNew.markSeen(WhatsNew.pending[0].id)
            }
        }

        TextMetrics {
            id: tagWidth

            font.family: Appearance.font.family
            font.pixelSize: Appearance.font.size.small
            text: root.shortList.reduce((longest, line) => line.tag.length > longest.length ? line.tag : longest, "")
        }

        Repeater {
            model: root.shortList

            delegate: Item {
                id: tagged

                required property var modelData

                readonly property color hue: root.hue(tagged.modelData.key)

                readonly property bool keyable: true

                width: root.width
                height: Math.max(tagChip.height, taggedText.height)

                FocusMark {
                    shown: tagged.activeFocus
                    around: Appearance.rounding.small
                }

                SquircleRect {
                    visible: tagged.modelData.unread === true
                    width: root.unreadBar
                    height: tagged.height
                    pill: "object"
                    color: Appearance.colour.accent
                }

                StyledText {
                    id: tagChip

                    x: root.unreadCount > 0 ? root.unreadBar + Appearance.padding.small : 0
                    width: Math.ceil(tagWidth.advanceWidth)
                    text: tagged.modelData.tag
                    color: Appearance.blend(Appearance.colour.text, tagged.hue, 0.55)
                }

                StyledText {
                    id: taggedText

                    x: tagChip.x + tagChip.width + Appearance.padding.small
                    width: tagged.width - x
                    text: tagged.modelData.text
                    color: root.unreadCount > 0 && tagged.modelData.unread !== true ? Appearance.colour.textDim : Appearance.colour.text
                    wrapMode: Text.WordWrap
                }
            }
        }

        Repeater {
            model: root.sections

            delegate: SquircleRect {
                id: section

                required property var modelData
                required property int index

                readonly property int eager: Math.max(0, root.eagerLines - root.linesBefore[section.index])

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

                    UpdateChangeLines {
                        width: sectionBody.width
                        unreadBar: root.unreadBar
                        lines: section.modelData.changes.slice(0, section.eager)
                        hue: section.hue
                        major: section.major
                    }

                    Loader {
                        width: sectionBody.width
                        active: root.settled && section.modelData.changes.length > section.eager
                        asynchronous: true

                        sourceComponent: UpdateChangeLines {
                            unreadBar: root.unreadBar
                            lines: section.modelData.changes.slice(section.eager)
                            hue: section.hue
                            major: section.major
                        }
                    }
                }
            }
        }
    }

    Row {
        id: updateRow

        visible: Update.busy || (!root.asking && !Update.diverged && !Update.paused && (Update.behind > 0 || Update.state === Update.failed))
        spacing: Appearance.padding.normal

        Button {
            anchors.verticalCenter: parent.verticalCenter
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

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !Update.busy && Update.state !== Update.failed && Update.buttonNote !== ""
            text: Update.buttonNote
            color: Update.deps.length > 0 ? Appearance.colour.text : Appearance.colour.textDim
        }
    }

    StyledText {
        width: parent.width
        visible: !!Update.error
        text: Update.error
        color: Update.state === Update.failed ? Appearance.colour.updateFailed : Appearance.colour.textFaint
        wrapMode: Text.WordWrap
    }

    Column {
        width: parent.width
        visible: Update.ahead > 0 && Update.own.length > 0 && (Update.diverged || !root.asking)
        spacing: Appearance.padding.hair

        StyledText {
            width: parent.width
            text: Update.ownTitle
            color: Appearance.colour.textDim
        }

        Repeater {
            model: Update.own

            delegate: UpdateChangeLine {
                required property string modelData

                width: root.width
                text: modelData
                major: true
            }
        }

        StyledText {
            width: parent.width
            visible: Update.ahead > Update.own.length
            text: `and ${Update.ahead - Update.own.length} more`
            color: Appearance.colour.textFaint
        }
    }

    StyledText {
        width: parent.width
        visible: Update.diverged
        text: `This copy cannot just move forward. To keep ${Update.ahead === 1 ? "your change" : "your changes"}, run in a terminal:`
        color: Appearance.colour.updateFailed
        wrapMode: Text.WordWrap
    }

    Item {
        id: pullRow

        readonly property real copyWidth: copyPull.implicitWidth + Appearance.padding.small
        readonly property real fullWidth: pullText.implicitWidth + Appearance.padding.normal * 2 + pullRow.copyWidth

        width: parent.width
        height: Math.max(pullBox.height, copyPull.implicitHeight)
        visible: Update.diverged

        SquircleRect {
            id: pullBox

            width: Math.min(pullText.implicitWidth + Appearance.padding.normal * 2, pullRow.width - pullRow.copyWidth)
            height: Appearance.font.line.small + Appearance.padding.small * 2
            anchors.verticalCenter: parent.verticalCenter
            radius: Appearance.rounding.small
            color: Appearance.colour.fillStrong

            StyledText {
                id: pullText

                x: Appearance.padding.normal
                width: parent.width - Appearance.padding.normal * 2
                anchors.verticalCenter: parent.verticalCenter
                text: Update.pullCommand
                color: Appearance.colour.text
                wrapMode: Text.NoWrap
                elide: Text.ElideMiddle
            }
        }

        Button {
            id: copyPull

            anchors.left: pullBox.right
            anchors.leftMargin: Appearance.padding.small
            anchors.verticalCenter: parent.verticalCenter
            text: copiedPull.running ? "Copied" : "Copy"
            icon: copiedPull.running ? "check" : "content_copy"
            style: "ring"

            onClicked: {
                Quickshell.execDetached(["wl-copy", "-n", "--", Update.pullCommand]);
                copiedPull.restart();
            }
        }

        Timer {
            id: copiedPull

            interval: 2000
        }
    }

    Button {
        id: goBackOffer

        visible: !root.asking && Update.canGoBack
        text: `Go back to ${Update.previousVersion}`
        icon: "history"
        style: "ring"

        onClicked: root.goBackConfirm = true
    }

    ButtonPair {
        id: goBackRow

        rest: "ring"
        visible: root.leaving
        actions: [{ text: `Go back to ${Update.previousVersion}`, icon: "history" }, { text: `Stay on ${Update.version}` }]

        onTriggered: index => {
            root.goBackConfirm = false;
            if (index === 0)
                Update.goBack();
        }
    }

    Row {
        id: refreshRow

        visible: !root.asking
        spacing: Appearance.padding.small

        InkText {
            anchors.verticalCenter: parent.verticalCenter
            alignInk: true
            text: Update.checkedAt.getTime() === 0 ? "Never checked" : `Last checked ${Update.ago(Update.checkedAt)}`
            color: Appearance.colour.textFaint
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: Update.checking ? "Refreshing..." : "Refresh"
            style: "ring"
            interactive: !Update.checking

            onClicked: Update.check()
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

        InkText {
            width: parent.width
            alignInk: true
            text: "Your keybinds are deprecated"
            color: Appearance.colour.accent
            wrapMode: Text.WordWrap
        }

        ButtonPair {
            id: offerRow

            rest: "ring"
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

            rest: "ring"
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
