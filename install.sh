#!/bin/sh
# ============================================================================
#  necros-g4 — network bootstrap
#
#  ROLE: this script only *fetches* NecrOS onto a fresh machine and then hands
#  off to the authoritative installer, necro_install.sh. All real installation
#  logic lives there and in lib/. Keep this file minimal: it runs BEFORE the
#  repository (and therefore lib/necros-common.sh) exists locally, so it cannot
#  source the shared library and deliberately duplicates only the bare minimum.
#
#  Usage:
#    wget -qO- https://raw.githubusercontent.com/WaD45/NecrOS-G4/main/install.sh | sh
#  Any options are passed through to necro_install.sh, e.g.:
#    wget -qO- .../install.sh | sh -s -- --minimal --dry-run
# ============================================================================

set -eu

REPO="https://github.com/WaD45/NecrOS-G4"
BRANCH="main"
INSTALL_DIR="$(mktemp -d 2>/dev/null || echo "/tmp/necros-install-$$")"

cleanup() { rm -rf "$INSTALL_DIR"; }
trap cleanup EXIT INT TERM

echo "[*] necros-g4 bootstrap — \"Resurrecting the Silicon Dead\""

# --- Minimal preconditions (full checks run again in necro_install.sh) ------
[ "$(id -u)" -eq 0 ] || {
    echo "[x] Ce script doit etre execute en tant que root."
    exit 1
}
if [ ! -f /etc/alpine-release ] && [ ! -f /etc/adelie-release ]; then
    echo "[x] NecrOS necessite une base Alpine Linux ou Adelie Linux."
    exit 1
fi

echo "[+] Telechargement de NecrOS depuis ${REPO} (${BRANCH})..."

# --- Fetch: prefer git (commit-level integrity), fall back to a tarball ------
fetch_tarball() {
    # $1: downloader command prefix that writes stdout
    mkdir -p "$INSTALL_DIR"
    "$@" "${REPO}/archive/refs/heads/${BRANCH}.tar.gz" |
        tar xz --strip-components=1 -C "$INSTALL_DIR"
}

if command -v git >/dev/null 2>&1; then
    git clone --depth 1 -b "$BRANCH" "${REPO}.git" "$INSTALL_DIR" 2>/dev/null ||
        {
            echo "[!] git clone echoue, tentative via tarball..."
            if command -v curl >/dev/null 2>&1; then
                fetch_tarball curl -fsSL
            else fetch_tarball wget -qO-; fi
        }
elif command -v curl >/dev/null 2>&1; then
    fetch_tarball curl -fsSL
elif command -v wget >/dev/null 2>&1; then
    fetch_tarball wget -qO-
else
    echo "[x] Ni git, ni curl, ni wget disponible."
    exit 1
fi

[ -f "$INSTALL_DIR/necro_install.sh" ] || {
    echo "[x] Telechargement incomplet."
    exit 1
}

echo "[+] Lancement de l'installeur..."
cd "$INSTALL_DIR"
chmod +x necro_install.sh 2>/dev/null || true
sh necro_install.sh "$@"

echo "[+] Termine."
