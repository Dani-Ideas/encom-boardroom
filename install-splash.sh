#!/bin/bash
# Dani-Ideas splash screen for Plasma (the screen right after login, while the
# desktop loads), from plasma-splash/.
#
#   ./install-splash.sh test        preview it in a window, without installing
#   ./install-splash.sh install     install it for this user and select it
#   ./install-splash.sh uninstall   remove it and go back to the default splash
#
# It can also be picked in System Settings > Colors & Themes > Splash Screen.
set -e
cd "$(dirname "$0")"

ID=com.daniideas.encom.splash
INSTALLED="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/look-and-feel/$ID"

# The splash belongs to your user (~/.local/share, ~/.config/ksplashrc); with
# sudo it would go to root's home and never show up.
if [ "$(id -u)" = 0 ]; then
    echo "No uses sudo: este tema se instala solo para tu usuario. Ejecuta ./install-splash.sh $1" >&2
    exit 1
fi

case "$1" in
    test)
        ksplashqml --test --window "$PWD/plasma-splash"
        ;;
    install)
        # (kpackagetool6 --show can't tell: for an unknown id it shows Breeze and succeeds)
        if [ -d "$INSTALLED" ]; then
            kpackagetool6 --type Plasma/LookAndFeel --upgrade plasma-splash
        else
            kpackagetool6 --type Plasma/LookAndFeel --install plasma-splash
        fi
        kwriteconfig6 --file ksplashrc --group KSplash --key Engine KSplashQML
        kwriteconfig6 --file ksplashrc --group KSplash --key Theme "$ID"
        echo "Instalado y seleccionado. Se verá la próxima vez que inicies sesión."
        ;;
    uninstall)
        kpackagetool6 --type Plasma/LookAndFeel --remove "$ID" || true
        kwriteconfig6 --file ksplashrc --group KSplash --key Theme --delete
        echo "Quitado. Plasma vuelve a la pantalla de bienvenida predeterminada."
        ;;
    *)
        sed -n '2,10p' "$0"
        exit 1
        ;;
esac
