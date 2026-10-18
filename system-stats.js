/* Samples this machine's RAM, CPU, network download and disk writes from
 * /proc (Linux only) for the light table's bandwidth panel.
 * sample() returns {ram, cpu} in percent and {netDown, diskWrite} in bytes
 * per second since the previous call, or null where /proc isn't available. */

var fs = require("fs");

function read(file){
    try {
        return fs.readFileSync(file, "utf8");
    } catch(ex){
        return null;
    }
}

function ramPercent(){
    var info = read("/proc/meminfo");
    if(!info){
        return null;
    }
    var total = /MemTotal:\s+(\d+)/.exec(info),
        available = /MemAvailable:\s+(\d+)/.exec(info);
    return total && available ? 100 * (1 - available[1] / total[1]) : null;
}

// Aggregate "cpu" line: user nice system idle iowait irq softirq steal ...
function cpuTimes(){
    var stat = read("/proc/stat");
    if(!stat){
        return null;
    }
    var fields = stat.split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
    return {idle: fields[3] + fields[4], total: fields.reduce(function(a, b){ return a + b; }, 0)};
}

// Received bytes on every interface except loopback.
function netReceived(){
    var dev = read("/proc/net/dev");
    if(!dev){
        return null;
    }
    return dev.split("\n").slice(2).reduce(function(sum, line){
        var parts = line.trim().split(/[:\s]+/);
        return parts.length > 1 && parts[0] !== "lo" ? sum + Number(parts[1]) : sum;
    }, 0);
}

// Sectors written on whole disks (the ones in /sys/block, minus loop/ram/zram
// devices), so partitions aren't counted twice. Sectors are always 512 bytes here.
function diskWritten(){
    var stats = read("/proc/diskstats");
    if(!stats){
        return null;
    }
    var disks = fs.readdirSync("/sys/block").filter(function(name){
        return !/^(loop|ram|zram)/.test(name);
    });
    return stats.split("\n").reduce(function(sum, line){
        var parts = line.trim().split(/\s+/);
        return disks.indexOf(parts[2]) >= 0 ? sum + Number(parts[9]) * 512 : sum;
    }, 0);
}

var previous = null;

function sample(){
    var now = {time: Date.now(), cpu: cpuTimes(), net: netReceived(), disk: diskWritten()},
        result = {ram: ramPercent(), cpu: null, netDown: null, diskWrite: null};

    if(previous){
        var seconds = Math.max(0.001, (now.time - previous.time) / 1000);
        if(now.cpu && previous.cpu && now.cpu.total > previous.cpu.total){
            result.cpu = 100 * (1 - (now.cpu.idle - previous.cpu.idle) / (now.cpu.total - previous.cpu.total));
        }
        if(now.net !== null && previous.net !== null){
            result.netDown = Math.max(0, now.net - previous.net) / seconds;
        }
        if(now.disk !== null && previous.disk !== null){
            result.diskWrite = Math.max(0, now.disk - previous.disk) / seconds;
        }
    }
    previous = now;
    return result;
}

module.exports = {sample: sample};
