import QtQuick

// .lt-button: cyan outline; orange on hover, filled cyan when active.
Rectangle {
    id: button
    property string text: ""
    property bool active: false
    signal clicked()

    implicitWidth: label.implicitWidth + 28
    implicitHeight: label.implicitHeight + 8
    radius: 2
    color: active ? Theme.cyan : mouse.containsMouse ? Theme.orange : "black"
    border.width: 1
    border.color: active ? Theme.cyan : mouse.containsMouse ? Theme.orange : Theme.cyanDim

    Text {
        id: label
        anchors.centerIn: parent
        text: button.text
        color: button.active || mouse.containsMouse ? "black" : Theme.cyan
        font.family: Theme.font
        font.pixelSize: 13
        font.letterSpacing: 1
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
