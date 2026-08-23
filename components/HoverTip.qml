import QtQuick
import qs.config

// A TOOLTIP, ON ANYTHING. Drop one inside an item and that item answers "what is
// that" after a beat.
//
// Tooltips.qml has always been able to serve any widget in the shell, and almost
// nothing asked: the two callers each hand-rolled the same three lines onto a
// MouseArea they already had, so a control without a MouseArea, which is most of
// them, had no way to speak at all. The icon-only ones, the chevrons and meters
// and switches that are exactly the things a person has to guess at, were
// silent, and the rows that could already be read out loud were the only things
// with labels.
//
// A HOVERHANDLER, and that is the whole reason this can be dropped anywhere.
// MouseAreas are exclusive about hover: the topmost one takes it and everything
// under it is told the cursor left, so a MouseArea added purely to ask a
// question would silently put out the hover of the control it was added to.
// Handlers do not consume anything, and the thing this is attached to keeps
// every bit of its own behaviour.
//
// WHAT HANDLERS DO NOT DO is see through a MouseArea that is already there.
// Hover stops at the first thing that takes it, and a MouseArea filling its own
// item takes it before that item's handlers are reached, so on a real control
// the handler is deaf in BOTH directions. That is what `asked` below is for,
// and every host that owns a MouseArea has to use it.
//
// It asks on behalf of `host`, which is what the label points at. The default is
// the item you dropped it into; set it when the thing worth pointing at is
// bigger than the thing worth hovering.
HoverHandler {
    id: root

    property string text: ""
    property Item host: root.parent

    // WITHOUT THE BEAT, for a control whose label is the only thing telling it
    // from the one next to it. See the exception in Tooltips.qml; the default is
    // the wait, and it should stay the default.
    property bool now: false

    // WHO SAYS THE CURSOR IS HERE, and the default is the handler itself.
    //
    // That default is right for anything that is only a shape: a glyph, a
    // meter, a plate. It is WRONG for a control that owns a MouseArea, and
    // silently so. Hover is delivered down the tree and stops at the first
    // thing that takes it: a MouseArea filling its own item takes the event
    // before that item's handlers are ever reached, so the handler under one
    // never hears an enter AND never hears a leave. A tooltip put up by some
    // other route then has no way down at all, which is exactly what the share
    // button did: press it and its label stayed on screen for good.
    //
    // So a host that already knows the answer hands it in, and the question
    // and the answer come from the same place, which is the only arrangement
    // that cannot get stuck half way.
    property bool asked: root.hovered

    // Nothing to say, nothing to ask.
    enabled: !!root.text

    onAskedChanged: {
        if (root.asked)
            Tooltips.request(root.host, root.text, root.now);
        else
            Tooltips.release(root.host);
    }

    // A tip that goes quiet is a tip that is over, whoever is asking. This is
    // the way out for a host whose text empties while the cursor is still
    // sitting on it, and it does not go through `asked` at all.
    onEnabledChanged: if (!root.enabled)
        Tooltips.release(root.host)

    // Text that changes UNDER a resting cursor, which is the normal case for a
    // tip that reads out a live value: a meter's percentage moves while you are
    // looking straight at it.
    onTextChanged: if (root.asked)
        Tooltips.request(root.host, root.text, root.now)

    Component.onDestruction: Tooltips.release(root.host)
}
