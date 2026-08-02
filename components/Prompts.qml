pragma Singleton

import QtQuick
import Quickshell

// WHO IS WAITING ON A KEYSTROKE, shell-wide.
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
Singleton {
    id: root

    readonly property bool active: root.claims.length > 0

    property var claims: []

    function request(item: Item): void {
        if (!root.claims.includes(item))
            root.claims = [...root.claims, item];
    }

    function release(item: Item): void {
        root.claims = root.claims.filter(c => c !== item);
    }
}
