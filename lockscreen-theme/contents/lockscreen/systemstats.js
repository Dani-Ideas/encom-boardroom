.pragma library

// QML port of ../system-stats.js: RAM and CPU in percent, download and disk
// writes in bytes per second since the previous sample(). Reading files from
// QML needs QML_XHR_ALLOW_FILE_READ=1 in the greeter's environment
// (install-sddm-theme.sh sets it); without it sample() returns null and the
// monitor shows example values instead.

function read(path) {
    var request = new XMLHttpRequest();
    try {
        request.open("GET", "file://" + path, false);
        request.send(null);
    } catch (ex) {
        return null;
    }
    return request.responseText || null;
}

function ramPercent(info) {
    var total = /MemTotal:\s+(\d+)/.exec(info);
    var available = /MemAvailable:\s+(\d+)/.exec(info);
    return total && available ? 100 * (1 - available[1] / total[1]) : null;
}

// Aggregate "cpu" line: user nice system idle iowait irq softirq steal ...
function cpuTimes(stat) {
    var fields = stat.split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
    var total = 0;
    for (var i = 0; i < fields.length; i++)
        total += fields[i];
    return { idle: fields[3] + fields[4], total: total };
}

// Received bytes on every interface except loopback.
function netReceived(dev) {
    var sum = 0;
    var lines = dev.split("\n").slice(2);
    for (var i = 0; i < lines.length; i++) {
        var parts = lines[i].trim().split(/[:\s]+/);
        if (parts.length > 1 && parts[0] !== "lo")
            sum += Number(parts[1]);
    }
    return sum;
}

// Whole disks only, so partitions aren't counted twice. QML can't list
// /sys/block like system-stats.js does, so match the usual device names.
// Sectors are 512 bytes.
var wholeDisk = /^(sd[a-z]+|vd[a-z]+|hd[a-z]+|xvd[a-z]+|nvme\d+n\d+|mmcblk\d+)$/;

function diskWritten(stats) {
    var sum = 0;
    var lines = stats.split("\n");
    for (var i = 0; i < lines.length; i++) {
        var parts = lines[i].trim().split(/\s+/);
        if (wholeDisk.test(parts[2]))
            sum += Number(parts[9]) * 512;
    }
    return sum;
}

var previous = null;

function sample() {
    var meminfo = read("/proc/meminfo"), stat = read("/proc/stat");
    if (!meminfo || !stat)
        return null;
    var dev = read("/proc/net/dev"), disk = read("/proc/diskstats");

    var now = { time: Date.now(), cpu: cpuTimes(stat),
                net: dev ? netReceived(dev) : null, disk: disk ? diskWritten(disk) : null };
    var result = { ram: ramPercent(meminfo), cpu: null, netDown: null, diskWrite: null };

    if (previous) {
        var seconds = Math.max(0.001, (now.time - previous.time) / 1000);
        if (now.cpu.total > previous.cpu.total)
            result.cpu = 100 * (1 - (now.cpu.idle - previous.cpu.idle) / (now.cpu.total - previous.cpu.total));
        if (now.net !== null && previous.net !== null)
            result.netDown = Math.max(0, now.net - previous.net) / seconds;
        if (now.disk !== null && previous.disk !== null)
            result.diskWrite = Math.max(0, now.disk - previous.disk) / seconds;
    }
    previous = now;
    return result;
}

// Plausible values when /proc can't be read (port of Feeds.js exampleSystemStats).
var example = { ram: 40, cpu: 10, net: 0, disk: 0 };

function exampleSample() {
    example.ram = Math.min(90, Math.max(20, example.ram + (Math.random() - 0.5) * 2));
    example.cpu = Math.min(100, Math.max(2, example.cpu * 0.7 + Math.random() * 8 + (Math.random() < 0.1 ? 50 : 0)));
    example.net = Math.random() < 0.2 ? Math.random() * 3e6 : example.net * 0.5;
    example.disk = Math.random() < 0.1 ? Math.random() * 2e7 : example.disk * 0.3;
    return { ram: example.ram, cpu: example.cpu, netDown: example.net, diskWrite: example.disk, example: true };
}
