#!/usr/bin/env bash
set -Eeuo pipefail

readonly EXPECTED_BY_ID="/dev/disk/by-id/usb-Samsung_PSSD_T7_Shield_S6NSNJ0W901819H-0:0"
readonly EXPECTED_MODEL="PSSD_T7_Shield"
readonly EXPECTED_SERIAL="Samsung_PSSD_T7_Shield_S6NSNJ0W901819H-0:0"
readonly CONFIRMATION="ERASE S6NSNJ0W901819H"
readonly DISK_GUID="4e09161a-2e88-4e8c-921e-16f99eed5919"
readonly ESP_GUID="f56f1c9a-f1bf-4f4e-8edf-171518083a2d"
readonly LUKS_PART_GUID="3a3789b9-541f-433f-ae61-de54f029e6b1"
readonly ESP_ID="0d08e253"
readonly LUKS_UUID="4505e5ba-379c-4c90-a0d7-10586dfe84ef"
readonly BTRFS_UUID="e3f960b7-e183-4fa8-948e-e3e555a75f56"
readonly MAPPER_NAME="cryptroot"
readonly INSTALL_ROOT="/mnt"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

usage() {
  echo "Usage: $0 [--preflight-only | --set-password-only | --update-existing]"
  echo
  echo "With no option, this irreversibly erases the bound Samsung T7 Shield."
  echo "--set-password-only mounts an existing installation and changes nop's password."
  echo "--update-existing installs the current flake into an existing portable system."
}

PREFLIGHT_ONLY=false
SET_PASSWORD_ONLY=false
UPDATE_EXISTING=false
case "${1:-}" in
  "") ;;
  --preflight-only) PREFLIGHT_ONLY=true ;;
  --set-password-only) SET_PASSWORD_ONLY=true ;;
  --update-existing) UPDATE_EXISTING=true ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

required_commands=(
  blkid btrfs chown cryptsetup env findmnt grep lsblk mkdir mkfs.btrfs mkfs.fat mount
  nix nixos-enter nixos-install partprobe rsync sgdisk shellcheck sync udevadm umount
  wipefs
)

missing=()
for command_name in "${required_commands[@]}"; do
  command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
done

