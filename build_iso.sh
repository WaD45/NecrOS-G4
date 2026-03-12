#!/bin/sh
# ============================================================================
#  necros-g4 ISO Builder — "The Phylactery Forge"
#  Builds a bootable NecrOS ISO from an Alpine Linux base.
#
#  Requirements: Must be run on an Alpine Linux system.
#  Usage: sh build_iso.sh [--arch x86|x86_64|ppc] [--output dir]
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/necros-common.sh" 2>/dev/null || {
    log()  { printf '[+] %s\n' "$1"; }
    warn() { printf '[!] %s\n' "$1"; }
    die()  { printf '[✗] %s\n' "$1"; exit 1; }
    ok()   { printf '[✓] %s\n' "$1"; }
    info() { printf '[*] %s\n' "$1"; }
}

VERSION=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "1.0.0")
BUILD_ARCH="x86"  # Default to 32-bit (our raison d'être)
OUTPUT_DIR="$SCRIPT_DIR/build"
WORK_DIR="/tmp/necros-iso-build-$$"
NECROS_SRC="$SCRIPT_DIR"
PPC_BUNDLE_DIR=""

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --arch)     BUILD_ARCH="$2"; shift ;;
        --output)   OUTPUT_DIR="$2"; shift ;;
        -h|--help)
            cat <<EOF
necros-g4 ISO Builder v${VERSION}

Usage: sh build_iso.sh [OPTIONS]

Options:
  --arch ARCH     Target architecture: x86 (default), x86_64, ppc
  --output DIR    Output directory (default: ./build)
  -h, --help      Show help

Requirements:
  - Alpine Linux as build host
  - Root access
  - ~2GB free space

For x86/x86_64, the resulting ISO is a bootable live system with NecrOS pre-configured.
For ppc, the builder emits an installable bundle (overlay + rootfs metadata) because
PowerBook G4 boot media requires an Open Firmware path distinct from the x86 ISO flow.
EOF
            exit 0
            ;;
        *) warn "Unknown option: $1" ;;
    esac
    shift
done

case "$BUILD_ARCH" in
    x86|x86_64|ppc) ;;
    *) die "Unsupported architecture: $BUILD_ARCH (expected x86, x86_64 or ppc)" ;;
esac

# ---------------------------------------------------------------------------
# Validate environment
# ---------------------------------------------------------------------------
[ "$(id -u)" -eq 0 ] || die "Root required"
[ -f /etc/alpine-release ] || die "Must be run on Alpine Linux"

ALPINE_VER=$(cut -d. -f1,2 /etc/alpine-release)
log "Building necros-g4 v${VERSION} ISO for ${BUILD_ARCH}"
log "Alpine base: v${ALPINE_VER}"
log "Output: ${OUTPUT_DIR}"

# ---------------------------------------------------------------------------
# Install build dependencies
# ---------------------------------------------------------------------------
log "Installing build tools..."
apk add --no-cache \
    alpine-sdk build-base apk-tools alpine-conf \
    mtools dosfstools grub grub-efi \
    squashfs-tools xorriso syslinux \
    sudo 2>/dev/null || die "Cannot install build tools"

# ---------------------------------------------------------------------------
# Setup builder user (abuild requirement)
# ---------------------------------------------------------------------------
if ! id "necros-builder" >/dev/null 2>&1; then
    adduser -D necros-builder 2>/dev/null || true
    addgroup necros-builder abuild 2>/dev/null || true
    echo "necros-builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers 2>/dev/null || true
fi

# Generate signing keys if needed
if [ ! -f /home/necros-builder/.abuild/abuild.conf ]; then
    su - necros-builder -c "abuild-keygen -a -i -n" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Prepare overlay (custom files injected into the live ISO)
# ---------------------------------------------------------------------------
log "Preparing NecrOS overlay..."
mkdir -p "$WORK_DIR/overlay"
OVERLAY="$WORK_DIR/overlay"

# /etc
mkdir -p "$OVERLAY/etc"
echo "necros" > "$OVERLAY/etc/hostname"
cat > "$OVERLAY/etc/hosts" <<EOF
127.0.0.1    localhost necros
::1          localhost necros
EOF

