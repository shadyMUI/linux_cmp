#!/bin/bash
# ============================================================
# build-iso.sh — Arch Gaming OS ISO Builder
# ============================================================
# Esegui come root su un sistema Arch Linux con 'archiso' installato.
#
# Uso: sudo ./scripts/build-iso.sh
#
# Prerequisiti:
#   sudo pacman -S archiso
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROFILE_DIR="${PROJECT_ROOT}/archiso-profile"
WORK_DIR="/tmp/archiso-work"
OUT_DIR="${PROJECT_ROOT}/out"

# Verifica che siamo root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Questo script deve essere eseguito come root."
    echo "Uso: sudo $0"
    exit 1
fi

# Verifica che archiso sia installato
if ! command -v mkarchiso &> /dev/null; then
    echo "ERROR: 'archiso' non è installato."
    echo "Installa con: sudo pacman -S archiso"
    exit 1
fi

# Pulizia work dir precedente (se esiste)
if [[ -d "$WORK_DIR" ]]; then
    echo ">>> Pulizia work directory precedente..."
    rm -rf "$WORK_DIR"
fi

# Crea output directory
mkdir -p "$OUT_DIR"

echo "============================================================"
echo "  Arch Gaming OS — ISO Build"
echo "  Profile: ${PROFILE_DIR}"
echo "  Work:    ${WORK_DIR}"
echo "  Output:  ${OUT_DIR}"
echo "============================================================"

# Build ISO
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

echo ""
echo "============================================================"
echo "  Build completata!"
echo "  ISO: $(ls -1 ${OUT_DIR}/*.iso 2>/dev/null | tail -1)"
echo "============================================================"
