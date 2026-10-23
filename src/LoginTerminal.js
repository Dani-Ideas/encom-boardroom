/* Login terminal for the light table. It asks for a login and a password like
 * a Unix console, answers with errors, locks after too many failures, and
 * calls onLogin() on success. Also drives the KEYBOARD / SLEEP / SWITCH USER
 * buttons and the virtual keyboard.
 *
 * This page is the mockup; the real login screen is the native SDDM theme in
 * sddm-theme/, which ports this logic to QML. Here only the demo
 * credentials below are accepted. */

var $ = require("jquery"),
    GeoLock = require("./GeoLock.js");

var DEMO_USER = "flynn",
    DEMO_PASSWORD = "tron",
    HOSTNAME = "llvm992",
    MAX_ATTEMPTS = 3,
    LOCK_SECONDS = 30,
    VERIFY_MS = 1200,               // the pause a real login makes before answering
    LAST_LOGIN_KEY = "encom-last-login";

var KEYBOARD_ROWS = [
    ["ESC", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "BACK"],
    ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
    ["A", "S", "D", "F", "G", "H", "J", "K", "L", "ENTER"],
    ["Z", "X", "C", "V", "B", "N", "M", ".", "_", "-"],
    ["SPACE"]
];

// (user, secret, done(ok)): the demo password, or the saved geo-lock
// sequence (GeoLock.js), both for DEMO_USER only
var authenticate = function(user, pass, done){
    setTimeout(function(){
        if (user !== DEMO_USER) {
            done(false);
        } else if (GeoLock.isSecret(pass)) {
            GeoLock.check(pass, done);
        } else {
            done(pass === DEMO_PASSWORD);
        }
    }, VERIFY_MS);
};

var attemptListeners = [];   // fn(ok) after each attempt (the geo-lock panel resets)

function attemptFinished(ok){
    attemptListeners.forEach(function(fn){ fn(ok); });
}

var state = "idle",     // "login" | "password" | "busy" | "locked" | "done"
    username = "",
    password = "",
    attempts = 0,
    onLogin = function(){},
    sleeping = false;

/* output */

function lines(){
    return $("#lt-command-lines");
}

function scrollToEnd(){
    var box = $("#lt-command-line");
    box.scrollTop(box[0].scrollHeight);
}

function write(html, cls){
    lines().append('<div class="' + (cls || "response") + '">' + html + "</div>");
    scrollToEnd();
}

// A new input line: "<label><typed text><blinking cursor>".
function prompt(label){
    $(".command-blinker").removeClass("blink").removeClass("command-blinker");
    lines().append('<div class="command"><span class="prompt">' + label + '&nbsp;</span>' +
                   '<span class="command-text"></span><span class="blink command-blinker">&nbsp;</span></div>');
    scrollToEnd();
}

function typed(){
    return $(".command-text").last();
}

function stopCursor(){
    $(".command-blinker").removeClass("blink").removeClass("command-blinker");
}

function escapeHtml(text){
    return $("<div>").text(text).html();
}

function formatDate(date){
    return date.toDateString() + " " + date.toTimeString().slice(0, 8);
}

/* login flow */

function askLogin(){
    state = "login";
    username = "";
    password = "";
    prompt("encom-os12 login:");
}

function askPassword(){
    state = "password";
    prompt("Password:");
}

function verify(){
    state = "busy";
    stopCursor();
    write("&gt;&gt;encom-sh: verifying credentials ...");

    authenticate(username, password, function(ok){
        if(ok){
            granted();
        } else {
            denied();
        }
    });
}

function granted(){
    state = "done";
    var previous = null;
    try {
        previous = localStorage.getItem(LAST_LOGIN_KEY);
        localStorage.setItem(LAST_LOGIN_KEY, formatDate(new Date()));
    } catch(ex){
        // private window or blocked storage: just don't remember
    }
    if(previous){
        write("Last login: " + previous + " on " + HOSTNAME);
    }
    write('<span class="highlight">ACCESS GRANTED.</span> Welcome, <strong>' + escapeHtml(username) + "</strong>");
    attemptFinished(true);
    write("&gt;&gt;encom-sh: launching boardroom ...");
    setTimeout(onLogin, 1500);
}

function denied(){
    attempts++;
    write('<span class="alert">ACCESS DENIED.</span> Login incorrect');
    attemptFinished(false);
    if(attempts >= MAX_ATTEMPTS){
        lock();
    } else {
        write((MAX_ATTEMPTS - attempts) + " attempt" + (MAX_ATTEMPTS - attempts === 1 ? "" : "s") + " remaining");
        askLogin();
    }
}

function lock(){
    state = "locked";
    write('<span class="alert">Maximum number of tries exceeded (' + MAX_ATTEMPTS + ")</span>");
    write('Terminal locked for <span class="lt-lock-countdown">' + LOCK_SECONDS + "</span> s");
    var countdown = $(".lt-lock-countdown").last(),
        remaining = LOCK_SECONDS;
    var timer = setInterval(function(){
        remaining--;
        countdown.text(remaining);
        if(remaining <= 0){
            clearInterval(timer);
            attempts = 0;
            write("Terminal unlocked");
            askLogin();
        }
    }, 1000);
}

/* input: physical and virtual keys both end up here */

