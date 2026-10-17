var $ = require("jquery"),
    Boardroom = require("./Boardroom.js"),
    LightTable = require("./LightTable.js"),
    Feeds = require("./Feeds.js"),
    PleaseRotate = require("pleaserotate.js"),
    init = false;

// The only thing jQuery UI was used for.
$.easing.easeInOutBack = function(p){
    var c1 = 1.70158, c2 = c1 * 1.525;
    return p < 0.5
        ? (Math.pow(2 * p, 2) * ((c2 + 1) * 2 * p - c2)) / 2
        : (Math.pow(2 * p - 2, 2) * ((c2 + 1) * (p * 2 - 2) + c2) + 2) / 2;
};

$.fn.center = function (scale) {

    var top = Math.max(0, (($(window).height() - $(this).outerHeight()) / 2 - 50) + $(window).scrollTop());
    var left = Math.max(0, (($(window).width() - $(this).outerWidth()) / 2) + $(window).scrollLeft());

    if(scale){
        top = Math.max(0, (($(window).height() - $(this).outerHeight() * scale) / 2 - 50) + $(window).scrollTop());
        left = Math.max(0, (($(window).width() - $(this).outerWidth() * scale) / 2) + $(window).scrollLeft());
    }

    this.css("position","fixed");
    this.css("top", top + "px");
    this.css("left", left + "px");
    return this;
}

var active = "lt";
var esPath = "/events.js";
if(window._esPath){
    esPath = window._esPath;
}
var feeds = new Feeds(function(message){
    if(active === "lt"){
        LightTable.message(message);
    } else {
        setTimeout(function(){
            Boardroom.message(message);
        }, 3000 * Math.random());
    }
}, esPath);


var onSwitch = function(view){
    feeds.select(view);
    var screensaver = $("#screensaver");
    screensaver.center();
    screensaver.css({visibility: "visible"});

    screensaver.delay(3000).animate({ opacity: 0 },{ 
        step: function(now, tween){ 
            screensaver.css('transform', 'scale(' + now + ',' + now + '');
        },
        duration: 600, 
        easing: "easeInOutBack"});

    if(view === "github"){

        screensaver.text("GITHUB");
        LightTable.hide();
        Boardroom.init("github", window.githubHistory);

        setTimeout(function(){
            active = "br";
            Boardroom.show();
        }, 3000)

    } else if (view === "wikipedia"){
        $("#screensaver").text("WIKIPEDIA");
        LightTable.hide();
        Boardroom.init("wikipedia");
        setTimeout(function(){
            active = "br";
            Boardroom.show();
        }, 3000)

    } else if (view === "test"){
        $("#screensaver").text("TEST DATA");
        LightTable.hide();
        Boardroom.init("test");
        setTimeout(function(){
            active = "br";
            Boardroom.show();
        }, 3000)

        /* lets just throw some data in there */

        setInterval(function(){
            if(Boardroom){
                Boardroom.message({
                    stream: 'test',
                    latlon: {
                        lat: Math.random() * 180 - 90,
                        lon: Math.random() * 360 - 180
                    },
                    location: 'Test ' + Math.floor(Math.random() * 100),
                    type: 'Type ' + Math.floor(Math.random() * 8),
                    picSmall: 'images/not_available_small.png',
                    picLarge: 'images/not_available_large.png',
                    username: "arscan" + Math.floor(Math.random()*1000),
                    userurl: "http://github.com/arscan",
                    title: "Test " + Math.floor(Math.random() * 100),
                    url: "http://github.com/arscan/encom-boardroom/",
                    size: Math.floor(Math.random()*10000),
                    popularity: Math.floor(Math.random()*10000)
                });
            }

        }, 800);
    }

};

PleaseRotate.start({onHide: function(){
    if(init){
        return;
    }
    init = true;
    try {
        LightTable.init(onSwitch);

    } catch (ex){

        
        $("#error-message")
           .css("visibility", "visible")
           .center();

        console.log(ex);

        return;


    }
    $("#light-table").center();
    $("#boardroom").center();
    LightTable.show();

    var animate = function(){

        if(active === "lt"){
            LightTable.animate();
        } else {
            Boardroom.animate()
        }

        requestAnimationFrame(animate);
    };

    animate();

    var timeout = 0;
    function onWindowResize(){

        if(active === "lt"){
            LightTable.resize();
        } else {
            Boardroom.resize();
        }
    }

    window.addEventListener( 'resize', onWindowResize, false );

}});

