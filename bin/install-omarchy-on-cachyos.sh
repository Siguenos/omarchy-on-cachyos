#!/usr/bin/env bash
set -eEuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
source "$SCRIPT_DIR/release.sh"
source "$SCRIPT_DIR/check-platform.sh"
usage() {
  echo "Usage: bash $0 [--prepare-only] [--allow-arch-with-cachyos-kernel]"
  echo "--prepare-only downloads/verifies v$OMARCHY_VERSION without changing the system."
}
prepare_only=0
allow_arch=0
while (( $# )); do
  case $1 in
    --prepare-only) prepare_only=1 ;;
    --allow-arch-with-cachyos-kernel) allow_arch=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done
command -v git >/dev/null || { echo "Install git first." >&2; exit 1; }
export OMARCHY_SOURCE_DIR=${OMARCHY_SOURCE_DIR:-"$HOME/.cache/omarchy-on-cachyos/source-$OMARCHY_VERSION"}
if (( prepare_only )); then
  bash "$SCRIPT_DIR/fetch-omarchy.sh"
  exit 0
fi
(( EUID != 0 )) || { echo "Run as your normal user, without sudo." >&2; exit 1; }
os_release=/etc/os-release
[[ -r $os_release ]] || os_release=/usr/lib/os-release
omarchy_check_platform "$os_release" /etc/cachyos-release /etc/arch-release "$(uname -r)" "$allow_arch"
[[ $(uname -m) == x86_64 ]] || { echo "Only x86_64 is supported." >&2; exit 1; }
[[ $(findmnt -n -o FSTYPE /) == btrfs ]] || { echo "A Btrfs root is required." >&2; exit 1; }
for command in sudo pacman pacman-key makepkg snapper; do
  command -v "$command" >/dev/null || { echo "Required command missing: $command" >&2; exit 1; }
done
sudo snapper -c root get-config >/dev/null
for package in gnome-shell plasma-desktop omarchy omarchy-dev omarchy-settings omarchy-settings-dev; do
  if pacman -Qq "$package" 2>/dev/null | grep -Fxq "$package"; then
    echo "Found $package. Use a fresh CachyOS Hyprland installation; this is not a conversion tool." >&2
    exit 1
  fi
