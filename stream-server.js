/* Serves the boardroom and streams GitHub and Wikipedia events to it as
 * server-sent events on /events.js. Without this server the page reads the
 * public feeds itself (src/Feeds.js); what the server adds is location data:
 * GitHub profile locations (needs GITHUB_TOKEN) and IP geolocation for the
 * anonymous Wikipedia edits that still show one.
 *
 *   GITHUB_TOKEN=... PORT=8000 node stream-server.js */

var express = require("express"),
    path = require("path"),
    streams = require("./src/streams.js"),
    systemStats = require("./system-stats.js");

var PORT = process.env.PORT || 8000,
    GITHUB_TOKEN = process.env.GITHUB_TOKEN,
    USER_AGENT = "encom-boardroom/1.0 (https://github.com/arscan/encom-boardroom)";

var app = express();
app.set("trust proxy", true);
["js", "images", "css", "build"].forEach(function(dir){
    app.use("/" + dir, express.static(path.join(__dirname, dir)));
});
app.get("/", function(req, res){
    res.sendFile(path.join(__dirname, "index.html"));
});
app.get("/favicon.ico", function(req, res){
    res.sendFile(path.join(__dirname, "images", "favicon.ico"));
});

/* event stream */

var openConnections = new Set();

function sendData(data){
    var payload = "id: " + Date.now() + "\ndata:" + JSON.stringify(data) + "\n\n";
    openConnections.forEach(function(res){
        res.write(payload);
    });
}

app.get("/events.js", function(req, res){
    req.socket.setTimeout(0);
    res.writeHead(200, {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
        "Access-Control-Allow-Origin": "*"
    });
    res.write("\n");

    openConnections.add(res);
    console.log("New Connection.  Current Connections: " + openConnections.size);
    sendData({stream: "meta", type: "connect", size: openConnections.size});

    req.on("close", function(){
        openConnections.delete(res);
        sendData({stream: "meta", type: "disconnect", size: openConnections.size});
        console.log("Closed Connection. Current Connections: " + openConnections.size);
    });
});

setInterval(function(){
    sendData({stream: "meta", type: "heartbeat", size: openConnections.size});
}, 3000);

// This machine's RAM, CPU, download and disk writes for the light table's
// bandwidth panel (fields are null where /proc isn't available).
systemStats.sample();
setInterval(function(){
    var stats = systemStats.sample();
    stats.stream = "system";
    sendData(stats);
}, 1000);

/* helpers */

// Runs the scheduled calls one at a time, at most one per `interval` ms.
function rateLimiter(interval){
    var last = Promise.resolve();
    return function(fn){
        var result = last.then(fn);
        last = result.catch(function(){}).then(function(){
            return new Promise(function(resolve){ setTimeout(resolve, interval); });
        });
        return result;
    };
}

// Remembers results (including null for "not found") for the lifetime of the server.
function cached(limit, lookup){
    var cache = new Map();
    return function(key){
        if(cache.has(key)){
            return Promise.resolve(cache.get(key));
        }
        return lookup(key).catch(function(error){
            console.log("lookup failed for " + key + ": " + error.message);
            return null;
        }).then(function(value){
            if(cache.size >= limit){
                cache.delete(cache.keys().next().value);
            }
            cache.set(key, value);
            return value;
        });
    };
}

function getJson(url, headers){
    return fetch(url, {headers: Object.assign({"User-Agent": USER_AGENT}, headers)}).then(function(response){
        if(response.status === 404){
            return null;
        }
        if(!response.ok){
            throw new Error("HTTP " + response.status);
        }
        return response.json();
    });
}

/* Reads a server-sent events stream with fetch, reconnecting when it drops. */
function readEventStream(url, onData){
    var reconnect = function(){
        setTimeout(function(){ readEventStream(url, onData); }, 5000);
    };
    fetch(url, {headers: {"User-Agent": USER_AGENT, "Accept": "text/event-stream"}}).then(async function(response){
        if(!response.ok){
            throw new Error("HTTP " + response.status);
        }
        var decoder = new TextDecoder(),
            buffer = "";
        for await (var chunk of response.body){
            buffer += decoder.decode(chunk, {stream: true});
            var events = buffer.split(/\r?\n\r?\n/);
            buffer = events.pop();
            events.forEach(function(block){
                var data = block.split(/\r?\n/).filter(function(line){
                    return line.indexOf("data:") === 0;
                }).map(function(line){
                    return line.slice(5).replace(/^ /, "");
                }).join("\n");
                if(data){
                    try {
                        onData(JSON.parse(data));
                    } catch(ex){
                        // partial or non-JSON event; skip it
                    }
                }
            });
        }
        reconnect();
    }).catch(function(error){
        console.log("event stream " + url + " failed: " + error.message);
        reconnect();
    });
}

