<p align="center">
  <img src="necroslogo2.png" alt="NecrOS Logo" width="1000"/>
</p>

# necros-g4 v1.0

### "Resurrecting the Silicon Dead"

**necros-g4** — Un OS de pentest ultra-léger basé sur Alpine Linux, avec un chemin de portage PowerPC orienté Adélie Linux, conçu pour faire revivre les vieilles machines et offrir un environnement de hacking complet sur du matériel limité.

---

## Philosophie

Les distributions de sécurité modernes (Kali, Parrot, BlackArch) sont devenues des usines à gaz inutilisables sur du matériel ancien. NecrOS ramène le pentest à ses racines : **léger, efficace, terminal-first**.

| | NecrOS | Kali | Parrot |
|---|---|---|---|
| **RAM minimum** | 256 MB | 2 GB | 1 GB |
| **Disque minimum** | 500 MB | 20 GB | 16 GB |
| **Support 32-bit natif** | Oui | Abandonné | Limité |
| **Base** | Alpine / Adélie (musl) | Debian (glibc) | Debian (glibc) |
| **Init** | OpenRC | systemd | systemd |

---

## Caractéristiques

- Support x86 (32-bit), x86\_64, ARM64, ARMv7 et PowerPC 32-bit (installation target)
- Fonctionne avec **256 MB de RAM** (swap automatique)
- Auto-adaptation : détecte les contraintes matérielles et ajuste l'installation
- Interface i3wm ultra-légère avec thème "Necromancer"
- 6 toolboxes modulaires (WiFi, Web, Reverse, Blue Team, OSINT, Crypto)
- Outils exclusifs : `necros-recon`, `necros-vanish`, `necros-payload`, `necros-crypt`
- Installation idempotente (relançable après échec)
- Self-updater intégré

---

## Installation

### Prérequis

| | Minimum | Recommandé |
|---|---|---|
| CPU | x86 (Pentium III+) / PowerPC G4 | Tout x86/x86\_64 |
| RAM | 256 MB | 512 MB |
| Disque | 500 MB | 5 GB |
| Base | Alpine Linux 3.18+ ou Adélie Linux | Alpine 3.20+ |

### Méthode 1 : Installation rapide (réseau)

```bash
# Sur un Alpine Linux ou Adélie Linux fraîchement installé :
wget -qO- https://raw.githubusercontent.com/WaD45/NecrOS-G4/main/install.sh | sh
```

### Méthode 2 : Installation manuelle

```bash
# 1. Installer Alpine Linux (mode "sys") ou Adélie Linux
# 2. Cloner le dépôt
git clone https://github.com/WaD45/NecrOS-G4.git
cd NecrOS-G4

# 3. Lancer l'installation
sh necro_install.sh

# Options disponibles :
sh necro_install.sh --minimal    # Core seulement, pas de GUI
sh necro_install.sh --full       # Tout, y compris toutes les toolboxes
sh necro_install.sh --no-gui     # Pas d'interface graphique
sh necro_install.sh --force      # Relancer toutes les étapes
```

### Portage PowerBook G4

Le support PowerBook G4 passe actuellement par une **installation sur un Linux PowerPC existant**,
avec **Adélie Linux** comme base cible prioritaire.
Le flux ISO live reste orienté x86/x86\_64. Pour générer l'artefact PPC :

```bash
make build-ppc
```

Cela produit un bundle d'installation contenant `necros.apkovl.tar.gz` et les scripts NecrOS,
prévu pour être copié sur la machine cible puis installé localement.

### Après l'installation

```bash
startx                 # Lancer i3wm
necros-toolbox         # Installer des outils supplémentaires
necros-sysinfo         # Voir l'état du système
```

---

## Outils NecrOS

### necros-recon — Reconnaissance automatisée

```bash
necros-recon target.com              # Recon standard
necros-recon 192.168.1.0/24 -q      # Scan rapide
necros-recon target.com -f -o out   # Scan complet + rapport
necros-recon target.com -p          # Passif uniquement (OSINT)
necros-recon target.com -w          # Focus web
```

### necros-payload — Générateur de payloads

```bash
necros-payload                       # Mode interactif
necros-payload reverse 1             # Bash TCP reverse shell
necros-payload reverse 4             # Netcat FIFO
necros-payload --lhost 10.0.0.1 --lport 9001 reverse 5
```

13 reverse shells, bind shells, web shells, templates MSFvenom, et shell upgrade.

### necros-vanish — Anti-forensics

```bash
necros-vanish              # Mode ghost (logs + history)
necros-vanish stealth      # Ghost + cache + réseau
necros-vanish nuclear -y   # Destruction totale
necros-vanish status       # Voir ce qui sera effacé
```

