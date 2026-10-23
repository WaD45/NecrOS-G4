# PowerBook G4 Port

## Scope

NecrOS can be ported to PowerBook G4 hardware in two phases:

1. Runtime portability: installer, scripts, and userland must run correctly on 32-bit PowerPC.
2. Boot media portability: produce Open Firmware-compatible boot media for New World Power Macs.

This repository now covers phase 1 directly and exposes a build artifact for manual deployment.

## Why the base must be Adélie, not Alpine

The PowerBook G4 is **32-bit PowerPC**. Alpine Linux does not build a 32-bit
PowerPC port at all — its PowerPC architecture is `ppc64le` only. So a G4
**cannot** run an Alpine base. Adélie Linux keeps the same musl/apk/OpenRC
model but *does* ship a 32-bit `ppc` port, which is why it is the target base
for G4 hardware. Package availability per architecture (and the Alpine vs
Adélie split) is tracked in [package-matrix.md](package-matrix.md).

## Current status

- `powerpc` / `ppc` architectures are detected by the shared runtime library.
- The installer warns when running on PowerPC and avoids x86-specific GUI assumptions.
- `build_iso.sh --arch ppc` produces a deployment bundle rather than a misleading x86-style ISO
  (and no longer pulls the x86 ISO toolchain to do so).

## Why no PPC ISO yet

The current live image pipeline depends on Alpine `mkimage` plus x86-oriented boot tooling:

- `syslinux`
- `grub-efi`
- BIOS/UEFI ISO assumptions

PowerBook G4 systems boot through Open Firmware, typically with:

- Apple Partition Map (APM)
- `yaboot`, or
- `grub-ieee1275`

That requires a separate media layout and bootloader path.

## Recommended target workflow

1. Install a PPC-capable Linux base on the PowerBook G4.
2. Copy the NecrOS PPC bundle onto the machine.
3. Run `necro_install.sh` as root.
4. Validate:
   - networking
   - X11/i3 startup
   - toolboxes needed on that host

## Next engineering steps

1. Add a dedicated PPC rootfs builder, not tied to x86 ISO semantics.
2. Introduce a boot-media backend for Open Firmware (`yaboot` or `grub-ieee1275`).
3. Treat Adélie Linux as the primary PPC base because it keeps the `apk`/musl/OpenRC model intact.
