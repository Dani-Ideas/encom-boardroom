pragma Singleton
import QtQuick

// Colors and fonts from the web mockup's CSS (css/light-table-styles.css).
QtObject {
    readonly property color cyan: "#00eeee"       // .alt-1, links, buttons
    readonly property color cyanDim: "#6fc0ba"    // .container-border
    readonly property color yellow: "#ffcc00"     // .alt-2, strong
    readonly property color orange: "#feb400"     // hover
    readonly property color red: "#e31b1b"        // .alert
    readonly property color darkLine: "#1b2f2d"   // .content borders
    readonly property color headerLine: "#1d2c33" // .lt-header borders
    readonly property string font: "Inconsolata"

    readonly property FontLoader terminator: FontLoader { source: "terminator.ttf" }
}
