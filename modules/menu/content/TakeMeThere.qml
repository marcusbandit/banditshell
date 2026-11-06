import QtQuick
import Quickshell
import qs.components

Button {
    id: root

    property var go: []

    visible: root.go.length > 0
    text: "Take me there"
    icon: "arrow_forward"
    style: "ring"

    onClicked: {
        const win = QsWindow.window;
        win?.whatsNew?.hide();
        win?.menus?.hide();
        Quickshell.execDetached([`${Quickshell.shellDir}/cli/banditshell`, ...root.go]);
    }
}
