import QtQuick
import qs.config
import qs.components

// THE SUM YOU TYPED INTO THE SEARCH FIELD, answered in place.
//
// The launcher is where a hand already goes to ask this machine for something,
// and "what is 2+3*4" is a thing to ask it. Opening a calculator panel to find
// out is three surfaces and a keypad for a question you have already finished
// writing; the panel is for the sums you work through a step at a time, and this
// is for the ones you can type in one go. Same arithmetic behind both (see
// services/Calc.qml), which is the whole reason that file exists.
//
// A MenuRow, like every other row either launcher draws, rather than a shape of
// its own: it is one line in a list, it is selected and activated exactly as the
// application rows are, and a bespoke banner would be a second vocabulary in a
// panel that already has one. What it changes is only which way round the two
// texts go. An application row is a NAME with a description beside it; this is
// an ANSWER with the question beside it, because the answer is the thing you
// came for and the expression is what you can already see in the field above.
//
// WHY IT IS NOT IN THE RESULT LIST. The list is `Apps.search(query)` in one
// concept and a flat list of sections and entries in the other, and pushing a
// non-application into either means every consumer of a row learning that a row
// might not have an entry. It also puts the answer wherever the ranking happens
// to place it. Above the list, under the field, it is in the one position that
// is true: it is not a search result, it is what the field itself says.
MenuRow {
    id: root

    // Calc.answer's object, or null. Handed in rather than evaluated here, so
    // the launcher that owns the Enter key and this row cannot disagree about
    // whether there is an answer at all.
    required property var result

    // Whether Enter currently belongs to this row rather than to the list. Drawn
    // as the selection, because that is what a selection MEANS in these panels:
    // the thing Return would do.
    property bool holds: false

    signal copied

    visible: !!root.result
    // A row nobody can see must take up no room either, or the panel keeps a
    // row's worth of gap above its list for every query that is a word.
    height: visible ? implicitHeight : 0

    icon: "calculate"
    label: root.result?.text ?? ""
    detail: root.expression
    selected: root.holds
    inlineDetail: true

    onActivated: root.copied()

    // WHAT THE FIELD SAYS, so the row can show the question beside its answer.
    // Read from the caller rather than reconstructed from the parsed result: the
    // point of showing it is that it is what you typed, and a normalised
    // rewriting of your own expression back at you is the one version that
    // cannot confirm the machine read it the way you meant.
    property string expression: ""

    // WHAT RETURN WILL DO, spelled out, because there is nothing else on the row
    // that could say it. Every other row in these panels is an application and
    // Return launches it, which needs no caption; a row that puts something on
    // the clipboard is doing a thing to the rest of the session, and a panel
    // that did that without saying so would be a surprise every time.
    StyledText {
        text: "copy"
        font.pixelSize: Appearance.font.size.small
        color: root.holds ? Appearance.colour.accent : Appearance.colour.textGhost

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }
}
