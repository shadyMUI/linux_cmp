#!/usr/bin/env bash
# =============================================================================
# LINUX_CMP - GPU Driver Auto-Detection & Configuration
# =============================================================================
# Runs at boot (live) and post-install to detect GPU hardware and configure
# the optimal driver stack. Handles NVIDIA/AMD/Intel including hybrid setups.
# =============================================================================
set -euo pipefail

readonly LOGFILE="/var/log/linux-cmp-gpu-setup.log"
readonly NVIDIA_CONF="/etc/modprobe.d/nvidia-cmp.conf"
readonly MKINITCPIO_GPU="/etc/mkinitcpio.d/gpu-modules.conf"

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [GPU-SETUP] $*" | tee -a "${LOGFILE}"; }
warn() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [GPU-WARN]  $*" | tee -a "${LOGFILE}"; }
err()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [GPU-ERROR] $*" | tee -a "${LOGFILE}" >&2; }

# ---------------------------------------------------------------------------
# GPU Detection Functions
# ---------------------------------------------------------------------------

detect_gpus() {
    # Returns list of GPU vendors found via lspci VGA/3D classes
    # Class 0300 = VGA, Class 0302 = 3D controller (e.g., NVIDIA dGPU in Optimus)
    lspci -nn 2>/dev/null | grep -E '\[03(00|02)\]' || true
}

has_nvidia() {
    detect_gpus | grep -qi 'nvidia'
}

has_amd() {
    detect_gpus | grep -qi 'amd\|ati'
}

has_intel() {
    detect_gpus | grep -qi 'intel'
}

get_nvidia_device_id() {
    # Extract PCI device ID for NVIDIA GPU
    lspci -nn 2>/dev/null | grep -iE '(nvidia).*\[03(00|02)\]' \
        | grep -oP '\[10de:[0-9a-f]{4}\]' | head -1 | tr -d '[]' || echo ""
}

get_nvidia_generation() {
    # Determine NVIDIA GPU generation from device ID for optimal driver selection
    local dev_id
    dev_id="$(get_nvidia_device_id)"
    [[ -z "${dev_id}" ]] && echo "unknown" && return

    local num_id
    num_id="$(echo "${dev_id}" | cut -d: -f2)"
    local prefix="${num_id:0:2}"

    case "${prefix}" in
        # Ada Lovelace (RTX 40xx)
        26|27|28) echo "ada" ;;
        # Ampere (RTX 30xx)
        20|22|23|24|25) echo "ampere" ;;
        # Turing (RTX 20xx, GTX 16xx)
        1e|1f|21) echo "turing" ;;
        # Pascal (GTX 10xx)
        15|17|1b|1c|1d) echo "pascal" ;;
        # Maxwell
        13|14) echo "maxwell" ;;
        # Kepler
        0f|10|11|12) echo "kepler" ;;
        *) echo "unknown" ;;
    esac
}

# ---------------------------------------------------------------------------
# NVIDIA Configuration
# ---------------------------------------------------------------------------

configure_nvidia() {
    log "Configuring NVIDIA GPU..."

    local gen
    gen="$(get_nvidia_generation)"
    log "Detected NVIDIA generation: ${gen}"

    # Verify nvidia-dkms is installed
    if ! pacman -Qi nvidia-dkms &>/dev/null; then
        warn "nvidia-dkms not installed, attempting install..."
        pacman -S --noconfirm nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings 2>&1 | tee -a "${LOGFILE}"
    fi

    # Module parameters for maximum gaming performance
    cat > "${NVIDIA_CONF}" <<'MODPROBE'
# LINUX_CMP - NVIDIA Optimal Gaming Configuration
# DRM KMS required for Wayland & Gamescope
options nvidia_drm modeset=1 fbdev=1

# Preserve video memory on suspend/resume (prevents black screens)
options nvidia NVreg_PreserveVideoMemoryAllocations=1

# Enable PAT (Page Attribute Table) for better memory performance
options nvidia NVreg_UsePageAttributeTable=1

# Disable GSP firmware on problematic generations (can cause stuttering)
# Uncomment below if experiencing micro-stutters on Turing/Ampere:
# options nvidia NVreg_EnableGpuFirmware=0

# Power management for laptops (RTD3 for Turing+)
options nvidia NVreg_DynamicPowerManagement=0x02

# Increase shader cache size
options nvidia NVreg_RegistryDwords="RMSecBusResetDelay=250"
MODPROBE

    # Ensure nvidia modules load early in initramfs
    local mkinit_conf="/etc/mkinitcpio.conf"
    if [[ -f "${mkinit_conf}" ]]; then
        # Add nvidia modules to MODULES array if not present
        if ! grep -q 'nvidia nvidia_modeset nvidia_uvm nvidia_drm' "${mkinit_conf}"; then
            sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "${mkinit_conf}"
            # Remove duplicate spaces
            sed -i 's/MODULES=( /MODULES=(/' "${mkinit_conf}"
            log "Added NVIDIA modules to mkinitcpio.conf"
        fi
    fi

    # Pacman hook: rebuild initramfs on NVIDIA driver update
    mkdir -p /etc/pacman.d/hooks
    cat > /etc/pacman.d/hooks/nvidia.hook <<'HOOK'
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = nvidia-dkms
Target = linux-cachyos
Target = linux-cachyos-headers

[Action]
Description = Rebuilding initramfs after NVIDIA driver update...
Depends = mkinitcpio
When = PostTransaction
NeedsTargets
Exec = /usr/bin/mkinitcpio -P
HOOK

    # Enable nvidia-persistenced for lower latency on first GPU access
    systemctl enable nvidia-persistenced.service 2>/dev/null || true

    # Enable nvidia-powerd for dynamic boost (Ampere+)
    if [[ "${gen}" == "ampere" || "${gen}" == "ada" ]]; then
        systemctl enable nvidia-powerd.service 2>/dev/null || true
        log "Enabled nvidia-powerd (dynamic boost) for ${gen}"
    fi

    # Enable nvidia-suspend/resume/hibernate services
    systemctl enable nvidia-suspend.service 2>/dev/null || true
    systemctl enable nvidia-resume.service 2>/dev/null || true
    systemctl enable nvidia-hibernate.service 2>/dev/null || true

    # Create Wayland-compatible environment for NVIDIA
    mkdir -p /etc/environment.d
    cat > /etc/environment.d/50-nvidia-wayland.conf <<'ENV'
# NVIDIA Wayland support
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
# Electron/Chromium Wayland + VA-API
ELECTRON_OZONE_PLATFORM_HINT=auto
# Firefox hardware video decode
MOZ_ENABLE_WAYLAND=1
MOZ_DRM_DEVICE=/dev/dri/renderD128
# Disable VSync in compositor (let games handle it)
__GL_SYNC_TO_VBLANK=0
ENV

    log "NVIDIA configuration complete."
}

