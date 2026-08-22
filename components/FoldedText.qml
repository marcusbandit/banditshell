import QtQuick
import qs.config

// Text with two lengths: what a glance gets, and everything there is.
//
// A notification is written by whoever sent it, at whatever length they felt
// like, and the shell has exactly one card to put it in. Eliding is the cheap
// answer and it throws the rest away: the card says there was more and gives no
// way to see it. This keeps both forms and lets something else say which one is
// on screen.
//
// WHERE THE SHORT FORM COMES FROM, in order:
//
//   `brief`, when something upstream knows better than a character count. A
//   parser that understands the sender (see services/NotifBrief.qml) can throw
//   away the noise instead of the tail: qBittorrent's release names are mostly
//   bracket, and cutting the brackets says more in less room than cutting the
//   last forty characters does.
//
//   Otherwise the length, which is the fallback for every sender nobody has
//   written a rule for: measure the column, cut to what `lines` of it hold.
//
// The height MOVES between the two, because the card is in a stack and a stack
// that jumps by a hundred pixels loses the reader's place. Everything else in
// the shell tracks (~/.claude/rules/animation-smoothing.md); so does this.
Item {
    id: root

    // Everything the sender said.
    property string full: ""

    // The parser's short form. Empty means derive one from `full`.
    property string brief: ""

    // FOLD KNOBS.
    // How many lines the folded form gets, and the ceiling on the unfolded one.
    // The ceiling is not restraint, it is a fuse: a sender that emits a log file
    // must not be able to make the tray unnavigable.
    property int lines: 3
    property int fullLines: 40

    property bool unfolded: false

    // The label, for whoever is laying this out. `font` and `color` are the
    // whole of what a caller sets; the rest of the text behaviour is this
    // component's business.
    property alias font: label.font
    property alias color: label.color
    property alias topPadding: label.topPadding

    // MEASURED, not assumed. One character's advance off the font itself, so
    // the budget is right for whatever face the shell is set in rather than for
    // Monocraft's two-thirds. Ten glyphs and a division, because a single
    // character's advance is a rounding error's worth of the answer.
    readonly property real advance: ruler.advanceWidth / ruler.text.length
    readonly property int limit: root.lines * Math.max(1, Math.floor(root.width / Math.max(1, root.advance)))

    readonly property string folded: root.shorten(root.brief || root.full, root.limit)

    // Whether there is anything behind the fold. A short body has no short form
    // and wants no control offering one.
    readonly property bool foldable: root.folded !== root.full

    // CUT AT A WORD when there is one near the end of the budget, because a cut
    // mid-word reads as a broken string where a cut at the last space reads as a
    // sentence that carries on. A filename with no spaces in it gets the hard
    // cut, which is the right answer for a filename.
    //
    // The trailing space goes by regex and not by trimEnd: Quickshell's engine
    // is ES7 and does not have it, and a missing String method is a TypeError at
    // the moment the first long notification arrives rather than at load.
    function shorten(s: string, limit: int): string {
        if (s.length <= limit)
            return s;
        const cut = s.slice(0, limit);
        const space = cut.lastIndexOf(" ");
        return `${(space > limit * 0.6 ? cut.slice(0, space) : cut).replace(/\s+$/, "")}…`;
    }

    implicitWidth: label.implicitWidth
    implicitHeight: grow.value

    // So the text keeps its real size while the box is still on its way there.
    clip: true

    // Snapped on arrival: a card opening is already an animation, and a body
    // that ALSO grew into place would be two of them disagreeing.
    Component.onCompleted: grow.snap()

    Follow {
        id: grow

        target: label.implicitHeight
        speed: Appearance.anim.revealSpeed
    }

    StyledText {
        id: label

        width: root.width

        text: root.unfolded ? root.full : root.folded
        wrapMode: Text.Wrap
        // The cap is belt and braces over the character budget: wrapping breaks
        // early at a word, so a string cut to three lines' worth of characters
        // can still land on four.
        maximumLineCount: root.unfolded ? root.fullLines : root.lines
        elide: Text.ElideRight
    }

    TextMetrics {
        id: ruler

        font: label.font
        text: "0123456789"
    }
}
