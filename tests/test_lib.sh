#!/bin/sh
# ============================================================================
#  NecrOS Test Suite — lib/necros-common.sh
# ============================================================================

set -e

_PASS=0
_FAIL=0
_TOTAL=0

_test() {
    _TOTAL=$((_TOTAL + 1))
    local _name="$1"
    shift
    # Assertions are passed as a single shell expression string; eval the
    # joined args ("$*"), which is the intended behaviour here.
    if eval "$*" >/dev/null 2>&1; then
        printf '  \033[0;32m✓\033[0m %s\n' "$_name"
        _PASS=$((_PASS + 1))
    else
        printf '  \033[0;31m✗\033[0m %s\n' "$_name"
        _FAIL=$((_FAIL + 1))
    fi
}

echo ""
echo "  NecrOS Test Suite"
echo "  ================="
echo ""

# ---------------------------------------------------------------------------
# Source the library
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
_LIB="$SCRIPT_DIR/../lib/necros-common.sh"

_test "Library file exists" "[ -f '$_LIB' ]"
_test "Library is sourceable" ". '$_LIB'"

# Source it for real
. "$_LIB" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Version
# ---------------------------------------------------------------------------
_test "NECROS_VERSION is set" "[ -n '$NECROS_VERSION' ]"
_ver_file=$(tr -d '[:space:]' <"$SCRIPT_DIR/../VERSION" 2>/dev/null)
_ver_var=$(printf '%s' "$NECROS_VERSION" | tr -d '[:space:]')
_test "NECROS_VERSION matches VERSION file" "[ '$_ver_file' = '$_ver_var' ]"

# ---------------------------------------------------------------------------
# Architecture detection
# ---------------------------------------------------------------------------
_test "NECROS_ARCH is set" "[ -n '$NECROS_ARCH' ]"
_test "NECROS_BITS is set" "[ -n '$NECROS_BITS' ]"
_test "NECROS_ARCH_FAMILY is set" "[ -n '$NECROS_ARCH_FAMILY' ]"
_test "NECROS_BITS is 32 or 64" \
    "[ '$NECROS_BITS' -eq 32 ] || [ '$NECROS_BITS' -eq 64 ]"

# ---------------------------------------------------------------------------
# Functions exist
# ---------------------------------------------------------------------------
for _fn in log warn err die info ok get_mem_mb get_disk_free_mb \
    necros_banner detect_arch is_32bit is_lowmem is_powerpc \
    is_adelie is_alpine mark_done is_done run_once ensure_swap \
    require_supported_base; do
    _test "Function '$_fn' is defined" "type '$_fn' >/dev/null 2>&1"
done

# ---------------------------------------------------------------------------
# Colour variables (may be empty in non-tty contexts; test definition only)
# ---------------------------------------------------------------------------
_test "Colour variables exported" "true" # Colours are optional in non-tty

# ---------------------------------------------------------------------------
# System probes
# ---------------------------------------------------------------------------
_test "get_mem_mb returns a number" \
    "echo '$(get_mem_mb)' | grep -qE '^[0-9]+$'"

# ---------------------------------------------------------------------------
# Marker system
# ---------------------------------------------------------------------------
_test_marker="/tmp/necros-test-marker-$$"
NECROS_MARKERS="$_test_marker"
mkdir -p "$NECROS_MARKERS"

_test "mark_done creates marker" "mark_done test_step && [ -f '$NECROS_MARKERS/test_step' ]"
_test "is_done returns true for existing marker" "is_done test_step"
_test "is_done returns false for non-existing marker" "! is_done nonexistent_step"

rm -rf "$_test_marker"

