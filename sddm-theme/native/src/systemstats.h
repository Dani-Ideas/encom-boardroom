#pragma once

#include <QtGlobal>
#include <optional>

// One reading of this machine (port of ../../system-stats.js): RAM and CPU in
// percent, download and disk writes in bytes per second since the previous
// sample. `example` marks made-up values, used when /proc can't be read.
struct SystemReading {
    double ram = 0;
    double cpu = 0;
    double netDown = 0;
    double diskWrite = 0;
    bool example = false;
};

class SystemStats
{
public:
    SystemReading sample();

private:
    struct Counters {
        qint64 timeMs = 0;
        quint64 cpuIdle = 0;
        quint64 cpuTotal = 0;
        quint64 netReceived = 0;
        quint64 diskWritten = 0;
    };

    std::optional<Counters> m_previous;
    SystemReading m_example{ 40, 10, 0, 0, true };
};
