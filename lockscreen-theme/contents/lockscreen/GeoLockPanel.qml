import QtQuick
// The native particle globe (copied here by install-lockscreen.sh from
// encom-globe/native); a local directory import, no QML_IMPORT_PATH needed.
import "encomglobe"
import "geolock.js" as GeoLock

// Pick the geo-lock sequence on the globe: a click (not a drag, that turns
// the globe) snaps to the nearest anchor and drops a pin there; after
// GeoLock.LENGTH places it emits `completed` with the secret string. Used by
// the lock screen (LockScreenUi.qml) and by the setup window (GeoLockSetup.qml).
Item {
    id: panel

    property bool acceptInput: true
    property var picks: []                  // anchor indices so far
    readonly property int length: GeoLock.LENGTH
    signal completed(string secret)

    function reset() {
        picks = [];
        globe.clearPins();
    }

    function undo() {
        if (!picks.length)
            return;
        var kept = picks.slice(0, -1);
        reset();
        kept.forEach(function (index) { place(index); });
    }

    function place(index) {
        var a = GeoLock.anchors()[index];
        picks = picks.concat([index]);
        globe.addPin(a.lat, a.lon, "");   // no number: someone could be watching
    }

    function pick(x, y) {
        if (!acceptInput || picks.length >= length)
            return;
        var p = globe.pickLatLon(x, y);
        if (!p)
            return;
        place(GeoLock.nearest(p.lat, p.lon).index);
        if (picks.length === length)
            finishTimer.start();
    }

    // let the last pin land before handing the sequence over
    Timer {
        id: finishTimer
        interval: 350
        onTriggered: panel.completed(GeoLock.token(panel.picks))
    }

    // slots: filled / next / empty
    Row {
        id: slots
        spacing: 8
        Repeater {
            model: panel.length
            Rectangle {
                required property int index
                readonly property bool filled: index < panel.picks.length
                readonly property bool next: index === panel.picks.length
                width: 26
                height: 26
                radius: 2
                color: "transparent"
                border.width: 1
                border.color: filled ? Theme.yellow : next ? Theme.cyan : Theme.darkLine
                Text {
                    anchors.centerIn: parent
                    text: parent.filled ? "●" : parent.index + 1
                    color: parent.border.color
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: slots.verticalCenter
        spacing: 8
        TronButton { text: "UNDO"; onClicked: panel.undo() }
        TronButton { text: "CLEAR"; onClicked: panel.reset() }
    }

    Rectangle {
        anchors.top: slots.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
        width: parent.width
        color: "black"
        border.color: Theme.darkLine
        border.width: 1
        clip: true

        ParticleGlobe {
            id: globe
            anchors.fill: parent
            anchors.margins: 1
            baseColor: "#c6c7f5"
            globeScale: 1.6
            introDuration: 1500
            startLongitude: -90
            tilt: 0.2
            dayLength: 600000         // a slow drift; picking stays easy
            hoverPull: 0              // no gravity well: it would move places under the cursor
            hoverTurbulence: 4
            initialPins: false
            maxPins: GeoLock.LENGTH
            maxMarkers: 0
            atmosphereParticles: 1200
            maxFps: 30

            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                text: panel.acceptInput ? "CLICK " + panel.length + " PLACES IN ORDER · DRAG TO TURN" : "VERIFYING ..."
                color: Theme.cyanDim
                font.family: Theme.font
                font.pixelSize: 11
                font.letterSpacing: 1
            }

            // a tap picks; the globe itself still turns on drags
            TapHandler {
                gesturePolicy: TapHandler.DragThreshold
                onTapped: function (eventPoint) {
                    panel.pick(eventPoint.position.x, eventPoint.position.y);
                }
            }
        }
    }
}
