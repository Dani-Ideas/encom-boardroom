#!/bin/bash
# Encom Boardroom boot animation (Plymouth theme in plymouth-theme/).
#
#   ./install-plymouth-theme.sh test        preview it for ~12 s (takes over the screen, then comes back)
#   ./install-plymouth-theme.sh install     install it and rebuild the initramfs so it shows at boot
#   ./install-plymouth-theme.sh uninstall   go back to the previous theme
#
# Run it without sudo; it asks for sudo itself. A broken Plymouth theme never
# stops the computer from booting: at worst the boot shows a black screen or
# text, and `./install-plymouth-theme.sh uninstall` puts the old one back.
set -e
cd "$(dirname "$0")"

NAME=encom-boardroom
THEME_DIR=/usr/share/plymouth/themes/$NAME
PREVIOUS_FILE=$THEME_DIR/.previous-theme

if [ "$(id -u)" = 0 ]; then
    echo "Ejecútalo sin sudo; el script lo pide cuando hace falta." >&2
    exit 1
fi

copy_theme() {
    python3 plymouth-theme/make-theme.py
    local current
    current=$(plymouth-set-default-theme)
    sudo mkdir -p "$THEME_DIR"
    sudo cp plymouth-theme/build/* "$THEME_DIR/"
    # remember the theme to go back to (only the first time)
    if [ "$current" != "$NAME" ] && [ ! -f "$PREVIOUS_FILE" ]; then
        echo "$current" | sudo tee "$PREVIOUS_FILE" > /dev/null
    fi
}

case "$1" in
    test)
        copy_theme
        current=$(plymouth-set-default-theme)
        sudo plymouth-set-default-theme "$NAME"   # just the config, no initramfs rebuild
        echo "Vista previa por ~12 s..."
        sudo plymouthd --debug --debug-file=/tmp/plymouth-$NAME.log
        sudo plymouth --show-splash
        for step in 1 2 3 4 5 6; do
            sudo plymouth --update="test-step-$step.service"
            sleep 2
        done
        sudo plymouth --quit
        sudo plymouth-set-default-theme "$current"
        echo "Listo. Registro de depuración en /tmp/plymouth-$NAME.log"
        ;;
    install)
        copy_theme
        echo "Seleccionando el tema y reconstruyendo el initramfs (tarda un poco)..."
        sudo plymouth-set-default-theme -R "$NAME"
        echo "Instalado. Se verá en el próximo arranque."
        ;;
    uninstall)
        previous=manjaro
        [ -f "$PREVIOUS_FILE" ] && previous=$(cat "$PREVIOUS_FILE")
        sudo plymouth-set-default-theme -R "$previous"
        sudo rm -rf "$THEME_DIR"
        echo "Quitado. Plymouth vuelve a '$previous'."
        ;;
    *)
        sed -n '2,11p' "$0"
        exit 1
        ;;
esac
