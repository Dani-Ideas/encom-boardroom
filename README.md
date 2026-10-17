Encom Boardroom
=================

An HTML5 recreation of the [Boardroom
Scene](http://work.gmunk.com/TRON-Board-Room) in Disney's [Tron:
Legacy](http://www.imdb.com/title/tt1104001/).  It currently displays realtime
data from GitHub and Wikipedia to make it a bit more fun.  View it in action at
https://www.robscanlon.com/encom-boardroom/ .

![Boardroom light table](https://raw.github.com/arscan/encom-boardroom/master/images/screenshot_lighttable.jpg "Boardroom light table")

![Boardroom screen](https://raw.github.com/arscan/encom-boardroom/master/images/screenshot.jpg "Boardroom screen")

While I attempted to stay true to the film, it simply wasn't practical to
recreate every element that is portrayed in the scene. The graphics displayed
in the film contain a remarkable amount of detail despite only being visible
for a couple of seconds. I am in awe of those that put it together.

My focus was on the globe and I made it available as a [standalone
library](https://github.com/arscan/encom-globe) for those interested. The other
elements are only loose adaptations of the film version. This project is not
associated with GitHub, Wikipedia, Tron: Legacy, or Disney. It is just a
tribute.

### Usage

```sh
npm install        # encom-globe comes from ../encom-globe (the local hex-globe fork)
npm run build      # vite -> build/encom-boardroom.js and build/encom-boardroom.min.js
```

The page works without a server: serve the directory with any static server
(for example `python3 -m http.server`) and the browser reads the public
Wikipedia and GitHub feeds itself. Opening `index.html` straight from disk
also works in regular browsers, but Qt WebEngine blocks remote requests from
`file://` pages by default.

For locations on the GitHub stream, and IP geolocation for the Wikipedia
edits that still show one, run the stream server:

```sh
GITHUB_TOKEN=<token> PORT=8000 npm start
```

Then point your browser at `http://localhost:8000`. The token only needs
public read access; without it the server still runs, but GitHub events have
no location.

### Notable Dependencies

* [Node.js](https://nodejs.org/) 20 or newer, [Vite](https://vite.dev/) and [Express](https://expressjs.com/) 5
* [Three.js](https://threejs.org/) 0.184
* [Encom Globe](https://github.com/arscan/encom-globe), the local fork in `../encom-globe`
* [jQuery](https://jquery.com/) 3
* [pleaserotate.js](https://www.github.com/arscan/pleaserotate.js)

### Feed Info

**GitHub:** Events come from GitHub's public [events
API](https://docs.github.com/en/rest/activity/events), which allows 60
unauthenticated requests an hour, so the browser polls it once a minute and
spreads each batch over that minute. With `GITHUB_TOKEN`, the server looks up
each user's profile location and maps it with [OpenStreetMap
Nominatim](https://nominatim.openstreetmap.org/) (at most one request a second,
cached), plus the repository's language and stars. Historic 2013 data was
retrieved from the [GitHub Archive](https://www.gharchive.org/). User pictures
are GitHub avatars.

**Wikipedia:** Edits are streamed in realtime from Wikimedia's
[EventStreams](https://stream.wikimedia.org/?doc) `recentchange` feed (human
edits on the English, Chinese, French, Russian, Spanish, Italian, Portuguese,
Dutch, German, Swedish, Vietnamese and Japanese Wikipedias). Each edit is
placed in the region where its language is mostly spoken. Most wikis now give
anonymous editors temporary accounts instead of showing their IP; for the
edits that still show one, the server maps it with
[ip-api.com](https://ip-api.com/).

### License

The MIT License (MIT)
Copyright (c) 2014-2017 Robert Scanlon

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
