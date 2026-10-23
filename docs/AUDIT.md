# NecrOS-G4 — Audit technique

> État au démarrage de la branche `claude/audit-1`.
> Base auditée : commit `main` « Add GitHub Pages landing page for NecrOS-G4 ».
> Objectif : décrire l'architecture **réelle**, les écarts entre le README et le
> code, et la dette technique. Les corrections sont faites dans des commits
> séparés sur `claude/audit-1` ; ce document est la photo *avant* travaux (les
> sections « Résolu » sont annotées au fur et à mesure).

---

## 1. Architecture réelle

NecrOS-G4 n'est **pas** une distribution au sens d'une image système complète.
C'est un **ensemble de scripts shell POSIX** qui transforment une base
Alpine/Adélie déjà installée en poste de pentest, plus un générateur d'artefacts
(ISO x86, bundle PPC).

```
                      install.sh  (bootstrap réseau)
                           │  télécharge le dépôt, puis exécute ↓
                           ▼
   necro_install.sh  ──source──▶  lib/necros-common.sh  (bibliothèque partagée)
        │                              ▲        ▲
        │ déploie dans /usr/local/necros│        │ source au runtime
        ▼                              │        │
   core/*.sh   ───────────────────────┘        │
   (vanish, payload, recon, sysinfo, update,    │
    splash[service OpenRC])                      │
        │ symlinks ▶ /usr/local/bin/necros-*     │
        ▼                                        │
   toolbox/install_*.sh ──────────────────────── ┘
   (wifi, web, reverse, blue, osint, crypto)
```

### Composants

| Composant | Rôle réel | Exécuté quand |
|---|---|---|
| `install.sh` | Bootstrap réseau : root/base check, télécharge le dépôt, lance `necro_install.sh`. | `wget … \| sh` sur une base vierge |
| `necro_install.sh` | **Installeur principal**. Détection matériel, dépôts, paquets, GUI, shell, déploiement, thème, wordlists. | Sur la cible, en root |
| `lib/necros-common.sh` | Bibliothèque sourcée : couleurs, logs, détection arch/distro, probes, helpers paquets, swap, marqueurs idempotents, bannière. | Sourcée par tout le reste |
| `core/*.sh` | Outils runtime installés dans `/usr/local/necros/core`, symlinkés `necros-*`. | Par l'utilisateur après install |
| `toolbox/install_*.sh` | Installeurs modulaires de catégories d'outils. | À la demande via `necros-toolbox` |
| `build_iso.sh` | Fabrique une ISO live (x86/x86_64 via Alpine `mkimage`) ou un bundle d'install PPC. | Sur un hôte Alpine, en root |
| `tests/test_lib.sh` | Suite de tests maison (pas de framework). | `make test` / CI |
| `.github/workflows/ci.yml` | CI : lint, syntax, tests Ubuntu + conteneur Alpine. | Push / PR |

### Déterminations clés

- **`install.sh` vs `necro_install.sh` ne sont pas des doublons fonctionnels.**
  `install.sh` est un *bootstrap* qui s'exécute **avant** que le dépôt n'existe
  sur la machine ; il ne peut donc pas sourcer `lib/necros-common.sh`. La vraie
  redondance est le code de *bootstrap dupliqué* (bannière ANSI, check root,
  check base) présent à la fois dans `install.sh` et dans la lib. C'est ce qui
  est factorisé, pas la fusion des deux fichiers (voir §4).
- **L'outil qui « fait foi » pour installer sur une cible est
  `necro_install.sh`.** `install.sh` ne fait que le récupérer et l'appeler.

---

## 2. Écarts README ↔ code

| # | README / CHANGELOG affirme | Réalité du code | Gravité |
|---|---|---|---|
| E1 | « Installation rapide : `wget … /install.sh \| sh` » | `install.sh` pointe vers `https://github.com/WaD45/NecrOS-G4-G4-G4` (suffixe triplé). Le clone **échoue toujours**. | 🔴 Bloquant |
| E2 | `necros-update` met NecrOS à jour | `core/update.sh` utilise la **même URL cassée** `-G4-G4-G4`. Le self-updater ne peut ni vérifier ni tirer. | 🔴 Bloquant |
| E3 | « Installation idempotente, relançable » | Vrai pour les étapes `run_once`, mais `deploy_necros_files()` fait `mkdir -p "$_dest"/{lib,core,…}` : **ash/dash n'étendent pas les accolades**, un seul dossier littéral `{lib,core,toolbox,wordlists}` est créé → déploiement cassé sur la cible. | 🔴 Bloquant |
| E4 | « All scripts pass shellcheck / POSIX sh » | 39 usages de `local` → `SC3043` sous `shellcheck -s sh`. Toléré par ash/dash mais **non POSIX strict** ; l'affirmation est fausse telle quelle. | 🟠 Majeur |
| E5 | Sécurité implicite d'un OS « pentest » | Oh My Zsh via `curl … \| sh` **sans vérification** ; GEF, radare2, rockyou, dirb téléchargés **sans checksum**. Aucune vérification d'intégrité nulle part. | 🔴 Majeur (sécurité) |
| E6 | « 6 toolboxes modulaires » + alacritty mentionné | Le code installe toujours `rxvt-unicode` (les deux branches de `if is_32bit` sont identiques) ; alacritty n'est jamais installé. | 🟡 Mineur |
| E7 | README liste `necros-crypt` comme outil `core/` | `necros-crypt` n'existe **que** généré par `toolbox/install_crypto.sh`. Il n'est pas dans `core/`, pas déployé par `deploy_necros_files`, pas symlinké. Absent en `--minimal`. | 🟡 Mineur |
| E8 | README : arbre projet montre `profiles/` ; CONTRIBUTING aussi | Le dossier `profiles/` n'existe pas. `build_iso.sh` génère le profil mkimage à la volée. | 🟡 Mineur |
| E9 | CHANGELOG : « Alpine version auto-detection, no hardcoded URLs » | Vrai pour les dépôts APK, mais les URLs GitHub sont codées en dur **et fausses** (E1/E2). | 🟡 Mineur |
| E10 | README/CONTRIBUTING clonent `WaD45/NecrOS.git` | Ce dépôt est `NecrOS-G4`. Les exemples pointent vers le dépôt 32-bit d'origine. | 🟡 Mineur |
| E11 | `necros-audit` « Audit complet (Lynis) », `necros-seccheck` etc. listés en core | Ce sont des helpers générés par `toolbox/install_blue.sh`, pas des outils core. Indisponibles sans la toolbox blue. | 🟡 Mineur |

