#!/bin/bash
# Builds the SystemTube plugin into sddm-theme/EncomSystem/, where Main.qml's
# monitor imports it from (a local directory import, no QML_IMPORT_PATH).
set -e
cd "$(dirname "$0")"

mkdir -p build
(cd build && qmake6 ../encomsystem.pro && make -j"$(nproc)")

MODULE_DIR=../EncomSystem
mkdir -p "$MODULE_DIR"
cp build/libencomsystemplugin.so module/qmldir "$MODULE_DIR/"
echo "Plugin listo en sddm-theme/EncomSystem"
