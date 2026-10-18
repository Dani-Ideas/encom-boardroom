import QtQuick
import "systemstats.js" as Stats

// Fallback for TubeNative.qml when the EncomSystem plugin isn't built: the
// same tube drawn on a Canvas (on the CPU, so it costs more). Port of the
// mockup's bandwidth tube (createWebGlTest in src/LightTable.js), drawn with the same perspective three.js used: camera at z=100,
// 50° vertical field of view, swaying ±20 sideways every 10 s. x is time
// (newest sample on the right) and each side of the tube is one channel whose
// radius is that channel's value. Reads /proc through systemstats.js, which
// needs QML_XHR_ALLOW_FILE_READ=1; otherwise it shows example values.
Item {
    id: monitor

    // Shrinks the scene by this much so it renders at screen resolution.
    property real pixelScale: 1
    property real reveal: 1   // fades the tube in

    readonly property var channels: [
        { key: "ram", label: "RAM", color: "#00eeee" },
        { key: "cpu", label: "CPU", color: "#ffcc00" },
        { key: "netDown", label: "NET", color: "#ffffff", minScale: 1e6 },
        { key: "diskWrite", label: "DISK", color: "#ff5050", minScale: 5e6 }
    ]
    readonly property int samples: 150    // at one a second, 2.5 minutes
    readonly property int interval: 1000

    property var history: []
    property double lastSampleTime: Date.now()
    property double started: Date.now()
    property var latest: null

    function formatRate(bytes) {
        return bytes >= 1e6 ? (bytes / 1e6).toFixed(1) + " MB/s" : Math.round(bytes / 1e3) + " KB/s";
    }

    function addSample() {
        var stats = Stats.sample() || Stats.exampleSample();
        var sample = channels.map(function (c) { return stats[c.key] || 0; });
        if (history.length === 0) {
            // start from the first reading instead of an empty history
            for (var t = 0; t < samples; t++)
                history.push(sample.slice());
        }
        history.shift();
        history.push(sample);
        lastSampleTime = Date.now();
        latest = stats;
    }

    Timer {
        interval: monitor.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: monitor.addSample()
    }

    // Rendered at screen pixels: sized up by pixelScale and scaled back down.
    Canvas {
        id: canvas
        width: monitor.width * monitor.pixelScale
        height: monitor.height * monitor.pixelScale
        scale: 1 / monitor.pixelScale
        transformOrigin: Item.TopLeft
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Cooperative

        // 20 fps is smooth enough for the slow rotation and keeps the
        // greeter's CPU use low (Canvas paints on the CPU).
        Timer {
            interval: 50
            running: monitor.visible
            repeat: true
            onTriggered: canvas.requestPaint()
        }

        onPaint: {
            var ctx = getContext("2d");
            var w = width, h = height;
            ctx.reset();
            ctx.clearRect(0, 0, w, h);
            if (monitor.history.length === 0)
                return;

            var now = Date.now();
            var fov = 50 * Math.PI / 180;
            var focal = (h / 2) / Math.tan(fov / 2);
            var aspect = w / h;
            var cameraX = Math.sin(2 * Math.PI * (now - monitor.started) / 10000) * 20;
            var rotation = (now - monitor.started) / 1000 * 0.6;   // .01 rad per frame at 60 fps

            function project(x, y, z) {
                var depth = 100 - z;
                return [w / 2 + (x - cameraX) * focal / depth, h / 2 - y * focal / depth];
            }

            // backdrop: 25 dark horizontal lines on a plane behind the tube
            ctx.lineWidth = 1;
            ctx.strokeStyle = Qt.rgba(0x1b / 255, 0x2f / 255, 0x2d / 255, 0.333 * monitor.reveal);
            ctx.beginPath();
            for (var b = 0; b < 25; b++) {
                var p0 = project(-1500, 100 - b * 8, -100), p1 = project(1500, 100 - b * 8, -100);
                ctx.moveTo(p0[0], p0[1]);
                ctx.lineTo(p1[0], p1[1]);
            }
            ctx.stroke();

            // the tube
            var count = monitor.channels.length;
            var points = monitor.samples * count;
            var visibleHalfWidth = 100 * Math.tan(fov / 2) * aspect;
            var span = 2 * (visibleHalfWidth - 40);
            var step = span / (points - 1);
            // slide left between samples so the history scrolls smoothly
            var slide = Math.min(1, (now - monitor.lastSampleTime) / monitor.interval) * count * step;

            // rates have no fixed maximum: scale them to the largest value on screen
            var scales = monitor.channels.map(function (c, k) {
                if (!c.minScale)
                    return 100;
                var max = c.minScale;
                for (var t = 0; t < monitor.history.length; t++)
                    max = Math.max(max, monitor.history[t][k]);
                return max;
            });

            var cos = Math.cos(rotation), sin = Math.sin(rotation);
            var projected = [];
            for (var i = 0; i < points; i++) {
                var k = i % count;
                var value = Math.min(1, monitor.history[Math.floor(i / count)][k] / scales[k]);
                var radius = 3 + value * 35;
                var angle = 2 * Math.PI * k / count + i / points;
                var y = radius * Math.sin(angle), z = radius * Math.cos(angle);
                // rotate around x
                projected.push(project(i * step - span / 2 - slide, y * cos - z * sin, y * sin + z * cos));
            }

            // one path per channel: each segment takes its start point's color
            ctx.globalAlpha = monitor.reveal;
            for (var c = 0; c < count; c++) {
                ctx.strokeStyle = monitor.channels[c].color;
                ctx.beginPath();
                for (var s = c; s < points - 1; s += count) {
                    ctx.moveTo(projected[s][0], projected[s][1]);
                    ctx.lineTo(projected[s + 1][0], projected[s + 1][1]);
                }
                ctx.stroke();
            }
        }
    }
}
