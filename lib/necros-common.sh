#!/bin/sh
# ============================================================================
#  NecrOS Common Library
#  Shared functions for all NecrOS scripts — source this, don't execute it.
# ============================================================================

# Guard against double-sourcing
[ -n "$_NECROS_LIB_LOADED" ] && return 0
_NECROS_LIB_LOADED=1

# ---------------------------------------------------------------------------
# Version (read from VERSION file if available, else fallback)
# ---------------------------------------------------------------------------
if [ -f /usr/local/necros/VERSION ]; then
    NECROS_VERSION=$(tr -d '[:space:]' </usr/local/necros/VERSION)
elif [ -f "$(dirname "$0")/../VERSION" ]; then
    NECROS_VERSION=$(tr -d '[:space:]' <"$(dirname "$0")/../VERSION")
else
    NECROS_VERSION="1.0.0"
fi
export NECROS_VERSION

# ---------------------------------------------------------------------------
# Terminal colours (POSIX-safe, degrades gracefully without tty)
# ---------------------------------------------------------------------------
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    MAGENTA=$(tput setaf 5)
    CYAN=$(tput setaf 6)
    BOLD=$(tput bold)
    NC=$(tput sgr0)
elif [ -t 1 ]; then
    # tty without tput (e.g. minimal busybox): materialise real ESC bytes so
    # they render when passed to printf '%s' (NOT literal "\033[..." strings).
    RED=$(printf '\033[0;31m')
    GREEN=$(printf '\033[0;32m')
    YELLOW=$(printf '\033[1;33m')
    BLUE=$(printf '\033[0;34m')
    MAGENTA=$(printf '\033[0;35m')
    CYAN=$(printf '\033[0;36m')
    BOLD=$(printf '\033[1m')
    NC=$(printf '\033[0m')
else
    # Not a terminal (pipe, CI, log): no colour at all, clean plain output.
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    BOLD=''
    NC=''
fi
export RED GREEN YELLOW BLUE MAGENTA CYAN BOLD NC

# ---------------------------------------------------------------------------
# Base distribution detection
# ---------------------------------------------------------------------------
detect_base_distro() {
    NECROS_BASE_DISTRO="unknown"
    NECROS_BASE_VERSION="unknown"

    if [ -r /etc/os-release ]; then
        NECROS_BASE_DISTRO=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print $2; exit}' /etc/os-release)
        NECROS_BASE_VERSION=$(awk -F= '/^VERSION_ID=/{gsub(/"/, "", $2); print $2; exit}' /etc/os-release)
    fi

    if [ "$NECROS_BASE_DISTRO" = "unknown" ] && [ -f /etc/alpine-release ]; then
        NECROS_BASE_DISTRO="alpine"
        NECROS_BASE_VERSION=$(cat /etc/alpine-release 2>/dev/null)
    fi

    if [ "$NECROS_BASE_DISTRO" = "unknown" ] && [ -f /etc/adelie-release ]; then
        NECROS_BASE_DISTRO="adelie"
        NECROS_BASE_VERSION=$(cat /etc/adelie-release 2>/dev/null)
    fi

    export NECROS_BASE_DISTRO NECROS_BASE_VERSION
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
NECROS_LOG="/var/log/necros.log"

_log_write() {
    local _lvl="$1"
    shift
    printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$_lvl" "$*" \
        >>"$NECROS_LOG" 2>/dev/null || true
}

log() {
    _log_write "INFO" "$@"
    printf '%s[+]%s %s\n' "$GREEN" "$NC" "$*"
}
warn() {
    _log_write "WARN" "$@"
    printf '%s[!]%s %s\n' "$YELLOW" "$NC" "$*"
}
err() {
    _log_write "ERROR" "$@"
    printf '%s[✗]%s %s\n' "$RED" "$NC" "$*"
}
die() {
    err "$@"
    exit 1
}
info() { printf '%s[*]%s %s\n' "$CYAN" "$NC" "$*"; }
ok() { printf '%s[✓]%s %s\n' "$GREEN" "$NC" "$*"; }

# ---------------------------------------------------------------------------
# Pinned-sources manifest (URLs + checksums). Best-effort location; if it is
# not found, the NECROS_*_SHA values stay empty and necros_fetch refuses any
# unverified download (fail safe).
# ---------------------------------------------------------------------------
for _cand in \
    /usr/local/necros/lib/necros-sources.sh \
    "$(dirname "$0")/lib/necros-sources.sh" \
    "$(dirname "$0")/../lib/necros-sources.sh" \
    "$(dirname "$0")/necros-sources.sh"; do
    if [ -f "$_cand" ]; then
        . "$_cand"
        break
    fi
done
unset _cand

