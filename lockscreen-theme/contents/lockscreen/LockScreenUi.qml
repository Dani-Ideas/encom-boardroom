import QtQuick
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.plasma.private.sessions

// Encom Boardroom lock screen: a copy of the SDDM theme's Main.qml
// (sddm-theme/), kept separate so the two can change independently. It looks
// the same; the terminal (LockTerminal.qml) only asks for this session's
// password and unlocks through kscreenlocker. The layout is the mockup's
// large-screen one, a 1580x800 stage scaled to fit.
Rectangle {
    id: root

    width: 1920
    height: 1080
    color: "black"

    readonly property real stageScale: Math.min(width / stage.width, height / stage.height)

    // Intro timeline in ms, like LightTable.show(): the frame first, headers at
    // 1.5 s, panels growing from their centre right after, contents at 2.2 s.
    property real t: 0
    NumberAnimation on t { from: 0; to: 3000; duration: 3000 }

    function ramp(from, duration) {
        return Math.max(0, Math.min(1, (t - from) / duration));
    }

    property bool sleeping: false
    property bool geoMode: false   // the GEO-LOCK panel is showing
    property bool geoUsed: false   // it was opened once (then it stays loaded)

    // Shows the password and each key event in the terminal. Only for trying
    // changes with ./install-lockscreen.sh test; never leave it on.
    property bool debugInput: false

    KeyTranslator { id: translator }

    // Plasma knows the real lock states here (SDDM's greeter doesn't always)
    KeyboardIndicator.KeyState {
        id: capsState
        key: Qt.Key_CapsLock
        onLockedChanged: translator.capsLock = locked
        Component.onCompleted: translator.capsLock = locked
    }
    KeyboardIndicator.KeyState {
        id: numState
        key: Qt.Key_NumLock
        onLockedChanged: translator.numLock = locked
        Component.onCompleted: translator.numLock = locked
    }

    SessionManagement { id: sessionManagement }

    function key(k) {
        if (sleeping) {
            sleeping = false;
            return;
        }
        terminal.input(k);
    }

    focus: true
    Component.onCompleted: forceActiveFocus()
    Keys.onPressed: function (event) {
        var keys = translator.translate(event);
        terminal.debugLine = translator.lastEvent;
        for (var i = 0; i < keys.length; i++)
            root.key(keys[i]);
        event.accepted = true;
    }

    // A Caps Lock / Num Lock lamp: lit when on, outlined when off, "?" until known.
    component LockLamp: Rectangle {
        property string label
        property var on: null
        implicitWidth: lampText.implicitWidth + 16
        implicitHeight: 18
        radius: 2
        color: on === true ? Theme.yellow : "black"
        border.width: 1
        border.color: on === true ? Theme.yellow : Theme.darkLine
        Text {
            id: lampText
            anchors.centerIn: parent
            text: parent.label + (parent.on === null ? " ?" : parent.on ? " ON" : " OFF")
            color: parent.on === true ? "black" : Theme.cyanDim
            font.family: Theme.font
            font.pixelSize: 11
            font.letterSpacing: 1
        }
    }

    Item {
        id: stage
        width: 1580
        height: 800
        anchors.centerIn: parent
        scale: root.stageScale

        // #lt-container-outside / -inside: two concentric rounded frames
        Rectangle {
            anchors.centerIn: parent
            width: 1544
            height: 764
            radius: 5
            color: "transparent"
            border.color: Theme.cyanDim
            border.width: 2
            opacity: root.ramp(0, 1000)
        }
        Rectangle {
            id: inside
            anchors.centerIn: parent
            width: 1504
            height: 754
            radius: 5
            color: "transparent"
            border.color: Theme.cyanDim
            border.width: 2
            opacity: root.ramp(300, 800)

            // the two merged columns (#lt-main-column)
            Item {
                x: 54
                y: 2
                width: 1328
                height: 750

                HeaderBar {
                    y: 25
                    width: parent.width
                    visible: root.t >= 1500
                    leftText: "Plymouth LOGIN TERMINAL APP <font color='#00eeee'>OS</font><font color='#ffcc00'>26.1.2</font> ... MANJARO ... <font color='#00eeee'>LAUNCH LINUX GLOBALIZATION</font>"
                    rightText: "OIA | 012"
                }

                Panel {
                    id: loginPanel
                    y: 60
                    width: parent.width
                    height: 398
                    reveal: root.ramp(1700, 500)
                    contentVisible: root.t >= 2200
                    title: "DANI-IDEAS OS12 ... SECURE LOGIN <font color='#00eeee'>.SESSION</font>"
                    titleRight: "END. PROGRAM"

                    LockTerminal {
                        id: terminal
                        x: 10
                        y: 20
                        width: parent.width * 0.48
                        height: 300
                        userName: kscreenlocker_userName
                        onSwitchUserRequested: sessionManagement.switchUser()
                        debug: root.debugInput
                        onKeyTyped: function (k) { keyboard.flash(k) }
                        Component.onCompleted: start()
                    }

                    // lock lamps and warnings, under the terminal
                    Row {
                        x: 10
                        y: parent.height - height - 8
                        spacing: 10

                        LockLamp { label: "CAPS LOCK"; on: translator.capsLock }
                        LockLamp { label: "NUM LOCK"; on: translator.numLock }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: translator.capsLock === true
                            text: "\u26a0 CAPS LOCK IS ON" + (terminal.state_ === "password" ? ": THE PASSWORD WILL BE TYPED IN CAPITALS" : "")
                            color: Theme.yellow
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.letterSpacing: 1
                            SequentialAnimation on opacity {
                                running: translator.capsLock === true
                                loops: Animation.Infinite
                                NumberAnimation { from: 1; to: 0.35; duration: 600 }
                                NumberAnimation { from: 0.35; to: 1; duration: 600 }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: translator.numLock === false && translator.capsLock !== true
                            text: "NUM LOCK IS OFF: THE NUMERIC KEYPAD WON'T TYPE DIGITS"
                            color: Theme.cyanDim
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.letterSpacing: 1
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.debugInput
                            text: "[DEBUG MODE: PASSWORD VISIBLE]"
                            color: Theme.orange
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.letterSpacing: 1
                        }
                    }

                    Column {
                        id: sideColumn
                        x: parent.width * 0.54 - 12
                        y: 27
                        width: parent.width * 0.46
                        spacing: 14

                        Row {
                            id: buttonRow
                            spacing: 10
                            TronButton {
                                text: "KEYBOARD"
                                active: keyboard.visible
                                onClicked: {
                                    keyboard.visible = !keyboard.visible;
                                    root.geoMode = false;
                                }
                            }
                            TronButton {
                                text: "SLEEP"
                                onClicked: root.sleeping = true
                            }
                            TronButton {
                                text: "SWITCH USER"
                                onClicked: terminal.switchUser()
                            }
                            TronButton {
                                text: "GEO-LOCK"
                                active: root.geoMode
                                onClicked: {
                                    root.geoMode = !root.geoMode;
                                    root.geoUsed = true;
                                    keyboard.visible = false;
                                }
                            }
                        }

                        // The second way to unlock: the place sequence on the globe
                        // (GeoLockPanel.qml). Loaded the first time it's opened, and
                        // in a Loader so a problem with the globe plugin can't take
                        // the password prompt down with it.
                        Loader {
                            id: geoLock
                            width: parent.width
                            height: sideColumn.parent.height - sideColumn.y - buttonRow.height - sideColumn.spacing - 10
                            visible: root.geoMode
                            active: root.geoUsed
                            source: "GeoLockPanel.qml"
                            onStatusChanged: {
                                if (status === Loader.Error)
                                    terminal.write("<font color='#e31b1b'>&gt;&gt;encom-sh: geo-lock unavailable, use the password</font>");
                            }
                            Binding {
                                target: geoLock.item
                                property: "acceptInput"
                                value: terminal.prompting
                                when: geoLock.item !== null
                            }
                            Connections {
                                target: geoLock.item
                                function onCompleted(secret) {
                                    if (!terminal.submitSecret(secret))
                                        geoLock.item.reset();
                                }
                            }
                            Connections {
                                target: terminal
                                function onAttemptFinished(ok) {
                                    if (geoLock.item && !ok)
                                        geoLock.item.reset();
                                }
                            }
                        }

                        VirtualKeyboard {
                            id: keyboard
                            visible: false
                            width: parent.width
                            onKeyPressed: function (k) { root.key(k) }
                        }
                    }
                }

                Panel {
                    y: 490
                    width: parent.width
                    height: 188
                    reveal: root.ramp(1600, 500)
                    contentVisible: root.t >= 2200
                    title: "SYSTEM MONITOR <font color='#00eeee'>.GENERAL</font>"
                    titleRight: "DATALINK: <font color='#00aa00'>CONNECTED. 1 USER</font>"

                    SystemMonitor {
                        anchors.fill: parent
                        anchors.bottomMargin: 6
                        pixelScale: root.stageScale
                        reveal: root.ramp(2500, 3000)
                    }
                }

                // footer: "DOCKING CHANNEL" and three small boxes
                HeaderBar {
                    y: 700
                    width: parent.width
                    visible: root.t >= 1500
                    leftText: "DOCKING CHANNEL"

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        layoutDirection: Qt.RightToLeft
                        Rectangle { width: 35; height: 6; radius: 2; color: "transparent"; border.color: Theme.cyanDim }
                        Rectangle { width: 30; height: 6; radius: 2; color: "transparent"; border.color: Theme.darkLine }
                        Rectangle { width: 35; height: 6; radius: 2; color: "transparent"; border.color: Theme.cyanDim }
                    }
                }
            }

            // #lt-far-right-column: logo and pulsing thumbprint
            Item {
                x: 1402
                y: 2
                width: 80
                height: 700

                Rectangle {
                    x: 20
                    y: 35
                    width: logo.width + 6
                    height: logo.implicitHeight + 4
                    radius: 4
                    color: "transparent"
                    border.color: Theme.cyanDim
                    border.width: 2
                    visible: root.t >= 1500
                    // open on the right, like the CSS (no border-right)
                    Rectangle { anchors.right: parent.right; y: 4; width: 3; height: parent.height - 8; color: "black" }
                    Text {
                        id: logo
                        x: 4
                        y: 2
                        // two lines, like the narrow column wraps it in the mockup
                        text: "Dani-\nIdeas"
                        color: Theme.cyanDim
                        font.family: Theme.terminator.name
                        font.pixelSize: 11
                    }
                }

                Image {
                    x: 15
                    y: 630
                    source: "thumbprint.png"
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.3; to: 1; duration: 2500; easing.type: Easing.OutQuad }
                        NumberAnimation { from: 1; to: 0.3; duration: 2500; easing.type: Easing.OutQuad }
                    }
                }
            }
        }
    }

    // sleep mode: covers everything until a key or click
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.sleeping ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.sleeping ? 800 : 500 } }

        Column {
            anchors.centerIn: parent
            spacing: 16
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "ENCOM <font color='#00eeee'>OS</font><font color='#ffcc00'>12</font> ... SLEEP MODE"
                textFormat: Text.StyledText
                color: "white"
                font.family: Theme.font
                font.pixelSize: 26
                font.letterSpacing: 6
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "PRESS ANY KEY OR CLICK TO WAKE"
                color: Theme.cyanDim
                font.family: Theme.font
                font.pixelSize: 13
                font.letterSpacing: 3
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.3; to: 1; duration: 2500 }
                    NumberAnimation { from: 1; to: 0.3; duration: 2500 }
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.sleeping
            onClicked: root.sleeping = false
        }
    }
}
