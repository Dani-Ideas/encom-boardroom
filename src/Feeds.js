/* Where the boardroom's messages come from.
 *
 * With stream-server.js running, everything arrives on its /events.js
 * server-sent events endpoint (GitHub enriched with user locations, Wikipedia
 * IPs geolocated). Without it (index.html opened from disk or any static
 * host), the browser reads the public feeds itself: Wikipedia's EventStreams
 * and GitHub's /events API, which allows ~60 unauthenticated requests an hour. */

var streams = require("./streams.js");

var MAX_PER_SECOND = 3,   // the original server sent a few events a second
    QUEUE_LIMIT = 30,
    GITHUB_MIN_INTERVAL = 60000;

function Feeds(onMessage, esPath){
    this.onMessage = onMessage;
    this.esPath = esPath;
    this.direct = false;
    this.selected = null;
    this.queue = [];
    this.connect();
}

Feeds.prototype.connect = function(){
    var _this = this;
    if(!/^https?:$/.test(location.protocol)){
        this.startDirect();
        return;
    }

    var received = false,
        es = new EventSource(this.esPath);
    es.addEventListener("message", function(event){
        received = true;
        _this.onMessage(JSON.parse(event.data));
    });
    es.addEventListener("error", function(){
        // No stream server here (404 or not an event stream): read the feeds directly.
        if(!received){
            es.close();
            _this.startDirect();
        }
    });
};

Feeds.prototype.startDirect = function(){
    var _this = this;
    if(this.direct){
        return;
    }
    this.direct = true;
    console.log("encom-boardroom: no stream server, reading the public feeds directly");

    // The light table shows the link as down when no message arrives for 8 s.
    var heartbeat = function(){
        _this.onMessage({stream: "meta", type: "heartbeat", size: 1});
    };
    heartbeat();
    setInterval(heartbeat, 3000);

    setInterval(function(){
        for(var i = 0; i < MAX_PER_SECOND && _this.queue.length; i++){
            _this.onMessage(_this.queue.shift());
        }
    }, 1000);

    if(this.selected){
        this.select(this.selected);
    }
};

Feeds.prototype.enqueue = function(message){
    this.queue.push(message);
    if(this.queue.length > QUEUE_LIMIT){
        this.queue.shift();
    }
};

/* Called with the stream the light table launched. In direct mode only that
 * feed is opened; the server sends both regardless. */
Feeds.prototype.select = function(stream){
    this.selected = stream;
    if(!this.direct){
        return;
    }
    if(stream === "wikipedia"){
        this.startWikipedia();
    } else if(stream === "github"){
        this.startGithub();
    }
};

Feeds.prototype.startWikipedia = function(){
    var _this = this;
    var es = new EventSource(streams.WIKIPEDIA_STREAM);
    es.addEventListener("message", function(event){
        var message = streams.wikipediaMessage(JSON.parse(event.data));
        if(message){
            _this.enqueue(message);
        }
    });
};

/* GitHub's events are a few minutes old and come 100 at a time, so spread
 * each batch over the polling interval instead of dumping it at once. */
Feeds.prototype.startGithub = function(){
    var _this = this,
        etag = null,
        seen = {};

    var poll = function(){
        var headers = {Accept: "application/vnd.github+json"};
        if(etag){
            headers["If-None-Match"] = etag;
        }
        fetch(streams.GITHUB_EVENTS, {headers: headers}).then(function(response){
            var interval = Math.max(GITHUB_MIN_INTERVAL, 1000 * (parseInt(response.headers.get("X-Poll-Interval"), 10) || 0));
            setTimeout(poll, interval);
            if(response.status !== 200){
                return;
            }
            etag = response.headers.get("ETag");
            return response.json().then(function(events){
                var fresh = events.filter(function(event){
                    return !seen[event.id];
                }).reverse();
                seen = {};
                events.forEach(function(event){
                    seen[event.id] = true;
                });
                fresh.forEach(function(event, i){
                    setTimeout(function(){
                        _this.onMessage(streams.githubMessage(event));
                    }, interval * i / fresh.length);
                });
            });
        }).catch(function(error){
            console.log("encom-boardroom: GitHub events failed", error);
            setTimeout(poll, GITHUB_MIN_INTERVAL);
        });
    };
    poll();
};

module.exports = Feeds;