cat > "$OVERLAY/etc/motd" <<MOTD

    ███╗   ██╗███████╗ ██████╗██████╗  ██████╗ ███████╗
    ████╗  ██║██╔════╝██╔════╝██╔══██╗██╔═══██╗██╔════╝
    ██╔██╗ ██║█████╗  ██║     ██████╔╝██║   ██║███████╗
    ██║╚██╗██║██╔══╝  ██║     ██╔══██╗██║   ██║╚════██║
    ██║ ╚████║███████╗╚██████╗██║  ██║╚██████╔╝███████║
    ╚═╝  ╚═══╝╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝

    "Resurrecting the Silicon Dead" — v${VERSION}

    Login: root (no password)
    Then run: necro_install.sh

MOTD

# Auto-login on tty1
mkdir -p "$OVERLAY/etc/inittab.d"

# Network auto-start
mkdir -p "$OVERLAY/etc/runlevels/default"

# /usr/local/necros — embed the full NecrOS source
mkdir -p "$OVERLAY/usr/local/necros"
cp -r "$NECROS_SRC/lib" "$OVERLAY/usr/local/necros/"
cp -r "$NECROS_SRC/core" "$OVERLAY/usr/local/necros/"
cp -r "$NECROS_SRC/toolbox" "$OVERLAY/usr/local/necros/"
cp "$NECROS_SRC/VERSION" "$OVERLAY/usr/local/necros/"
cp "$NECROS_SRC/necro_install.sh" "$OVERLAY/usr/local/necros/"

# Convenience: symlink installer to /usr/local/bin
mkdir -p "$OVERLAY/usr/local/bin"
cat > "$OVERLAY/usr/local/bin/necro_install.sh" <<'WRAPPER'
#!/bin/sh
exec sh /usr/local/necros/necro_install.sh "$@"
WRAPPER
chmod +x "$OVERLAY/usr/local/bin/necro_install.sh"

# APK repositories
mkdir -p "$OVERLAY/etc/apk"
cat > "$OVERLAY/etc/apk/repositories" <<REPOS
https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VER}/main
https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VER}/community
REPOS

ok "Overlay prepared"

# ---------------------------------------------------------------------------
# Generate the overlay tarball (apkovl)
# ---------------------------------------------------------------------------
log "Generating overlay archive..."
APKOVL="$WORK_DIR/necros.apkovl.tar.gz"
(cd "$OVERLAY" && tar czf "$APKOVL" .)
ok "Overlay archive: $APKOVL"

if [ "$BUILD_ARCH" = "ppc" ]; then
    log "PowerPC target selected — generating a portable install bundle instead of an x86 ISO"
    mkdir -p "$OUTPUT_DIR"
    PPC_BUNDLE_DIR="$OUTPUT_DIR/necros-${VERSION}-ppc"
    rm -rf "$PPC_BUNDLE_DIR"
    mkdir -p "$PPC_BUNDLE_DIR"

    cp "$APKOVL" "$PPC_BUNDLE_DIR/necros.apkovl.tar.gz"
    cp "$NECROS_SRC/necro_install.sh" "$PPC_BUNDLE_DIR/"
    cp "$NECROS_SRC/install.sh" "$PPC_BUNDLE_DIR/"
    cp "$NECROS_SRC/README.md" "$PPC_BUNDLE_DIR/"

    cat > "$PPC_BUNDLE_DIR/POWERBOOK_G4.txt" <<EOF
necros-g4 PowerPC bundle
=====================

Target architecture: ppc (32-bit PowerPC / PowerBook G4 class)
Version: ${VERSION}
Base Alpine release: ${ALPINE_VER}

This bundle does not include a bootable ISO.
Reason: PowerBook G4 boot media must use an Open Firmware-compatible boot path
(typically Apple Partition Map + yaboot or GRUB ieee1275), while the current
NecrOS ISO pipeline is x86 BIOS/UEFI oriented.

Included:
- necros.apkovl.tar.gz
- necro_install.sh
- install.sh

Recommended workflow:
1. Install a PPC-capable Linux base on the PowerBook G4.
2. Copy this bundle onto the machine.
3. Run necro_install.sh as root on that target system.
EOF

    tar czf "$OUTPUT_DIR/necros-g4-${VERSION}-ppc-bundle.tar.gz" -C "$OUTPUT_DIR" "$(basename "$PPC_BUNDLE_DIR")"
    ok "PowerPC bundle created: $OUTPUT_DIR/necros-g4-${VERSION}-ppc-bundle.tar.gz"
    log "Cleaning up..."
    rm -rf "$WORK_DIR"
    ok "Done"
    exit 0
fi

