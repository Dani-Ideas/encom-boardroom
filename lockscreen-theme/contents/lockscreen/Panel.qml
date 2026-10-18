import QtQuick

// .content-container from the web mockup: a 2px cyan border, 3px padding, an
// inner 1px dark border and an h2 title bar with an <em> on the right.
// Children go below the title. `reveal` (0..1) grows it from its centre like
// showContentBoxes() does.
Item {
    id: panel

    property string title: ""        // StyledText, e.g. "SYSTEM MONITOR <font color='#00eeee'>.GENERAL</font>"
    property string titleRight: ""   // StyledText
    property real reveal: 1
    property bool contentVisible: true
    default property alias content: body.data

    readonly property int titleHeight: 24

    Rectangle {
        anchors.centerIn: parent
        width: parent.width * panel.reveal
        height: parent.height * panel.reveal
        visible: panel.reveal > 0
        color: "black"
        border.color: Theme.cyanDim
        border.width: 2
        radius: 2

        Rectangle {
            id: inner
            anchors.fill: parent
            anchors.margins: 5
            color: "transparent"
            border.color: Theme.darkLine
            border.width: 1

            Item {
                visible: panel.contentVisible
                anchors.fill: parent

                Text {
                    x: 4
                    height: panel.titleHeight
                    verticalAlignment: Text.AlignVCenter
                    text: panel.title
                    textFormat: Text.StyledText
                    color: "white"
                    font.family: Theme.font
                    font.pixelSize: 16
                    font.bold: true
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    height: panel.titleHeight
                    verticalAlignment: Text.AlignVCenter
                    text: panel.titleRight
                    textFormat: Text.StyledText
                    color: Theme.cyan
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.bold: true
                }
                Rectangle {
                    y: panel.titleHeight
                    width: parent.width
                    height: 1
                    color: Theme.darkLine
                }

                Item {
                    id: body
                    anchors.fill: parent
                    anchors.topMargin: panel.titleHeight + 1
                }
            }
        }
    }
}
