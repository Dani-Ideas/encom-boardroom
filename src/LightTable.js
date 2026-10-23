var $ = require("jquery"),
    THREE = require("three"),
    Utils = require("./Utils.js"),
    LoginTerminal = require("./LoginTerminal.js"),
    GeoLockPanel = require("./GeoLockPanel.js");

// Stream the boardroom opens after a successful (demo) login.
var LOGIN_STREAM = "test";

var webglTest,
    active = false,
    initialized = false,
    currentWidth = 0,
    currentHeight = 0,
    hideFn = function(){},
    LightTable = {},
    lastMessageTime = null,
    numUsers = 1,
    dataStreamOn = false;

/* public function */

LightTable.init = function(_hideFn){

    hideFn = _hideFn;

    $(".lt-header").css("visibility", "hidden");
    $(".content-container").css("visibility", "hidden");

    webglTest = createWebGlTest();

    $("#light-table").css("visibility", "visible");

    currentWidth = $(window).width();
    currentHeight = $(window).height();


    LoginTerminal.init(function onLogin(){
        $(".container-border").animate({opacity: 0}, 500);
        setTimeout(function(){
            hideFn(LOGIN_STREAM);
        }, 500);
    });
    GeoLockPanel.init();

    initialized = true;
};

LightTable.show = function(cb){

    $("#light-table").css("opacity", 1);
    // do the intro animations
    showContainer();
    setTimeout(showHeaders, 500);

    showContentBoxes($("#lt-bandwidth"), 100);
    showContentBoxes($("#lt-globalization"), 200);

    if($("#lt-mobile-readme").width() > 0){
        showContentBoxes($("#lt-mobile-readme"), 0);
    }

    LoginTerminal.start();

    if(typeof cb == "function"){
        setTimeout(cb, 500);
    }

    active = true;
};

LightTable.hide = function(cb) {
    // reset everything

    active = false;
    $("#lt-mobile-readme").attr("style","");
    $(".lt-header-animator-right").attr("style","");
    $(".lt-header-animator-left").attr("style","");

    $("#light-table").animate({
        opacity: 0
    }, 500);

    setTimeout(function(){
        hideContainer();
        hideWebgl();
    }, 500);

    webglTest.reset();

    LoginTerminal.stop();

    if(typeof cb == "function"){
        cb();
    }
};

LightTable.animate = function(){
    if(active && initialized){
        webglTest.tick();
    }
};

var resizing = false;
LightTable.resize = function(){
    $("#light-table").center();
    if(!resizing && (currentWidth > 1600 && $(window).width() <= 1600) || (currentWidth <= 1600 && $(window).width() > 1600)){

        currentWidth = $(window).width();
        resizing = true;
        LightTable.hide();
        setTimeout(LightTable.show,1000);

        setTimeout(function(){
            resizing = false;
        }, 3000);
    }
};


LightTable.message = function(message){
    lastMessageTime = Date.now();

    if(message.stream === "system"){
        if(webglTest){   // messages can arrive before init()
            webglTest.addSample(message);
        }
        return;
    }

    if(message.stream === "meta" && message.size > 0){
        $("#datalink-status").text("CONNECTED. " + message.size + " USER" + (parseInt(message.size,10) === 1 ? "" : "S "));
        $("#datalink-status").css("color", "green");
    }

};

/* private functions */

/* Bandwidth panel channels: one side of the tube each, in this order.
 * minScale marks a rate (bytes/s) and is the smallest full-scale value. */
var SYSTEM_CHANNELS = [
    {key: "ram", label: "RAM", color: "#00eeee"},
    {key: "cpu", label: "CPU", color: "#ffcc00"},
    {key: "netDown", label: "NET", color: "#ffffff", minScale: 1e6},
    {key: "diskWrite", label: "DISK", color: "#ff5050", minScale: 5e6}
];
var SYSTEM_SAMPLES = 150,     // history length; at one sample a second, 2.5 minutes
    SYSTEM_INTERVAL = 1000;   // ms between samples, as sent by the server and Feeds.js

function formatRate(bytes){
    if(bytes >= 1e6){
        return (bytes / 1e6).toFixed(1) + " MB/s";
    }
    return Math.round(bytes / 1e3) + " KB/s";
}