/* Wikipedia */

// ip-api.com's free endpoint allows 45 requests a minute.
var ipLimiter = rateLimiter(1500),
    lookupIp = cached(5000, function(ip){
        return ipLimiter(function(){
            return getJson("http://ip-api.com/json/" + encodeURIComponent(ip) + "?fields=status,lat,lon,city,countryCode,country");
        }).then(function(result){
            return result && result.status === "success" ? result : null;
        });
    });

var wikipediaPending = 0;

readEventStream(streams.WIKIPEDIA_STREAM, function(change){
    var message = streams.wikipediaMessage(change);
    // The feed runs at tens of edits a second; keep it to what the boardroom can show.
    if(!message || wikipediaPending > 5 || Math.random() > 0.3){
        return;
    }
    if(!message.ip){
        sendData(message);
        return;
    }
    wikipediaPending++;
    lookupIp(message.ip).then(function(result){
        if(result){
            message.latlon = {lat: result.lat, lon: result.lon};
            message.location = result.city ? result.city + ", " + result.countryCode : result.country;
        }
        sendData(message);
    }).finally(function(){
        wikipediaPending--;
    });
});

/* GitHub */

var githubHeaders = {Accept: "application/vnd.github+json"};
if(GITHUB_TOKEN){
    githubHeaders.Authorization = "Bearer " + GITHUB_TOKEN;
}

// Authenticated requests get 5000 an hour; stay under that.
var githubLimiter = rateLimiter(800),
    lookupUser = cached(20000, function(login){
        return githubLimiter(function(){
            return getJson("https://api.github.com/users/" + encodeURIComponent(login), githubHeaders);
        });
    }),
    lookupRepo = cached(20000, function(name){
        return githubLimiter(function(){
            return getJson("https://api.github.com/repos/" + name, githubHeaders);
        });
    }),
    // Nominatim's usage policy: at most one request a second, cache the results.
    geocodeLimiter = rateLimiter(1100),
    geocode = cached(20000, function(place){
        return geocodeLimiter(function(){
            return getJson("https://nominatim.openstreetmap.org/search?format=json&limit=1&q=" + encodeURIComponent(place));
        }).then(function(results){
            return results && results.length ? {lat: parseFloat(results[0].lat), lon: parseFloat(results[0].lon)} : null;
        });
    });

function enrichGithub(event, message){
    if(!GITHUB_TOKEN){
        return Promise.resolve(message);
    }
    var user = event.actor ? lookupUser(event.actor.login).then(function(info){
        if(!info || !info.location){
            return;
        }
        message.location = info.location;
        return geocode(info.location).then(function(latlon){
            if(latlon){
                message.latlon = latlon;
            }
        });
    }) : Promise.resolve();

    var repo = event.repo ? lookupRepo(event.repo.name).then(function(info){
        if(info){
            message.size = info.size;
            message.popularity = info.stargazers_count;
            if(info.language){
                message.type = info.language;
            }
        }
    }) : Promise.resolve();

    return Promise.all([user, repo]).then(function(){
        return message;
    });
}

var githubPending = 0,
    githubSeen = new Set();

function pollGithub(etag){
    var headers = Object.assign({}, githubHeaders);
    if(etag){
        headers["If-None-Match"] = etag;
    }
    fetch(streams.GITHUB_EVENTS, {headers: Object.assign({"User-Agent": USER_AGENT}, headers)}).then(function(response){
        var interval = Math.max(GITHUB_TOKEN ? 10000 : 60000,
                                1000 * (parseInt(response.headers.get("X-Poll-Interval"), 10) || 0));
        var nextEtag = response.headers.get("ETag") || etag;
        setTimeout(function(){ pollGithub(nextEtag); }, interval);
        if(response.status !== 200){
            return;
        }
        return response.json().then(function(events){
            // Consecutive pages overlap.
            var fresh = events.filter(function(event){
                return !githubSeen.has(event.id);
            }).reverse();
            githubSeen = new Set(events.map(function(event){ return event.id; }));
            fresh.forEach(function(event, i){
                setTimeout(function(){
                    // Lookups are rate limited; drop events rather than fall behind.
                    if(githubPending > 20){
                        return;
                    }
                    githubPending++;
                    enrichGithub(event, streams.githubMessage(event)).then(sendData).finally(function(){
                        githubPending--;
                    });
                }, interval * i / fresh.length);
            });
        });
    }).catch(function(error){
        console.log("GitHub events failed: " + error.message);
        setTimeout(function(){ pollGithub(etag); }, 60000);
    });
}

pollGithub(null);
if(!GITHUB_TOKEN){
    console.log("GITHUB_TOKEN not set: GitHub events will have no locations");
}

app.listen(PORT, function(){
    console.log("Express server listening on port " + PORT);
});
