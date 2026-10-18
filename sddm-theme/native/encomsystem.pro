TEMPLATE = lib
CONFIG += plugin c++17
QT += qml quick
TARGET = encomsystemplugin

SOURCES += src/plugin.cpp src/systemtubeitem.cpp src/systemstats.cpp
HEADERS += src/systemtubeitem.h src/systemstats.h
