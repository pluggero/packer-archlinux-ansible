#!/usr/bin/env bash
# ------------------------------------------------------------------------
# Title   : Arch Linux headless base-box installer (Packer-friendly)
# Author  : you@example.com
# License : MIT
# ------------------------------------------------------------------------
set -Eeuo pipefail
IFS=$'\n\t'

# ---------------------------- Configurable vars -------------------------
readonly DISK="${DISK_DEVICE:-$([[ ${PACKER_BUILDER_TYPE:-} == "qemu" ]] && echo "/dev/vda" || echo "/dev/sda")}"
readonly ROOT_PART="${DISK}2"

readonly FQDN="${FQDN:-arch-cleanroom}"
readonly KEYMAP="${KEYMAP:-us}"
readonly LANGUAGE="${LANGUAGE:-en_US.UTF-8}"
readonly PASSWORD_HASH="${PASSWORD_HASH:-$(openssl passwd -6 'vagrant')}"
readonly TIMEZONE="${TIMEZONE:-UTC}"
readonly COUNTRY="${COUNTRY:-US}"

readonly TARGET_DIR="/mnt"
readonly CONFIG_SCRIPT="/usr/local/bin/arch-config.sh"
readonly MIRRORLIST_URL="https://archlinux.org/mirrorlist/?country=${COUNTRY}&protocol=http&protocol=https&ip_version=4&use_mirror_status=on"
readonly MIRROR_COUNTRIES=("United States")

readonly LOG_FILE="/var/log/packer-arch-install.log"

# Package sets -----------------------------------------------------------
readonly PKG_BASE=(base base-devel linux linux-firmware)
readonly PKG_TOOLS=(gptfdisk openssh grub dhcpcd networkmanager python)

# ------------------------------ Utilities -------------------------------
log() { printf '%s %s\n' "==>" "$*" | tee -a "$LOG_FILE"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

cleanup() {
  umount -R "$TARGET_DIR" 2>/dev/null || true
}
trap cleanup INT TERM ERR EXIT

# ---------------------------- Main actions ------------------------------
partition_disk() {
  log "Partitioning ${DISK}"
  if sgdisk -p "$DISK" | grep -q 'root'; then
    log "Partitions already present, skipping."
    return
  fi

  sgdisk --zap             "$DISK"
  dd if=/dev/zero of="$DISK" bs=512 count=2048 status=none
  wipefs --all "$DISK"

  log "Creating partitions on $DISK"
  sgdisk -n1:0:+1MiB  -t1:ef02 -c1:grub "$DISK"   # BIOS boot
  sgdisk -n2:0:0      -t2:8300 -c2:root "$DISK"   # root
}

make_filesystems() {
  log "Creating ext4 on ${ROOT_PART}"
  if lsblk -f "$ROOT_PART" | grep -q ext4; then
    log "${ROOT_PART} already formatted."
    return
  fi
  mkfs.ext4 -F -m0 -L root "$ROOT_PART"
}

mount_root() {
  log "Mounting root to ${TARGET_DIR}"
  mount -o noatime "$ROOT_PART" "$TARGET_DIR"
}

configure_mirrors() {
  log "Configuring pacman mirrors (${COUNTRY})"
  curl -sSL "$MIRRORLIST_URL" | sed 's/^#Server/Server/' >/etc/pacman.d/mirrorlist
}

bootstrap_system() {
  log "Bootstrapping base system"
  pacstrap "$TARGET_DIR" "${PKG_BASE[@]}"
}

install_tools() {
  log "Installing extra packages in chroot"
  arch-chroot "$TARGET_DIR" pacman -Sy --noconfirm "${PKG_TOOLS[@]}"
}

write_chroot_script() {
  log "Writing chroot-side configuration script"
  cat <<CHROOT >"${TARGET_DIR}${CONFIG_SCRIPT}"
#!/usr/bin/env bash
set -Eeuo pipefail
echo "==> Running chroot configuration script"

# hostname, locale, time --------------------------------------------------
echo -n '$FQDN' > /etc/hostname
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

sed -i "s/#${LANGUAGE}/${LANGUAGE}/" /etc/locale.gen
locale-gen
echo "LANG=${LANGUAGE}" > /etc/locale.conf
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

# initramfs ---------------------------------------------------------------
mkinitcpio -P

# bootloader --------------------------------------------------------------
grub-install --target=i386-pc --recheck "${DISK}"
grub-mkconfig -o /boot/grub/grub.cfg

# networking --------------------------------------------------------------
systemctl enable NetworkManager.service

# ssh ---------------------------------------------------------------------
sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
systemctl enable sshd.service

# services ----------------------------------------------------------------
cat <<'EOF' >/etc/systemd/system/poweroff.timer
[Unit]
Description=Packer shutdown timer

[Timer]
OnActiveSec=1
Unit=poweroff.target
EOF

# mirrors -----------------------------------------------------------------
countries="\$(IFS=,; echo "${MIRROR_COUNTRIES[@]}")"
echo "==> Selecting fastest mirrors for: \$countries"
if ! command -v reflector &>/dev/null; then
  pacman -Sy --noconfirm reflector
fi
reflector --country "\$countries" --protocol https --sort rate --save /etc/pacman.d/mirrorlist
pacman -Syu --noconfirm


# root password -----------------------------------------------------------
usermod --password '${PASSWORD_HASH}' root

# vagrant user ------------------------------------------------------------
useradd --comment 'Vagrant User' --create-home --user-group vagrant
usermod --password '${PASSWORD_HASH}' vagrant
chown -R vagrant:vagrant /home/vagrant
echo 'Defaults env_keep += "SSH_AUTH_SOCK"' > /etc/sudoers.d/10_vagrant
echo 'vagrant ALL=(ALL) NOPASSWD: ALL'      >> /etc/sudoers.d/10_vagrant
chmod 0440 /etc/sudoers.d/10_vagrant
CHROOT

  chmod +x "${TARGET_DIR}${CONFIG_SCRIPT}"
}

run_chroot_config() {
  log "Running chroot configuration script"
  arch-chroot "$TARGET_DIR" "$CONFIG_SCRIPT"
  rm -f "${TARGET_DIR}${CONFIG_SCRIPT}"
}

finalize() {
  log "Generating fstab"
  genfstab -U "$TARGET_DIR" >>"$TARGET_DIR/etc/fstab"

  log "Syncing disks & unmounting"
  sleep 2
  umount -R "$TARGET_DIR"
}

main() {
  exec > >(tee -a "$LOG_FILE") 2>&1

  partition_disk
  make_filesystems
  mount_root
  configure_mirrors
  bootstrap_system
  install_tools
  write_chroot_script
  run_chroot_config
  finalize

  log "Installation complete – rebooting"
  reboot
}

main "$@"
