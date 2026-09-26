pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// The update menu: which branch is tracked, what the check found, and the one
// deed the state is asking for.
//
// A SMALL MENU ON PURPOSE. The marker above the clock already carries the
// alarm; this panel's job is to resolve it in one press, and every row in here
// exists to serve that: the branch the check was made against, the count it
// found, and the action - "Download Update" in the red state, "Restart the
// shell" in the blue one, "Search for update" when nothing is confirmed - the
// same slot trading deeds as the state moves, because at most one of them can
// be true at a time.
//
// The BRANCH CHOICE lives in here rather than in a settings page, for the
// reason the clock's zones do: a tracker and its question belong together, and
// "which branch do I follow" is asked exactly when the answer is wanted.
// Written through Config.set, so the choice survives the session.
Column {
    id: root

    spacing: Appearance.padding.small

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

    // THE BRANCH, as the choice it is. Three named tracks, exactly one
    // followed; a Segments and not a switch for the reason Segments' header
    // spends. Picking one writes the setting and re-checks at once, so the
    // panel's numbers above are the new branch's numbers by the time you read
    // them.
    Column {
        width: parent.width
        spacing: 0

        StyledText {
            leftPadding: Appearance.padding.normal
            text: "branch"
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textFaint
        }

        Segments {
            id: branchChoice

            // THE THREE NAMES, in the order offered: the channel the shell
            // actually ships from first. These are branch NAMES, not labels -
            // what a pick does is point the next check at that ref on GitHub,
            // and a ref that does not exist yet is said in the panel above
            // rather than hidden here.
            options: ["dev", "main", "release"]
            current: Math.max(0, branchChoice.options.indexOf(Update.branch))

            onPicked: index => Config.set("updates.branch", branchChoice.options[index])
        }
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
