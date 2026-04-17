#!/usr/bin/env bash
# =============================================================================
# LINUX_CMP - archiso Profile Definition
# =============================================================================

iso_name="linux_cmp"
iso_label="LINUX_CMP_$(date +%Y%m)"
iso_publisher="Linux CMP Project <https://github.com/linux-cmp>"
iso_application="Linux CMP - Ultimate Gaming Distribution"
iso_version="$(date +%Y.%m.%d)"

install_dir="arch"
buildmodes=('iso')
bootmodes=(
    'bios.syslinux.mbr'
    'bios.syslinux.eltorito'
    'uefi-ia32.grub.esp'
    'uefi-x64.grub.esp'
    'uefi-ia32.grub.eltorito'
    'uefi-x64.grub.eltorito'
)

arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')

# File permissions for airootfs
# [path]  [mode] [uid] [gid]
file_permissions=(
    ["/etc/shadow"]="0:0:0400"
    ["/etc/gshadow"]="0:0:0400"
    ["/etc/sudoers.d/gaming"]="0:0:0440"
    ["/usr/local/bin/gpu-driver-setup.sh"]="0:0:0755"
    ["/usr/local/bin/proton-ge-updater.sh"]="0:0:0755"
    ["/usr/local/bin/linux-cmp-postinstall.sh"]="0:0:0755"
    ["/usr/local/bin/linux-cmp-welcome.sh"]="0:0:0755"
)
