import QtQuick

// The on-screen keyboard (#lt-vkeyboard). Emits keyPressed with a character,
// or "ENTER" / "BACK" / "ESC". flash(key) lights a key for physical presses too.
Column {
    id: keyboard
    signal keyPressed(string key)

    readonly property var rows: [
        ["ESC", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "BACK"],
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L", "ENTER"],
        ["Z", "X", "C", "V", "B", "N", "M", ".", "_", "-"],
        ["SPACE"]
    ]
    property string flashed: ""

    function flash(key) {
        flashed = key.length === 1 ? key.toUpperCase() : key;
        flashTimer.restart();
    }

    spacing: 4

    Timer { id: flashTimer; interval: 150; onTriggered: keyboard.flashed = "" }

    Repeater {
        model: keyboard.rows
        Row {
            required property var modelData
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4

            Repeater {
                model: parent.modelData
                Rectangle {
                    id: key
                    required property string modelData
                    readonly property string symbol: modelData === "SPACE" ? " " : modelData
                    readonly property bool lit: mouse.containsMouse || keyboard.flashed === symbol

                    width: modelData === "SPACE" ? 300 : Math.max(30, label.implicitWidth + 20)
                    height: 24
                    radius: 2
                    color: lit ? "white" : "black"
                    border.width: 1
                    border.color: Theme.darkLine

                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: key.modelData
                        color: key.lit ? "black" : Theme.cyan
                        font.family: Theme.font
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // letters type lowercase
                        onPressed: keyboard.keyPressed(key.symbol.length === 1 ? key.symbol.toLowerCase() : key.symbol)
                    }
                }
            }
        }
    }
}
