#!/usr/bin/env bash
# =============================================================================
# LINUX_CMP - Competitive Gaming Distribution
# Master ISO Build Script (archiso-based)
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROFILE_DIR="${SCRIPT_DIR}/archiso-profile"
readonly WORK_DIR="${SCRIPT_DIR}/work"
readonly OUT_DIR="${SCRIPT_DIR}/out"
readonly LOG_FILE="${SCRIPT_DIR}/build-$(date +%Y%m%d-%H%M%S).log"
readonly ISO_LABEL="LINUX_CMP"
readonly ISO_VERSION="$(date +%Y.%m.%d)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[BUILD]${NC} $*" | tee -a "${LOG_FILE}"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*" | tee -a "${LOG_FILE}"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" | tee -a "${LOG_FILE}" >&2; }
info() { echo -e "${CYAN}[INFO]${NC}  $*" | tee -a "${LOG_FILE}"; }

check_prerequisites() {
    log "Checking build prerequisites..."

    if [[ "$(id -u)" -ne 0 ]]; then
        err "This script must be run as root (or via sudo)."
        exit 1
    fi

    local required_pkgs=(archiso git base-devel squashfs-tools libisoburn mtools dosfstools)
    local missing_pkgs=()

    for pkg in "${required_pkgs[@]}"; do
        if ! pacman -Qi "${pkg}" &>/dev/null; then
            missing_pkgs+=("${pkg}")
        fi
    done

    if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
        warn "Installing missing build dependencies: ${missing_pkgs[*]}"
        pacman -Sy --noconfirm --needed "${missing_pkgs[@]}"
    fi

    log "All prerequisites satisfied."
}

setup_cachyos_repo() {
    log "Setting up CachyOS repository keys..."

    # Import CachyOS keyring and mirrorlist if not already present
    if ! pacman -Qi cachyos-keyring &>/dev/null; then
        local CACHYOS_KEY="cachyos-keyring-20240331-1-any.pkg.tar.zst"
        local CACHYOS_MIRROR="cachyos-mirrorlist-18-1-any.pkg.tar.zst"
        local BASE_URL="https://mirror.cachyos.org/repo/x86_64/cachyos"

        curl -fLO "${BASE_URL}/${CACHYOS_KEY}" || true
        curl -fLO "${BASE_URL}/${CACHYOS_MIRROR}" || true

        pacman -U --noconfirm "${CACHYOS_KEY}" "${CACHYOS_MIRROR}" 2>/dev/null || {
            warn "CachyOS keyring install from binary failed, importing key manually..."
            pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
            pacman-key --lsign-key F3B607488DB35A47
        }
        rm -f "${CACHYOS_KEY}" "${CACHYOS_MIRROR}" 2>/dev/null || true
    fi

    log "CachyOS repository configured."
}

prepare_profile() {
    log "Preparing archiso profile..."

    # Clean previous work directory
    if [[ -d "${WORK_DIR}" ]]; then
        warn "Cleaning previous work directory..."
        rm -rf "${WORK_DIR}"
    fi

    mkdir -p "${OUT_DIR}"

    # Verify profile structure
    if [[ ! -f "${PROFILE_DIR}/profiledef.sh" ]]; then
        err "profiledef.sh not found in ${PROFILE_DIR}"
        exit 1
    fi

    if [[ ! -f "${PROFILE_DIR}/packages.x86_64" ]]; then
        err "packages.x86_64 not found in ${PROFILE_DIR}"
        exit 1
    fi

    # Ensure all scripts in airootfs are executable
    find "${PROFILE_DIR}/airootfs/" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    chmod +x "${PROFILE_DIR}/airootfs/usr/local/bin/"* 2>/dev/null || true

    log "Profile ready at ${PROFILE_DIR}"
}

build_iso() {
    log "=========================================="
    log " Starting ISO build: ${ISO_LABEL} v${ISO_VERSION}"
    log "=========================================="

    mkarchiso -v \
        -w "${WORK_DIR}" \
        -o "${OUT_DIR}" \
        "${PROFILE_DIR}" \
        2>&1 | tee -a "${LOG_FILE}"

    local iso_file
    iso_file="$(find "${OUT_DIR}" -name '*.iso' -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2)"

    if [[ -n "${iso_file}" && -f "${iso_file}" ]]; then
        local iso_size
        iso_size="$(du -h "${iso_file}" | cut -f1)"
        log "=========================================="
        log " BUILD SUCCESSFUL"
        log " ISO: ${iso_file}"
        log " Size: ${iso_size}"
        log "=========================================="

        # Generate SHA256 checksum
        sha256sum "${iso_file}" > "${iso_file}.sha256"
        log "Checksum: ${iso_file}.sha256"
    else
        err "ISO build failed. Check ${LOG_FILE} for details."
        exit 1
    fi
}

clean() {
    log "Cleaning build artifacts..."
    rm -rf "${WORK_DIR}"
    log "Clean complete."
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [COMMAND]

Commands:
    build       Full build (prerequisites + profile + ISO)
    clean       Remove work directory
    rebuild     Clean + full build
    help        Show this message

Example:
    sudo ./build.sh build
EOF
}

main() {
    local cmd="${1:-build}"

    case "${cmd}" in
        build)
            check_prerequisites
            setup_cachyos_repo
            prepare_profile
            build_iso
            ;;
        clean)
            clean
            ;;
        rebuild)
            clean
            check_prerequisites
            setup_cachyos_repo
            prepare_profile
            build_iso
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            err "Unknown command: ${cmd}"
            usage
            exit 1
            ;;
    esac
}

main "$@"