function showSystemStats(stats){
    var html = SYSTEM_CHANNELS.map(function(channel){
        var value = stats[channel.key];
        var text = value === null || value === undefined ? "--"
                 : channel.minScale ? formatRate(value) : Math.round(value) + "%";
        return '<span style="color: ' + channel.color + '">' + channel.label + " " + text + "</span>";
    }).join(" ");
    $("#lt-sysstats").html(html + (stats.example ? ' <span class="lt-sysstats-example">(EJEMPLO)</span>' : ""));
}

function showContainer(){
    var outside = $("#lt-container-outside");
    var inside = $("#lt-container-inside");

    outside.center();
    inside.center();

    var outsideOffset = outside.offset();
    var insideOffset = inside.offset();

    var outsideWidth = outside.width();
    var outsideHeight = outside.height();

    var insideWidth = inside.width();
    var insideHeight = inside.height();

    var outsideBlockerTopRight = $("<div>");
    var outsideBlockerBottomLeft = $("<div>");
    var insideBlockerTopRight = $("<div>");
    var insideBlockerBottomLeft = $("<div>");

    $('body').append(outsideBlockerTopRight)
    .append(outsideBlockerBottomLeft)
    .append(insideBlockerTopRight)
    .append(insideBlockerBottomLeft);

    outsideBlockerTopRight.css({
        "background-color": "#000",
        // "background-color": "#aa0000",
        // opacity: .5,
        position: "absolute",
        top: outsideOffset.top - 5,
        left: outsideOffset.left - 5,
        width: outside.outerWidth() + 10,
        height: outside.outerHeight(),
        "z-index": 15
    });

    outsideBlockerBottomLeft.css({
        "background-color": "#000",
        // "background-color": "#00aa00",
        // opacity: .5,
        position: "absolute",
        top: outsideOffset.top + 5,
        left: outsideOffset.left - 5,
        width: outsideWidth,
        height: outsideHeight + 10,
        "z-index": 15
    });

    insideBlockerTopRight.css({
        "background-color": "#000",
        // "background-color": "#0000aa",
        // opacity: .5,
        position: "absolute",
        top: insideOffset.top-3,
        left: insideOffset.left-5,
        width: insideWidth + 15,
        height: insideHeight,
        "z-index": 25
    });

    insideBlockerBottomLeft.css({
        "background-color": "#000",
        // "background-color": "#aa00aa",
        // opacity: .5,
        position: "absolute",
        top: insideOffset.top +5,
        left: insideOffset.left -3,
        width: insideWidth,
        height: insideHeight,
        "z-index": 25
    });

    outsideBlockerTopRight.animate({
        height: 10,
    }, 500).animate({
        width: 0,

    }, 500);

    outsideBlockerBottomLeft.animate({
        width: 20,
    }, 500);

    outsideBlockerBottomLeft.delay(500).animate({
        height: 0,
        top: (outsideOffset.top + outsideHeight)/2,
    }, 500);


    insideBlockerBottomLeft.animate({
        width: 0,
    }, 300);

    insideBlockerTopRight.delay(300).animate({
        height: 10,
    }, 500);

    insideBlockerTopRight.animate({
        width: 0,
        left: insideOffset.left + insideWidth
    }, 500);

    setTimeout(function(){
        outsideBlockerTopRight.remove();
        outsideBlockerBottomLeft.remove();
        insideBlockerTopRight.remove();
        insideBlockerBottomLeft.remove();
    }, 3000);

}

function hideContainer(){
    $(".lt-header").css("visibility", "hidden");
    $(".content-container").css("opacity", 0);
}

function showHeaders(){

    setTimeout(function showHeaders(){
        $(".lt-header").css("visibility", "visible");
        $(".content-container").css("visibility", "visible");

    }, 1000);

    setTimeout(function hideAnimations(){
        $(".lt-header-animator-outside").css("display", "none");
        $(".lt-header-animator-inside").css("display", "none");
    }, 1000);

}

