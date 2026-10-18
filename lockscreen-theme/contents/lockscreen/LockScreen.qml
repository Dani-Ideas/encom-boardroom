import QtQuick

// Entry point kscreenlocker loads (the package's "lockscreenmainscript").
// Everything visible is in LockScreenUi.qml.
// A FocusScope so the keyboard always reaches LockScreenUi, whichever item
// kscreenlocker gives the focus to.
FocusScope {
    id: root
    focus: true

    // These are magical properties that kscreenlocker looks for
    // (same as Plasma's own LockScreen.qml)
    property bool viewVisible: false
    property bool debug: false
    property string notification
    signal clearPassword()
    signal notificationRepeated()

    implicitWidth: 800
    implicitHeight: 600

    LockScreenUi {
        anchors.fill: parent
        focus: true
    }
}
