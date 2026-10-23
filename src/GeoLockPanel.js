/* GEO-LOCK panel of the light table's login (index.html #lt-geolock): the
 * particle globe from encom-globe, where clicking places in order builds a
 * geo-lock sequence (GeoLock.js) that is sent to the login terminal like a
 * password. A drag turns the globe and the mouse wheel zooms, so the smaller
 * zones of the bigger settings can still be hit.
 *
 * SET SEQUENCE records a new sequence (asked twice) with the current number
 * of places and zones; UNLOCK mode (the default) submits one at the
 * Password: prompt. All of it is the web simulation; see GeoLock.js. */

var $ = require("jquery"),
    ParticleGlobe = require("encom-globe/src/ParticleGlobe.js"),
    GeoLock = require("./GeoLock.js"),
    LoginTerminal = require("./LoginTerminal.js");

var PLACE_OPTIONS = [6, 8, 10],
    ZONE_OPTIONS = [256, 1024, 4096],
    MIN_ZOOM = 1.2,
    MAX_ZOOM = 6;

var places = 6,
    zones = 256,
    picks = [],
    mode = "unlock",       // "unlock" | "setup" | "confirm"
    firstSecret = null,
    waiting = false,       // a sequence is being verified
    globe = null,
    open = false,
    zoom = 1.6,
    frame = null;

function say(text, cls){
    LoginTerminal.write("&gt;&gt;geolock: " + text, cls);
}

/* display */

function renderSlots(){
    var slots = $("#lt-geolock-slots").empty();
    for (var i = 0; i < places; i++) {
        var cls = i < picks.length ? "filled" : i === picks.length ? "next" : "";
        $('<div class="lt-geolock-slot"></div>').addClass(cls)
            .text(i < picks.length ? "●" : i + 1).appendTo(slots);
    }
    $("#lt-geolock-setup").toggleClass("lt-button-active", mode !== "unlock");
}

function renderOptions(){
    $("#lt-geolock-places .lt-geolock-choice").each(function(){
        $(this).toggleClass("lt-button-active", parseInt($(this).attr("data-value"), 10) === places);
    });
    $("#lt-geolock-zones .lt-geolock-choice").each(function(){
        $(this).toggleClass("lt-button-active", parseInt($(this).attr("data-value"), 10) === zones);
    });
    $("#lt-geolock-bits").html("COMBINATIONS 2<sup>" + Math.round(GeoLock.bits(zones, places)) + "</sup> · ZONES ~" +
                               Math.round(GeoLock.spacingKm(zones)) + " KM APART");
}

function hint(){
    var text = mode === "setup" ? "SET SEQUENCE: PICK " + places + " PLACES"
             : mode === "confirm" ? "PICK THE SAME " + places + " PLACES AGAIN"
             : waiting ? "VERIFYING ..."
             : "PICK " + places + " PLACES · DRAG TO TURN · WHEEL TO ZOOM";
    $("#lt-geolock-hint").text(text);
}

function refresh(){
    renderSlots();
    renderOptions();
    hint();
}

/* picking */

function clearPins(){
    if (globe) {
        globe.setMaxPins(0);   // removes them all
        globe.setMaxPins(PLACE_OPTIONS[PLACE_OPTIONS.length - 1]);
    }
}

function reset(){
    picks = [];
    clearPins();
    refresh();
}

function undo(){
    if (!picks.length || waiting) {
        return;
    }
    var kept = picks.slice(0, -1);
    picks = [];
    clearPins();
    kept.forEach(function(index){
        place(GeoLock.anchors(zones)[index]);
    });
    refresh();
}

function place(anchor){
    picks.push(anchor.index);
    globe.addPin(anchor.lat, anchor.lon, "");   // no numbers: someone could be watching
}

function pick(clientX, clientY){
    if (waiting || picks.length >= places) {
        return;
    }
    var p = globe.pickLatLon(clientX, clientY);
    if (!p) {
        return;
    }
    place(GeoLock.nearest(zones, p.lat, p.lon));
    refresh();
    if (picks.length === places) {
        setTimeout(finish, 350);   // let the last pin land
    }
}

