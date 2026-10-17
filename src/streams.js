/* Turns raw Wikipedia and GitHub events into the boardroom's message format:
 * {stream, action, title, url, type, size, popularity, username, userurl,
 *  picSmall, picLarge, location, latlon: {lat, lon}}
 * Shared by the browser (direct mode, src/Feeds.js) and stream-server.js. */

var WIKIPEDIA_STREAM = "https://stream.wikimedia.org/v2/stream/recentchange",
    GITHUB_EVENTS = "https://api.github.com/events?per_page=100";

/* Wikipedias shown, with the region their editors mostly come from. Edits are
 * placed there (spread out a little) unless the server can geolocate an IP. */
var wikipediaLanguages = {
    "en": {name: "English", lat: 39.8, lon: -98.6},
    "zh": {name: "Chinese", lat: 34.3, lon: 108.9},
    "fr": {name: "French", lat: 46.6, lon: 2.4},
    "ru": {name: "Russian", lat: 55.8, lon: 37.6},
    "es": {name: "Spanish", lat: 19.4, lon: -99.1},
    "it": {name: "Italian", lat: 42.5, lon: 12.5},
    "pt": {name: "Portuguese", lat: -15.8, lon: -47.9},
    "nl": {name: "Dutch", lat: 52.1, lon: 5.3},
    "de": {name: "German", lat: 51.2, lon: 10.4},
    "sv": {name: "Swedish", lat: 59.3, lon: 18.1},
    "vi": {name: "Vietnamese", lat: 16.0, lon: 106.0},
    "ja": {name: "Japanese", lat: 36.2, lon: 138.3}
};

var ipPattern = /^(\d{1,3}\.){3}\d{1,3}$|^[0-9a-f]*:[0-9a-f:]+$/i;

function jitter(value, amount){
    return value + (Math.random() - 0.5) * 2 * amount;
}

/* recentchange event -> message, or null for anything that isn't a human edit
 * on one of the Wikipedias above. */
function wikipediaMessage(change){
    if(!change || !change.server_name || change.bot || (change.type !== "edit" && change.type !== "new")){
        return null;
    }
    var parts = change.server_name.split(".");
    if(parts.length !== 3 || parts[1] !== "wikipedia"){
        return null;
    }
    var language = wikipediaLanguages[parts[0]];
    if(!language){
        return null;
    }

    var size = change.length ? Math.abs((change.length["new"] || 0) - (change.length.old || 0)) : 0;

    return {
        stream: "wikipedia",
        action: change.type,
        title: change.title,
        url: change.meta && change.meta.uri,
        type: language.name,
        size: size,
        username: change.user,
        userurl: change.server_url + "/wiki/User:" + encodeURIComponent(change.user),
        picSmall: "images/not_available_small.png",
        picLarge: "images/not_available_large.png",
        ip: ipPattern.test(change.user) ? change.user : null,
        location: parts[0] + ".wikipedia",
        latlon: {lat: jitter(language.lat, 4), lon: jitter(language.lon, 6)}
    };
}

/* GitHub /events entry -> message. Location, repo language and stars need
 * extra API calls, so only stream-server.js (with a token) fills them in. */
function githubMessage(event){
    var message = {
        stream: "github",
        action: event.type,
        type: event.type.replace(/Event$/, ""),
        ip: null
    };
    if(event.actor){
        message.username = event.actor.login;
        message.userurl = "https://github.com/" + event.actor.login;
        if(event.actor.avatar_url){
            var separator = event.actor.avatar_url.indexOf("?") >= 0 ? "&" : "?";
            message.picSmall = event.actor.avatar_url + separator + "s=89";
            message.picLarge = event.actor.avatar_url + separator + "s=184";
        }
    }
    if(event.repo){
        message.title = event.repo.name;
        message.url = "https://github.com/" + event.repo.name;
    }
    return message;
}

module.exports = {
    WIKIPEDIA_STREAM: WIKIPEDIA_STREAM,
    GITHUB_EVENTS: GITHUB_EVENTS,
    wikipediaLanguages: wikipediaLanguages,
    wikipediaMessage: wikipediaMessage,
    githubMessage: githubMessage
};