function showContentBoxes(item, extraDelay) {

    var itemContent = item.find(".content");

    item.removeAttr("style");

    // .css() gives the height in the box's own box-sizing, which is what
    // animate() sets back (the merged column's boxes are border-box).
    var height = parseFloat(item.css("height"));
    var width = item.width();
    var left = item.position().left;
    var top = item.position().top;

    var border = item.css("border");
    var boxShadow = item.css("box-shadow");

    var contentBorder = itemContent.css("border");
    var contentBoxShadow = itemContent.css("box-shadow");

    itemContent.children().each(function(index, element){
        $(element).css("visibility", "hidden");
    });

    item.height(0)
    .width(0)
    .css("top", top + height/2)
    .css("left", left + width/2);

    setTimeout(function doHeaderAnimations(){

        item.animate({
            height: height,
            width: "100%",
            left: left,
            top: top

        }, 500);
        item.css({
            opacity: 1
        });
    }, 1500 + extraDelay);

    setTimeout(function(){

        itemContent.children().each(function(index, element){
            $(element).css("visibility", "visible");
        });


    }, 2200);

}

function hideContentBoxes(){
    var itemContent = item.find(".content");
    itemContent.children().each(function(index, element){
        $(element).css("visibility", "hidden");
    });
}




function createWebGlTest(){
    var canvas = document.getElementById('lt-webglCanvas');
    var renderer = new THREE.WebGLRenderer( { antialias : true, canvas: canvas } );
    var cameraDistance = 100;
    var camera = new THREE.PerspectiveCamera( 50, canvas.width / canvas.height, 1, 400 );
    var cameraAngle=0;
    var scene = new THREE.Scene();
    var splineGeometry = new Utils.VertexGeometry();
    var splineMaterial = new THREE.LineBasicMaterial({
        vertexColors: true,   // each channel has its own color (SYSTEM_CHANNELS)
        opacity: 0,
        transparent: true
    });

    var backdropGeometry = new Utils.VertexGeometry();
    var backdropMaterial = new THREE.LineBasicMaterial({
        color: 0x1b2f2d,
        opacity: 1,
        transparent: true
    });

    var cameraUp = false;

    // The canvas is sized by CSS (#lt-webglCanvas); fitCanvas() below keeps the
    // renderer and camera matched to it.
    renderer.setPixelRatio(window.devicePixelRatio);
    renderer.setSize(canvas.clientWidth || canvas.width, canvas.clientHeight || canvas.height, false);
    camera.position.z = cameraDistance;
    camera.lookAt(scene.position);

    var lastRenderDate = new Date();

    /* The tube is the system monitor: x is time (newest sample on the right),
     * and each of its sides is one channel whose radius is that channel's value.
     * Point i belongs to sample floor(i / channels) and channel i % channels. */
    var channels = SYSTEM_CHANNELS.length,
        points = SYSTEM_SAMPLES * channels,
        span = 0,                         // x extent of the tube, set by fitCanvas()
        step = 0,                         // x distance between points
        history = [],
        sampled = false;

    for(var t = 0; t < SYSTEM_SAMPLES; t++){
        history.push(SYSTEM_CHANNELS.map(function(){ return 0; }));
    }

    for(var i = 0; i < points; i++){
        splineGeometry.vertices.push(new THREE.Vector3());
    }
    var splineLine = new THREE.Line(splineGeometry.build(), splineMaterial);
    scene.add(splineLine);

    var colors = new Float32Array(points * 3);
    for(var i = 0; i < points; i++){
        new THREE.Color(SYSTEM_CHANNELS[i % channels].color).toArray(colors, i * 3);
    }
    splineGeometry.geometry.setAttribute("color", new THREE.BufferAttribute(colors, 3));

    // Rates have no fixed maximum: scale them to the largest value on screen.
    var channelScale = function(k){
        var channel = SYSTEM_CHANNELS[k];
        if(!channel.minScale){
            return 100;   // percentages
        }
        return history.reduce(function(max, sample){
            return Math.max(max, sample[k]);
        }, channel.minScale);
    };

    var rebuild = function(){
        var scales = SYSTEM_CHANNELS.map(function(channel, k){ return channelScale(k); });
        for(var i = 0; i < points; i++){
            var k = i % channels,
                value = Math.min(1, history[Math.floor(i / channels)][k] / scales[k]),
                radius = 3 + value * 35,
                angle = 2 * Math.PI * k / channels + i / points,
                vertex = splineGeometry.vertices[i];
            vertex.x = i * step - span / 2;
            vertex.y = radius * Math.sin(angle);
            vertex.z = radius * Math.cos(angle);
        }
        splineGeometry.verticesNeedUpdate = true;
        splineGeometry.update();
    };

    // Match the drawing buffer and camera to the canvas' CSS size, and stretch
    // the tube across the visible width minus the camera's ±20 sway and a margin.
    var fittedWidth = 0, fittedHeight = 0;
    var fitCanvas = function(){
        var width = canvas.clientWidth,
            height = canvas.clientHeight;
        if(!width || !height || (width === fittedWidth && height === fittedHeight)){
            return;
        }
        fittedWidth = width;
        fittedHeight = height;
        renderer.setSize(width, height, false);
        camera.aspect = width / height;
        camera.updateProjectionMatrix();
        var visibleHalfWidth = cameraDistance * Math.tan(THREE.MathUtils.degToRad(camera.fov / 2)) * camera.aspect;
        span = 2 * (visibleHalfWidth - 40);
        step = span / (points - 1);
        rebuild();
    };
    fitCanvas();
    rebuild();

    var lastSampleTime = Date.now();

    for(var i = 0; i< 25; i++){
        backdropGeometry.vertices.push(new THREE.Vector3(-1500,100-i*8,-100));
        backdropGeometry.vertices.push(new THREE.Vector3(1500,100-i*8,-100));
    }
    var backdropLine = new THREE.LineSegments(backdropGeometry.build(), backdropMaterial);
    scene.add(backdropLine);

    renderer.render( scene, camera );

    var firstRun = null;
    var introAnimationDone = false;

    return {
        tick: function (){
            if(firstRun === null){
                firstRun = Date.now() + 2500;
            }
            // renderer.render( this.scene, this.camera );
            var renderTime = new Date() - lastRenderDate;
            var timeSinceStart = Date.now() - firstRun;
            lastRenderDate = new Date();

            var rotateCameraBy = (2 * Math.PI)/(10000/renderTime);
            cameraAngle += rotateCameraBy;

            if(timeSinceStart < 3000){
                backdropMaterial.opacity = Math.max(0,(timeSinceStart-2000)/3000);
                splineMaterial.opacity = timeSinceStart/3000;
            } else if(!introAnimationDone){
                introAnimationDone = true;
                backdropMaterial.opacity = .333;
                splineMaterial.opacity = 1;
            }

            if(lastMessageTime !== null && !dataStreamOn){
                dataStreamOn = true;
                $("#datalink-status").text("CONNECTED");
                $("#datalink-status").css("color", "green");
            }

            if(Math.random() < .1){
                if((lastMessageTime === null && timeSinceStart > 8000) || (lastMessageTime !== null && Date.now() - lastMessageTime > 8000)){
                    $("#datalink-status").text("ERROR");
                    $("#datalink-status").css("color", "red");
                } 
            }


            camera.position.x = Math.sin(cameraAngle) * 20;

            // The panel grows in during the intro and changes size with the window.
            fitCanvas();

            // Slide left between samples so the history scrolls smoothly; each
            // new sample moves the points back by exactly this distance.
            var sinceSample = Math.min(1, (Date.now() - lastSampleTime) / SYSTEM_INTERVAL);
            splineLine.position.x = -sinceSample * channels * step;

            renderer.render(scene, camera );

            splineLine.rotation.x += .01;

        }, 
        reset: function(){
            firstRun = null;
        },
        // stats: a {stream: "system"} message (see system-stats.js / Feeds.js)
        addSample: function(stats){
            var sample = SYSTEM_CHANNELS.map(function(channel){
                return stats[channel.key] || 0;
            });
            if(!sampled){
                // Start from the first reading instead of an empty history.
                sampled = true;
                history = history.map(function(){ return sample.slice(); });
            }
            history.shift();
            history.push(sample);
            lastSampleTime = Date.now();
            rebuild();
            showSystemStats(stats);
        }
    };

}

function hideWebgl(){
    $('#lt-bandwidth').css("opacity", 0);
}

module.exports = LightTable;