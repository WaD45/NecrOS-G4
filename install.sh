#!/bin/sh
# ============================================================================
#  necros-g4 Quick Install
#  Usage: wget -qO- https://raw.githubusercontent.com/WaD45/NecrOS-G4/main/install.sh | sh
#  Or:    curl -sL  https://raw.githubusercontent.com/WaD45/NecrOS-G4/main/install.sh | sh
# ============================================================================

set -e

REPO="https://github.com/WaD45/NecrOS-G4-G4-G4"
BRANCH="main"
INSTALL_DIR="/tmp/necros-install-$$"

printf '\033[0;36m'
cat <<'BANNER'

    ███╗   ██╗███████╗ ██████╗██████╗  ██████╗ ███████╗
    ████╗  ██║██╔════╝██╔════╝██╔══██╗██╔═══██╗██╔════╝
    ██╔██╗ ██║█████╗  ██║     ██████╔╝██║   ██║███████╗
    ██║╚██╗██║██╔══╝  ██║     ██╔══██╗██║   ██║╚════██║
    ██║ ╚████║███████╗╚██████╗██║  ██║╚██████╔╝███████║
    ╚═╝  ╚═══╝╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝

    Quick Installer — "Resurrecting the Silicon Dead"

BANNER
printf '\033[0m'

# Check root
[ "$(id -u)" -eq 0 ] || { echo "[✗] Ce script doit être exécuté en tant que root."; exit 1; }

# Check Alpine
if [ ! -f /etc/alpine-release ] && [ ! -f /etc/adelie-release ]; then
    echo "[✗] NecrOS nécessite Alpine Linux ou Adélie Linux."
    exit 1
fi

echo "[+] Téléchargement de NecrOS..."

# Prefer git, fallback to wget/curl tarball
if command -v git >/dev/null 2>&1; then
    git clone --depth 1 -b "$BRANCH" "${REPO}.git" "$INSTALL_DIR" 2>/dev/null || {
        echo "[!] git clone échoué, essai via tarball..."
        mkdir -p "$INSTALL_DIR"
        wget -qO- "${REPO}/archive/refs/heads/${BRANCH}.tar.gz" | tar xz --strip-components=1 -C "$INSTALL_DIR"
    }
else
    mkdir -p "$INSTALL_DIR"
    if command -v wget >/dev/null 2>&1; then
        wget -qO- "${REPO}/archive/refs/heads/${BRANCH}.tar.gz" | tar xz --strip-components=1 -C "$INSTALL_DIR"
    elif command -v curl >/dev/null 2>&1; then
        curl -sL "${REPO}/archive/refs/heads/${BRANCH}.tar.gz" | tar xz --strip-components=1 -C "$INSTALL_DIR"
    else
        echo "[✗] Ni git, ni wget, ni curl disponible."
        exit 1
    fi
fi

echo "[+] Lancement de l'installation..."
cd "$INSTALL_DIR"
chmod +x necro_install.sh
sh necro_install.sh "$@"

# Cleanup
rm -rf "$INSTALL_DIR"
echo "[✓] Installation terminée."
