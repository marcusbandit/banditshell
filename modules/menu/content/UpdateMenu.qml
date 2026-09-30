pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Column {
    id: root

    property bool showing: false

    property var card: []

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
        leftPadding: Appearance.padding.normal
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
            leftPadding: Appearance.padding.normal
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
                    leftPadding: Appearance.padding.normal
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
        leftPadding: Appearance.padding.normal
        visible: Update.behind > 0 && !!Update.remoteHead
        text: `latest: ${Update.remoteHead}`
        font.pixelSize: Appearance.font.size.small
        color: Appearance.colour.textFaint
    }

    StyledText {
        width: parent.width
        leftPadding: Appearance.padding.normal
        visible: !!Update.error
        text: Update.error
        color: Update.state === Update.failed ? Appearance.colour.updateFailed : Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
        wrapMode: Text.WordWrap
    }

    Separator {
        width: parent.width
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
        leftPadding: Appearance.padding.normal
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
