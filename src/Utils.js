var THREE = require("three");

var Utils = {};

/* Holds a THREE.Geometry-style `vertices` array of Vector3s for code written
 * against the old API; build() makes the BufferGeometry and update() copies
 * the vertices into it when verticesNeedUpdate is set. */
Utils.VertexGeometry = function(){
    this.vertices = [];
    this.verticesNeedUpdate = false;
    this.geometry = new THREE.BufferGeometry();
};

Utils.VertexGeometry.prototype.build = function(){
    this.geometry.setAttribute("position", new THREE.BufferAttribute(new Float32Array(this.vertices.length * 3), 3));
    this.verticesNeedUpdate = true;
    this.update();
    return this.geometry;
};

Utils.VertexGeometry.prototype.update = function(){
    if(!this.verticesNeedUpdate){
        return;
    }
    var position = this.geometry.attributes.position;
    for(var i = 0; i < this.vertices.length; i++){
        position.setXYZ(i, this.vertices[i].x, this.vertices[i].y, this.vertices[i].z);
    }
    position.needsUpdate = true;
    this.geometry.computeBoundingSphere();
    this.verticesNeedUpdate = false;
};

/* Canvas textures hold sRGB pixels. */
Utils.canvasTexture = function(canvas){
    var texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    return texture;
};

/* Mix two #rrggbb colors, t = 0 gives a, t = 1 gives b (replaces pusher.color's blend). */
Utils.blendColor = function(a, b, t){
    var x = parseInt(a.slice(1), 16),
        y = parseInt(b.slice(1), 16),
        out = 0;
    for(var shift = 16; shift >= 0; shift -= 8){
        var ca = (x >> shift) & 0xff,
            cb = (y >> shift) & 0xff;
        out |= Math.round(ca + (cb - ca) * t) << shift;
    }
    return "#" + (0x1000000 + out).toString(16).slice(1);
};

Utils.renderToCanvas = function (width, height, renderFunction) {
    var buffer = document.createElement('canvas');
    buffer.width = width;
    buffer.height = height;
    renderFunction(buffer.getContext('2d'));
    return buffer;
};

Utils.extend = function(first, second) {
    for(var i in first){
        second[i] = first[i];
    }
};

Utils.sCurve = function(t) {
    return 1/(1 + Math.exp(-t*12 + 6));
};

// http://stackoverflow.com/a/13542669
Utils.shadeColor = function(color, percent) {   
    var num = parseInt(color.slice(1),16), 
    amt = Math.round(2.55 * percent), 
    R = (num >> 16) + amt, 
    G = (num >> 8 & 0x00FF) + amt, 
    B = (num & 0x0000FF) + amt;

    return "#" + (0x1000000 + (R<255?R<1?0:R:255)*0x10000 + (G<255?G<1?0:G:255)*0x100 + (B<255?B<1?0:B:255)).toString(16).slice(1);
}

Utils.drawCurvedRectangle = function(ctx, left, top, width, height, radius){

    ctx.beginPath();
    ctx.moveTo(left + radius, top);
    ctx.lineTo(left + width - radius, top);
    ctx.quadraticCurveTo(left + width, top, left + width, top + radius);
    ctx.lineTo(left + width, top + height - radius);
    ctx.quadraticCurveTo(left + width, top + height, left + width - radius, top + height);
    ctx.lineTo(left + radius, top + height);
    ctx.quadraticCurveTo(left, top + height, left, top + height - radius);
    ctx.lineTo(left, top + radius);
    ctx.quadraticCurveTo(left, top, left + radius, top);
    ctx.stroke();
    ctx.fill();
    ctx.closePath();
}

module.exports = Utils;
