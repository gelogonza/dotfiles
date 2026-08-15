#!/usr/bin/env bash
#
# Install the gelo-liquid SDDM theme and switch the display manager to SDDM.
#
# Run with sudo:  sudo sddm/install.sh
#
# Why the theme is COPIED rather than symlinked: the greeter runs as the unix
# user `sddm`, and $HOME here is mode 700. A symlink into the home directory
# gives a greeter that cannot read its own theme, which fails as a blank or
# fallback login screen. Re-run this script after changing the theme.
#
# Every step is reversible; see docs/login-screen.md for the rollback and for
# the TTY recovery procedure if the graphical login does not come back.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEME_SRC="$REPO/sddm/themes/gelo-liquid"
THEME_DST="/usr/share/sddm/themes/gelo-liquid"
CONF_DIR="/etc/sddm.conf.d"
CONF="$CONF_DIR/10-gelo.conf"

if [[ $EUID -ne 0 ]]; then
    echo "error: run with sudo" >&2
    exit 1
fi

if [[ ! -f "$THEME_SRC/Main.qml" ]]; then
    echo "error: theme not found at $THEME_SRC" >&2
    exit 1
fi

if [[ ! -f "$THEME_SRC/Shaders/fluid.frag.qsb" ]]; then
    echo "error: shader not compiled — run design/build-shaders.sh first" >&2
    exit 1
fi

echo ":: installing theme -> $THEME_DST"
rm -rf "$THEME_DST"
mkdir -p "$THEME_DST"
cp -r "$THEME_SRC/." "$THEME_DST/"
# World-readable: the greeter runs as `sddm`, not as root or as you.
chown -R root:root "$THEME_DST"
chmod -R a+rX "$THEME_DST"

echo ":: writing $CONF"
mkdir -p "$CONF_DIR"
cat > "$CONF" <<EOF
# Managed by dotfiles (sddm/install.sh). Delete this file to revert to the
# SDDM default theme.
[Theme]
Current=gelo-liquid

[General]
# Wayland greeter: this desktop is Hyprland, and the X11 greeter would pull in
# an otherwise unnecessary Xorg session just to draw the login screen.
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell
EOF

echo ":: current display manager"
systemctl status display-manager --no-pager 2>/dev/null | head -3 || true

cat <<'EOF'

Theme installed. It is NOT yet the active display manager.

Verify it renders before switching anything:

    sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/gelo-liquid

When that looks right, switch from GDM to SDDM:

    sudo systemctl disable gdm.service
    sudo systemctl enable sddm.service

Then reboot. Read docs/login-screen.md FIRST — it has the recovery
procedure for the case where the graphical login does not come back.
EOF
