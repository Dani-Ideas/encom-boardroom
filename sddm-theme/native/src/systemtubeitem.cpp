#include "systemtubeitem.h"

#include <QSGGeometryNode>
#include <QSGVertexColorMaterial>

#include <algorithm>
#include <cmath>

namespace {

struct Channel {
    QColor color;
    double minScale; // 0 = a percentage; otherwise the smallest full-scale rate
};

// Same order and colors as SYSTEM_CHANNELS in src/LightTable.js.
const Channel channels[] = {
    { QColor(0x00, 0xee, 0xee), 0 },   // RAM
    { QColor(0xff, 0xcc, 0x00), 0 },   // CPU
    { QColor(0xff, 0xff, 0xff), 1e6 }, // download, bytes/s
    { QColor(0xff, 0x50, 0x50), 5e6 }, // disk writes, bytes/s
};

const QColor backdropColor(0x1b, 0x2f, 0x2d);

// QSGVertexColorMaterial expects premultiplied colors.
void setVertex(QSGGeometry::ColoredPoint2D &v, float x, float y, const QColor &c, float alpha)
{
    const float a = float(c.alphaF()) * alpha;
    v.set(x, y, uchar(c.red() * a), uchar(c.green() * a), uchar(c.blue() * a), uchar(255 * a));
}

} // namespace

SystemTubeItem::SystemTubeItem(QQuickItem *parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents, true);
    m_clock.start();

    connect(&m_sampleTimer, &QTimer::timeout, this, &SystemTubeItem::addSample);
    m_sampleTimer.start(IntervalMs);
    addSample();

    // 30 fps is plenty for the slow rotation; the geometry is rebuilt on the
    // render thread from the history, which costs next to nothing.
    connect(&m_frameTimer, &QTimer::timeout, this, &QQuickItem::update);
    m_frameTimer.start(33);
}

void SystemTubeItem::setReveal(qreal reveal)
{
    if (qFuzzyCompare(reveal, m_reveal))
        return;
    m_reveal = reveal;
    emit revealChanged();
}

void SystemTubeItem::addSample()
{
    const SystemReading r = m_stats.sample();
    const std::array<float, Channels> sample{ float(r.ram), float(r.cpu), float(r.netDown), float(r.diskWrite) };

    // Start from the first reading instead of an empty history.
    if (m_history.empty())
        m_history.assign(Samples, sample);
    m_history.pop_front();
    m_history.push_back(sample);
    m_lastSampleMs = m_clock.elapsed();

    m_latest = { { QStringLiteral("ram"), r.ram },
                 { QStringLiteral("cpu"), r.cpu },
                 { QStringLiteral("netDown"), r.netDown },
                 { QStringLiteral("diskWrite"), r.diskWrite },
                 { QStringLiteral("example"), r.example } };
    emit latestChanged();
}

QSGNode *SystemTubeItem::updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *)
{
    constexpr int backdropLines = 25;
    constexpr int points = Samples * Channels;
    constexpr int vertexCount = backdropLines * 2 + (points - 1) * 2;

    auto *node = static_cast<QSGGeometryNode *>(oldNode);
    if (!node) {
        node = new QSGGeometryNode;
        auto *geometry = new QSGGeometry(QSGGeometry::defaultAttributes_ColoredPoint2D(), vertexCount);
        geometry->setDrawingMode(QSGGeometry::DrawLines);
        geometry->setLineWidth(1);
        node->setGeometry(geometry);
        node->setMaterial(new QSGVertexColorMaterial);
        node->setFlags(QSGNode::OwnsGeometry | QSGNode::OwnsMaterial);
    }

    const float w = float(width()), h = float(height());
    if (w <= 0 || h <= 0 || m_history.empty())
        return node;

    const double t = m_clock.elapsed() / 1000.0;
    const double fov = 50.0 * M_PI / 180.0;
    const double focal = (h / 2) / std::tan(fov / 2);
    const double cameraX = std::sin(2 * M_PI * t / 10.0) * 20;
    const double rotation = t * 0.6; // .01 rad a frame at 60 fps, as in the mockup

    auto project = [&](double x, double y, double z, float &sx, float &sy) {
        const double depth = 100 - z;
        sx = float(w / 2 + (x - cameraX) * focal / depth);
        sy = float(h / 2 - y * focal / depth);
    };

    QSGGeometry::ColoredPoint2D *v = node->geometry()->vertexDataAsColoredPoint2D();
    const float reveal = float(m_reveal);

    // backdrop: dark horizontal lines on a plane behind the tube
    for (int i = 0; i < backdropLines; ++i) {
        float x0, y0, x1, y1;
        project(-1500, 100 - i * 8, -100, x0, y0);
        project(1500, 100 - i * 8, -100, x1, y1);
        setVertex(*v++, x0, y0, backdropColor, 0.333f * reveal);
        setVertex(*v++, x1, y1, backdropColor, 0.333f * reveal);
    }

    // rates have no fixed maximum: scale them to the largest value on screen
    double scales[Channels];
    for (int k = 0; k < Channels; ++k) {
        scales[k] = channels[k].minScale > 0 ? channels[k].minScale : 100.0;
        if (channels[k].minScale > 0) {
            for (const auto &sample : m_history)
                scales[k] = std::max(scales[k], double(sample[k]));
        }
    }

    const double visibleHalfWidth = 100 * std::tan(fov / 2) * (w / h);
    const double span = 2 * (visibleHalfWidth - 40);
    const double step = span / (points - 1);
    // slide left between samples so the history scrolls smoothly
    const double sinceSample = std::min(1.0, double(m_clock.elapsed() - m_lastSampleMs) / IntervalMs);
    const double slide = sinceSample * Channels * step;
    const double cosR = std::cos(rotation), sinR = std::sin(rotation);

    float previousX = 0, previousY = 0;
    for (int i = 0; i < points; ++i) {
        const int k = i % Channels;
        const double value = std::min(1.0, m_history[i / Channels][k] / scales[k]);
        const double radius = 3 + value * 35;
        const double angle = 2 * M_PI * k / Channels + double(i) / points;
        const double y = radius * std::sin(angle), z = radius * std::cos(angle);
        float sx, sy;
        // rotate around x
        project(i * step - span / 2 - slide, y * cosR - z * sinR, y * sinR + z * cosR, sx, sy);
        if (i > 0) {
            // each segment takes its start point's channel color
            const QColor &color = channels[(i - 1) % Channels].color;
            setVertex(*v++, previousX, previousY, color, reveal);
            setVertex(*v++, sx, sy, color, reveal);
        }
        previousX = sx;
        previousY = sy;
    }

    node->markDirty(QSGNode::DirtyGeometry);
    return node;
}