# ---------------------------------------------------------------------------
# AMD Configuration
# ---------------------------------------------------------------------------

configure_amd() {
    log "Configuring AMD GPU (Mesa/RADV stack)..."

    # Ensure Mesa/RADV packages
    local amd_pkgs=(mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon
                    libva-mesa-driver lib32-libva-mesa-driver
                    mesa-vdpau lib32-mesa-vdpau xf86-video-amdgpu)

    for pkg in "${amd_pkgs[@]}"; do
        if ! pacman -Qi "${pkg}" &>/dev/null; then
            pacman -S --noconfirm "${pkg}" 2>&1 | tee -a "${LOGFILE}" || true
        fi
    done

    # AMDGPU kernel parameters
    cat > /etc/modprobe.d/amdgpu-cmp.conf <<'MODPROBE'
# LINUX_CMP - AMDGPU Gaming Optimizations
# Enable FreeSync/VRR
options amdgpu dc=1

# GPU reset on hang (prevents hard locks)
options amdgpu gpu_recovery=1

# Enable power management performance mode
options amdgpu ppfeaturemask=0xffffffff

# Disable deep power down for faster wake (slight power cost)
options amdgpu dpm=1
MODPROBE

    # AMD-specific mkinitcpio modules
    local mkinit_conf="/etc/mkinitcpio.conf"
    if [[ -f "${mkinit_conf}" ]]; then
        if ! grep -q 'amdgpu' "${mkinit_conf}"; then
            sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 amdgpu)/' "${mkinit_conf}"
            log "Added amdgpu to mkinitcpio.conf"
        fi
    fi

    # Performance environment variables
    mkdir -p /etc/environment.d
    cat > /etc/environment.d/50-amd-gaming.conf <<'ENV'
# Force RADV (Vulkan) - superior for gaming vs AMDVLK
AMD_VULKAN_ICD=RADV
# Enable ACO shader compiler (faster compilation)
RADV_PERFTEST=aco
# Wayland native
MOZ_ENABLE_WAYLAND=1
ELECTRON_OZONE_PLATFORM_HINT=auto
# Disable VSync at driver level
vblank_mode=0
ENV

    log "AMD configuration complete."
}

# ---------------------------------------------------------------------------
# Intel Configuration
# ---------------------------------------------------------------------------

configure_intel() {
    log "Configuring Intel GPU (Mesa/ANV stack)..."

    local intel_pkgs=(vulkan-intel lib32-vulkan-intel
                      intel-media-driver libva-intel-driver lib32-libva-intel-driver)

    for pkg in "${intel_pkgs[@]}"; do
        if ! pacman -Qi "${pkg}" &>/dev/null; then
            pacman -S --noconfirm "${pkg}" 2>&1 | tee -a "${LOGFILE}" || true
        fi
    done

    # Intel i915/xe module options
    cat > /etc/modprobe.d/intel-cmp.conf <<'MODPROBE'
# LINUX_CMP - Intel GPU
# Enable GuC/HuC firmware for hardware video decode and scheduling
options i915 enable_guc=3
options i915 enable_fbc=1
options i915 fastboot=1

# Xe driver (Intel Arc+)
options xe force_probe=*
MODPROBE

    local mkinit_conf="/etc/mkinitcpio.conf"
    if [[ -f "${mkinit_conf}" ]]; then
        if ! grep -q 'i915' "${mkinit_conf}"; then
            sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 i915)/' "${mkinit_conf}"
            log "Added i915 to mkinitcpio.conf"
        fi
    fi

    mkdir -p /etc/environment.d
    cat > /etc/environment.d/50-intel-gaming.conf <<'ENV'
