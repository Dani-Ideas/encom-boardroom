.pragma library

// Geo-lock: a sequence of places on the globe used as a secret.
//
// A click can't be compared exactly (nobody hits the same pixel twice), and
// a hash needs exact input, so every click snaps to the nearest of ANCHORS
// fixed points spread evenly over the sphere (a Fibonacci lattice, ~12.7°
// apart). The sequence of anchor numbers is the secret:
//   "geolock1:256:17-203-88-5-140-61"
// which the lock screen sends to PAM exactly like a typed password; the
// encom-geolock check (install-geolock.sh) compares it with a PBKDF2 hash.
// Changing ANCHORS changes every secret, so it is part of the string.

var ANCHORS = 256;
var LENGTH = 6;
var PREFIX = "geolock1:";

var _anchors = null;

function toRad(d) { return d * Math.PI / 180; }
function toDeg(r) { return r * 180 / Math.PI; }

// unit vector for lat/lon (any fixed convention works; the anchors use the same)
function vector(lat, lon) {
    var la = toRad(lat), lo = toRad(lon);
    return [Math.cos(la) * Math.cos(lo), Math.sin(la), Math.cos(la) * Math.sin(lo)];
}

function anchors() {
    if (_anchors)
        return _anchors;
    var golden = Math.PI * (3 - Math.sqrt(5));
    _anchors = [];
    for (var i = 0; i < ANCHORS; i++) {
        var y = 1 - (i + 0.5) * 2 / ANCHORS;
        var r = Math.sqrt(1 - y * y);
        var phi = i * golden;
        var v = [Math.cos(phi) * r, y, Math.sin(phi) * r];
        _anchors.push({ index: i, v: v, lat: toDeg(Math.asin(y)), lon: toDeg(Math.atan2(v[2], v[0])) });
    }
    return _anchors;
}

// the anchor closest to lat/lon: {index, lat, lon}
function nearest(lat, lon) {
    var p = vector(lat, lon), best = null, bestDot = -2;
    var list = anchors();
    for (var i = 0; i < list.length; i++) {
        var a = list[i].v, dot = a[0] * p[0] + a[1] * p[1] + a[2] * p[2];
        if (dot > bestDot) {
            bestDot = dot;
            best = list[i];
        }
    }
    return { index: best.index, lat: best.lat, lon: best.lon };
}

function token(indices) {
    return PREFIX + ANCHORS + ":" + indices.join("-");
}