done
bash "$SCRIPT_DIR/fetch-omarchy.sh"
state_dir="$HOME/.local/state/omarchy-on-cachyos"
mkdir -p "$state_dir"
log="$state_dir/install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$log") 2>&1
trap 'echo "Stopped at line $LINENO. Log: $log. Fix the reported error before rebooting." >&2' ERR
echo "Omarchy $OMARCHY_VERSION on CachyOS (community adapter; experimental)."
echo "Installs desktop/apps and replaces desktop configs. Keeps CachyOS kernel, drivers and bootloader."
echo "Omarchy desktop packages take precedence over CachyOS packages with the same names."
read -r -p "Type INSTALL to continue: " answer
[[ $answer == INSTALL ]] || exit 0
read -r -p "Git display name (optional): " OMARCHY_USER_NAME
read -r -p "Git email (optional): " OMARCHY_USER_EMAIL
export OMARCHY_USER_NAME OMARCHY_USER_EMAIL
backup="$state_dir/backup-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$backup"
sudo cp -a /etc/pacman.conf "$backup/pacman.conf"
[[ ! -e $HOME/.config ]] || cp -a "$HOME/.config" "$backup/config"
[[ ! -e $HOME/.bashrc ]] || cp -a "$HOME/.bashrc" "$backup/bashrc"
[[ ! -e $HOME/.local/state/omarchy ]] || cp -a "$HOME/.local/state/omarchy" "$backup/omarchy-state"
[[ ! -e $HOME/.local/share/applications ]] || cp -a "$HOME/.local/share/applications" "$backup/applications"
[[ ! -e $HOME/.local/share/icons ]] || cp -a "$HOME/.local/share/icons" "$backup/icons"
sudo snapper -c root create --description "Before Omarchy on CachyOS $OMARCHY_VERSION"
echo "Config backup: $backup"
fingerprint=40DFB630FF42BCFFB047046CF0134EE680CAC571
sudo pacman-key --recv-keys "$fingerprint" --keyserver keys.openpgp.org
sudo pacman-key --lsign-key "$fingerprint"
new_config=$(mktemp)
awk -f "$SCRIPT_DIR/pacman-config.awk" /etc/pacman.conf > "$new_config"
sudo install -m 644 "$new_config" /etc/pacman.conf
rm -f "$new_config"
sudo pacman -Syu --needed base-devel git imagemagick omarchy-keyring
# Official Quattro packages pull in Limine. Build the reviewed CachyOS variant.
mkdir -p "$HOME/.cache/omarchy-on-cachyos"
build_dir=$(mktemp -d "$HOME/.cache/omarchy-on-cachyos/build.XXXXXX")
cp "$PROJECT_DIR/pkgbuilds/omarchy-cachyos/PKGBUILD" "$build_dir/"
# Optional local patches listed in the PKGBUILD source array.
for patch in "$PROJECT_DIR"/pkgbuilds/omarchy-cachyos/*.patch; do
  [[ ! -f $patch ]] || cp "$patch" "$build_dir/"
done
(cd "$build_dir" && makepkg --syncdeps --noconfirm)
package_list=$(cd "$build_dir" && makepkg --packagelist)
mapfile -t local_packages <<< "$package_list"
for package_file in "${local_packages[@]}"; do
  [[ -f $package_file ]] || { echo "Built package missing: $package_file" >&2; exit 1; }
done
sudo pacman -U --needed "${local_packages[@]}"
# The ISO normally installs this list. Preserve tealdeer and boot integration.
mapfile -t packages < <(sed 's/#.*//' "$OMARCHY_SOURCE_DIR/install/omarchy-base.packages" |
  awk 'NF && $1 !~ /^(tldr|plymouth|kernel-modules-hook)$/ {print $1}')
sudo pacman -S --needed "${packages[@]}" tealdeer pipewire pipewire-alsa pipewire-pulse qt6-wayland
# Retire hyprland.conf so it cannot override the new Lua configuration.
mkdir -p "$HOME/.config"
[[ ! -e $HOME/.config/hypr ]] || mv "$HOME/.config/hypr" "$backup/hypr-retired"
cp -a /usr/share/omarchy/config/. "$HOME/.config/"
mkdir -p "$HOME/.local/share/icons/hicolor" "$HOME/.local/share/applications"
cp -a /usr/share/omarchy/application-icons/hicolor/. "$HOME/.local/share/icons/hicolor/"
for desktop in /usr/share/omarchy/applications/hidden/*.desktop; do
  [[ ! -f $desktop ]] || cp "$desktop" "$HOME/.local/share/applications/"
done
mkdir -p "$HOME/.local/state/omarchy/toggles/hypr" "$HOME/.local/share/nautilus-python/extensions"
cp /usr/share/omarchy/default/hypr/toggles/flags.lua "$HOME/.local/state/omarchy/toggles/hypr/"
cp /usr/share/omarchy/default/nautilus-python/extensions/*.py "$HOME/.local/share/nautilus-python/extensions/"
export OMARCHY_PATH=/usr/share/omarchy
export OMARCHY_INSTALL="$OMARCHY_PATH/install"
export PATH="$OMARCHY_PATH/bin:$PATH"
export OMARCHY_SETUP_CONTEXT=cachyos
omarchy-provision-user --first-install
# Skip upstream system/hardware/login orchestrators, which assume Omarchy's
# drivers, Snapper policy, authentication and boot settings.
sudo systemctl enable sddm.service NetworkManager.service
sudo systemctl set-default graphical.target
echo "Installation completed. Log: $log"
echo "Reboot manually, then select Omarchy (Hyprland uwsm) in SDDM."
echo "Use sudo pacman -Syu for system packages; rebuild this fork for adapted Omarchy updates."