# ---------------------------------------------------------------------------
# Dry-run support
#   NECROS_DRY_RUN=1 makes mutating helpers describe what they would do
#   instead of doing it. Installers set it from a --dry-run flag.
# ---------------------------------------------------------------------------
: "${NECROS_DRY_RUN:=0}"
export NECROS_DRY_RUN

necros_is_dry_run() { [ "$NECROS_DRY_RUN" = "1" ]; }

run_cmd() {
    # Run a command, or just print it under --dry-run.
    if necros_is_dry_run; then
        printf '%s[dry-run]%s %s\n' "$YELLOW" "$NC" "$*"
        return 0
    fi
    "$@"
}

write_file() {
    # write_file DEST   (content read from stdin). Honors --dry-run.
    _wf_dest="$1"
    if necros_is_dry_run; then
        printf '%s[dry-run]%s écrirait %s\n' "$YELLOW" "$NC" "$_wf_dest"
        cat >/dev/null # drain stdin so the heredoc is consumed
        unset _wf_dest
        return 0
    fi
    mkdir -p "$(dirname "$_wf_dest")" 2>/dev/null || true
    cat >"$_wf_dest"
    unset _wf_dest
}

# ---------------------------------------------------------------------------
# Verified downloads
#   Every network fetch in NecrOS goes through necros_fetch so integrity is
#   enforced in one place. Unverified downloads are refused by default.
# ---------------------------------------------------------------------------
NECROS_ALLOW_UNVERIFIED="${NECROS_ALLOW_UNVERIFIED:-0}"

sha256_of() {
    # Print the SHA-256 of a file, portably across busybox/coreutils/openssl.
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" 2>/dev/null | cut -d' ' -f1
    elif command -v sha256 >/dev/null 2>&1; then
        sha256 -q "$1" 2>/dev/null
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$1" 2>/dev/null | awk '{print $NF}'
    else
        return 1
    fi
}

necros_verify_sha256() {
    # necros_verify_sha256 FILE EXPECTED_SHA -> 0 only if the file's SHA-256
    # exists and equals EXPECTED_SHA. Separated out so it is unit-testable
    # without any network access.
    _vs_got="$(sha256_of "$1")" || {
        unset _vs_got
        return 1
    }
    if [ -n "$_vs_got" ] && [ "$_vs_got" = "$2" ]; then
        unset _vs_got
        return 0
    fi
    unset _vs_got
    return 1
}

_necros_download_to() {
    # _necros_download_to URL DEST  — raw fetch, no verification. Internal.
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --proto '=https' --tlsv1.2 -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$2" "$1"
    else
        err "Ni curl ni wget disponible pour télécharger: $1"
        return 1
    fi
}

necros_fetch() {
    # necros_fetch URL DEST [SHA256]
    #   Download URL to DEST, verifying SHA-256 when provided. Refuses to keep
    #   an unverified file unless NECROS_ALLOW_UNVERIFIED=1.
    _nf_url="$1"
    _nf_dest="$2"
    _nf_sha="${3:-}"

    if necros_is_dry_run; then
        if [ -n "$_nf_sha" ]; then
            printf '%s[dry-run]%s téléchargerait %s → %s (sha256 %s…)\n' \
                "$YELLOW" "$NC" "$_nf_url" "$_nf_dest" \
                "$(printf '%s' "$_nf_sha" | cut -c1-12)"
        else
            printf '%s[dry-run]%s téléchargerait %s → %s (NON vérifié)\n' \
                "$YELLOW" "$NC" "$_nf_url" "$_nf_dest"
        fi
        unset _nf_url _nf_dest _nf_sha
        return 0
    fi

    if [ -z "$_nf_sha" ] && [ "$NECROS_ALLOW_UNVERIFIED" != "1" ]; then
        err "Refus de télécharger sans checksum: $_nf_url"
        err "Mettez à jour lib/necros-sources.sh, ou NECROS_ALLOW_UNVERIFIED=1 pour outrepasser."
        unset _nf_url _nf_dest _nf_sha
        return 1
    fi

    _nf_tmp="$(mktemp 2>/dev/null || echo "/tmp/necros-dl-$$")"
    info "Téléchargement: $_nf_url"
    if ! _necros_download_to "$_nf_url" "$_nf_tmp"; then
        err "Téléchargement échoué: $_nf_url"
        rm -f "$_nf_tmp"
        unset _nf_url _nf_dest _nf_sha _nf_tmp
        return 1
    fi

    if [ -n "$_nf_sha" ]; then
        if ! necros_verify_sha256 "$_nf_tmp" "$_nf_sha"; then
            err "Checksum invalide (ou pas d'outil de hash) pour $_nf_url"
            err "  attendu: $_nf_sha"
            err "  obtenu:  $(sha256_of "$_nf_tmp" 2>/dev/null)"
            rm -f "$_nf_tmp"
            unset _nf_url _nf_dest _nf_sha _nf_tmp
            return 1
        fi
        ok "Checksum vérifié: $(basename "$_nf_dest")"
    else
        warn "Téléchargement NON vérifié (override actif): $_nf_url"
    fi

    mkdir -p "$(dirname "$_nf_dest")" 2>/dev/null || true
    mv "$_nf_tmp" "$_nf_dest"
    unset _nf_url _nf_dest _nf_sha _nf_tmp
}

