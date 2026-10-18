#!/bin/bash
# Encom Boardroom login screen (SDDM theme in sddm-theme/).
#
#   ./install-sddm-theme.sh test        build and preview it full screen, without installing,
#                                       in debug mode (the password and each key are shown)
#   ./install-sddm-theme.sh install     build, copy to /usr/share/sddm/themes and select it (sudo)
#   ./install-sddm-theme.sh uninstall   go back to the previous theme (sudo)
#
# If the login screen ever fails to start, press Ctrl+Alt+F3, log in on the
# console and run:  sudo rm /etc/sddm.conf.d/zz-encom-boardroom.conf
set -e
cd "$(dirname "$0")"

THEME_NAME=encom-boardroom
THEME_DIR=/usr/share/sddm/themes/$THEME_NAME
CONF=/etc/sddm.conf.d/zz-$THEME_NAME.conf   # "zz-" so it overrides kde_settings.conf

build() {
    sddm-theme/native/build.sh
}

case "$1" in
    test)
        build
        # debug mode only for the preview: theme.conf.user overrides theme.conf
        # and is never installed
        printf '[General]\ndebugInput=true\n' > sddm-theme/theme.conf.user
        trap 'rm -f sddm-theme/theme.conf.user' EXIT
        echo "Vista previa en modo depuración: la contraseña y cada tecla se muestran."
        echo "El modo prueba no verifica contraseñas. Cierra con Alt+F4."
        sddm-greeter-qt6 --test-mode --theme "$PWD/sddm-theme"
        ;;
    install)
        build
        sudo rm -rf "$THEME_DIR"
        sudo mkdir -p "$THEME_DIR"
        # the theme without the plugin's sources and build tree
        sudo cp -r sddm-theme/*.qml sddm-theme/*.js sddm-theme/qmldir sddm-theme/metadata.desktop sddm-theme/theme.conf \
                   sddm-theme/*.ttf sddm-theme/*.png sddm-theme/EncomSystem "$THEME_DIR/"
        printf '[Theme]\nCurrent=%s\n' "$THEME_NAME" | sudo tee "$CONF" > /dev/null
        echo "Instalado en $THEME_DIR y seleccionado en $CONF."
        echo "Se verá la próxima vez que se muestre el login (cierra sesión o reinicia)."
        ;;
    uninstall)
        sudo rm -f "$CONF"
        sudo rm -rf "$THEME_DIR"
        echo "Quitado. SDDM vuelve al tema de /etc/sddm.conf.d/kde_settings.conf."
        ;;
    *)
        sed -n '2,10p' "$0"
        exit 1
        ;;
esac
