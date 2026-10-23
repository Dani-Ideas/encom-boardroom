import QtQuick

// The lock screen's terminal: a copy of the SDDM theme's Terminal.qml, kept
// separate so the two can change independently. The session's user is fixed
// (userName), so it only asks for the password and hands it to kscreenlocker's
// `authenticator` (PAM, like the stock lock screen); the answer comes back
// through its failed / succeeded signals, and a correct password unlocks.
// Feed keys with input(): a character, "ENTER", "BACK" or "ESC".
//
// Every failed PAM attempt counts towards pam_faillock, which on Manjaro locks
// the account for 10 minutes after 3 in a row. So, like Plasma's own lock
// screen, this only starts a PAM conversation when you start typing (a lock
// screen that opens and closes untouched counts nothing), never restarts one
// that is still open, waits 3 s after a failure before the next, and prints
// PAM's own messages (such as "account locked") instead of guessing.
//
// With `debug` on the password is shown as it will be sent, and debugLine
// (the last key event) is printed under the prompt. Never leave it on.
Item {
    id: terminal

    property string hostName: "llvm992"
    property string userName: ""
    // pam_faillock's "deny" (/etc/security/faillock.conf, 3 by default), for the warning
    property int systemDeny: 3
    // A real login answers wrong passwords after a pause; this keeps the
    // "verifying" line up at least this long either way.
    property int minVerifyMs: 1200
    property bool debug: false
    property string debugLine: ""

    signal keyTyped(string key)   // for the virtual keyboard's flash
    signal switchUserRequested()
    signal attemptFinished(bool ok)   // after each password or geo-lock attempt

    // ("state" is taken by Item)
    property string state_: "idle"  // password | busy | done
    property string username: ""
    property string password: ""
    property int failures: 0          // in a row, since the lock screen opened
    property double verifyStarted: 0
    property bool authStarted: false      // a PAM conversation is open
    property bool secretRequested: false  // PAM asked for the password
    property bool waitingForPrompt: false // Enter came before PAM asked

    readonly property bool prompting: state_ === "password"
    readonly property string promptText: "Password:"

    function write(html, kind) {
        lines.append({ html: html, kind: kind || "response" });
    }

    // Freeze the current input line into the scrollback.
    function commitPrompt(shown) {
        write(promptText + "&nbsp;" + "<font color='#aaaaaa'>" + escapeHtml(shown) + "</font>", "command");
    }

    function escapeHtml(text) {
        return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    function start() {
        lines.clear();
        failures = 0;
        username = userName;
        write("&gt;&gt;encom-sh: session locked");
        write("encom-os12 login:&nbsp;<font color='#aaaaaa'>" + escapeHtml(userName) + "</font>", "command");
        password = "";
        state_ = "password";
    }

    // Opens a PAM conversation if none is open (on the first key, like Plasma).
    function ensureAuthenticating() {
        if (authStarted)
            return;
        authStarted = true;
        secretRequested = false;
        authenticator.startAuthenticating();
    }

    // A geo-lock sequence goes to PAM the same way as a typed password.
    // Returns false when an attempt can't be made right now.
    function submitSecret(secret) {
        if (!prompting)
            return false;
        ensureAuthenticating();
        write("&gt;&gt;encom-sh: geo-lock sequence submitted");
        password = secret;
        if (debug)
            write("<font color='#feb400'>[DEBUG] authenticator.respond(" + escapeHtml(JSON.stringify(password)) + ")</font>");
        verify();
        return true;
    }

    function verify() {
        state_ = "busy";
        write("&gt;&gt;encom-sh: verifying credentials ...");
        verifyStarted = Date.now();
        if (secretRequested) {
            respond();
        } else {
            // PAM hasn't asked yet; answer as soon as it does
            waitingForPrompt = true;
            promptWait.start();
        }
    }

    function respond() {
        waitingForPrompt = false;
        promptWait.stop();
        secretRequested = false;
        authenticator.respond(password);
        watchdog.start();
    }

    // The authenticator's answers, held until minVerifyMs has passed.
    function answer(ok) {
        if (state_ !== "busy")
            return;
        watchdog.stop();
        answerTimer.ok = ok;
        answerTimer.interval = Math.max(1, minVerifyMs - (Date.now() - verifyStarted));
        answerTimer.start();
    }

    function granted() {
        state_ = "done";
        write("<font color='#ffcc00'>ACCESS GRANTED.</font> Welcome back, <font color='#ffcc00'><b>" + escapeHtml(username) + "</b></font>");
        write("&gt;&gt;encom-sh: unlocking session ...");
        attemptFinished(true);
        quitTimer.start();
    }

    function denied() {
        failures++;
        authStarted = false;   // this conversation is over
        write("<font color='#e31b1b'>ACCESS DENIED.</font> Login incorrect");
        if (failures === systemDeny - 1)
            write("<font color='#feb400'>Warning: one more failure locks this account for 10 minutes</font>");
        attemptFinished(false);
        retryLater();
    }

    // Plasma's lock screen waits 3 s before the next attempt; so do we.
    function retryLater() {
        state_ = "busy";
        password = "";
        grace.start();
    }

    // Another user logs in from SDDM; this session stays locked behind it.
    function switchUser() {
        if (!prompting)
            return;
        write("&gt;&gt;encom-sh: switching user ...");
        switchUserRequested();
    }

    function input(key) {
        if (!prompting)
            return;
        keyTyped(key);
        ensureAuthenticating();

        if (key === "ENTER") {
            commitPrompt("");
            if (password.length === 0)
                return;   // an empty password would only count as a failure
            if (debug)
                write("<font color='#feb400'>[DEBUG] authenticator.respond(" + escapeHtml(JSON.stringify(password)) + ")</font>");
            verify();
        } else if (key === "ESC") {
            // just clear what was typed; restarting PAM could count as a failure
            commitPrompt("^C");
            password = "";
        } else if (key === "BACK") {
            password = password.slice(0, -1);
        } else if (key.length === 1) {
            password += key;   // not echoed, like a real password prompt
        }
    }

    Connections {
        target: authenticator
        // kind 0 is the password; others are fingerprint/smartcard attempts
        function onFailed(kind) {
            if (kind !== 0)
                return;
            if (terminal.state_ === "busy")
                terminal.answer(false);
            else
                terminal.authStarted = false;   // a conversation ended on its own
        }
        function onSucceeded() {
            // without a password prompt (no password, or another authenticator) just unlock
            if (terminal.state_ === "busy")
                terminal.answer(true);
            else
                Qt.quit();
        }
        function onPromptForSecretChanged() {
            terminal.secretRequested = true;
            if (terminal.waitingForPrompt)
                terminal.respond();
        }
        // PAM's own words, e.g. why the account is locked
        function onInfoMessageChanged() {
            if (authenticator.infoMessage)
                terminal.write("&gt;&gt;pam: " + terminal.escapeHtml(authenticator.infoMessage));
        }
        function onErrorMessageChanged() {
            if (authenticator.errorMessage)
                terminal.write("<font color='#e31b1b'>&gt;&gt;pam: " + terminal.escapeHtml(authenticator.errorMessage) + "</font>");
        }
        function onPromptChanged() {
            if (authenticator.prompt && authenticator.prompt !== "Password: " && authenticator.prompt !== "Password:")
                terminal.write("&gt;&gt;pam: " + terminal.escapeHtml(authenticator.prompt));
        }
    }

    // If PAM never asks for the password, send it anyway after a moment.
    Timer {
        id: promptWait
        interval: 2000
        onTriggered: terminal.respond()
    }

    // Never sit on "verifying" forever.
    Timer {
        id: watchdog
        interval: 15000
        onTriggered: {
            terminal.write("<font color='#e31b1b'>&gt;&gt;encom-sh: no answer from the authenticator, retrying</font>");
            terminal.authStarted = false;
            terminal.retryLater();
        }
    }

    Timer {
        id: grace
        interval: 3000
        onTriggered: terminal.state_ = "password"
    }

    // kscreenlocker unlocks when the greeter quits; give "ACCESS GRANTED" a moment.
    Timer {
        id: quitTimer
        interval: 700
        onTriggered: Qt.quit()
    }

    Timer {
        id: answerTimer
        property bool ok: false
        onTriggered: ok ? terminal.granted() : terminal.denied()
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
