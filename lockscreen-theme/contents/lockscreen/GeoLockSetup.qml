import QtQuick
import QtQuick.Window

// Window to record the geo-lock sequence; run by install-geolock.sh, never by
// the lock screen. It asks for the places twice and, when both match, prints
//   GEOLOCK-SECRET <secret>
// for the script to hash, and quits. With "--verify" as the last argument it
// asks once and prints the secret, so the script can check it against the
// saved hash without going through PAM.
Window {
    id: win
    width: 1100
    height: 720
    visible: true
    color: "black"
    title: "Encom geo-lock setup"

    readonly property bool verifyOnly: Qt.application.arguments[Qt.application.arguments.length - 1] === "--verify"
    property string first: ""

    function say(text, color) {
        message.text = text;
        message.color = color || "white";
    }

    Text {
        x: 24
        y: 18
        text: "DANI-IDEAS OS12 ... GEO-LOCK <font color='#00eeee'>" + (win.verifyOnly ? ".VERIFY" : ".SETUP") + "</font>"
        textFormat: Text.StyledText
        color: "white"
        font.family: Theme.font
        font.pixelSize: 18
        font.bold: true
    }

    Text {
        id: message
        x: 24
        y: 50
        width: parent.width - 48
        wrapMode: Text.Wrap
        color: "white"
        font.family: Theme.font
        font.pixelSize: 14
        text: win.verifyOnly ? "Pick your sequence to check it against the saved one."
                             : "Pick 6 places in order. Each click snaps to the nearest fixed point; remember where your pins land."
    }

    GeoLockPanel {
        id: panel
        x: 24
        y: 90
        width: parent.width - 48
        height: parent.height - 114

        onCompleted: function (secret) {
            if (win.verifyOnly) {
                console.log("GEOLOCK-SECRET " + secret);
                Qt.quit();
            } else if (win.first === "") {
                win.first = secret;
                win.say("Now pick the same 6 places again to confirm.", Theme.cyan);
                panel.reset();
            } else if (secret === win.first) {
                win.say("Sequence confirmed. Saving ...", Theme.yellow);
                console.log("GEOLOCK-SECRET " + secret);
                quitTimer.start();
            } else {
                win.first = "";
                win.say("The two sequences don't match. Start again: pick 6 places.", Theme.red);
                panel.reset();
            }
        }
    }

    Timer { id: quitTimer; interval: 800; onTriggered: Qt.quit() }
}