# ---------------------------------------------------------------------------
# Architecture detection
# ---------------------------------------------------------------------------
detect_arch() {
    NECROS_ARCH=$(uname -m)
    case "$NECROS_ARCH" in
        i686 | i386 | i486 | i586)
            NECROS_ARCH_FAMILY="x86"
            NECROS_BITS=32
            ;;
        x86_64 | amd64)
            NECROS_ARCH_FAMILY="x86_64"
            NECROS_BITS=64
            ;;
        ppc | powerpc | ppc32)
            NECROS_ARCH_FAMILY="powerpc"
            NECROS_BITS=32
            ;;
        ppc64 | ppc64le | powerpc64 | powerpc64le)
            NECROS_ARCH_FAMILY="powerpc"
            NECROS_BITS=64
            ;;
        aarch64 | arm64)
            NECROS_ARCH_FAMILY="aarch64"
            NECROS_BITS=64
            ;;
        armv7l | armv6l)
            NECROS_ARCH_FAMILY="arm"
            NECROS_BITS=32
            ;;
        *)
            NECROS_ARCH_FAMILY="unknown"
            NECROS_BITS=0
            ;;
    esac
    export NECROS_ARCH NECROS_ARCH_FAMILY NECROS_BITS
}

# Convenience check
is_32bit() { [ "$NECROS_BITS" -eq 32 ] 2>/dev/null; }
is_lowmem() { [ "$(get_mem_mb)" -lt 512 ] 2>/dev/null; }
is_powerpc() { [ "$NECROS_ARCH_FAMILY" = "powerpc" ] 2>/dev/null; }
is_adelie() { [ "$NECROS_BASE_DISTRO" = "adelie" ] 2>/dev/null; }
is_alpine() { [ "$NECROS_BASE_DISTRO" = "alpine" ] 2>/dev/null; }

# ---------------------------------------------------------------------------
# System probes
# ---------------------------------------------------------------------------
get_mem_mb() {
    awk '/MemTotal/ { printf "%d", $2/1024 }' /proc/meminfo 2>/dev/null || echo 0
}

get_disk_free_mb() {
    df -m "${1:-/}" 2>/dev/null | awk 'NR==2 { print $4 }'
}

get_alpine_version() {
    if [ -f /etc/alpine-release ]; then
        cut -d. -f1,2 /etc/alpine-release
    elif [ -n "$NECROS_BASE_VERSION" ] && [ "$NECROS_BASE_VERSION" != "unknown" ]; then
        printf '%s\n' "$NECROS_BASE_VERSION"
    else
        echo "unknown"
    fi
}

# ---------------------------------------------------------------------------
# Requirement checks
# ---------------------------------------------------------------------------
require_root() {
    [ "$(id -u)" -eq 0 ] && return 0
    if necros_is_dry_run; then
        warn "[dry-run] non-root: l'exécution réelle exigerait root"
        return 0
    fi
    die "Ce script doit être exécuté en tant que root."
}

require_alpine() {
    is_alpine || die "NecrOS nécessite Alpine Linux comme base."
}

require_supported_base() {
    is_alpine && return 0
    is_adelie && return 0
    if necros_is_dry_run; then
        warn "[dry-run] base non supportée (${NECROS_BASE_DISTRO:-?}): l'exécution réelle exigerait Alpine/Adélie"
        return 0
    fi
    die "NecrOS nécessite une base APK/OpenRC compatible: Alpine Linux ou Adélie Linux."
}

require_mem() {
    local _min="${1:-256}"
    local _actual
    _actual=$(get_mem_mb)
    [ "$_actual" -ge "$_min" ] 2>/dev/null ||
        die "RAM insuffisante: ${_actual}MB (minimum ${_min}MB)"
}

require_disk() {
    local _min="${1:-500}" _mount="${2:-/}"
    local _actual
    _actual=$(get_disk_free_mb "$_mount")
    [ "$_actual" -ge "$_min" ] 2>/dev/null ||
        die "Espace disque insuffisant: ${_actual}MB libre sur $_mount (minimum ${_min}MB)"
}

