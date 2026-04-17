#!/usr/bin/env bash
# =============================================================================
# LINUX_CMP - Proton-GE Automatic Updater
# =============================================================================
# Checks for and installs the latest Proton-GE release for all users.
# Designed to run via systemd timer or manually.
# =============================================================================
set -euo pipefail

readonly PROTON_DIR="/usr/share/steam/compatibilitytools.d"
readonly GH_API="https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest"
readonly LOGFILE="/var/log/proton-ge-updater.log"
readonly LOCK="/tmp/proton-ge-updater.lock"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOGFILE}"; }

cleanup() {
    rm -f "${LOCK}"
}
trap cleanup EXIT

# Prevent concurrent runs
if [[ -f "${LOCK}" ]]; then
    log "Another instance is running. Exiting."
    exit 0
fi
echo $$ > "${LOCK}"

get_latest_version() {
    curl -fsSL "${GH_API}" 2>/dev/null \
        | grep '"tag_name"' \
        | head -1 \
        | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/'
}

get_installed_version() {
    if [[ -d "${PROTON_DIR}" ]]; then
        # Find most recent Proton-GE directory
        ls -1d "${PROTON_DIR}"/GE-Proton* 2>/dev/null \
            | sort -V \
            | tail -1 \
            | xargs -r basename
    fi
}

install_proton_ge() {
    local version="$1"
    local tarball="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${version}/${version}.tar.gz"

    log "Downloading ${version}..."
    local tmpdir
    tmpdir="$(mktemp -d)"

    if curl -fSL "${tarball}" -o "${tmpdir}/${version}.tar.gz"; then
        mkdir -p "${PROTON_DIR}"
        log "Extracting to ${PROTON_DIR}..."
        tar -xzf "${tmpdir}/${version}.tar.gz" -C "${PROTON_DIR}/"
        log "Proton-GE ${version} installed successfully."

        # Cleanup old versions (keep last 2)
        local versions
        versions="$(ls -1d "${PROTON_DIR}"/GE-Proton* 2>/dev/null | sort -V)"
        local count
        count="$(echo "${versions}" | wc -l)"

        if [[ ${count} -gt 2 ]]; then
            local to_remove
            to_remove="$(echo "${versions}" | head -n $((count - 2)))"
            for old in ${to_remove}; do
                log "Removing old version: $(basename "${old}")"
                rm -rf "${old}"
            done
        fi
    else
        log "ERROR: Failed to download ${version}"
    fi

    rm -rf "${tmpdir}"
}

# Also install per-user for any existing home directories
install_per_user() {
    local version="$1"
    for home_dir in /home/*/; do
        local user
        user="$(basename "${home_dir}")"
        local user_proton="${home_dir}.steam/root/compatibilitytools.d"

        if [[ -d "${home_dir}.steam" ]]; then
            mkdir -p "${user_proton}"
            # Symlink to system-wide install
            if [[ -d "${PROTON_DIR}/${version}" ]]; then
                ln -sfn "${PROTON_DIR}/${version}" "${user_proton}/${version}"
                chown -h "${user}:${user}" "${user_proton}/${version}"
                log "Linked ${version} for user ${user}"
            fi
        fi
    done
}

main() {
    log "=== Proton-GE Update Check ==="

    local latest
    latest="$(get_latest_version)"

    if [[ -z "${latest}" ]]; then
        log "ERROR: Could not fetch latest version from GitHub."
        exit 1
    fi

    local installed
    installed="$(get_installed_version)"

    log "Latest:    ${latest}"
    log "Installed: ${installed:-none}"

    if [[ "${latest}" == "${installed}" ]]; then
        log "Already up to date."
        exit 0
    fi

    install_proton_ge "${latest}"
    install_per_user "${latest}"

    log "=== Update complete ==="
}

main "$@"