if ((${#missing[@]} > 0)); then
  if [[ "${MY_NIX_INSTALL_ENV:-0}" == "1" ]]; then
    echo "Missing required commands inside the installer environment: ${missing[*]}" >&2
    exit 1
  fi

  echo "Entering a pinned Nix tool environment (missing: ${missing[*]})..."
  exec nix --extra-experimental-features "nix-command flakes" develop \
    "$REPO_DIR#installer" \
    --command env MY_NIX_INSTALL_ENV=1 "$0" "$@"
fi

if [[ ! -L "$EXPECTED_BY_ID" ]]; then
  echo "Refusing: expected disk link is absent: $EXPECTED_BY_ID" >&2
  exit 1
fi

DEVICE="$(readlink -f -- "$EXPECTED_BY_ID")"
if [[ ! -b "$DEVICE" || "$(lsblk -dnro TYPE -- "$DEVICE")" != "disk" ]]; then
  echo "Refusing: $EXPECTED_BY_ID does not resolve to a whole block device." >&2
  exit 1
fi

declare -A properties=()
while IFS='=' read -r key value; do
  properties["$key"]="$value"
done < <(udevadm info --query=property --name="$DEVICE")

if [[ "${properties[ID_MODEL]:-}" != "$EXPECTED_MODEL" ]]; then
  echo "Refusing: model mismatch (${properties[ID_MODEL]:-unknown})." >&2
  exit 1
fi
if [[ "${properties[ID_SERIAL]:-}" != "$EXPECTED_SERIAL" ]]; then
  echo "Refusing: serial mismatch (${properties[ID_SERIAL]:-unknown})." >&2
  exit 1
fi

DEVICE_SIZE="$(lsblk -bdnro SIZE -- "$DEVICE")"
if ((DEVICE_SIZE < 1900000000000 || DEVICE_SIZE > 2100000000000)); then
  echo "Refusing: unexpected capacity $DEVICE_SIZE bytes." >&2
  exit 1
fi

ROOT_SOURCE="$(findmnt -nro SOURCE /)"
if lsblk -srnpo NAME -- "$ROOT_SOURCE" 2>/dev/null | grep -Fxq -- "$DEVICE"; then
  echo "Refusing: target disk backs the running root filesystem." >&2
  exit 1
fi

echo "Validated target:"
lsblk -d -o NAME,SIZE,MODEL,SERIAL,TRAN -- "$DEVICE"
echo "Stable path: $EXPECTED_BY_ID"

if $PREFLIGHT_ONLY; then
  echo "Preflight passed. No changes were made."
  exit 0
fi

if findmnt -rn "$INSTALL_ROOT" >/dev/null 2>&1; then
  echo "Refusing: $INSTALL_ROOT is already a mount point; unmount it or choose another install host." >&2
  exit 1
fi

ESP_PART="${EXPECTED_BY_ID}-part1"
LUKS_PART="${EXPECTED_BY_ID}-part2"

cleanup() {
  set +e
  if findmnt -rn "$INSTALL_ROOT" >/dev/null 2>&1; then
    sudo "$(command -v umount)" -R "$INSTALL_ROOT"
  fi
  if sudo "$(command -v cryptsetup)" status "$MAPPER_NAME" >/dev/null 2>&1; then
    sudo "$(command -v cryptsetup)" close "$MAPPER_NAME"
  fi
}

mount_installed_layout() {
  sudo "$(command -v mount)" -o "subvol=@root,compress=zstd:3,noatime" "/dev/mapper/$MAPPER_NAME" "$INSTALL_ROOT"
  sudo "$(command -v mkdir)" -p \
    "$INSTALL_ROOT/boot" \
    "$INSTALL_ROOT/home" \
    "$INSTALL_ROOT/nix" \
    "$INSTALL_ROOT/var/log" \
    "$INSTALL_ROOT/.snapshots"
  sudo "$(command -v mount)" -o "subvol=@home,compress=zstd:3,noatime" "/dev/mapper/$MAPPER_NAME" "$INSTALL_ROOT/home"
  sudo "$(command -v mkdir)" -p "$INSTALL_ROOT/home/.snapshots"
  sudo "$(command -v mount)" -o "subvol=@nix,compress=zstd:3,noatime" "/dev/mapper/$MAPPER_NAME" "$INSTALL_ROOT/nix"
  sudo "$(command -v mount)" -o "subvol=@log,compress=zstd:3,noatime" "/dev/mapper/$MAPPER_NAME" "$INSTALL_ROOT/var/log"
  sudo "$(command -v mount)" -o "subvol=@snapshots-root,compress=zstd:3,noatime" "/dev/mapper/$MAPPER_NAME" "$INSTALL_ROOT/.snapshots"
  sudo "$(command -v mount)" -o "subvol=@snapshots-home,compress=zstd:3,noatime" "/dev/mapper/$MAPPER_NAME" "$INSTALL_ROOT/home/.snapshots"
  sudo "$(command -v mount)" "$ESP_PART" "$INSTALL_ROOT/boot"
}

validate_installed_filesystems() {
  if [[ "$(sudo "$(command -v blkid)" -s UUID -o value "$ESP_PART")" != "0D08-E253" ]] ||
     [[ "$(sudo "$(command -v blkid)" -s UUID -o value "$LUKS_PART")" != "$LUKS_UUID" ]]; then
    echo "Refusing: the installed partition UUIDs do not match this configuration." >&2
    return 1
  fi
  if [[ -e "/dev/mapper/$MAPPER_NAME" ]]; then
    echo "Refusing: /dev/mapper/$MAPPER_NAME already exists." >&2
    return 1
  fi

  sudo "$(command -v cryptsetup)" open "$LUKS_PART" "$MAPPER_NAME"
  if [[ "$(sudo "$(command -v blkid)" -s UUID -o value "/dev/mapper/$MAPPER_NAME")" != "$BTRFS_UUID" ]]; then
    echo "Refusing: the decrypted filesystem UUID does not match this configuration." >&2
    return 1
  fi
}

if $SET_PASSWORD_ONLY; then
  sudo -v
  trap cleanup EXIT

  validate_installed_filesystems

  sudo "$(command -v mount)" -o subvol=@root "/dev/mapper/$MAPPER_NAME" "$INSTALL_ROOT"
  sudo "$(command -v mkdir)" -p "$INSTALL_ROOT/nix" "$INSTALL_ROOT/boot"
  sudo "$(command -v mount)" -o subvol=@nix "/dev/mapper/$MAPPER_NAME" "$INSTALL_ROOT/nix"
  sudo "$(command -v mount)" "$ESP_PART" "$INSTALL_ROOT/boot"
  if ! sudo test -e "$INSTALL_ROOT/etc/NIXOS" ||
     ! sudo test -x "$INSTALL_ROOT/nix/var/nix/profiles/system/sw/bin/passwd"; then
    echo "Refusing: no completed NixOS installation was found." >&2
    exit 1
  fi

  echo "Set the login password for nop:"
  sudo "$(command -v env)" LC_ALL=C "$(command -v nixos-enter)" \
    --root "$INSTALL_ROOT" \
    -c "/nix/var/nix/profiles/system/sw/bin/passwd nop"
  test -f "$INSTALL_ROOT/boot/EFI/BOOT/BOOTX64.EFI"
  sudo "$(command -v sync)"
  echo "Password update and bootloader verification succeeded."
  exit 0
fi

if $UPDATE_EXISTING; then
  echo "Building the updated system before modifying the existing installation..."
  SYSTEM_PATH="$(nix --extra-experimental-features "nix-command flakes" build \
    "$REPO_DIR#nixosConfigurations.portable.config.system.build.toplevel" \
    --no-link \
    --print-out-paths)"
  readonly SYSTEM_PATH
  if [[ ! -x "$SYSTEM_PATH/bin/switch-to-configuration" ]]; then
    echo "Refusing: the completed build is not a NixOS system closure: $SYSTEM_PATH" >&2
    exit 1
  fi
  echo "Verified updated system closure: $SYSTEM_PATH"

  sudo -v
  trap cleanup EXIT
  validate_installed_filesystems
  mount_installed_layout
  if ! sudo test -e "$INSTALL_ROOT/etc/NIXOS"; then
    echo "Refusing: no completed NixOS installation was found." >&2
    exit 1
  fi

  sudo "$(command -v mkdir)" -p "$INSTALL_ROOT/home/nop/Projects/my-nix"
  sudo "$(command -v rsync)" -a --delete \
    --exclude=result \
    --exclude='result-*' \
    "$REPO_DIR/" "$INSTALL_ROOT/home/nop/Projects/my-nix/"
  sudo "$(command -v chown)" -R 1000:1000 "$INSTALL_ROOT/home/nop"
  sudo "$(command -v env)" LC_ALL=C "PATH=$SYSTEM_PATH/sw/bin:$PATH" "$(command -v nixos-install)" \
    --root "$INSTALL_ROOT" \
    --system "$SYSTEM_PATH" \
    --no-root-passwd

  test -f "$INSTALL_ROOT/boot/EFI/BOOT/BOOTX64.EFI"
  sudo "$(command -v sync)"
  echo "Existing installation updated and bootloader verified."
  exit 0
fi

echo "Building the complete generic system and NVIDIA specialization before erasing anything..."
SYSTEM_PATH="$(nix --extra-experimental-features "nix-command flakes" build \
  "$REPO_DIR#nixosConfigurations.portable.config.system.build.toplevel" \
  --no-link \
  --print-out-paths)"
readonly SYSTEM_PATH
if [[ ! -x "$SYSTEM_PATH/bin/switch-to-configuration" ]]; then
  echo "Refusing: the completed build is not a NixOS system closure: $SYSTEM_PATH" >&2
  exit 1
fi
echo "Verified system closure: $SYSTEM_PATH"

echo
echo "ALL DATA ON $DEVICE WILL BE DESTROYED."
read -r -p "Type '$CONFIRMATION' to continue: " response
if [[ "$response" != "$CONFIRMATION" ]]; then
  echo "Confirmation did not match; no disk changes were made."
  exit 1
fi

sudo -v
trap cleanup EXIT

while read -r node node_type; do
  if [[ "$node_type" == "part" ]] && findmnt -rn -S "$node" >/dev/null 2>&1; then
    # Unmount by the already verified block-device node. Parsing TARGET would
    # turn spaces into strings such as "\\x20", which are not real paths.
    sudo "$(command -v umount)" --all-targets -- "$node"
  fi
done < <(lsblk -nrpo NAME,TYPE -- "$DEVICE")

sudo "$(command -v wipefs)" --all --force "$DEVICE"
sudo "$(command -v sgdisk)" --zap-all "$DEVICE"
sudo "$(command -v sgdisk)" \
  --clear \
  --disk-guid="$DISK_GUID" \
  --new=1:0:+8GiB \
  --typecode=1:ef00 \
  --change-name=1:NIXBOOT \
  --partition-guid=1:"$ESP_GUID" \
  --new=2:0:0 \
  --typecode=2:8309 \
  --change-name=2:NIXCRYPT \
  --partition-guid=2:"$LUKS_PART_GUID" \
  "$DEVICE"
sudo "$(command -v partprobe)" "$DEVICE"
sudo "$(command -v udevadm)" settle

for _ in {1..10}; do
  [[ -b "$ESP_PART" && -b "$LUKS_PART" ]] && break
  sleep 1
done
if [[ ! -b "$ESP_PART" || ! -b "$LUKS_PART" ]]; then
  echo "Partition device links did not appear." >&2
  exit 1
fi

sudo "$(command -v mkfs.fat)" -F 32 -n NIXBOOT -i "$ESP_ID" "$ESP_PART"
echo "Create the portable disk's LUKS passphrase. Use characters available on a US keymap."
sudo "$(command -v cryptsetup)" luksFormat --type luks2 --uuid "$LUKS_UUID" "$LUKS_PART"
sudo "$(command -v cryptsetup)" open "$LUKS_PART" "$MAPPER_NAME"
sudo "$(command -v mkfs.btrfs)" -f -L NIXROOT -U "$BTRFS_UUID" "/dev/mapper/$MAPPER_NAME"

sudo "$(command -v mount)" "/dev/mapper/$MAPPER_NAME" "$INSTALL_ROOT"
for subvolume in @root @home @nix @log @snapshots-root @snapshots-home; do
  sudo "$(command -v btrfs)" subvolume create "$INSTALL_ROOT/$subvolume"
done
sudo "$(command -v umount)" "$INSTALL_ROOT"

mount_installed_layout

sudo "$(command -v mkdir)" -p "$INSTALL_ROOT/home/nop/Projects/my-nix"
sudo "$(command -v rsync)" -a --delete \
  --exclude=result \
  --exclude='result-*' \
  "$REPO_DIR/" "$INSTALL_ROOT/home/nop/Projects/my-nix/"
sudo "$(command -v chown)" -R 1000:1000 "$INSTALL_ROOT/home/nop"

sudo "$(command -v env)" LC_ALL=C "PATH=$SYSTEM_PATH/sw/bin:$PATH" "$(command -v nixos-install)" \
  --root "$INSTALL_ROOT" \
  --system "$SYSTEM_PATH" \
  --no-root-passwd

echo "Set the login password for nop:"
sudo "$(command -v env)" LC_ALL=C "$(command -v nixos-enter)" \
  --root "$INSTALL_ROOT" \
  -c "/nix/var/nix/profiles/system/sw/bin/passwd nop"

test "$(sudo "$(command -v blkid)" -s UUID -o value "$ESP_PART")" = "0D08-E253"
test "$(sudo "$(command -v blkid)" -s UUID -o value "$LUKS_PART")" = "$LUKS_UUID"
test "$(sudo "$(command -v blkid)" -s UUID -o value "/dev/mapper/$MAPPER_NAME")" = "$BTRFS_UUID"
test -f "$INSTALL_ROOT/boot/EFI/BOOT/BOOTX64.EFI"
sudo "$(command -v sync)"

echo "Installation and on-disk verification succeeded."
echo "Shut this host down, enable UEFI boot and disable Secure Boot, then select the T7 Shield."
echo "On this NVIDIA desktop, select the 'nvidia' specialization in GRUB."
