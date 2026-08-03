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
// Handlers compose. Several can be hovered at once, none of them consume
// anything, and the thing this is attached to keeps every bit of its own
// behaviour.
//
// It asks on behalf of `host`, which is what the label points at. The default is
// the item you dropped it into; set it when the thing worth pointing at is
// bigger than the thing worth hovering.
HoverHandler {
    id: root

    property string text: ""
    property Item host: root.parent

    // Nothing to say, nothing to ask. Disabling clears `hovered`, which releases
    // through the handler below rather than needing a second path out.
    enabled: !!root.text

    onHoveredChanged: {
        if (root.hovered)
            Tooltips.request(root.host, root.text);
        else
            Tooltips.release(root.host);
    }

    // Text that changes UNDER a resting cursor, which is the normal case for a
    // tip that reads out a live value: a meter's percentage moves while you are
    // looking straight at it.
    onTextChanged: if (root.hovered)
        Tooltips.request(root.host, root.text)

    Component.onDestruction: Tooltips.release(root.host)
}
