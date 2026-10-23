# Changelog

All notable changes to NecrOS will be documented in this file.

## [1.1.0] — 2026-10-23

Audit & reliability pass (branch `claude/audit-1`). See `docs/AUDIT.md`.

### Fixed
- Repository URL was `NecrOS-G4-G4-G4` (tripled) in `install.sh` and
  `core/update.sh` — network install and self-update always failed.
- `deploy_necros_files()` used brace expansion in `mkdir`, which BusyBox
  ash/dash do not expand, so core/toolbox files were never deployed.
- `--minimal` now actually drops the GUI and the extended Python stack, as its
  help always claimed.
- Rewrote fragile `A && B || C` chains as explicit `if/else`.

### Security (installer)
- Every download goes through `necros_fetch` and is verified against a pinned
  SHA-256 in `lib/necros-sources.sh`; an unverified download is refused by
  default (`NECROS_ALLOW_UNVERIFIED=1` to override).
- Removed the `curl … | sh` Oh My Zsh bootstrap (remote code execution).
- GEF pinned to a release and checksum-verified; rockyou verified; dirb taken
  from its package; radare2 built from a pinned tag; ffuf/subfinder pinned
  (no `@latest`).
- New `--dry-run` mode: preview the whole install with zero system mutation.

### Quality
- shellcheck clean under `-s dash` (the real ash/dash dialect); `shfmt -i 4 -ci`
  applied across all scripts; colour fallback no longer leaks literal escapes
  in non-tty output.
- `make lint` now fails on findings (was always-pass); added `make fmt`/`fmt-fix`.

### Tests & CI
- Test suite expanded 53 → 69 assertions (checksum verification, dry-run, pinned
  sources), still dependency-free POSIX sh.
- CI reworked: lint and syntax jobs can now actually fail; added an unprivileged
  `--dry-run` install smoke and a PowerPC bundle build.

### Docs
- `docs/AUDIT.md` (architecture, README gaps, debt), `docs/package-matrix.md`
  with a reproducible generator, and the Alpine-has-no-ppc32 / use-Adélie
  reality made explicit in `docs/powerbook-g4.md`.

## [1.0.0] — 2026-03-09

### Architecture
- **Shared library** (`lib/necros-common.sh`): single source of truth for colours, logging, architecture detection, package helpers, swap management, idempotent marker system
- **Idempotent installer**: every step uses `run_once` markers — safe to re-run after failure
- **Automatic swap**: machines with <512MB RAM get automatic swap file creation
- **Auto-downgrade**: machines with <384MB RAM automatically switch to `--minimal` mode
- **Alpine version auto-detection**: no more hardcoded repository URLs

### New Core Tools
- `necros-recon`: automated reconnaissance pipeline (DNS, WHOIS, port scan, web recon, passive OSINT, report generation)
- `necros-sysinfo`: system information dashboard (hardware, network, installed tools, toolbox status)
- `necros-update`: self-updater (check, pull, system update)
- `necros-crypt`: crypto swiss army knife (hash, encode, encrypt, generate passwords)

### Improved Core Tools
- `necros-vanish` v2.0: better POSIX compliance, NecrOS trace cleanup, expanded wipe targets
- `necros-payload` v2.0: 13 reverse shells (added OpenSSL encrypted), MSFvenom templates, shell upgrade section, CLI quick mode with `--lhost`/`--lport` flags

### New Toolboxes
- **OSINT & Recon**: subdomain enumeration (crt.sh, subfinder), WHOIS, Shodan CLI, exiftool, theHarvester
- **Crypto & Stego**: steghide, pycryptodome, `necros-crypt` multi-tool, hash identification

### Improved Toolboxes
- All toolboxes now use the shared library (no more duplicated code)
- Architecture-aware installation throughout (32-bit light mode)
- Toolbox status tracking via marker system

### Build System
- `Makefile` with lint, test, build, release targets
- `build_iso.sh` rewritten with proper Alpine mkimage integration + fallback
- `install.sh` rewritten for network install with git/wget/curl fallback chain

### Quality
- Full test suite (`tests/test_lib.sh`): library functions, syntax validation, markers
- GitHub Actions CI: shellcheck lint, syntax check, tests on Ubuntu + Alpine container
- All scripts pass `sh -n` syntax validation
- shellcheck compliance (SC1091, SC2034, SC1008 excluded by design)

### Project Infrastructure
- `VERSION` file (single source of truth)
- `LICENSE` (MIT)
- `CHANGELOG.md`
- `CONTRIBUTING.md`
- Comprehensive `.gitignore`

---

## [0.3.0] — 2024 (Previous)

- necros-vanish: ghost/stealth/nuclear modes
- necros-payload: 12+ reverse shells
- Boot splash animation
- Blue Team toolbox

## [0.2.0] — 2024 (Initial)

- Base Alpine Linux installer
- i3wm + urxvt theme
- WiFi, Web, Reverse Engineering toolboxes
- Zsh + Oh My Zsh configuration
