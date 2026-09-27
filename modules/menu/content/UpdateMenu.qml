pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// The update menu: what the check found, and the one deed the state is asking
// for.
//
// A SMALL MENU ON PURPOSE. The marker above the clock already carries the
// alarm; this panel's job is to resolve it in one press, and every row in here
// exists to serve that: the count the check found, and the action - "Download
// Update" in the red state, "Restart the shell" in the blue one, "Search for
// update" when nothing is confirmed - the same slot trading deeds as the
// state moves, because at most one of them can be true at a time.
//
// The BRANCH is deliberately not in here. Which branch is tracked is
// configuration, not a choice a menu offers: it is `updates.branch` in
// config.json, and the panel says which one its numbers were counted against
// so a person reading it always knows the answer they got.
//
// AND, WHEN THERE IS NEWS, THE WHAT'S NEW CARD at the top: every log entry
// accumulated past the user's marker (services/WhatsNew.qml), which is the
// changes a pull or a download has put on this machine that no card has been
// shown for yet. The menu is the news's host because the news IS about this
// menu's own state, and the launch opens this menu outright when there is
// anything pending rather than trusting the panel to be found.
Column {
    id: root

    // MENU PANEL'S HANDSHAKE: what a body is told through the Loader, bound
    // to the page's `believed` - on screen, and long enough to be read. The
    // card's only clock hangs off this.
    property bool showing: false

    // THE CARD, LATCHED. `pending` is live and `card` is what this visit of
    // the menu is showing: marking seen empties `pending` (that is its whole
    // job), and a binding here would take the news away mid-read. Latched at
    // the moment it is offered, and it dies with the menu instance - a fresh
    // open with nothing pending draws no card.
    property var card: []

    spacing: Appearance.padding.small

    // The offering: latch the card, then mark it seen - in that order, because
    // the mark is what empties what the latch is taken from. It runs on either
    // of the two ways the news can arrive: the menu opening with entries
    // already pending (`showing` arriving), or entries arriving while the menu
    // is already open and believed - a download landing under a stationary
    // cursor, the card growing into the panel where the button was just
    // pressed.
    //
    // SHOWN, NOT ACKNOWLEDGED. Seen is written when the panel believes the
    // card has been read, never by a dismiss: an acknowledge button would be a
    // second door on a panel whose whole job is one deed and a sentence, and a
    // card left sitting unacknowledged would re-summon every launch forever
    // after. What is lost is the re-read; the log is in the repo for that.
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

    // THE STATE, IN WORDS. What the marker compressed into a colour and a
    // size, said plainly, because the menu is where the detail lives.
    StyledText {
        width: parent.width
        leftPadding: Appearance.padding.normal
        text: {
            if (Update.state === Update.downloaded)
                return "Downloaded - restart to apply";
            if (Update.state === Update.downloading)
                return "Downloading from GitHub...";
            if (Update.behind > 0)
                return `${Update.behind} new commit${Update.behind === 1 ? "" : "s"} on ${Update.branch}`;
            if (Update.checkedAt.getTime() === 0)
                return "Not checked yet";
            return "No updates confirmed";
        }
        font.pixelSize: Appearance.font.size.small
        color: Appearance.colour.textDim
    }

    // ---- THE WHAT'S NEW CARD ----
    //
    // One block per entry, newest first: the version line it shipped under,
    // then each change with the mark of its type. A Major entry's caption
    // takes the accent, because the accent is rationed for state that earns a
    // colour and "you must do something" is exactly what earns it; the minor
    // entries keep the quiet tier and read as ordinary news.
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

                // The version line, and the date beside it when the two say
                // different things: an id that IS a date is not said twice.
                StyledText {
                    width: parent.width
                    leftPadding: Appearance.padding.normal
                    text: entryBlock.modelData.date !== "" && entryBlock.modelData.date !== entryBlock.modelData.id ? `${entryBlock.modelData.id} · ${entryBlock.modelData.date}` : entryBlock.modelData.id
                    font.pixelSize: Appearance.font.size.small
                    color: WhatsNew.severityOf(entryBlock.modelData) === "major" ? Appearance.colour.accent : Appearance.colour.textFaint
                }

                Repeater {
                    model: entryBlock.modelData.changes

                    // AN ITEM, NOT THE ROW ITSELF: a Column manages both of a
                    // child's coordinates, so the indent to the caption's own
                    // text edge needs a wrapper that a positioner does not
                    // own. The Row inside it is then free, and its children
                    // are not.
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
                                // A POSITIONER MANAGES X ONLY, so the mark's
                                // height is set by hand against the FIRST
                                // line of the text it leads - the line the
                                // mark belongs to, centred the way
                                // StyledText's line box centres - rather than
                                // anchoring to the row, which a positioner
                                // forbids.
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

    // WHERE THE LATEST COMMIT STANDS, when there is one to name. A count says
    // how many; a hash says what arrived, and "is that the one I pushed" is
    // answered by reading it.
    StyledText {
        width: parent.width
        leftPadding: Appearance.padding.normal
        visible: Update.behind > 0 && !!Update.remoteHead
        text: `latest: ${Update.remoteHead}`
        font.pixelSize: Appearance.font.size.small
        color: Appearance.colour.textFaint
    }

    // WHAT WENT WRONG, if anything: offline, a branch that does not exist yet,
    // or the shell running from the snapshot (which has no .git to ask). Said
    // here rather than blinked on the bar.
    StyledText {
        width: parent.width
        leftPadding: Appearance.padding.normal
        visible: !!Update.error
        text: Update.error
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
        wrapMode: Text.WordWrap
    }

    Separator {
        width: parent.width
    }

    // THE DEED, one at a time in the slot: download in the red state, restart
    // in the blue one, a search when nothing is confirmed - which is the
    // quiet marker's own promise, spelled out here. While an action is
    // impossible the slot says what it is doing instead of going away, so the
    // panel never narrows mid-press.
    Button {
        text: {
            if (Update.state === Update.downloaded)
                return "Restart the shell";
            if (Update.state === Update.downloading)
                return "Downloading...";
            if (Update.behind > 0)
                return "Download Update";
            return "Search for update";
        }
        icon: {
            if (Update.state === Update.downloaded)
                return "restart_alt";
            if (Update.state === Update.downloading)
                return "cloud_download";
            if (Update.behind > 0)
                return "download";
            return "sync";
        }
        style: Update.behind > 0 || Update.state === Update.downloaded ? "filled" : "tonal"
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

    // WHEN THE ANSWER WAS LAST FETCHED, so "up to date" can be judged: an
    // answer four seconds old and four hours old are different facts.
    StyledText {
        leftPadding: Appearance.padding.normal
        visible: Update.checkedAt.getTime() > 0
        text: `checked ${root.ago(Update.checkedAt)}`
        font.pixelSize: Appearance.font.size.small
        color: Appearance.colour.textFaint
    }

    // The mark per change type, from the vocabulary docs/agents/whats-new.md
    // defines. A type the rule gains later is drawn as a plain chevron rather
    // than a missing glyph: the writer's vocabulary can move without this
    // file's.
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

    // How long ago a completed check was, in the units the gap actually is.
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
