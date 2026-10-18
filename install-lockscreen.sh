#!/bin/bash
# Encom Boardroom lock screen (lockscreen-theme/): what you see after locking
# (Super+L) or waking from sleep. Same look as the SDDM login, separate files.
#
#   ./install-lockscreen.sh test        try it in a window; unlock with your password to close it
#   ./install-lockscreen.sh install     use it as the lock screen
#   ./install-lockscreen.sh uninstall   go back to Plasma's lock screen
#
# Plasma 6 takes the lock screen from the desktop shell package
# (org.kde.plasma.desktop) and has no setting to pick another one. So
# `install` puts a local copy of that package in ~/.local/share/plasma/shells
# (it's ~500 KB) with this theme as its contents/lockscreen; the desktop keeps
# using the same files. (Links don't work: KPackage refuses files outside the
# package folder.) A small systemd user service re-copies the system package
# before Plasma starts at every login, so a Plasma update never leaves the
# copy stale.
#
# If this lock screen fails to load, Plasma falls back to its built-in basic
# locker, so you can still unlock. To go back: ./install-lockscreen.sh uninstall
#
# Careful: every wrong password (in `test` too) counts for pam_faillock, which
# locks the account for 10 minutes after 3 in a row, everywhere (lock screen,
# login, console, sudo). If that happens, wait 10 minutes or reboot (the count
# lives in /run and a reboot clears it).
set -e
cd "$(dirname "$0")"

ID=com.daniideas.encom.lockscreen
SHELLS="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/shells"
OUR_PACKAGE="$SHELLS/$ID"
OVERRIDE="$SHELLS/org.kde.plasma.desktop"
SYSTEM=/usr/share/plasma/shells/org.kde.plasma.desktop
MARKER=.encom-lockscreen-override
SYNC_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/encom-lockscreen"
UNIT=encom-lockscreen-sync.service
UNIT_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/$UNIT"

if [ "$(id -u)" = 0 ]; then
    echo "No uses sudo: la pantalla de bloqueo es de tu usuario." >&2
    exit 1
fi

copy_package() {
    sddm-theme/native/build.sh   # the monitor's C++ plugin, shared with the login theme
    rm -rf "$OUR_PACKAGE"
    mkdir -p "$SHELLS"
    cp -r lockscreen-theme "$OUR_PACKAGE"
    rm -rf "$OUR_PACKAGE/contents/lockscreen/EncomSystem"
    cp -r sddm-theme/EncomSystem "$OUR_PACKAGE/contents/lockscreen/"
}

case "$1" in
    test)
        copy_package
        echo "Prueba: escribe tu contraseña para cerrarla (se valida de verdad)."
        echo "Ojo: 3 contraseñas incorrectas seguidas bloquean la cuenta 10 minutos (pam_faillock)."
        /usr/lib/kscreenlocker_greet --testing --shell "$ID"
        ;;
    install)
        copy_package
        if [ -e "$OVERRIDE" ] && [ ! -e "$OVERRIDE/$MARKER" ]; then
            echo "Ya existe $OVERRIDE y no lo creó este script; no lo toco." >&2
            exit 1
        fi
        # the sync script: system shell package + this lock screen -> the copy
        mkdir -p "$SYNC_DIR"
        rm -rf "$SYNC_DIR/lockscreen"
        cp -r "$OUR_PACKAGE/contents/lockscreen" "$SYNC_DIR/lockscreen"
        cat > "$SYNC_DIR/sync.sh" <<SYNC
#!/bin/bash
# Written by encom-boardroom/install-lockscreen.sh: refreshes the local copy of
# Plasma's desktop shell package, keeping the Encom lock screen in it.
set -e
mkdir -p "$OVERRIDE"
rsync -a --delete --exclude /contents/lockscreen --exclude /$MARKER "$SYSTEM/" "$OVERRIDE/"
rsync -a --delete "$SYNC_DIR/lockscreen/" "$OVERRIDE/contents/lockscreen/"
touch "$OVERRIDE/$MARKER"
SYNC
        chmod +x "$SYNC_DIR/sync.sh"
        "$SYNC_DIR/sync.sh"

        mkdir -p "$(dirname "$UNIT_FILE")"
        cat > "$UNIT_FILE" <<UNITEOF
[Unit]
Description=Refresh the Encom lock screen's copy of the Plasma shell package
Before=plasma-plasmashell.service plasma-ksmserver.service plasma-kwin_wayland.service plasma-kwin_x11.service

[Service]
Type=oneshot
ExecStart=$SYNC_DIR/sync.sh

[Install]
WantedBy=plasma-workspace.target
UNITEOF
        systemctl --user daemon-reload
        systemctl --user enable "$UNIT" > /dev/null
        echo "Instalada. Pruébala bloqueando la sesión (Super+L)."
        ;;
    uninstall)
        systemctl --user disable "$UNIT" > /dev/null 2>&1 || true
        rm -f "$UNIT_FILE"
        systemctl --user daemon-reload
        rm -rf "$SYNC_DIR"
        if [ -e "$OVERRIDE/$MARKER" ]; then
            rm -rf "$OVERRIDE"
        fi
        rm -rf "$OUR_PACKAGE"
        echo "Quitada. Vuelve la pantalla de bloqueo de Plasma."
        ;;
    *)
        sed -n '2,25p' "$0"
        exit 1
        ;;
esac
