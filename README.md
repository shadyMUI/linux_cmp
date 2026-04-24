# Arch Gaming OS

Distribuzione Linux custom ottimizzata per il gaming su PC desktop, basata su Arch Linux.

## Architettura

- **Base:** Arch Linux (rolling release)
- **Kernel:** Custom con patch BORE scheduler, Zen tweaks, HZ 1000
- **Stack Grafico:** Wayland + Gamescope (no X11, no DE tradizionale)
- **GPU:** Mesa/RADV/ACO (AMD) | Driver proprietari (NVIDIA)
- **Gaming Stack:** Proton-GE, GameMode, MangoHud
- **Boot Mode:** Kiosk → Gamescope → Steam Big Picture Mode
- **Filesystem:** BTRFS con subvolumes e snapshot automatici

## Struttura del Progetto

```
linux_cmp/
├── archiso-profile/         # Profilo archiso per la build ISO
│   ├── airootfs/            # Overlay filesystem (config + scripts)
│   ├── efiboot/             # Bootloader EFI per la live ISO
│   ├── packages.x86_64     # Lista pacchetti
│   ├── pacman.conf          # Config pacman per il build
│   └── profiledef.sh        # Definizione profilo
├── configs/                 # Configurazioni standalone (reference)
│   ├── kernel/              # Config kernel custom (Fase 2)
│   └── gaming/              # GameMode, MangoHud (Fase 4)
└── scripts/                 # Script di build e automazione
```

## Build ISO

Richiede un sistema Arch Linux con `archiso` installato:

```bash
sudo pacman -S archiso
sudo mkarchiso -v -w /tmp/archiso-work -o /tmp/archiso-out ./archiso-profile/
```

## Stato del Progetto

- [x] Fase 0 — Analisi architetturale (→ Arch Linux)
- [x] Fase 1 — Bootstrap sistema base
- [x] Fase 2 — Kernel custom
- [x] Fase 3 — Stack grafico Wayland + Gamescope
- [x] Fase 4 — Integrazione stack gaming
- [x] Fase 5 — UX Kiosk
- [x] Fase 6 — Packaging ISO e distribuzione

## Licenza

GPL-2.0 (coerente con il kernel Linux)
