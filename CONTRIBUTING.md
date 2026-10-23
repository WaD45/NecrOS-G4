# Contributing to NecrOS

Merci de vouloir contribuer à NecrOS ! Voici les règles du jeu.

## Quick Start

```bash
git clone https://github.com/WaD45/NecrOS-G4.git
cd NecrOS-G4
make lint      # shellcheck (dialecte dash)
make fmt       # Vérifier le formatage (shfmt) ; make fmt-fix pour appliquer
make test      # lint + tests
```

## Rules

1. **POSIX sh + BusyBox ash** — Les scripts tournent sous `/bin/sh` d'Alpine
   (BusyBox ash) et dash. `local` est autorisé (supporté par ash/dash) ; les
   vrais bashismes (`[[ ]]`, expansion d'accolades `{a,b}`, tableaux) sont
   interdits. On lint avec `shellcheck -s dash` (`make lint`).
2. **Formatage** — `make fmt` doit être propre (shfmt `-i 4 -ci`).
3. **32-bit first** — Chaque feature doit fonctionner sur une machine i686 avec 256MB de RAM.
4. **Shared library** — Utilisez `lib/necros-common.sh` pour les fonctions communes.
5. **Idempotent + dry-run** — Les installations doivent être relançables et
   respecter `--dry-run` (via `run_cmd`, `write_file`, `pkg_install`, …).
6. **Téléchargements vérifiés** — Tout fetch passe par `necros_fetch` avec un
   SHA-256 épinglé dans `lib/necros-sources.sh`. Jamais de `curl | sh`.
7. **Lightweight** — Préférez les outils légers aux usines à gaz.

## Structure

```
lib/           Shared functions (source this, don't execute)
               necros-common.sh (library) + necros-sources.sh (pinned URLs/SHA)
core/          NecrOS tools (vanish, payload, recon, etc.)
toolbox/       Modular tool installers (wifi, web, reverse, etc.)
tests/         Test suite (dependency-free POSIX harness)
docs/          Documentation (AUDIT.md, powerbook-g4.md, package-matrix.md)
```

## Adding a new tool

1. Create `core/mytool.sh` using the template:
   ```sh
   #!/bin/sh
   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   . "${SCRIPT_DIR}/../lib/necros-common.sh"
   # ... your code
   ```
2. Add a symlink in `necro_install.sh` → `deploy_necros_files()`
3. Add tests in `tests/`
4. Update `CHANGELOG.md`

## Adding a new toolbox

1. Create `toolbox/install_mytoolbox.sh`
2. Register it in `necro_install.sh` → `create_toolbox_manager()`
3. Use `mark_done "toolbox_mytoolbox"` at the end

## Commit Messages

Format: `[component] description`

Examples:
- `[core/vanish] add encrypted RAM wipe option`
- `[toolbox/wifi] fix 32-bit hashcat detection`
- `[lib] add disk space check helper`
- `[ci] add Alpine 3.21 test matrix`

## Legal

NecrOS is under MIT license. By contributing, you agree to license your code under MIT.

NecrOS is an **educational tool**. Do not add features designed for malicious use.
