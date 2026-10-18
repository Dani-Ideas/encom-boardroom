import QtQuick

// The login screen's system monitor: the tube (RAM / CPU / download / disk
// writes over the last 2.5 minutes) and the current readings below it.
// The tube is the C++ SystemTube when the EncomSystem plugin is built
// (TubeNative.qml), otherwise the slower Canvas version (TubeCanvas.qml).
Item {
    id: monitor

    property real pixelScale: 1   // the stage's scale, for the Canvas fallback
    property real reveal: 1       // fades the tube in

    readonly property var channels: [
        { key: "ram", label: "RAM", color: "#00eeee" },
        { key: "cpu", label: "CPU", color: "#ffcc00" },
        { key: "netDown", label: "NET", color: "#ffffff", rate: true },
        { key: "diskWrite", label: "DISK", color: "#ff5050", rate: true }
    ]
    readonly property var latest: tube.item ? tube.item.latest : null

    function formatRate(bytes) {
        return bytes >= 1e6 ? (bytes / 1e6).toFixed(1) + " MB/s" : Math.round(bytes / 1e3) + " KB/s";
    }

    Loader {
        id: tube
        width: parent.width
        height: parent.height - readout.height - 6
        source: "TubeNative.qml"
        onStatusChanged: {
            if (status === Loader.Error) {
                console.log("EncomSystem plugin not available, using the Canvas monitor");
                source = "TubeCanvas.qml";
            }
        }
        onLoaded: {
            item.pixelScale = Qt.binding(function () { return monitor.pixelScale });
            item.reveal = Qt.binding(function () { return monitor.reveal });
        }
    }

    Row {
        id: readout
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: 8
        spacing: 14
        Repeater {
            model: monitor.channels
            Text {
                required property var modelData
                text: {
                    var value = monitor.latest ? monitor.latest[modelData.key] : null;
                    var shown = value === null || value === undefined ? "--"
                              : modelData.rate ? monitor.formatRate(value) : Math.round(value) + "%";
                    return modelData.label + " " + shown;
                }
                color: modelData.color
                font.family: Theme.font
                font.pixelSize: 11
                font.letterSpacing: 1
            }
        }
        Text {
            visible: monitor.latest !== null && monitor.latest.example === true
            text: "(EXAMPLE)"
            color: "#666666"
            font.family: Theme.font
            font.pixelSize: 11
            font.letterSpacing: 1
        }
    }
}
