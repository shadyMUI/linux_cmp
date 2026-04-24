#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# Arch Gaming OS — archiso profile definition
# Questa è la definizione del profilo per mkarchiso.

iso_name="archgaming"
iso_label="ARCHGAMING_$(date +%Y%m)"
iso_publisher="Arch Gaming OS <https://github.com/shadyMUI/linux_cmp>"
iso_application="Arch Gaming OS Live/Install"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('uefi-x64.systemd-boot.esp' 'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15')

# Permessi file specifici
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/polkit-1/rules.d/49-gaming-power.rules"]="0:0:644"
  ["/usr/local/bin/gaming-poweroff"]="0:0:755"
  ["/usr/local/bin/gaming-reboot"]="0:0:755"
  ["/usr/local/bin/gaming-suspend"]="0:0:755"
  ["/usr/local/bin/gaming-update"]="0:0:755"
  ["/usr/local/bin/install-archgaming"]="0:0:755"
  ["/usr/local/bin/post-install-chroot"]="0:0:755"
  ["/usr/local/bin/pacman-snapshot"]="0:0:755"
)
