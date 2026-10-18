import QtQuick

// .lt-header: a thin double line with text on a black band at each end.
Item {
    id: bar
    property string leftText: ""    // StyledText
    property string rightText: ""   // StyledText

    height: 18

    Rectangle { width: parent.width; height: 1; color: Theme.headerLine }
    Rectangle { y: parent.height - 1; width: parent.width; height: 1; color: Theme.headerLine }

    Text {
        x: 3
        anchors.verticalCenter: parent.verticalCenter
        text: bar.leftText
        textFormat: Text.StyledText
        color: "white"
        font.family: Theme.font
        font.pixelSize: 11
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 3
        anchors.verticalCenter: parent.verticalCenter
        text: bar.rightText
        textFormat: Text.StyledText
        color: "white"
        font.family: Theme.font
        font.pixelSize: 11
    }
}