---

## 3. Dette technique

### 3.1 Sécurité de l'installeur (priorité absolue)
- **Aucune vérification d'intégrité** sur quoi que ce soit de téléchargé.
  - `curl -fsSL …ohmyzsh/install.sh | sh` → exécution de code distant arbitraire.
  - `wget …/gef.py -O /root/.gef.py` puis `source ~/.gef.py` dans `.gdbinit` → code distant chargé à chaque `gdb`.
  - `git clone …/radare2 && sys/install.sh` → build script distant en root.
  - `rockyou.txt`, `dirb/common.txt` → aucun checksum.
- **Pas de `--dry-run`** : impossible de voir ce que l'installeur ferait sans modifier le système.
- **Idempotence partielle** : les marqueurs `run_once` protègent les étapes, mais plusieurs effets de bord ne sont pas idempotents (réécriture `/etc/apk/repositories`, `chsh`, `rc-update`).

### 3.2 Qualité shell
- 39× `local` (SC3043) — non POSIX strict ; corrigé en linting `-s dash` (dialecte réel de la cible) + justification documentée.
- `A && B || C` (SC2015) à 12+ endroits : `C` peut s'exécuter même si `A` réussit mais `B` échoue → faux positifs de succès/erreur.
- `ls | grep` (SC2010) dans `recon.sh` génération de rapport.
- `eval "$@"` (SC2294) dans la suite de tests.
- Fallback de couleurs `\033[…]` passé à `printf '%s'` sans `%b` : certaines fonctions impriment la séquence littérale quand la lib n'est pas sourcée.
- Pas de `shfmt` appliqué : indentation et style hétérogènes.

### 3.3 Robustesse / fonctionnel
- E3 (brace expansion) : bug fonctionnel sur la cible.
- `install_gui()` : branche `is_32bit` morte (identique des deux côtés).
- `necros-crypt` non déployé en core alors qu'il est documenté comme tel (E7).
- `build_iso.sh` : chemin ISO manuel laisse un squashfs sans bootloader (pas d'ISO bootable réelle en fallback) — honnête dans les logs mais le `make build` peut « réussir » sans produire d'ISO.
- `get_disk_free_mb` via `df -m` : sur certaines busybox `df -m` n'est pas supporté → à vérifier.

### 3.4 Tests & CI
- La suite teste surtout l'existence de fonctions et la syntaxe ; **peu de tests comportementaux**.
- CI : le job `lint` fait `|| true` → **ne casse jamais** même en cas d'avertissement. Lint décoratif.
- Aucun test d'idempotence, aucun test de `--dry-run`, aucun smoke-test d'installation.
- Pas de `shfmt` dans la CI.

### 3.5 Portage PPC / Adélie
- `docs/powerbook-g4.md` est honnête (phase 1 runtime seulement, pas d'ISO PPC).
- **Mais** aucune vérification réelle de disponibilité des paquets par architecture.
  Beaucoup d'outils (hashcat, gnuradio, suricata…) peuvent manquer sur `ppc`
  dans Alpine/Adélie. Pas de matrice paquet × arch (produite dans
  `docs/package-matrix.md`).

---

## 4. Plan de remédiation (suivi sur `claude/audit-1`)

1. **Bugs bloquants** : URLs `-G4-G4-G4`, brace expansion, SC2015. → commit `fix:`
2. **Dédup bootstrap** : helpers de téléchargement vérifié dans `lib/`, rôles
   clarifiés entre `install.sh` et `necro_install.sh`. → commit `refactor:`
3. **Sécurité installeur** : vérif d'intégrité (checksums épinglés), suppression
   du `curl|sh`, `--dry-run`, idempotence renforcée. → commit `security:`
4. **Qualité** : shellcheck propre (`-s dash`), `shfmt`, directives source. → commit `style:`
5. **Tests** : helpers de vérif, dry-run, idempotence. → commit `test:`
6. **CI** : lint bloquant + shfmt + smoke dry-run en conteneur Alpine. → commit `ci:`
7. **PPC** : matrice paquet × arch, mise à jour doc. → commit `docs:`
8. **Docs/version** : README/CONTRIBUTING/CHANGELOG corrigés, bump cohérent. → commit `docs:`

Chaque point est détaillé dans le rapport final de la PR.
