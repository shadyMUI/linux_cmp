#!/usr/bin/env bash
# =============================================================================
# LINUX_CMP - Post-Install Configuration Script
# =============================================================================
# Runs after first boot to finalize system configuration.
# =============================================================================
set -euo pipefail

readonly LOGFILE="/var/log/linux-cmp-postinstall.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOGFILE}"; }

# ---------------------------------------------------------------------------
# Configure SDDM for Wayland + Auto-detect session
# ---------------------------------------------------------------------------
configure_sddm() {
    log "Configuring SDDM..."

    mkdir -p /etc/sddm.conf.d

    cat > /etc/sddm.conf.d/linux-cmp.conf <<'SDDM'
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
SessionDir=/usr/share/wayland-sessions
CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1

[Theme]
Current=breeze

[Users]
MaximumUid=60000
MinimumUid=1000
SDDM

    systemctl enable sddm.service
    log "SDDM configured for Wayland."
}

# ---------------------------------------------------------------------------
# Configure KDE Plasma for gaming-optimal defaults
# ---------------------------------------------------------------------------
configure_kde_defaults() {
    log "Setting KDE Plasma gaming defaults..."

    local skel="/etc/skel"
    mkdir -p "${skel}/.config"

    # KWin compositing: prefer performance
    cat > "${skel}/.config/kwinrc" <<'KWIN'
[Compositing]
Backend=OpenGL
GLCore=true
GLPreferBufferSwap=e
OpenGLIsUnsafe=false
AnimationSpeed=2
Enabled=true
HiddenPreviews=5
WindowsBlockCompositing=false
LatencyPolicy=Low

[Wayland]
InputMethod=
VirtualKeyboardEnabled=false

[Xwayland]
Scale=1

[Effect-overview]
BorderActivate=9

[NightColor]
Active=false
KWIN

    # Force Wayland as default session
    cat > "${skel}/.config/kdeglobals" <<'GLOBALS'
[General]
TerminalApplication=konsole
TerminalService=org.kde.konsole.desktop

[KDE]
AnimationDurationFactor=0.5
SingleClick=false
GLOBALS

    cat > "${skel}/.config/kcminputrc" <<'INPUT'
[Mouse]
cursorSize=24
cursorTheme=breeze_cursors

[Libinput]
PointerAcceleration=-0.4
PointerAccelerationProfile=1
INPUT

    # Disable Baloo file indexer (saves CPU during gaming)
    cat > "${skel}/.config/baloofilerc" <<'BALOO'
[General]
dbVersion=2
exclude filters=*~,*.part,*.tmp,*.o,*.la,*.lo,*.loT,*.moc,moc_*,*.obj
first run=false
only basic indexing=true
BALOO

    log "KDE defaults configured."
}

# ---------------------------------------------------------------------------
# Enable essential services
# ---------------------------------------------------------------------------
enable_services() {
    log "Enabling system services..."

    local services=(
        NetworkManager.service
        bluetooth.service
        sddm.service
        fstrim.timer
        power-profiles-daemon.service
        firewalld.service
        systemd-timesyncd.service
        gpu-driver-setup.service
        proton-ge-updater.timer
    )

    for svc in "${services[@]}"; do
        systemctl enable "${svc}" 2>/dev/null && log "Enabled ${svc}" || warn "Could not enable ${svc}"
    done
}

# ---------------------------------------------------------------------------
# Configure Flatpak with Flathub
# ---------------------------------------------------------------------------
configure_flatpak() {
    log "Configuring Flatpak..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    log "Flathub added."
}

# ---------------------------------------------------------------------------
# Install paru (AUR helper) for the default user
# ---------------------------------------------------------------------------
install_aur_helper() {
    log "Installing paru AUR helper..."

    if command -v paru &>/dev/null; then
        log "paru already installed."
        return
    fi

    local tmpdir
    tmpdir="$(mktemp -d)"

    git clone https://aur.archlinux.org/paru-bin.git "${tmpdir}/paru-bin"
    pushd "${tmpdir}/paru-bin" > /dev/null
    # Build as nobody (makepkg refuses root)
    sudo -u nobody makepkg -si --noconfirm 2>&1 | tee -a "${LOGFILE}" || {
        warn "paru install as nobody failed, will be installed per-user on first login."
    }
    popd > /dev/null
    rm -rf "${tmpdir}"
}

# ---------------------------------------------------------------------------
# GameMode configuration
# ---------------------------------------------------------------------------
configure_gamemode() {
    log "Configuring Feral GameMode..."

    mkdir -p /etc
    cat > /etc/gamemode.ini <<'GAMEMODE'
[general]
reaper_freq=5
desiredgov=performance
softrealtime=auto
renice=10
ioprio=0
inhibit_screensaver=1

[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=0
amd_performance_level=high
nv_powermizer_mode=1
nv_core_clock_mhz_offset=0
nv_mem_clock_mhz_offset=0

[cpu]
park_cores=no
pin_cores=yes

[custom]
start=notify-send "GameMode" "Gaming optimizations activated"
end=notify-send "GameMode" "Gaming optimizations deactivated"
GAMEMODE

    log "GameMode configured."
}

# ---------------------------------------------------------------------------
# MangoHud default config
# ---------------------------------------------------------------------------
configure_mangohud() {
    log "Configuring MangoHud defaults..."

    local skel="/etc/skel"
    mkdir -p "${skel}/.config/MangoHud"

    cat > "${skel}/.config/MangoHud/MangoHud.conf" <<'MANGO'
### LINUX_CMP MangoHud Default Configuration ###

# Toggle
toggle_hud=Shift_R+F12
toggle_fps_limit=Shift_R+F1
toggle_logging=Shift_R+F2

# Display
legacy_layout=0
position=top-left
round_corners=8
background_alpha=0.4
font_size=20
text_outline
text_outline_thickness=1.5
font_file=/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf

# Metrics
fps
fps_color_change
frametime
frame_timing
cpu_stats
cpu_temp
cpu_power
gpu_stats
gpu_temp
gpu_core_clock
gpu_mem_clock
gpu_power
ram
vram
vulkan_driver
wine
gamemode
fsr
hdr

# Frametime graph
histogram

# Logging
output_folder=/tmp/mangohud_logs
log_duration=30
autostart_log=0
MANGO

    log "MangoHud configured."
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    log "================================================================"
    log "LINUX_CMP Post-Install Configuration"
    log "================================================================"

    configure_sddm
    configure_kde_defaults
    enable_services
    configure_flatpak
    configure_gamemode
    configure_mangohud
    install_aur_helper

    log "================================================================"
    log "Post-install complete. System ready for gaming."
    log "================================================================"
}

main "$@"
