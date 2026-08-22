pragma Singleton

import QtQuick
import Quickshell

// THE SHORT FORM OF A NOTIFICATION, for senders whose long form is mostly noise.
//
// The spec gives a notification a summary and a body and no idea of length, so
// a card can only ever fall back to cutting the tail off (see
// components/FoldedText.qml, which is what does that). Cutting the tail is the
// worst possible cut for the sender this file was written for: qBittorrent puts
// the release name in the body, and a release name is a filename wearing four
// bracketed groups of metadata, so the twenty-five characters a card can show
// are the fansub group and the resolution rather than the name of the thing that
// finished downloading.
//
// A RULE IS A FUNCTION, not a pattern to configure. What has to be thrown away
// differs per sender in kind and not merely in place, and a table of regexes
// with a replacement each would be a small language nobody asked for; a rule
// that is a function can do whatever that sender needs and reads as what it
// does.
//
// It only ever SHORTENS. Nothing here invents text, reorders it, or translates
// it: the unfolded card still shows exactly what arrived, so a rule that guesses
// wrong costs a fold and never the message.
Singleton {
    id: root

    // Matched against the desktop entry and the app name, lowercased, as a
    // substring: `qbittorrent` catches `qBittorrent` and
    // `org.qbittorrent.qBittorrent` alike, which is the pair a sender picks
    // between without telling anyone.
    readonly property var rules: [
        {
            apps: ["qbittorrent"],

            // THE SENTENCE AND EVERY BRACKETED GROUP, which between them are all
            // but four words of it:
            //
            //   '[Erai-raws] Yomi no Tsugai - 20 [1080p CR WEB-DL AVC AAC][MultiSub].mkv' has finished downloading.
            //   Yomi no Tsugai - 20.mkv
            //
            // The CLAUSE goes because the summary right above it already says
            // "Download completed", and a card that says the same thing twice
            // has spent its second line saying nothing. The QUOTES go with it:
            // they were marking the name off from the sentence around it, and
            // once the sentence is gone a quoted string on its own line reads as
            // punctuation nobody closed.
            //
            // A group's TRAILING space goes with the group rather than its
            // leading one, because a group is nearly always followed by the
            // thing it qualifies. What is left is the gap a group leaves in
            // front of punctuation (` .mkv`), which is that line's whole job.
            brief: body => body.replace(/\s+has finished downloading\.?\s*$/, "").replace(/\[[^\]]*\]\s*/g, "").replace(/\s+/g, " ").replace(/\s+([.,;:!?)])/g, "$1").replace(/^\s+|\s+$/g, "").replace(/^'(.*)'$/, "$1")
        }
    ]

    function ruleFor(entry: var): var {
        const names = [entry?.desktopEntry, entry?.appName].filter(n => n).map(n => n.toLowerCase());
        if (names.length === 0)
            return null;
        return root.rules.find(rule => rule.apps.some(app => names.some(name => name.includes(app)))) ?? null;
    }

    // The body's short form, or "" for "nobody here knows better than the
    // length". Empty is also the answer when a rule leaves NOTHING (a body that
    // was brackets end to end) or changes nothing, because a fold whose two
    // sides are the same is a control that does not do anything.
    function briefFor(entry: var): string {
        const body = entry?.body ?? "";
        if (!body)
            return "";

        const rule = root.ruleFor(entry);
        if (!rule)
            return "";

        const short = rule.brief(body);
        return short && short !== body ? short : "";
    }
}
