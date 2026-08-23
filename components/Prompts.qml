pragma Singleton

import QtQuick
import Quickshell

// WHO IS WAITING ON A KEYSTROKE, and ON WHICH SURFACE.
//
// It lives in components rather than services for the same reason Tooltips does:
// it knows nothing about this shell, only that a field somewhere is open and
// wants typing into.
//
// It exists because a layer surface is handed no key events unless its window
// asks the compositor for them, and the window is the only thing that can ask. A
// field cannot: it sits inside a menu's content, which is a Component handed in
// and loaded two levels down, in one of MenuPanel's two cross-fade slots.
// Threading a flag back up through all of that would make every menu that ever
// holds a field remember to forward something it does not care about, and a menu
// that forgot would fail silently, in the one way that looks like a broken
// keyboard. So the field says what it wants and the window listens, with nothing
// in between having to know.
//
// BY ITEM, like Tooltips, and idempotent both ways: a menu builds one field per
// row and shows one of them, so the nine that never opened must not be able to
// hand back a claim they never made. That also lets a field say where it stands
// on every edge it has, including its own destruction, which is how a menu
// closing gives the keyboard back.
//
// AND ANSWERED PER WINDOW, which is the whole of what a second monitor changes
// here. The shell draws one surface per screen (shell.qml), so there are N
// windows reading this one list, and a list that only says THAT something is
// waiting makes every one of them ask for the keyboard on behalf of a field that
// is on exactly one of them. Two layer surfaces both holding it exclusively is
// the "typing goes nowhere" failure ShellWindow's keyboardFocus spends eighty
// lines guarding against: a password field open in a menu over here, any menu
// still up over there, and the keys land in neither. A claim is a fact about ONE
// surface, so the question has to be put per surface, and activeIn is where it
// is put.
Singleton {
    id: root

    // ANYWHERE AT ALL, which is a fact about the shell rather than about a
    // surface, and therefore not the question anything drawn on one may ask.
    // Nothing asks it today; it is kept because "is the shell holding a prompt"
    // is a real thing to want to know and this is its answer, and because
    // reaching for the wrong one by accident is no longer possible: a window
    // that wants an answer it can act on has to name itself to get one.
    readonly property bool active: root.claims.length > 0

    property var claims: []

    function request(item: Item): void {
        if (!root.claims.includes(item))
            root.claims = [...root.claims, item];
    }

    function release(item: Item): void {
        root.claims = root.claims.filter(c => c !== item);
    }

    // WHETHER ANYTHING ON THIS SURFACE IS WAITING TO BE TYPED INTO, which is the
    // question a window asks and the only one with an answer it can act on.
    //
    // THE CLAIM IS NOT TOLD ITS WINDOW, IT IS ASKED. A claim is still the item
    // and nothing else; the window is read out of it here, at the moment the
    // question is put, through the same `QsWindow.window` an item uses to name
    // the surface it is drawn on (modules/SettingsCorner.qml reads it to turn its
    // own rectangle into layout coordinates). An attached property is reachable
    // from outside the object it is attached to, which is what makes asking
    // possible at all.
    //
    // Snapshotting the window into the claim when it is made was the obvious
    // shape and is the wrong one twice over. A field registers from
    // Component.onCompleted, and an item not yet parented into anything has no
    // window: the snapshot would be a null nothing ever comes back to correct,
    // which is a claim that can never be honoured and a keyboard that never
    // arrives. It would also put a thing to remember back onto every field that
    // ever wants typing into, which is exactly what this singleton exists so
    // that nobody has to do, and a field that forgot would fail in the silent
    // way described above. Asked live, both ends are bindings: a QML binding
    // captures every property it touched while it was evaluating, including the
    // ones touched inside here, so a claim that finds its window a frame later
    // drags the window's own keyboardFocus along with it.
    //
    // A CLAIM THAT CANNOT NAME A WINDOW MATCHES NOTHING, not everything. Both
    // are wrong for as long as they last, and only one of them is wrong in the
    // direction this exists to remove: counted everywhere it is every surface
    // grabbing the keyboard at once, which is the failure itself; counted
    // nowhere it is a frame of a field with no keys, which the next pass over
    // the binding repairs.
    function activeIn(window: var): bool {
        // Read out of the property BEFORE the window is tested, and not inside a
        // condition that can skip it. A binding only depends on what it actually
        // touched while it ran, so a version that short-circuited on a null
        // window would come back false having never looked at the list, and
        // would then not hear about the claim that arrived a moment later.
        const claims = root.claims;
        return !!window && claims.some(c => c?.QsWindow?.window === window);
    }
}
