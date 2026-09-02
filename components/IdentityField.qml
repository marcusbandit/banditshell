import QtQuick
import qs.config

// AN ENTERPRISE SIGN-IN, in the slot the passphrase field would have taken.
//
// PasswordField next door asks for a shared secret, which is the whole of what a
// WPA2-PSK network knows about anyone: everybody who is on it typed the same
// string. An 802.1X network has no such string. It wants to know WHO you are, so
// it takes a name, a password that is yours rather than the room's, and the
// method the two of them travel in.
//
// That is a second component rather than a flag on the first because a field that
// sprouts two more boxes when a property is set is two components wearing one
// name, and every caller of the simple one would have to start reading which of
// them it had.
Item {
    id: root

    property string placeholder: ""

    signal accepted(string identity, string password, string eap, string phase2)
    signal cancelled

    // THE OUTER METHOD, AND THE INNER ONE THAT ALWAYS COMES WITH IT.
    //
    // Two lists read at the same index, rather than a question followed by a
    // second question about the answer to the first. peap carries mschapv2 and
    // ttls carries pap in very nearly every deployment there is: eduroam, the
    // universities behind it, and the corporate networks built on the same kit.
    // Spending a fourth control on the pairing would be asking everybody to
    // confirm the only answer they were ever going to give, in a thing that
    // hovers and closes when you look away.
    //
    // The rarer pairings, and EAP-TLS, stay in ~/bin/wifi. TLS is not a longer
    // version of this form, it is a different one: it identifies you with a
    // certificate, and a certificate is a file that has to be gone and found.
    // This is a menu, and a menu has no business opening a file picker.
    readonly property var methods: ["peap", "ttls"]
    readonly property var inner: ["mschapv2", "pap"]

    property int method: 0

    implicitHeight: visible ? stack.implicitHeight : 0

    // NOTHING LEAVES HERE HALF-FILLED. Enter means the same thing in both boxes,
    // and when one of them is still empty it puts the cursor in that one instead
    // of sending a sign-in the network can only refuse.
    function submit(): void {
        if (!identity.text)
            identity.input.forceActiveFocus();
        else if (!password.text)
            password.input.forceActiveFocus();
        else
            root.accepted(identity.text, password.text, root.methods[root.method], root.inner[root.method]);
    }

    // The claim, the focus, and the round trip a surface makes before it has any
    // keys to give: all of it is PasswordField's, unchanged, and the reasoning is
    // written out over there rather than twice. The only thing this one decides
    // for itself is which box gets the cursor, and a form is filled from the top.
    //
    // The method is deliberately not reset with the text. It is a fact about the
    // network, not a secret, so a rejected password should not also cost you the
    // choice you made above it.
    readonly property bool surfaceActive: root.Window.active
    onSurfaceActiveChanged: if (root.surfaceActive && root.visible)
        identity.input.forceActiveFocus()

    function claim(): void {
        identity.text = "";
        password.text = "";
        if (root.visible) {
            Prompts.request(root);
            identity.input.forceActiveFocus();
        } else {
            Prompts.release(root);
        }
    }

    onVisibleChanged: root.claim()
    Component.onCompleted: root.claim()
    Component.onDestruction: Prompts.release(root)

    // ONE BOX, USED TWICE, and it signals outward instead of calling root
    // directly because an inline component cannot see the ids of the file it is
    // declared in. Wiring it up at each use site is the price of the two fields
    // being the same object rather than two copies free to drift apart.
    component Entry: Item {
        id: entry

        property alias input: box
        property alias text: box.text
        property string hint: ""
        property bool secret: false

        // Where Tab goes. The two boxes are one form; without it they are two
        // islands and the only way across is the mouse.
        property Item next: null

        signal entered
        signal escaped

        implicitHeight: box.implicitHeight + Appearance.padding.normal * 2

        G2Rect {
            anchors.fill: parent
            anchors.topMargin: Appearance.padding.small
            anchors.bottomMargin: Appearance.padding.small
            radius: Appearance.rounding.small
            color: Appearance.colour.fillStrong
        }

        TextInput {
            id: box

            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.normal
            anchors.rightMargin: Appearance.padding.normal

            verticalAlignment: TextInput.AlignVCenter
            echoMode: entry.secret ? TextInput.Password : TextInput.Normal
            clip: true

            font.family: Appearance.font.family
            font.pixelSize: Appearance.font.size.small
            renderType: Text.NativeRendering
            color: Appearance.colour.text
            selectionColor: Appearance.colour.accent
            selectedTextColor: Appearance.colour.accentText

            KeyNavigation.tab: entry.next

            onAccepted: entry.entered()

            Keys.onEscapePressed: entry.escaped()

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: !box.text && !box.activeFocus
                text: entry.hint
                color: Appearance.colour.textFaint
                font.pixelSize: Appearance.font.size.small
            }
        }
    }

    Column {
        id: stack

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        Entry {
            id: identity

            width: parent.width
            hint: root.placeholder ? `username for ${root.placeholder}` : "username"
            next: password.input

            onEntered: root.submit()
            onEscaped: root.cancelled()
        }

        Entry {
            id: password

            width: parent.width
            hint: "password"
            secret: true

            onEntered: root.submit()
            onEscaped: root.cancelled()
        }

        Item {
            width: parent.width
            implicitHeight: pick.implicitHeight + Appearance.padding.small * 2

            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: Appearance.padding.normal
                anchors.verticalCenter: parent.verticalCenter

                text: "sign-in method"
                color: Appearance.colour.textFaint
            }

            Segments {
                id: pick

                anchors.right: parent.right
                anchors.rightMargin: Appearance.padding.normal
                anchors.verticalCenter: parent.verticalCenter

                options: root.methods
                current: root.method
                onPicked: i => root.method = i
            }
        }
    }
}