### necros-crypt — Crypto toolkit

```bash
necros-crypt hash file.bin           # Tous les hashes
necros-crypt b64enc "hello"          # Base64 encode
necros-crypt identify "5d41402..."   # Identifier un hash
necros-crypt genpass 32              # Mot de passe aléatoire
necros-crypt encrypt secret.txt     # Chiffrer AES-256
necros-crypt decrypt secret.txt.enc # Déchiffrer
```

### Autres

```bash
necros-toolbox          # Gestionnaire de toolboxes
necros-sysinfo          # Dashboard système
necros-update check     # Vérifier les mises à jour
necros-update pull      # Appliquer les mises à jour
necros-seccheck         # Check sécurité rapide
necros-audit            # Audit complet (Lynis)
necros-webrecon URL     # Recon web rapide
necros-dirscan URL      # Scan de répertoires
necros-bininfo binary   # Analyse rapide de binaire
necros-osint domain     # OSINT sur un domaine
necros-monitor wlan0 start  # Mode monitor WiFi
```

---

## Toolboxes

Installez uniquement ce dont vous avez besoin :

```bash
necros-toolbox wifi      # WiFi / Radio (aircrack-ng, reaver, SDR...)
necros-toolbox web       # Web Pentest (sqlmap, nikto, hydra, ffuf...)
necros-toolbox reverse   # Reverse Engineering (gdb+GEF, radare2, pwntools...)
necros-toolbox blue      # Blue Team (suricata, fail2ban, lynis, YARA...)
necros-toolbox osint     # OSINT (subfinder, shodan, theHarvester...)
necros-toolbox crypto    # Crypto & Stego (steghide, john, necros-crypt...)
necros-toolbox all       # Tout installer
necros-toolbox status    # Voir ce qui est installé
```

---

## Raccourcis i3

| Raccourci | Action |
|---|---|
| `Super+Enter` | Terminal |
| `Super+D` | Rofi (lanceur) |
| `Super+Space` | dmenu |
| `Super+Shift+Q` | Fermer fenêtre |
| `Super+H/J/K/L` | Navigation vim-style |
| `Super+1-9` | Workspaces |
| `Super+F` | Plein écran |
| `Super+R` | Mode resize |
| `Super+Escape` | Verrouiller |
| `Super+Shift+E` | Quitter i3 |

---

## Structure du projet

```
NecrOS/
├── lib/
│   └── necros-common.sh       # Bibliothèque partagée
├── core/
│   ├── vanish.sh              # Anti-forensics
│   ├── payload.sh             # Générateur de payloads
│   ├── recon.sh               # Reconnaissance automatisée
│   ├── sysinfo.sh             # Dashboard système
│   ├── update.sh              # Self-updater
│   └── splash.sh              # Boot animation
├── toolbox/
│   ├── install_wifi.sh        # WiFi / Radio
│   ├── install_web.sh         # Web Pentest
│   ├── install_reverse.sh     # Reverse Engineering
│   ├── install_blue.sh        # Blue Team
│   ├── install_osint.sh       # OSINT
│   └── install_crypto.sh      # Crypto & Stego
├── tests/
│   └── test_lib.sh            # Test suite
├── .github/workflows/
│   └── ci.yml                 # GitHub Actions CI
├── necro_install.sh           # Installeur principal
├── install.sh                 # Quick install (réseau)
├── build_iso.sh               # Constructeur d'ISO
├── Makefile                   # Build system
├── VERSION                    # Version unique
├── LICENSE                    # MIT
├── CHANGELOG.md               # Historique
└── CONTRIBUTING.md            # Guide de contribution
```

---

## Développement

```bash
make lint      # Shellcheck
make test      # Tests complets
make build     # Construire l'ISO (requiert Alpine)
make release   # Créer un tarball de release
```

---

## Avertissement légal

NecrOS est un outil **éducatif** destiné aux professionnels de la sécurité informatique. L'utilisation des outils fournis sur des systèmes ou réseaux sans autorisation explicite est **illégale**.

Utilisez NecrOS uniquement sur vos propres systèmes, en lab, ou avec autorisation écrite.

---

## Contribuer

Voir [CONTRIBUTING.md](CONTRIBUTING.md). Les contributions sont les bienvenues : bugs, nouveaux outils, documentation, toolboxes.

---

## Licence

MIT — Voir [LICENSE](LICENSE).

---

## Crédits

- **Base** : [Alpine Linux](https://alpinelinux.org)
- **Inspiration** : Kali Linux, BlackArch, Parrot OS, Tiny Core Linux
- **Philosophie** : *"Keep it simple, keep it light, keep it powerful"*

---

*"Dans les cendres du silicium oublié, le Nécromancien trouve sa puissance."*
