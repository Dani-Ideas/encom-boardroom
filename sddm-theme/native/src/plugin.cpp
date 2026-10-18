#include <QQmlExtensionPlugin>
#include <qqml.h>

#include "systemtubeitem.h"

class EncomSystemPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterType<SystemTubeItem>(uri, 1, 0, "SystemTube");
    }
};

#include "plugin.moc"
