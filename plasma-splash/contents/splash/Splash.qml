import QtQuick
import QtQuick.Effects

// Plasma splash screen: the "DANI-IDEAS" badge in the style of the boardroom's
// stream screen (#screensaver in css/global.css, shown by onSwitch in
// src/main.js): Terminator font in a thick rounded cyan frame with a pulsing
// glow, shrinking away with an ease-in-out-back when the desktop is ready.
// ksplashqml raises `stage` as Plasma starts; 5 means the desktop is up.
Rectangle {
    id: root
    color: "black"

    property int stage

    // The mockup's 30pt badge on its 800px-tall stage, scaled to this screen.
    readonly property real unit: height / 800

    FontLoader { id: terminator; source: "terminator.ttf" }

    onStageChanged: {
        if (stage >= 5)
            outro.start();
    }

    Item {
        id: badge
        anchors.centerIn: parent
        width: frame.width
        height: frame.height
        opacity: 0

        Rectangle {
            id: frame
            width: label.implicitWidth + 20 * root.unit + 2 * border.width
            height: label.implicitHeight + 2 * border.width
            radius: 12 * root.unit
            color: "transparent"
            border.color: "#6fc0ba"
            border.width: 6 * root.unit

            Text {
                id: label
                anchors.centerIn: parent
                text: "DANI-IDEAS"
                color: "#6fc0ba"
                font.family: terminator.name
                font.pixelSize: 40 * root.unit
            }
        }

        // box-shadow / text-shadow pulsing between 10px #333 and 20px #ccc
        layer.enabled: true
        layer.effect: MultiEffect {
            id: glow
            shadowEnabled: true
            shadowColor: "#cccccc"
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            autoPaddingEnabled: true
            shadowBlur: 0.4
            shadowOpacity: 0.5

            SequentialAnimation on shadowBlur {
                loops: Animation.Infinite
                NumberAnimation { from: 0.4; to: 0.9; duration: 1000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.9; to: 0.4; duration: 1000; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on shadowOpacity {
                loops: Animation.Infinite
                NumberAnimation { from: 0.5; to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.0; to: 0.5; duration: 1000; easing.type: Easing.InOutSine }
            }
        }

        NumberAnimation on opacity {
            id: intro
            from: 0
            to: 1
            duration: 400
        }

        // onSwitch's exit: scale follows opacity, 600 ms, easeInOutBack
        ParallelAnimation {
            id: outro
            NumberAnimation { target: badge; property: "opacity"; to: 0; duration: 600; easing.type: Easing.InOutBack }
            NumberAnimation { target: badge; property: "scale"; to: 0; duration: 600; easing.type: Easing.InOutBack }
        }
    }

    // a quiet progress line under the badge: one segment per startup stage
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: badge.bottom
        anchors.topMargin: 30 * root.unit
        spacing: 6 * root.unit
        opacity: badge.opacity

        Repeater {
            model: 5
            Rectangle {
                required property int index
                width: 26 * root.unit
                height: 4 * root.unit
                radius: 2 * root.unit
                color: root.stage > index ? "#6fc0ba" : "transparent"
                border.width: 1
                border.color: "#1b2f2d"
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
    }
}
