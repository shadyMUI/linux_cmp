#!/usr/bin/env bash
# =============================================================================
# LINUX_CMP - Welcome / First-Login Setup Script
# =============================================================================
# Runs on the user's first graphical login to finalize user-level setup.
# =============================================================================
set -euo pipefail

readonly MARKER="${HOME}/.config/linux-cmp/welcome-done"

if [[ -f "${MARKER}" ]]; then
    exit 0
fi

mkdir -p "${HOME}/.config/linux-cmp"

# ---------------------------------------------------------------------------
# Add user to required groups
# ---------------------------------------------------------------------------
for group in gamemode audio video render input; do
    if getent group "${group}" &>/dev/null; then
        sudo usermod -aG "${group}" "$(whoami)" 2>/dev/null || true
    fi
done

# ---------------------------------------------------------------------------
# Setup per-user Proton-GE symlinks
# ---------------------------------------------------------------------------
if [[ -d /usr/share/steam/compatibilitytools.d ]]; then
    mkdir -p "${HOME}/.steam/root/compatibilitytools.d"
    for proton in /usr/share/steam/compatibilitytools.d/GE-Proton*/; do
        if [[ -d "${proton}" ]]; then
            local_name="$(basename "${proton}")"
            ln -sfn "${proton}" "${HOME}/.steam/root/compatibilitytools.d/${local_name}"
        fi
    done
fi

# ---------------------------------------------------------------------------
# Create XDG user directories
# ---------------------------------------------------------------------------
xdg-user-dirs-update 2>/dev/null || true

# Create Steam and Games directories
mkdir -p "${HOME}/Games"
mkdir -p "${HOME}/.local/share/Steam"

# ---------------------------------------------------------------------------
# Setup MangoHud for Steam (launch option helper)
# ---------------------------------------------------------------------------
mkdir -p "${HOME}/.config/MangoHud"
if [[ ! -f "${HOME}/.config/MangoHud/MangoHud.conf" ]] && \
   [[ -f /etc/skel/.config/MangoHud/MangoHud.conf ]]; then
    cp /etc/skel/.config/MangoHud/MangoHud.conf "${HOME}/.config/MangoHud/"
fi

# ---------------------------------------------------------------------------
# Display welcome notification
# ---------------------------------------------------------------------------
if command -v notify-send &>/dev/null; then
    notify-send -i "applications-games" \
        "Welcome to Linux CMP" \
        "Your ultimate gaming system is ready.\n\n\
• Steam, Lutris, Heroic are installed\n\
• Proton-GE auto-updates weekly\n\
• MangoHud: Shift+F12 to toggle\n\
• GameMode: active on game launch\n\
\nHappy gaming! 🎮" \
        --expire-time=15000
fi

# Mark as done
touch "${MARKER}"