# ---------------------------------------------------------------------------
# Build the ISO using mkimage (Alpine's official method)
# ---------------------------------------------------------------------------
log "Building ISO image..."
mkdir -p "$OUTPUT_DIR"

# Clone aports for mkimage scripts if not present
APORTS="/tmp/aports-necros"
if [ ! -d "$APORTS/scripts" ]; then
    git clone --depth=1 --branch "${ALPINE_VER}-stable" \
        https://gitlab.alpinelinux.org/alpine/aports.git "$APORTS" 2>/dev/null || \
    git clone --depth=1 \
        https://gitlab.alpinelinux.org/alpine/aports.git "$APORTS" 2>/dev/null || \
        die "Cannot clone aports"
fi

# Create custom profile
cat > "$APORTS/scripts/mkimg.necros.sh" <<'PROFILE'
profile_necros() {
    title="NecrOS"
    desc="NecrOS — The 32-bit Pentest Distro"
    profile_standard
    image_ext="iso"
    arch="x86 x86_64"
    # Base packages for the live environment
    apks="$apks
        alpine-base
        openrc
        busybox
        busybox-suid
        network-extras
        dhcpcd
        openssh
        curl wget
        git
        bash
        vim nano
        htop tmux
        nmap tcpdump
        python3 py3-pip
    "
    local _k _a
    for _a in $arch; do
        for _k in lts virt; do
            apks="$apks linux-$_k"
        done
    done
}
PROFILE

# Run mkimage
cd "$APORTS/scripts"
sh mkimage.sh \
    --tag "v${ALPINE_VER}" \
    --outdir "$OUTPUT_DIR" \
    --arch "$BUILD_ARCH" \
    --repository "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VER}/main" \
    --repository "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VER}/community" \
    --extra-repository "https://dl-cdn.alpinelinux.org/alpine/edge/testing" \
    --profile necros \
    2>&1 | tee "$WORK_DIR/build.log" || {
        warn "mkimage failed — falling back to manual ISO build"

        # Fallback: create a simpler ISO using xorriso directly
        log "Attempting manual ISO build..."
        _iso_root="$WORK_DIR/iso-root"
        mkdir -p "$_iso_root"

        # Download Alpine mini rootfs
        _rootfs_url="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VER}/releases/${BUILD_ARCH}/alpine-minirootfs-${ALPINE_VER}.0-${BUILD_ARCH}.tar.gz"
        wget -q "$_rootfs_url" -O "$WORK_DIR/rootfs.tar.gz" 2>/dev/null || \
            die "Cannot download Alpine rootfs"

        # Extract and inject overlay
        mkdir -p "$_iso_root/rootfs"
        tar xzf "$WORK_DIR/rootfs.tar.gz" -C "$_iso_root/rootfs"
        tar xzf "$APKOVL" -C "$_iso_root/rootfs"

        # Create squashfs
        mksquashfs "$_iso_root/rootfs" "$_iso_root/rootfs.squashfs" \
            -comp xz -Xbcj x86 2>/dev/null || \
            mksquashfs "$_iso_root/rootfs" "$_iso_root/rootfs.squashfs" 2>/dev/null

        ok "Squashfs created"
        info "Note: Full bootable ISO requires ISOLINUX/GRUB setup."
        info "For now, use the NecrOS overlay + Alpine Standard ISO."
    }

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
log "Cleaning up..."
rm -rf "$WORK_DIR"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
_iso=$(find "$OUTPUT_DIR" -name "*.iso" -type f 2>/dev/null | head -1)
if [ -n "$_iso" ]; then
    _size=$(du -h "$_iso" | cut -f1)
    ok "ISO built successfully!"
    log "File: $_iso"
    log "Size: $_size"
    log "Arch: $BUILD_ARCH"
    echo ""
    echo "  To test:  qemu-system-${BUILD_ARCH} -m 512 -cdrom $_iso"
    echo "  To burn:  dd if=$_iso of=/dev/sdX bs=4M status=progress"
else
    warn "No ISO file produced."
    echo ""
    echo "  Alternative: Use the standard Alpine ISO and run necro_install.sh"
    echo "  1. Boot Alpine Standard ISO"
    echo "  2. setup-alpine (mode 'sys')"
    echo "  3. wget https://github.com/WaD45/NecrOS-G4/archive/main.tar.gz"
    echo "  4. tar xzf main.tar.gz && cd NecrOS-main"
    echo "  5. sh necro_install.sh"
fi
echo ""
