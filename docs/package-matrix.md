# Package × Architecture matrix

NecrOS claims support for x86 (32-bit), x86_64, ARM64, ARMv7 **and PowerPC
(PowerBook G4)**. Whether a given tool is actually installable depends on the
*base distribution's build farm*, not on NecrOS. This document records what is
realistic per architecture and how to verify it exactly.

> **The matrix is not hand-maintained for exactness.** Run
> `sh docs/gen-package-matrix.sh` (in an environment that can reach the Alpine
> mirror — e.g. the Alpine CI container) to produce a dated, authoritative
> table straight from the per-arch `APKINDEX`. The tables below are the
> architectural reality and the best-known availability, with confidence noted.

---

## 1. The architecture reality (read this first)

| Base | 32-bit x86 | x86_64 | aarch64 | ARMv7 | **PPC 32-bit (G4)** | ppc64le |
|---|---|---|---|---|---|---|
| **Alpine Linux** | `x86` ✓ | ✓ | ✓ | `armv7` ✓ | **✗ not built** | ✓ |
| **Adélie Linux** | `pmmx` ✓ | ✓ | ✓ | (partial) | **`ppc` ✓** | `ppc64` ✓ |

**The single most important fact:** Alpine Linux does **not** build a 32-bit
PowerPC port. Its released architectures are `x86`, `x86_64`, `armhf`, `armv7`,
`aarch64`, `ppc64le`, `s390x`, `riscv64`. A PowerBook G4 is 32-bit PowerPC, so
**it cannot run an Alpine base at all.** [Certain]

That is exactly why the G4 path targets **Adélie Linux**, which keeps the same
musl / apk / OpenRC model as Alpine but *does* ship a 32-bit PowerPC port
(`ppc`, plus `pmmx` for old 32-bit x86 and `ppc64`). See
[powerbook-g4.md](powerbook-g4.md). [Certain]

Consequence for NecrOS: on a G4 you get Adélie's package set, which is
**smaller** than Alpine's. Several heavy/niche tools below are simply absent
there and NecrOS must degrade gracefully. [Likely]

---

## 2. Availability by package group

Legend: ✓ expected available · ~ available but heavy/discouraged on that class ·
✗ typically unavailable. Alpine columns reflect `main`+`community`; the Adélie
column is the G4-relevant one (`ppc`). Confidence is per note; **regenerate for
exactness.**

### Always expected (portable C/CLI, all arches incl. G4)
`nmap`, `tcpdump`, `socat`, `netcat-openbsd`, `nftables`, `arp-scan`, `gdb`,
`strace`, `ltrace`, `binwalk`, `hydra`, `john`, `nikto`, `dirb`,
`proxychains-ng`, `tor`, `gnupg`, `openssl`, `steghide`, `exiftool`,
`imagemagick`, `ldns-tools`, `bind-tools`, `rkhunter`, `chkrootkit`, `lynis`,
`fail2ban`. [Likely — plain C, built on every release arch; confirm on Adélie `ppc`]

### GUI stack (works everywhere, but that's the point of "light")
`xorg-server`, `i3wm`, `i3status`, `rofi`, `dmenu`, `rxvt-unicode`, `feh`,
`scrot`. [Likely] On a G4, prefer `--no-gui` / `--minimal` unless the machine
has comfortable RAM.

### 64-bit / high-RAM oriented (NecrOS already gates these)
| Package | x86 (32) | x86_64 | aarch64 | ARMv7 | G4 (ppc) | NecrOS gate |
|---|---|---|---|---|---|---|
| `hashcat` | ✗ | ~ | ~ | ✗ | ✗ | 64-bit **and** >1 GB RAM only |
| `gnuradio` | ✗ | ✓ | ~ | ✗ | ✗ | 64-bit, non-lowmem only |
| `gqrx` | ✗ | ✓ | ~ | ✗ | ✗ | 64-bit, non-lowmem only |
| `wireshark` (GUI) | ~ | ✓ | ✓ | ~ | ~ | skipped on low-mem (tshark only) |
| `pwntools` (pip) | ✗ | ✓ | ✓ | ~ | ✗ | 64-bit only |
| `impacket` (pip) | ~ | ✓ | ✓ | ~ | ~ | 64-bit only |

[Guessing on the exact ppc/armv7 cells — these are the packages most likely to
be missing on a G4; the installer must not hard-fail on them, and it doesn't:
`pkg_install` tolerates a missing package and warns.]

### Build-from-source / Go fallbacks
| Tool | How NecrOS gets it | G4 (ppc) reality |
|---|---|---|
| `radare2` | apk if present, else pinned-tag source build (non-lowmem) | buildable but slow on a G4 [Guessing] |
| `ffuf` | `go install` pinned version | needs Go for ppc; may be impractical [Guessing] |
| `subfinder` | `go install` pinned version (64-bit, non-lowmem) | not attempted on 32-bit |
| `GEF` | checksum-verified single file | arch-independent (Python) ✓ |

### Radio / wireless
`aircrack-ng`, `reaver`, `iw`, `wireless-tools`, `rtl-sdr`, `bluez`: expected on
all Alpine arches [Likely]; on Adélie `ppc` verify `rtl-sdr` and SDR extras.

### Blue-team / forensics
`suricata`, `yara`, `clamav`, `sleuthkit`, `foremost`, `goaccess`, `lnav`:
present on Alpine `main`/`community` for the mainstream arches [Likely];
`suricata` and `clamav` are the ones most likely missing or heavy on Adélie
`ppc` and on low-RAM machines (NecrOS already skips `clamav` on low-mem).

---

## 3. How NecrOS copes with gaps

- `pkg_install` installs best-effort: a package absent on the current arch is
  **warned, not fatal** (`lib/necros-common.sh`).
- The installer gates the known-heavy packages on bitness and RAM
  (`is_32bit`, `is_lowmem`) so a G4 or a 256 MB box never tries to pull them.
- `--minimal` (auto-selected under 384 MB) installs the core only: no GUI, no
  extended Python stack.

So an incomplete arch degrades to a working core install rather than failing.

---

## 4. Regenerating the exact table

```sh
# Alpine side (run where the mirror is reachable, e.g. CI's Alpine container):
sh docs/gen-package-matrix.sh v3.20 > docs/_alpine-matrix.generated.md
```

For the Adélie `ppc` column, point the same APKINDEX approach at the Adélie
mirror (`https://distfiles.adelielinux.org/adelie/<release>/<repo>/ppc/`). This
is kept manual for now because Adélie release/repo layout differs from Alpine;
tracked as a follow-up in the audit report.