# Intel ANV Vulkan
INTEL_VULKAN_ICD=ANV
MOZ_ENABLE_WAYLAND=1
ELECTRON_OZONE_PLATFORM_HINT=auto
vblank_mode=0
ENV

    log "Intel configuration complete."
}

# ---------------------------------------------------------------------------
# Hybrid GPU Handling (NVIDIA Optimus / AMD+Intel)
# ---------------------------------------------------------------------------

configure_hybrid_nvidia_intel() {
    log "Detected hybrid NVIDIA + Intel GPU setup (Optimus)..."

    configure_nvidia
    configure_intel

    # PRIME render offload for NVIDIA as primary GPU
    cat > /etc/environment.d/60-prime-nvidia.conf <<'ENV'
# PRIME render offload: use NVIDIA for intensive workloads
__NV_PRIME_RENDER_OFFLOAD=1
__NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
__VK_LAYER_NV_optimus=NVIDIA_only
ENV

    # Provide a convenience script for PRIME offloading
    cat > /usr/local/bin/nvidia-offload <<'SCRIPT'
#!/bin/bash
export __NV_PRIME_RENDER_OFFLOAD=1
export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
exec "$@"
SCRIPT
    chmod +x /usr/local/bin/nvidia-offload

    log "Hybrid NVIDIA+Intel configured. Use 'nvidia-offload <app>' for dGPU."
}

configure_hybrid_nvidia_amd() {
    log "Detected hybrid NVIDIA + AMD GPU setup..."

    configure_nvidia
    configure_amd

    cat > /etc/environment.d/60-prime-nvidia-amd.conf <<'ENV'
__NV_PRIME_RENDER_OFFLOAD=1
__NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
__VK_LAYER_NV_optimus=NVIDIA_only
ENV

    cat > /usr/local/bin/nvidia-offload <<'SCRIPT'
#!/bin/bash
export __NV_PRIME_RENDER_OFFLOAD=1
export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
exec "$@"
SCRIPT
    chmod +x /usr/local/bin/nvidia-offload

    log "Hybrid NVIDIA+AMD configured."
}

# ---------------------------------------------------------------------------
# Blacklist Conflicting Modules
# ---------------------------------------------------------------------------

apply_blacklists() {
    log "Applying module blacklists..."

    if has_nvidia; then
        # Blacklist nouveau (conflicts with nvidia-dkms)
        cat > /etc/modprobe.d/blacklist-nouveau.conf <<'BL'
blacklist nouveau
options nouveau modeset=0
BL
        log "Blacklisted nouveau."
    fi

    # Blacklist watchdog and other unnecessary modules for reduced latency
    cat > /etc/modprobe.d/blacklist-cmp-misc.conf <<'BL'
# Reduce timer interrupts
blacklist iTCO_wdt
blacklist iTCO_vendor_support
# PC speaker (useless beep)
blacklist pcspkr
blacklist snd_pcsp
BL
}

# ---------------------------------------------------------------------------
# Rebuild Initramfs
# ---------------------------------------------------------------------------

rebuild_initramfs() {
    log "Rebuilding initramfs with updated GPU modules..."
    mkinitcpio -P 2>&1 | tee -a "${LOGFILE}"
    log "Initramfs rebuilt successfully."
}

# ---------------------------------------------------------------------------
# Main Entry Point
# ---------------------------------------------------------------------------

main() {
    log "================================================================"
    log "LINUX_CMP GPU Auto-Detection & Configuration"
    log "================================================================"

    local gpu_list
    gpu_list="$(detect_gpus)"
    log "Detected GPUs:"
    echo "${gpu_list}" | tee -a "${LOGFILE}"

    local nvidia_found=false
    local amd_found=false
    local intel_found=false

    has_nvidia && nvidia_found=true
    has_amd    && amd_found=true
    has_intel  && intel_found=true

    log "NVIDIA: ${nvidia_found} | AMD: ${amd_found} | Intel: ${intel_found}"

    # --- Determine configuration path ---
    if ${nvidia_found} && ${intel_found}; then
        configure_hybrid_nvidia_intel
    elif ${nvidia_found} && ${amd_found}; then
        configure_hybrid_nvidia_amd
    elif ${nvidia_found}; then
        configure_nvidia
    elif ${amd_found}; then
        configure_amd
    elif ${intel_found}; then
        configure_intel
    else
        warn "No recognized GPU detected! Falling back to generic Mesa."
        pacman -S --noconfirm mesa lib32-mesa 2>&1 | tee -a "${LOGFILE}" || true
    fi

    apply_blacklists

    # Rebuild initramfs to include configured modules
    if [[ "${1:-}" != "--no-rebuild" ]]; then
        rebuild_initramfs
    fi

    log "================================================================"
    log "GPU setup complete. A reboot is recommended."
    log "================================================================"
}

main "$@"