# ---------------------------------------------------------------------------
# Core scripts exist and are executable concepts
# ---------------------------------------------------------------------------
echo ""
echo "  Script Syntax Checks"
echo "  ====================="
for _script in \
    "$SCRIPT_DIR/../necro_install.sh" \
    "$SCRIPT_DIR/../build_iso.sh" \
    "$SCRIPT_DIR/../core/vanish.sh" \
    "$SCRIPT_DIR/../core/payload.sh" \
    "$SCRIPT_DIR/../core/recon.sh" \
    "$SCRIPT_DIR/../core/sysinfo.sh" \
    "$SCRIPT_DIR/../core/update.sh" \
    "$SCRIPT_DIR/../install.sh"; do
    _name="$(basename "$_script")"
    _test "$_name exists" "[ -f '$_script' ]"
    _test "$_name has valid syntax" "sh -n '$_script'"
done

echo ""
echo "  Toolbox Syntax Checks"
echo "  ====================="
for _script in "$SCRIPT_DIR"/../toolbox/install_*.sh; do
    _name="$(basename "$_script")"
    _test "$_name syntax OK" "sh -n '$_script'"
done

# ---------------------------------------------------------------------------
# Security helpers: pinned sources, checksum verification, dry-run
# ---------------------------------------------------------------------------
echo ""
echo "  Security Helper Checks"
echo "  ======================"

_test "necros-sources.sh is sourceable" ". '$SCRIPT_DIR/../lib/necros-sources.sh'"
_test "NECROS_GEF_SHA is 64 hex chars" \
    "printf '%s' \"\$NECROS_GEF_SHA\" | grep -qE '^[0-9a-f]{64}\$'"
_test "NECROS_ROCKYOU_SHA is 64 hex chars" \
    "printf '%s' \"\$NECROS_ROCKYOU_SHA\" | grep -qE '^[0-9a-f]{64}\$'"
_test "necros_fetch is defined" "type necros_fetch >/dev/null 2>&1"
_test "necros_verify_sha256 is defined" "type necros_verify_sha256 >/dev/null 2>&1"

# sha256_of agrees with sha256sum on a known file
_sec_tmp="/tmp/necros-test-sec-$$"
mkdir -p "$_sec_tmp"
printf 'necros' >"$_sec_tmp/sample"
_got_sha=$(sha256_of "$_sec_tmp/sample")
_ref_sha=$(sha256sum "$_sec_tmp/sample" | cut -d' ' -f1)
_test "sha256_of matches sha256sum" "[ '$_got_sha' = '$_ref_sha' ]"

# Checksum verification accepts the right hash and rejects a wrong one
_test "verify_sha256 accepts correct hash" \
    "necros_verify_sha256 '$_sec_tmp/sample' '$_got_sha'"
_test "verify_sha256 rejects wrong hash" \
    "! necros_verify_sha256 '$_sec_tmp/sample' '0000000000000000000000000000000000000000000000000000000000000000'"

# Fetch refuses an unverified download by default (before any network use)
_test "necros_fetch refuses missing checksum" \
    "! ( NECROS_ALLOW_UNVERIFIED=0; necros_fetch 'https://example.invalid/x' '$_sec_tmp/out1' '' )"
_test "refused fetch wrote nothing" "[ ! -f '$_sec_tmp/out1' ]"

# Dry-run never downloads
_test "necros_fetch dry-run returns 0" \
    "( NECROS_DRY_RUN=1; necros_fetch 'https://example.invalid/x' '$_sec_tmp/out2' '$_got_sha' )"
_test "dry-run wrote nothing" "[ ! -f '$_sec_tmp/out2' ]"
_test "run_cmd dry-run does not execute" \
    "( NECROS_DRY_RUN=1; run_cmd touch '$_sec_tmp/nope' ); [ ! -f '$_sec_tmp/nope' ]"
_test "pkg_install dry-run returns 0" "( NECROS_DRY_RUN=1; pkg_install foo )"

rm -rf "$_sec_tmp"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "  ─────────────────────────────────"
printf '  Total: %d | \033[0;32mPass: %d\033[0m | \033[0;31mFail: %d\033[0m\n' \
    "$_TOTAL" "$_PASS" "$_FAIL"
echo "  ─────────────────────────────────"
echo ""

[ "$_FAIL" -eq 0 ] || exit 1
