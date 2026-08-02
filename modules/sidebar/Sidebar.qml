import QtQuick
import qs.config

// What the sidebar contains.
//
// No background of its own: the sidebar IS part of the chassis shape, drawn once
// by Chassis.qml. This is only the layout of what sits in that band.
//
// Two groups and one focal element. The groups get a quiet container so related
// controls read as one thing; the clock gets none, because it is the thing you
// actually look at.
Item {
    id: root

    // Forwarded up to the menu layer, which lives outside the sidebar because
    // the menus are not part of it.
    property alias status: status

    // Full width, unlike everything else in here: the workspace ruler is drawn
    // ON the screen's edge and reaches in from it, so it needs the whole band to
    // measure from rather than a centred column.
    Workspaces {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
    }

    Column {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Appearance.padding.normal
        anchors.horizontalCenter: parent.horizontalCenter

        spacing: Appearance.padding.large

        Clock {
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StatusIcons {
            id: status
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
