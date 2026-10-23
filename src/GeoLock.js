/* Geo-lock for the web mockup: a sequence of places on the globe used as a
 * secret, next to the password (port of lockscreen-theme's geolock.js, with
 * the number of zones and places configurable to try them out).
 *
 * A click can't be compared exactly, so it snaps to the nearest of `zones`
 * fixed points spread evenly over the sphere (a Fibonacci lattice). The
 * sequence of zone numbers is the secret:
 *     "geolock1:256:17-203-88-5-140-61"
 * Combinations: zones ^ places, i.e. places * log2(zones) bits.
 *
 * Everything here is a simulation: the saved sequence is a SHA-256 hash in
 * this browser's localStorage, checked by LoginTerminal.js's demo login. */

var PREFIX = "geolock1:",
    STORE_KEY = "encom-geolock";

var anchorCache = {};

function toRad(d){ return d * Math.PI / 180; }
function toDeg(r){ return r * 180 / Math.PI; }

function vector(lat, lon){
    var la = toRad(lat), lo = toRad(lon);
    return [Math.cos(la) * Math.cos(lo), Math.sin(la), Math.cos(la) * Math.sin(lo)];
}

// `zones` points spread evenly over the sphere: [{index, v, lat, lon}]
function anchors(zones){
    if (anchorCache[zones]) {
        return anchorCache[zones];
    }
    var golden = Math.PI * (3 - Math.sqrt(5)),
        list = [];
    for (var i = 0; i < zones; i++) {
        var y = 1 - (i + 0.5) * 2 / zones,
            r = Math.sqrt(1 - y * y),
            phi = i * golden,
            v = [Math.cos(phi) * r, y, Math.sin(phi) * r];
        list.push({ index: i, v: v, lat: toDeg(Math.asin(y)), lon: toDeg(Math.atan2(v[2], v[0])) });
    }
    anchorCache[zones] = list;
    return list;
}

// the zone closest to lat/lon
function nearest(zones, lat, lon){
    var p = vector(lat, lon),
        list = anchors(zones),
        best = list[0],
        bestDot = -2;
    for (var i = 0; i < list.length; i++) {
        var a = list[i].v,
            dot = a[0] * p[0] + a[1] * p[1] + a[2] * p[2];
        if (dot > bestDot) {
            bestDot = dot;
            best = list[i];
        }
    }
    return best;
}

function secret(zones, indices){
    return PREFIX + zones + ":" + indices.join("-");
}

function isSecret(text){
    return typeof text === "string" && text.indexOf(PREFIX) === 0;
}

function bits(zones, places){
    return places * Math.log2(zones);
}

// average distance between neighbouring zones, in km
function spacingKm(zones){
    return Math.sqrt(4 * Math.PI / zones) * 6371;
}

// SHA-256 hex (WebCrypto needs a secure context: localhost or file://)
function hash(text, done){
    if (window.crypto && window.crypto.subtle && window.TextEncoder) {
        window.crypto.subtle.digest("SHA-256", new TextEncoder().encode(text)).then(function(buffer){
            done(Array.prototype.map.call(new Uint8Array(buffer), function(b){
                return ("0" + b.toString(16)).slice(-2);
            }).join(""));
        });
    } else {
        done("plain:" + text);   // demo fallback without WebCrypto
    }
}

function saved(){
    try {
        return JSON.parse(localStorage.getItem(STORE_KEY));
    } catch (ex) {
        return null;
    }
}

function save(text, zones, places, done){
    hash(text, function(digest){
        try {
            localStorage.setItem(STORE_KEY, JSON.stringify({ hash: digest, zones: zones, places: places }));
        } catch (ex) {}
        done();
    });
}

// done(true) if `text` is the saved sequence
function check(text, done){
    var stored = saved();
    if (!stored || !isSecret(text)) {
        done(false);
        return;
    }
    hash(text, function(digest){
        done(digest === stored.hash);
    });
}

module.exports = {
    anchors: anchors,
    nearest: nearest,
    secret: secret,
    isSecret: isSecret,
    bits: bits,
    spacingKm: spacingKm,
    saved: saved,
    save: save,
    check: check
};
