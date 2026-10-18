import QtQuick

// The login terminal (port of src/LoginTerminal.js). Asks for a login and a
// password like a Unix console and hands them to SDDM; SDDM's answer comes
// back through loginFailed / loginSucceeded. Too many failures lock it for
// lockSeconds. Feed keys with input(): a character, "ENTER", "BACK" or "ESC".
//
// With `debug` on (preview only, see theme.conf) the password is shown as it
// will be sent, and debugLine (the last key event) is printed under the prompt.
Item {
    id: terminal

    property string hostName: "llvm992"
    property int sessionIndex: 0
    property int maxAttempts: 3
    property int lockSeconds: 30
    // A real login answers wrong passwords after a pause; this keeps the
    // "verifying" line up at least this long either way.
    property int minVerifyMs: 1200
    property bool debug: false
    property string debugLine: ""

    signal keyTyped(string key)   // for the virtual keyboard's flash

    // ("state" is taken by Item)
    property string state_: "idle"  // login | password | busy | locked | done
    property string username: ""
    property string password: ""
    property int attempts: 0
    property int lockRemaining: 0
    property double verifyStarted: 0

    readonly property bool prompting: state_ === "login" || state_ === "password"
    readonly property string promptText: state_ === "password" ? "Password:" : "encom-os12 login:"

    function write(html, kind) {
        lines.append({ html: html, kind: kind || "response" });
    }

    // Freeze the current input line into the scrollback.
    function commitPrompt(shown) {
        write(promptText + "&nbsp;" + "<font color='#aaaaaa'>" + escapeHtml(shown) + "</font>", "command");
    }

    function escapeHtml(text) {
        return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    function start() {
        lines.clear();
        attempts = 0;
        askLogin();
    }

    function askLogin() {
        username = "";
        password = "";
        state_ = "login";
    }

    function verify() {
        state_ = "busy";
        write("&gt;&gt;encom-sh: verifying credentials ...");
        verifyStarted = Date.now();
        sddm.login(username, password, sessionIndex);
    }

    // SDDM's answers, held until minVerifyMs has passed.
    function answer(ok) {
        if (state_ !== "busy")
            return;
        answerTimer.ok = ok;
        answerTimer.interval = Math.max(1, minVerifyMs - (Date.now() - verifyStarted));
        answerTimer.start();
    }

    function granted() {
        state_ = "done";
        write("<font color='#ffcc00'>ACCESS GRANTED.</font> Welcome, <font color='#ffcc00'><b>" + escapeHtml(username) + "</b></font>");
        write("&gt;&gt;encom-sh: starting session ...");
    }

    function denied() {
        attempts++;
        write("<font color='#e31b1b'>ACCESS DENIED.</font> Login incorrect");
        if (attempts >= maxAttempts) {
            state_ = "locked";
            write("<font color='#e31b1b'>Maximum number of tries exceeded (" + maxAttempts + ")</font>");
            lockRemaining = lockSeconds;
            write("Terminal locked for " + lockRemaining + " s", "lock");
            lockTimer.start();
        } else {
            var left = maxAttempts - attempts;
            write(left + " attempt" + (left === 1 ? "" : "s") + " remaining");
            askLogin();
        }
    }

    function switchUser() {
        if (!prompting)
            return;
        lines.clear();
        write("&gt;&gt;encom-sh: session closed. Switching user ...");
        attempts = 0;
        askLogin();
    }

    function input(key) {
        if (!prompting)
            return;
        keyTyped(key);

        if (key === "ENTER") {
            if (state_ === "login") {
                commitPrompt(username);
                if (username.length > 0)
                    state_ = "password";   // an empty login just asks again
            } else {
                commitPrompt("");
                if (debug)
                    write("<font color='#feb400'>[DEBUG] sddm.login(" + escapeHtml(JSON.stringify(username)) + ", "
                          + escapeHtml(JSON.stringify(password)) + ", " + sessionIndex + ")</font>");
                verify();
            }
        } else if (key === "ESC") {
            commitPrompt(state_ === "login" ? username + "^C" : "^C");
            askLogin();
        } else if (key === "BACK") {
            if (state_ === "login")
                username = username.slice(0, -1);
            else
                password = password.slice(0, -1);
        } else if (key.length === 1) {
            if (state_ === "login")
                username += key;
            else
                password += key;   // not echoed, like a real password prompt
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() { terminal.answer(false) }
        function onLoginSucceeded() { terminal.answer(true) }
    }

    Timer {
        id: answerTimer
        property bool ok: false
        onTriggered: ok ? terminal.granted() : terminal.denied()
    }

    Timer {
        id: lockTimer
        interval: 1000
        repeat: true
        onTriggered: {
            terminal.lockRemaining--;
            // rewrite the countdown line in place
            for (var i = lines.count - 1; i >= 0; i--) {
                if (lines.get(i).kind === "lock") {
                    lines.setProperty(i, "html", "Terminal locked for " + terminal.lockRemaining + " s");
                    break;
                }
            }
            if (terminal.lockRemaining <= 0) {
                stop();
                terminal.attempts = 0;
                terminal.write("Terminal unlocked");
                terminal.askLogin();
            }
        }
    }

    ListModel { id: lines }

    // "Last Login: ..." with the dashed rule under it
    Text {
        id: header
        width: parent.width
        text: "Last Login: Wed Nov 26 11:26:49 on " + terminal.hostName
        color: "white"
        font.family: Theme.font
        font.pixelSize: 11
    }
    Row {
        id: dashes
        anchors.top: header.bottom
        anchors.topMargin: 3
        spacing: 3
        Repeater {
            model: Math.max(0, Math.floor(terminal.width / 7))
            Rectangle { width: 4; height: 1; color: "white" }
        }
    }

    ListView {
        id: view
        anchors.top: dashes.bottom
        anchors.topMargin: 6
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        interactive: false
        model: lines
        spacing: 3
        onCountChanged: Qt.callLater(positionViewAtEnd)

        delegate: Text {
            required property string html
            required property string kind
            x: kind === "command" ? 0 : 25
            width: view.width - x
            text: html
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            color: "white"
            font.family: Theme.font
            font.pixelSize: kind === "command" ? 13 : 11
        }

        // the live input line (and, in debug mode, the last key event)
        footer: Column {
            width: view.width
            topPadding: 3
            spacing: 3

            Row {
                visible: terminal.prompting
                height: terminal.prompting ? implicitHeight : 0
                Text {
                    text: terminal.promptText
                    color: "white"
                    font.family: Theme.font
                    font.pixelSize: 13
                }
                Text {
                    text: "\u00a0" + (terminal.state_ === "login" ? terminal.username : "")
                    color: "#aaaaaa"
                    font.family: Theme.font
                    font.pixelSize: 13
                }
                Text {
                    // what SDDM will receive; only in debug mode
                    visible: terminal.debug && terminal.state_ === "password"
                    text: JSON.stringify(terminal.password)
                    color: Theme.orange
                    font.family: Theme.font
                    font.pixelSize: 13
                }
                Rectangle {
                    width: 8
                    height: 15
                    color: Theme.cyan
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        PropertyAction { value: 1 }
                        PauseAnimation { duration: 500 }
                        PropertyAction { value: 0 }
                        PauseAnimation { duration: 500 }
                    }
                }
            }

            Text {
                visible: terminal.debug && terminal.debugLine !== ""
                width: parent.width
                text: "[DEBUG] " + terminal.debugLine
                wrapMode: Text.WrapAnywhere
                color: Theme.orange
                font.family: Theme.font
                font.pixelSize: 11
            }
        }
    }
}