function finish(){
    var secret = GeoLock.secret(zones, picks);

    if (mode === "setup") {
        firstSecret = secret;
        mode = "confirm";
        say("first entry recorded; pick the same " + places + " places again");
        reset();
    } else if (mode === "confirm") {
        if (secret === firstSecret) {
            GeoLock.save(secret, zones, places, function(){
                say('<span class="highlight">sequence saved</span> (' + places + " places, " + zones + " zones)");
            });
            mode = "unlock";
        } else {
            say('<span class="alert">the two entries don\'t match</span>; start again');
            mode = "setup";
        }
        firstSecret = null;
        reset();
    } else {
        var stored = GeoLock.saved();
        if (!stored) {
            say("no sequence saved yet: use SET SEQUENCE");
            reset();
            return;
        }
        if (stored.zones !== zones || stored.places !== places) {
            say("note: the saved sequence uses " + stored.places + " places and " + stored.zones + " zones");
        }
        waiting = true;
        refresh();
        if (!LoginTerminal.submitGeo(secret)) {
            waiting = false;
            reset();
        }
    }
}

/* globe */

function createGlobe(){
    var container = $("#lt-geolock-globe");
    globe = new ParticleGlobe(container.width(), container.height(), {
        tiles: grid.tiles,            // js/globe-grid.js
        baseColor: "#c6c7f5",
        scale: zoom,
        introDuration: 1500,
        startLongitude: -90,
        tilt: 0.2,
        dayLength: 600000,            // a slow drift; picking stays easy
        hoverPull: 0,                 // no gravity well: it would move places under the cursor
        hoverTurbulence: 4,
        pointSize: 3,
        maxPins: PLACE_OPTIONS[PLACE_OPTIONS.length - 1],
        maxMarkers: 1
    });
    container.prepend(globe.domElement);

    // a click picks a place; a drag only turns the globe
    var el = globe.domElement,
        down = null;
    el.addEventListener("pointerdown", function(e){
        down = { x: e.clientX, y: e.clientY, time: performance.now() };
    });
    el.addEventListener("pointerup", function(e){
        if (down && Math.hypot(e.clientX - down.x, e.clientY - down.y) <= 6 && performance.now() - down.time < 500) {
            pick(e.clientX, e.clientY);
        }
        down = null;
    });
    el.addEventListener("wheel", function(e){
        e.preventDefault();
        zoom = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, zoom * Math.exp(-e.deltaY * 0.0015)));
        globe.setScale(zoom);
    }, { passive: false });

    globe.init(function(){
        animate();
    });
}

function animate(){
    if (!open) {
        frame = null;
        return;   // paused while the panel is closed
    }
    globe.tick();
    frame = requestAnimationFrame(animate);
}

function resizeGlobe(){
    if (globe) {
        var container = $("#lt-geolock-globe");
        globe.resize(container.width(), container.height());
    }
}

function toggle(){
    open = !open;
    $("#lt-geolock").toggleClass("lt-geolock-open", open);
    $("#lt-button-geolock").toggleClass("lt-button-active", open);
    if (open) {
        // the keyboard and the globe share the space
        $("#lt-vkeyboard").removeClass("lt-vkeyboard-visible");
        $("#lt-button-keyboard").removeClass("lt-button-active");
        if (!globe) {
            createGlobe();
        } else {
            resizeGlobe();
            if (!frame) {
                animate();
            }
        }
        refresh();
    }
}

/* public */

var GeoLockPanel = {};

// Once, from LightTable.init (after LoginTerminal.init).
GeoLockPanel.init = function(){
    $("#lt-button-geolock").on("click", toggle);
    $("#lt-geolock-undo").on("click", undo);
    $("#lt-geolock-clear").on("click", function(){
        if (!waiting) {
            reset();
        }
    });
    $("#lt-geolock-setup").on("click", function(){
        if (waiting) {
            return;
        }
        mode = mode === "unlock" ? "setup" : "unlock";
        firstSecret = null;
        say(mode === "setup" ? "pick " + places + " places for the new sequence" : "set sequence cancelled");
        reset();
    });

    var choices = function(id, values, apply){
        var box = $(id);
        values.forEach(function(value){
            $('<div class="lt-button lt-geolock-choice"></div>').attr("data-value", value).text(value)
                .on("click", function(){
                    if (waiting) {
                        return;
                    }
                    apply(value);
                    firstSecret = null;
                    if (mode === "confirm") {
                        mode = "setup";
                    }
                    reset();
                })
                .appendTo(box);
        });
    };
    choices("#lt-geolock-places", PLACE_OPTIONS, function(v){ places = v; });
    choices("#lt-geolock-zones", ZONE_OPTIONS, function(v){ zones = v; });

    // the login answered: start over (on success the boardroom takes over anyway)
    LoginTerminal.onAttempt(function(){
        waiting = false;
        reset();
    });

    $(window).on("resize", resizeGlobe);
    refresh();
};

module.exports = GeoLockPanel;
