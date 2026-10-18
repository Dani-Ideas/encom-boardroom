#include "systemstats.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QRandomGenerator>
#include <QRegularExpression>

#include <algorithm>

namespace {

QByteArray readProc(const QString &path)
{
    QFile file(path);
    // /proc files report size 0, so read until EOF instead of by size.
    return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray();
}

double random01()
{
    return QRandomGenerator::global()->generateDouble();
}

} // namespace

SystemReading SystemStats::sample()
{
    const QByteArray meminfo = readProc(QStringLiteral("/proc/meminfo"));
    const QByteArray stat = readProc(QStringLiteral("/proc/stat"));

    if (meminfo.isEmpty() || stat.isEmpty()) {
        // Not Linux, or no /proc: plausible values (Feeds.js exampleSystemStats).
        SystemReading &e = m_example;
        e.ram = std::clamp(e.ram + (random01() - 0.5) * 2, 20.0, 90.0);
        e.cpu = std::clamp(e.cpu * 0.7 + random01() * 8 + (random01() < 0.1 ? 50 : 0), 2.0, 100.0);
        e.netDown = random01() < 0.2 ? random01() * 3e6 : e.netDown * 0.5;
        e.diskWrite = random01() < 0.1 ? random01() * 2e7 : e.diskWrite * 0.3;
        return e;
    }

    SystemReading reading;
    Counters now;
    now.timeMs = QDateTime::currentMSecsSinceEpoch();

    // RAM: 1 - MemAvailable / MemTotal
    double total = 0, available = 0;
    for (const QByteArray &line : meminfo.split('\n')) {
        if (line.startsWith("MemTotal:"))
            total = line.simplified().split(' ').value(1).toDouble();
        else if (line.startsWith("MemAvailable:"))
            available = line.simplified().split(' ').value(1).toDouble();
    }
    if (total > 0)
        reading.ram = 100.0 * (1.0 - available / total);

    // CPU: the aggregate "cpu" line, user nice system idle iowait irq softirq steal
    const QList<QByteArray> cpu = stat.left(stat.indexOf('\n')).simplified().split(' ');
    for (int i = 1; i <= 8 && i < cpu.size(); ++i)
        now.cpuTotal += cpu[i].toULongLong();
    now.cpuIdle = cpu.value(4).toULongLong() + cpu.value(5).toULongLong();

    // Download: received bytes on every interface except loopback
    const QList<QByteArray> dev = readProc(QStringLiteral("/proc/net/dev")).split('\n');
    for (int i = 2; i < dev.size(); ++i) {
        const QByteArray line = dev[i].simplified();
        const int colon = line.indexOf(':');
        if (colon <= 0 || line.left(colon) == "lo")
            continue;
        now.netReceived += line.mid(colon + 1).simplified().split(' ').value(0).toULongLong();
    }

    // Disk writes: sectors written on whole disks (those in /sys/block, minus
    // loop/ram/zram), so partitions aren't counted twice. Sectors are 512 bytes.
    static const QRegularExpression virtualDisk(QStringLiteral("^(loop|ram|zram)"));
    QStringList disks = QDir(QStringLiteral("/sys/block")).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    disks.removeIf([](const QString &name) { return virtualDisk.match(name).hasMatch(); });
    for (const QByteArray &line : readProc(QStringLiteral("/proc/diskstats")).split('\n')) {
        const QList<QByteArray> parts = line.simplified().split(' ');
        if (parts.size() > 9 && disks.contains(QString::fromLatin1(parts[2])))
            now.diskWritten += parts[9].toULongLong() * 512;
    }

    if (m_previous) {
        const Counters &before = *m_previous;
        const double seconds = std::max(0.001, (now.timeMs - before.timeMs) / 1000.0);
        if (now.cpuTotal > before.cpuTotal)
            reading.cpu = 100.0 * (1.0 - double(now.cpuIdle - before.cpuIdle) / double(now.cpuTotal - before.cpuTotal));
        if (now.netReceived >= before.netReceived)
            reading.netDown = (now.netReceived - before.netReceived) / seconds;
        if (now.diskWritten >= before.diskWritten)
            reading.diskWrite = (now.diskWritten - before.diskWritten) / seconds;
    }
    m_previous = now;
    return reading;
}
