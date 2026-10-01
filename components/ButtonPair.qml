pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// THE BUTTON PAIR: (option||option). Two or more REAL Buttons - each with its
// own colour, hover and press - separated by the seam, the touching corners
// barely rounded, so the row reads as one shape without being one control.
//
// THE DESIGN LAW this component exists to hold: anywhere the shell offers a
// choice as side-by-side buttons, it uses THIS, and the join is tokens, never
// literals. The gap is `Appearance.button.seam`; the corners that face the
// seam round to `Appearance.button.seamRadius`; the outer ends keep the
// button's own full radius. A pair that reaches for `spacing:` or a manual
// `radiusLeft` is a pair that is drifting from the rule.
//
// `primary` names which action is the ask - the one the user is meant to
// press - and wears the filled style; the rest wear tonal. The confirm state
// of a question flips which is which, not the rule.
Row {
    id: root

    property var actions: []

    property int primary: 0

    signal triggered(int index)

    spacing: Appearance.button.seam

    Repeater {
        model: root.actions

        delegate: Button {
            id: member

            required property int index
            required property var modelData

            text: member.modelData.text ?? ""
            icon: member.modelData.icon ?? ""
            style: member.index === root.primary ? "filled" : "tonal"
            radiusLeft: member.index > 0 ? Appearance.button.seamRadius : -1
            radiusRight: member.index < root.actions.length - 1 ? Appearance.button.seamRadius : -1

            onClicked: root.triggered(member.index)
        }
    }
}
