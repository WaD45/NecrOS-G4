#!/bin/sh
# ============================================================================
#  NecrOS pinned external sources + SHA-256 checksums
#
#  Single source of truth for everything NecrOS downloads. Every fetch goes
#  through necros_fetch() (lib/necros-common.sh), which refuses to install a
#  file whose checksum is not listed here unless NECROS_ALLOW_UNVERIFIED=1.
#
#  To update a pinned resource: bump the version/URL AND the checksum in the
#  SAME change, after verifying the new hash yourself:
#      curl -fsSL <url> | sha256sum
# ============================================================================

# Guard against double-sourcing
[ -n "$_NECROS_SOURCES_LOADED" ] && return 0
_NECROS_SOURCES_LOADED=1

# --- GEF (GDB Enhanced Features) — pinned release, single-file ------------
NECROS_GEF_URL="https://raw.githubusercontent.com/hugsy/gef/2024.01/gef.py"
NECROS_GEF_SHA="acb7142bb4ecab5f5a867fcb583fc58e12d7f24829b8a9fdcf596f8e6eb3c18a"

# --- rockyou wordlist — fixed release asset -------------------------------
NECROS_ROCKYOU_URL="https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt"
NECROS_ROCKYOU_SHA="6dfa76aa0e02303994fd1062d0ac983f0b69ece5474d85a5bba36362e19c1076"

# --- radare2 — pinned tag (source build fallback when no apk package) -----
NECROS_R2_TAG="6.2.4"

# --- Go-built tools — pinned versions (never @latest) ---------------------
NECROS_FFUF_VERSION="v2.3.0"
NECROS_SUBFINDER_VERSION="v2.17.0"

export NECROS_GEF_URL NECROS_GEF_SHA
export NECROS_ROCKYOU_URL NECROS_ROCKYOU_SHA
export NECROS_R2_TAG NECROS_FFUF_VERSION NECROS_SUBFINDER_VERSION
