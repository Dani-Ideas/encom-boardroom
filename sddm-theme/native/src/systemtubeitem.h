#pragma once

#include "systemstats.h"

#include <QColor>
#include <QElapsedTimer>
#include <QQuickItem>
#include <QTimer>
#include <QVariantMap>

#include <array>
#include <deque>

// The login screen's system monitor (native port of the mockup's bandwidth
// tube, createWebGlTest in src/LightTable.js). Samples /proc every second and
// draws the history as a rotating tube of colored lines in the scene graph:
// x is time (newest on the right) and each side of the tube is one channel
// (RAM, CPU, download, disk writes) whose radius is that channel's value.
// The perspective matches the three.js original: camera at z=100, 50° vertical
// field of view, swaying ±20 sideways every 10 s.
class SystemTubeItem : public QQuickItem
{
    Q_OBJECT
    // Fades the tube in (0..1).
    Q_PROPERTY(qreal reveal READ reveal WRITE setReveal NOTIFY revealChanged)
    // The last reading: {ram, cpu, netDown, diskWrite, example}.
    Q_PROPERTY(QVariantMap latest READ latest NOTIFY latestChanged)

public:
    explicit SystemTubeItem(QQuickItem *parent = nullptr);

    qreal reveal() const { return m_reveal; }
    void setReveal(qreal reveal);
    QVariantMap latest() const { return m_latest; }

signals:
    void revealChanged();
    void latestChanged();

protected:
    QSGNode *updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *) override;

private:
    static constexpr int Channels = 4;
    static constexpr int Samples = 150; // at one a second, 2.5 minutes
    static constexpr int IntervalMs = 1000;

    void addSample();

    SystemStats m_stats;
    std::deque<std::array<float, Channels>> m_history;
    QVariantMap m_latest;
    qreal m_reveal = 1.0;

    QTimer m_sampleTimer;
    QTimer m_frameTimer;
    QElapsedTimer m_clock;      // drives rotation and sway
    qint64 m_lastSampleMs = 0;  // on m_clock
};
