import QtQuick

// Turns key events into what the terminal types, the way a text field would:
//  - dead keys compose with the next key (´ + a = á, ¨ + u = ü, ...); there
//    is no text field here, so nothing else would combine them
//  - AltGr characters (@ # € ... on a Spanish layout) are kept even when the
//    platform reports AltGr as Ctrl+Alt
// It also tracks Caps Lock and Num Lock. SDDM's keyboard model gives the
// starting state and any change it reports, but under some display servers it
// reports a fixed value, so the keys themselves always have the last word:
// a letter's case against Shift, the lock keys, keypad digits. Unknown is null.
QtObject {
    id: translator

    property var capsLock: null
    property var numLock: null
    property string lastEvent: ""   // for the debug line

    // SDDM's KeyboardModel, if this greeter provides a working one
    readonly property bool sddmKeyboard: typeof keyboard !== "undefined" && keyboard !== null && keyboard.enabled

    property string pendingDead: ""   // combining mark waiting for the next key

    readonly property var deadKeys: ({
        [Qt.Key_Dead_Acute]: { mark: "́", alone: "´" },
        [Qt.Key_Dead_Grave]: { mark: "̀", alone: "`" },
        [Qt.Key_Dead_Circumflex]: { mark: "̂", alone: "^" },
        [Qt.Key_Dead_Tilde]: { mark: "̃", alone: "~" },
        [Qt.Key_Dead_Diaeresis]: { mark: "̈", alone: "¨" }
    })

    function refreshFromSddm() {
        if (sddmKeyboard) {
            capsLock = keyboard.capsLock;
            numLock = keyboard.numLock;
        }
    }

    function describe(event, result) {
        var mods = [];
        if (event.modifiers & Qt.ShiftModifier) mods.push("Shift");
        if (event.modifiers & Qt.ControlModifier) mods.push("Ctrl");
        if (event.modifiers & Qt.AltModifier) mods.push("Alt");
        if (event.modifiers & Qt.MetaModifier) mods.push("Meta");
        if (event.modifiers & Qt.KeypadModifier) mods.push("Keypad");
        if (event.modifiers & Qt.GroupSwitchModifier) mods.push("AltGr");
        lastEvent = "key 0x" + event.key.toString(16)
                  + "  text " + JSON.stringify(event.text)
                  + "  mods " + (mods.length ? mods.join("+") : "-")
                  + "  -> " + (result.length ? result.map(function (k) { return JSON.stringify(k); }).join(" ") : "ignored");
    }

    // Updates the lock states from what a key produced.
    function guessLocks(event) {
        // A lock key flips the state, unless SDDM reports the new state on
        // its own right after (then flipping too would undo it). If it was
        // unknown, it's now probably on.
        if (event.key === Qt.Key_CapsLock || event.key === Qt.Key_NumLock) {
            lockFlip.caps = event.key === Qt.Key_CapsLock;
            lockFlip.before = lockFlip.caps ? capsLock : numLock;
            lockFlip.restart();
        }

        var text = event.text;
        // a letter's case against Shift tells Caps Lock's state
        if (text.length === 1 && text.toUpperCase() !== text.toLowerCase()) {
            var shift = (event.modifiers & Qt.ShiftModifier) !== 0;
            capsLock = (text === text.toUpperCase()) !== shift;
        }
        // keypad keys type digits only with Num Lock on
        if (event.modifiers & Qt.KeypadModifier) {
            if (/^[0-9]$/.test(text))
                numLock = true;
            else if (text === "" && [Qt.Key_Home, Qt.Key_End, Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down,
                                     Qt.Key_PageUp, Qt.Key_PageDown, Qt.Key_Insert, Qt.Key_Delete,
                                     Qt.Key_Clear].indexOf(event.key) >= 0)
                numLock = false;
        }
    }

    // Returns the list of terminal keys this event produces (usually one; a
    // dead key that doesn't combine gives two, a lone dead key none):
    // characters, "ENTER", "BACK" or "ESC".
    function translate(event) {
        var result = [];
        var ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        var alt = (event.modifiers & Qt.AltModifier) !== 0;

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            result.push("ENTER");
        } else if (event.key === Qt.Key_Backspace) {
            result.push("BACK");
        } else if (event.key === Qt.Key_Escape || (ctrl && !alt && event.key === Qt.Key_C)) {
            result.push("ESC");
        } else if (deadKeys[event.key] !== undefined) {
            var dead = deadKeys[event.key];
            if (pendingDead !== "") {
                // two dead keys: the first one on its own
                result.push(pendingDead === dead.mark ? dead.alone : spacingFor(pendingDead));
                pendingDead = pendingDead === dead.mark ? "" : dead.mark;
            } else {
                pendingDead = dead.mark;
            }
        } else if (event.text.length >= 1 && event.text >= " " && !(ctrl && !alt)) {
            // Ctrl+Alt is how some platforms report AltGr, so only plain Ctrl is a shortcut
            var text = event.text;
            if (pendingDead !== "") {
                var composed = (text + pendingDead).normalize("NFC");
                if (composed.length === 1)
                    result.push(composed);
                else
                    result.push(spacingFor(pendingDead), text);
                pendingDead = "";
            } else {
                result.push(text);
            }
        }

        guessLocks(event);
        describe(event, result);
        return result;
    }

    function spacingFor(mark) {
        for (var k in deadKeys) {
            if (deadKeys[k].mark === mark)
                return deadKeys[k].alone;
        }
        return "";
    }

    property Timer lockFlip: Timer {
        property bool caps: true
        property var before: null
        interval: 150
        onTriggered: {
            var now = caps ? translator.capsLock : translator.numLock;
            if (now !== before)
                return;   // SDDM already reported the change
            var flipped = before === null ? true : !before;
            if (caps)
                translator.capsLock = flipped;
            else
                translator.numLock = flipped;
        }
    }

    property Connections sddmKeyboardChanges: Connections {
        target: translator.sddmKeyboard ? keyboard : null
        ignoreUnknownSignals: true
        function onCapsLockChanged() { translator.refreshFromSddm() }
        function onNumLockChanged() { translator.refreshFromSddm() }
    }

    Component.onCompleted: refreshFromSddm()
}