# ---------------------------------------------------------------------------
# Package helpers (wrapping apk)
# ---------------------------------------------------------------------------
pkg_install() {
    # Install packages, tolerating individual failures.
    # Usage: pkg_install pkg1 pkg2 pkg3 ...
    local _failed="" _pkg
    if necros_is_dry_run; then
        printf '%s[dry-run]%s apk add:%s\n' "$YELLOW" "$NC" " $*"
        return 0
    fi
    for _pkg in "$@"; do
        if ! apk info -e "$_pkg" >/dev/null 2>&1; then
            apk add --no-cache "$_pkg" >>"$NECROS_LOG" 2>&1 || {
                warn "Paquet indisponible: $_pkg"
                _failed="$_failed $_pkg"
            }
        fi
    done
    [ -z "$_failed" ] || warn "Paquets manquants:$_failed"
}

pkg_installed() {
    apk info -e "$1" >/dev/null 2>&1
}

pip_install() {
    if necros_is_dry_run; then
        printf '%s[dry-run]%s pip3 install:%s\n' "$YELLOW" "$NC" " $*"
        return 0
    fi
    pip3 install --break-system-packages --quiet "$@" >>"$NECROS_LOG" 2>&1 ||
        warn "pip install échoué pour: $*"
}

# ---------------------------------------------------------------------------
# Swap management (crucial for 256MB machines)
# ---------------------------------------------------------------------------
ensure_swap() {
    local _size_mb="${1:-256}"
    local _swapfile="/var/cache/necros.swap"
    if necros_is_dry_run; then
        printf '%s[dry-run]%s créerait/activerait un swap de %sMB (%s)\n' \
            "$YELLOW" "$NC" "$_size_mb" "$_swapfile"
        return 0
    fi
    if [ "$(swapon --show --noheadings 2>/dev/null | wc -l)" -gt 0 ]; then
        return 0 # Swap already active
    fi
    if [ ! -f "$_swapfile" ]; then
        info "Création d'un swap de ${_size_mb}MB..."
        dd if=/dev/zero of="$_swapfile" bs=1M count="$_size_mb" status=none 2>/dev/null
        chmod 600 "$_swapfile"
        mkswap "$_swapfile" >>"$NECROS_LOG" 2>&1
    fi
    if swapon "$_swapfile" 2>/dev/null; then
        log "Swap activé (${_size_mb}MB)"
    else
        warn "Impossible d'activer le swap"
    fi
}

# ---------------------------------------------------------------------------
# Cleanup trap helper
# ---------------------------------------------------------------------------
_necros_cleanup_hooks=""

necros_on_exit() {
    _necros_cleanup_hooks="$_necros_cleanup_hooks
$1"
}

_necros_run_cleanup() {
    local _line
    echo "$_necros_cleanup_hooks" | while IFS= read -r _line; do
        if [ -n "$_line" ]; then eval "$_line" 2>/dev/null || true; fi
    done
}

trap _necros_run_cleanup EXIT INT TERM

# ---------------------------------------------------------------------------
# Idempotent marker system
# ---------------------------------------------------------------------------
NECROS_MARKERS="/var/lib/necros/markers"

mark_done() {
    necros_is_dry_run && return 0
    mkdir -p "$NECROS_MARKERS"
    touch "$NECROS_MARKERS/$1"
}

is_done() {
    [ -f "$NECROS_MARKERS/$1" ]
}

run_once() {
    # Usage: run_once "step_name" command args...
    local _step="$1"
    shift
    if is_done "$_step"; then
        info "Étape déjà complétée: $_step (skip)"
        return 0
    fi
    "$@"
    mark_done "$_step"
}

# ---------------------------------------------------------------------------
# NecrOS banner
# ---------------------------------------------------------------------------
necros_banner() {
    printf '%s' "$CYAN"
    cat <<'BANNER'

    ███╗   ██╗███████╗ ██████╗██████╗  ██████╗ ███████╗
    ████╗  ██║██╔════╝██╔════╝██╔══██╗██╔═══██╗██╔════╝
    ██╔██╗ ██║█████╗  ██║     ██████╔╝██║   ██║███████╗
    ██║╚██╗██║██╔══╝  ██║     ██╔══██╗██║   ██║╚════██║
    ██║ ╚████║███████╗╚██████╗██║  ██║╚██████╔╝███████║
    ╚═╝  ╚═══╝╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝
BANNER
    printf '%s\n' "$NC"
    printf '    %s"Resurrecting the Silicon Dead"%s  —  v%s\n\n' \
        "$YELLOW" "$NC" "$NECROS_VERSION"
}

# Auto-detect architecture on source
detect_arch
detect_base_distro