// key: a single character, or "ENTER" | "BACK" | "ESC"
function input(key){
    if(sleeping){
        wake();
        return;
    }
    if(state !== "login" && state !== "password"){
        return;
    }
    flashKey(key);

    if(key === "ENTER"){
        if(state === "login"){
            if(username.length === 0){
                askLogin();   // like a real console: an empty login just asks again
            } else {
                askPassword();
            }
        } else {
            verify();
        }
    } else if(key === "ESC"){
        stopCursor();
        write("^C", "response");
        askLogin();
    } else if(key === "BACK"){
        if(state === "login"){
            username = username.slice(0, -1);
            typed().text(username);
        } else {
            password = password.slice(0, -1);
        }
    } else if(key.length === 1){
        if(state === "login"){
            username += key;
            typed().text(username);
        } else {
            password += key;   // not echoed, like a real password prompt
        }
    }
}

function keyFromEvent(event){
    if(event.key === "Enter"){ return "ENTER"; }
    if(event.key === "Backspace"){ return "BACK"; }
    if(event.key === "Escape" || (event.ctrlKey && event.key === "c")){ return "ESC"; }
    if(event.key.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey){ return event.key; }
    return null;
}

/* virtual keyboard */

function buildKeyboard(){
    var keyboard = $("#lt-vkeyboard").empty();
    KEYBOARD_ROWS.forEach(function(row){
        var rowEl = $('<div class="lt-vkeyboard-row"></div>');
        row.forEach(function(label){
            // letters type lowercase; data-key stays uppercase for flashKey()
            var key = label === "SPACE" ? " " : label.length === 1 ? label.toLowerCase() : label;
            $('<div class="lt-vkey"></div>')
                .text(label)
                .toggleClass("lt-vkey-wide", label.length > 1)
                .attr("data-key", label === "SPACE" ? " " : label)
                .on("mousedown", function(event){
                    event.preventDefault();
                    input(key);
                })
                .appendTo(rowEl);
        });
        keyboard.append(rowEl);
    });
}

// Light up the matching virtual key, for physical presses too.
function flashKey(key){
    var el = $('#lt-vkeyboard .lt-vkey').filter(function(){
        return $(this).attr("data-key") === (key.length === 1 ? key.toUpperCase() : key);
    });
    el.addClass("lt-vkey-pressed");
    setTimeout(function(){ el.removeClass("lt-vkey-pressed"); }, 150);
}

/* buttons */

function toggleKeyboard(){
    var keyboard = $("#lt-vkeyboard");
    keyboard.toggleClass("lt-vkeyboard-visible");
    $("#lt-button-keyboard").toggleClass("lt-button-active", keyboard.hasClass("lt-vkeyboard-visible"));
}

function sleep(){
    sleeping = true;
    $("#lt-sleep").stop().css("display", "block").animate({opacity: 1}, 800);
}

function wake(){
    sleeping = false;
    $("#lt-sleep").stop().animate({opacity: 0}, 500, function(){
        $(this).css("display", "none");
    });
    if(state === "login" || state === "password"){
        stopCursor();
        write("&gt;&gt;encom-sh: system resumed from sleep");
        // resume where the user was
        if(state === "login"){
            prompt("encom-os12 login:");
            typed().text(username);
        } else {
            prompt("Password:");
        }
    }
}

function switchUser(){
    if(state === "busy" || state === "locked" || state === "done"){
        return;
    }
    lines().empty();
    write("&gt;&gt;encom-sh: session closed. Switching user ...");
    attempts = 0;
    askLogin();
}

function showHeader(){
    var lastLogin = null;
    try {
        lastLogin = localStorage.getItem(LAST_LOGIN_KEY);
    } catch(ex){}
    $("#lt-command-line-header").text("Last Login: " + (lastLogin || "Wed Nov 26 11:26:49") + " on " + HOSTNAME);
}

/* public */

var LoginTerminal = {};

// Once, from LightTable.init.
LoginTerminal.init = function(_onLogin){
    onLogin = _onLogin;
    buildKeyboard();

    showHeader();

    $("#lt-button-keyboard").on("click", toggleKeyboard);
    $("#lt-button-sleep").on("click", sleep);
    $("#lt-button-switch").on("click", switchUser);
    $("#lt-sleep").on("click", wake);
};

// Each time the light table shows: fresh terminal and keyboard listener.
LoginTerminal.start = function(){
    lines().empty();
    attempts = 0;
    askLogin();
    $(document).on("keydown.loginterminal", function(event){
        var key = keyFromEvent(event);
        if(key){
            event.preventDefault();
            input(key);
        }
    });
};

LoginTerminal.stop = function(){
    state = "idle";
    $(document).off("keydown.loginterminal");
};

/* Geo-lock (GeoLockPanel.js): a finished sequence is sent like a typed
 * password, at the Password: prompt after the login. Returns false (with a
 * hint in the terminal) when the terminal isn't asking for a password. */
LoginTerminal.submitGeo = function(secret){
    if(state !== "password"){
        if(state === "login"){
            write("&gt;&gt;encom-sh: type your login first, then use the geo-lock as the password");
        }
        return false;
    }
    stopCursor();
    write("&gt;&gt;encom-sh: geo-lock sequence submitted");
    password = secret;
    verify();
    return true;
};

LoginTerminal.write = write;

LoginTerminal.onAttempt = function(fn){
    attemptListeners.push(fn);
};

module.exports = LoginTerminal;
