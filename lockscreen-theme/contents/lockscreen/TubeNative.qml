import QtQuick
// Local directory import: loads the plugin listed in EncomSystem/qmldir
// (built by native/build.sh), no QML_IMPORT_PATH needed.
import "EncomSystem"

// The monitor's tube drawn by the C++ SystemTube (native/src/systemtubeitem.*).
SystemTube {
    property real pixelScale: 1   // unused: the scene graph draws at screen resolution
    clip: true
}
